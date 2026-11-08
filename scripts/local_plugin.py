#!/usr/bin/env python3
"""Transactional local deployment. No root privileges; only owned entries are removed."""
from __future__ import annotations

import argparse
import copy
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import time
import uuid

PLUGIN_ID = "jessie.switchboard"
BEGIN = "-- BEGIN jessie.switchboard (managed)"
END = "-- END jessie.switchboard (managed)"
ROOT = Path(__file__).resolve().parent.parent


def atomic_write(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, temporary = tempfile.mkstemp(prefix=".switchboard-", dir=path.parent)
    try:
        with os.fdopen(fd, "w") as stream:
            stream.write(text)
        if path.exists():
            os.chmod(temporary, path.stat().st_mode & 0o777)
        os.replace(temporary, path)
    finally:
        Path(temporary).unlink(missing_ok=True)


def strip_include(text: str) -> str:
    if text.count(BEGIN) != text.count(END) or text.count(BEGIN) > 1:
        raise ValueError("Managed binding block is malformed; repair its markers before deploying")
    return re.sub(r"(?m)^" + re.escape(BEGIN) + r"\n[\s\S]*?^" + re.escape(END) + r"\n?", "", text)


def lua_string(value: str) -> str:
    return '"' + ''.join('\\' + c if c in '\\"' else '\\%03d' % ord(c) if ord(c) < 32 else c for c in value) + '"'


def managed_include(path: Path) -> str:
    return (BEGIN + "\n" + "do\n  local chunk = loadfile(" + lua_string(str(path)) + ")\n"
            "  if chunk then\n    local ok, err = pcall(chunk)\n"
            "    if not ok then print(\"Switchboard bindings: \" .. tostring(err)) end\n"
            "  end\nend\n" + END + "\n")


def read_config(path: Path) -> dict:
    if not path.exists():
        default = Path(os.environ.get("OMARCHY_PATH", "/usr/share/omarchy")) / "config/omarchy/shell.json"
        data = json.loads(default.read_text())
    else:
        data = json.loads(path.read_text())
    if not isinstance(data, dict) or data.get("version") != 1 or not isinstance(data.get("plugins", []), list):
        raise ValueError("shell.json must have version: 1 and an array of plugins")
    entries = [e for e in data.get("plugins", []) if isinstance(e, dict) and e.get("id") == PLUGIN_ID]
    if len(entries) > 1:
        raise ValueError("Duplicate Switchboard entries in shell.json")
    return data


def replace_entry(config: dict, entry: dict | None) -> dict:
    out = copy.deepcopy(config)
    entries = out.setdefault("plugins", [])
    index = next((i for i, e in enumerate(entries) if isinstance(e, dict) and e.get("id") == PLUGIN_ID), len(entries))
    entries[:] = [e for e in entries if not (isinstance(e, dict) and e.get("id") == PLUGIN_ID)]
    if entry is not None:
        entries.insert(min(index, len(entries)), entry)
    return out


class Installer:
    def __init__(self, config_dir: Path | None = None, state_dir: Path | None = None, runner=None):
        # Omarchy itself currently scans ~/.config rather than XDG_CONFIG_HOME.
        self.config_dir = config_dir or Path.home() / ".config"
        self.state_dir = state_dir or Path(os.environ.get("XDG_STATE_HOME") or Path.home() / ".local/state") / "omarchy-switchboard"
        self.plugin = self.config_dir / "omarchy/plugins" / PLUGIN_ID
        self.shell_config = self.config_dir / "omarchy/shell.json"
        self.bindings = self.config_dir / "hypr/bindings.lua"
        self.metadata = self.state_dir / "installation.json"
        self.runner = runner or self.run

    @staticmethod
    def run(args: list[str]) -> str:
        result = subprocess.run(args, check=True, text=True, capture_output=True, timeout=8)
        return result.stdout.strip()

    def validate_desktop(self, strict_shell: bool = True) -> None:
        self.runner(["hyprctl", "reload"])
        errors = self.runner(["hyprctl", "configerrors"])
        if errors:
            raise RuntimeError("Hyprland configuration errors: " + errors)
        try:
            self.runner(["omarchy-shell", "shell", "rescanPlugins"])
        except subprocess.SubprocessError:
            if strict_shell:
                raise

    def backup(self) -> Path:
        self.state_dir.mkdir(parents=True, exist_ok=True)
        backup = Path(tempfile.mkdtemp(prefix=time.strftime("%Y%m%d-%H%M%S-"), dir=self.state_dir))
        for path, name in [(self.shell_config, "shell.json"), (self.bindings, "bindings.lua"), (self.metadata, "installation.json")]:
            if path.exists():
                shutil.copy2(path, backup / name)
        if self.plugin.exists():
            shutil.copytree(self.plugin, backup / "plugin", symlinks=True)
        return backup

    def rollback(self, backup: Path) -> None:
        for path, name in [(self.shell_config, "shell.json"), (self.bindings, "bindings.lua"), (self.metadata, "installation.json")]:
            if (backup / name).exists():
                atomic_write(path, (backup / name).read_text())
            else:
                path.unlink(missing_ok=True)
        if self.plugin.exists():
            shutil.rmtree(self.plugin)
        if (backup / "plugin").exists():
            shutil.copytree(backup / "plugin", self.plugin, symlinks=True)
        try:
            self.validate_desktop()
        except (subprocess.SubprocessError, RuntimeError):
            pass

    def install(self, binding_mode: bool | None) -> None:
        artifact = ROOT / "dist/plugin"
        if not (artifact / "manifest.json").exists():
            raise RuntimeError("Build dist/plugin before installing")
        config = read_config(self.shell_config)
        previous = next((e for e in config.get("plugins", []) if isinstance(e, dict) and e.get("id") == PLUGIN_ID), None)
        old_bindings = self.bindings.read_text() if self.bindings.exists() else ""
        clean_bindings = strip_include(old_bindings)
        mode = binding_mode if binding_mode is not None else bool(previous and previous.get("bindingsEnabled", False))
        backup = self.backup()
        metadata = json.loads(self.metadata.read_text()) if self.metadata.exists() else {
            "pluginId": PLUGIN_ID, "originalEntry": previous,
            "originalPlugin": str(backup / "plugin") if self.plugin.exists() else None,
            "bindingsExisted": self.bindings.exists(),
        }
        entry = dict(previous or {})
        entry.update(id=PLUGIN_ID, enabled=True, bindingsEnabled=mode)
        metadata["managedEntry"] = entry
        metadata["latestBackup"] = str(backup)
        self.plugin.parent.mkdir(parents=True, exist_ok=True)
        stage = Path(tempfile.mkdtemp(prefix=".switchboard-stage-", dir=self.plugin.parent))
        try:
            shutil.copytree(artifact, stage, dirs_exist_ok=True)
            # The host caches dynamically loaded QML by URL. A fresh runtime
            # path makes updates load every component and ESM from this build.
            build_id = uuid.uuid4().hex
            runtime = stage / "runtime" / build_id
            runtime.mkdir(parents=True)
            for name in ["Overlay.qml", "controllers", "adapters", "components", "previews", "generated", "i18n"]:
                shutil.move(str(stage / name), runtime / name)
            manifest = json.loads((stage / "manifest.json").read_text())
            manifest["entryPoints"]["overlay"] = "runtime/" + build_id + "/Overlay.qml"
            manifest["developmentBuildId"] = build_id
            atomic_write(stage / "manifest.json", json.dumps(manifest, indent=2) + "\n")
            self.runner(["omarchy", "plugin", "validate", str(stage)])
            atomic_write(stage / ".switchboard-owned", PLUGIN_ID + "\n")
            if self.plugin.exists():
                shutil.rmtree(self.plugin)
            os.replace(stage, self.plugin)
            atomic_write(self.shell_config, json.dumps(replace_entry(config, entry), ensure_ascii=False, indent=2) + "\n")
            new_bindings = clean_bindings
            if mode:
                new_bindings += ("" if not new_bindings or new_bindings.endswith("\n") else "\n") + managed_include(self.plugin / "bindings.lua")
            if new_bindings != old_bindings:
                atomic_write(self.bindings, new_bindings)
            atomic_write(self.metadata, json.dumps(metadata, ensure_ascii=False, indent=2) + "\n")
            self.validate_desktop()
            for attempt in range(12):
                try:
                    status = json.loads(self.runner(["omarchy-shell", PLUGIN_ID, "status"]))
                    if status.get("ready") and status.get("buildId") == build_id and (not mode or status.get("bindings")):
                        break
                except (subprocess.SubprocessError, ValueError):
                    pass
                time.sleep(0.15)
            else:
                raise RuntimeError("Plugin did not report ready; installation rolled back")
        except Exception:
            self.rollback(backup)
            raise
        finally:
            if stage.exists():
                shutil.rmtree(stage)
        print("Installed " + str(self.plugin))
        print("Bindings: " + ("enabled" if mode else "unchanged; use --bindings to take over Alt/Super shortcuts"))
        print("Backup: " + str(backup))
        print("Test: omarchy-shell shell summon jessie.switchboard '{\"mode\":\"workspace\"}'")

    def uninstall(self) -> None:
        if not self.metadata.exists():
            print("No managed Switchboard installation found.")
            return
        metadata = json.loads(self.metadata.read_text())
        if self.plugin.exists() and not (self.plugin / ".switchboard-owned").exists():
            raise RuntimeError("Plugin directory no longer belongs to this installation; leaving it intact")
        config = read_config(self.shell_config)
        current = next((e for e in config.get("plugins", []) if isinstance(e, dict) and e.get("id") == PLUGIN_ID), None)
        restore = metadata["originalEntry"]
        # Retain user changes to a pre-existing plugin's settings since the last deployment.
        if restore is not None and current:
            restore = dict(restore)
            managed = metadata.get("managedEntry", {})
            for key in set(current) | set(managed):
                if key in {"id", "bindingsEnabled"}:
                    continue
                if current.get(key) != managed.get(key):
                    if key in current: restore[key] = current[key]
                    else: restore.pop(key, None)
        old_bindings = self.bindings.read_text() if self.bindings.exists() else ""
        clean = strip_include(old_bindings)
        backup = self.backup()
        try:
            try:
                self.runner(["omarchy-shell", "shell", "hide", PLUGIN_ID])
            except subprocess.SubprocessError:
                pass  # An unavailable shell must not prevent removing a broken plugin.
            self.runner(["hyprctl", "eval", "_G.switchboard_lease=nil"])
            atomic_write(self.shell_config, json.dumps(replace_entry(config, restore), ensure_ascii=False, indent=2) + "\n")
            if clean != old_bindings:
                if not metadata["bindingsExisted"] and not clean:
                    self.bindings.unlink(missing_ok=True)
                else:
                    atomic_write(self.bindings, clean)
            if self.plugin.exists():
                shutil.rmtree(self.plugin)
            original = metadata.get("originalPlugin")
            if original:
                shutil.copytree(original, self.plugin, symlinks=True)
            self.metadata.unlink()
            self.validate_desktop(strict_shell=False)
        except Exception:
            self.rollback(backup)
            raise
        print("Uninstalled Switchboard; previous plugin entry and bindings restored.")
        print("Backups retained: " + str(self.state_dir))


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=["install", "uninstall"])
    flags = parser.add_mutually_exclusive_group()
    flags.add_argument("--bindings", dest="bindings", action="store_true", default=None)
    flags.add_argument("--no-bindings", dest="bindings", action="store_false")
    args = parser.parse_args()
    try:
        installer = Installer()
        if args.action == "install": installer.install(args.bindings)
        else: installer.uninstall()
    except (OSError, ValueError, RuntimeError, subprocess.SubprocessError) as error:
        parser.exit(1, "Switchboard: " + str(error) + "\n")


if __name__ == "__main__":
    main()
