#!/usr/bin/env python3
"""Real Omarchy CLI acceptance. Saves private snapshots and always cleans up.

Temporarily disables/enables the installed plugin and reloads Hyprland. Optional
deployment/restart are explicit flags. No test windows/workspaces are created.
"""
import argparse
from datetime import datetime
import hashlib
import json
from pathlib import Path
import shutil
import signal
import subprocess
import time

ROOT = Path(__file__).resolve().parents[2]
PLUGIN = "jessie.switchboard"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--deploy", action="store_true")
    parser.add_argument("--restart-shell", action="store_true")
    args = parser.parse_args()
    stamp = datetime.now().strftime("%Y%m%d-%H%M%S-%f")
    cache = ROOT / ".cache" / "plugin-lifecycle" / stamp
    results = ROOT / "test-results" / ("plugin-lifecycle-" + stamp)
    cache.mkdir(parents=True); results.mkdir(parents=True)
    probe = "jessie.switchboard-probe-" + stamp
    installed = Path.home() / ".config/omarchy/plugins"
    shell_config = Path.home() / ".config/omarchy/shell.json"
    assertions = []
    error = None
    restoration_errors = []

    def run(*command, timeout=20, required=True):
        result = subprocess.run(command, cwd=ROOT, capture_output=True, text=True, timeout=timeout)
        with (cache / "commands.log").open("a") as log:
            log.write(json.dumps(list(command)) + "\n" + result.stdout + result.stderr + "\n")
        if required and result.returncode:
            raise RuntimeError(f"{command[0]} {command[1:3]} failed: {result.stderr.strip()}")
        return result.stdout.strip()

    def desktop(name):
        return json.loads(run("hyprctl", "-j", name))

    def status(plugin=PLUGIN):
        try: return json.loads(run("omarchy-shell", plugin, "status", required=False))
        except ValueError: return {}

    def wait(description, predicate, timeout=15):
        deadline = time.monotonic() + timeout
        last = None
        while time.monotonic() < deadline:
            last = predicate()
            if last: return last
            time.sleep(0.1)
        raise AssertionError(f"Timed out: {description}; last={last}")

    def check(name, actual, expected):
        passed = actual == expected
        assertions.append({"name": name, "passed": passed, "actual": actual, "expected": expected})
        print(("PASS " if passed else "FAIL ") + name, flush=True)
        if not passed: raise AssertionError(name)

    def plugin_bindings():
        return [b for b in desktop("binds") if str(b.get("description", "")).startswith("Switchboard:")]

    before = {name: desktop(name) for name in ["monitors", "workspaces", "clients", "activewindow"]}
    before["plugin"] = status()
    for name, data in before.items():
        (cache / ("before-" + name + ".json")).write_text(json.dumps(data, ensure_ascii=False, indent=2))
    shutil.copy2(shell_config, cache / "before-shell.json")
    bindings_file = Path.home() / ".config/hypr/bindings.lua"
    if bindings_file.exists(): shutil.copy2(bindings_file, cache / "before-bindings.lua")
    config = json.loads(shell_config.read_text())
    original_entry = next(e for e in config["plugins"] if e.get("id") == PLUGIN)
    was_enabled = original_entry.get("enabled", True)
    binding_mode = before["plugin"].get("bindings", original_entry.get("bindingsEnabled", False))
    if not before["plugin"].get("ready") or before["plugin"].get("opened"):
        raise RuntimeError("The installed plugin must be ready with its panel closed before this test.")
    print("Results: " + str(results), flush=True)

    def interrupted(signum, frame):
        raise KeyboardInterrupt(f"signal {signum}")
    signal.signal(signal.SIGTERM, interrupted)

    try:
        if args.deploy:
            print("Deploying with the existing binding mode", flush=True)
            run(str(ROOT / "scripts/install.sh"), timeout=180)
        live = wait("installed ready", lambda: status().get("ready") and status())
        check("installed binding mode preserved", live.get("bindings"), binding_mode)
        if binding_mode:
            check("six runtime shortcuts", len(plugin_bindings()), 6)
            run("hyprctl", "reload")
            wait("bindings after config reload", lambda: status().get("ready") and status().get("bindings"))
            check("reload registers six shortcuts", len(plugin_bindings()), 6)

        run("omarchy", "plugin", "disable", PLUGIN)
        wait("native bindings restored after disable", lambda: not plugin_bindings())
        check("disable removes runtime shortcuts", len(plugin_bindings()), 0)
        native = desktop("binds")
        # Exercise the real compositor's watchdog with no QML heartbeat. The
        # installed plugin stays disabled while this temporary owner expires.
        script = installed / PLUGIN / json.loads((installed / PLUGIN / "manifest.json").read_text())["entryPoints"]["overlay"]
        script = script.parent / "bindings.lua"
        code = 'local s=assert(loadfile(' + json.dumps(str(script)) + '))(); print(s:claim("lifecycle-watchdog",0,"' + PLUGIN + '"))'
        check("watchdog probe claims runtime bindings", run("hyprctl", "repl", code), "true")
        wait("watchdog six bindings", lambda: len(plugin_bindings()) == 6)
        run("hyprctl", "eval", "_G.switchboard_runtime.expires=os.time()-1")
        wait("watchdog restores native config", lambda: not plugin_bindings(), timeout=5)
        def signature(bindings):
            # Lua registry numbers change on reload; actions and flags remain.
            return sorted(json.dumps({k: v for k, v in b.items() if k != "arg" or b.get("dispatcher") != "__lua"}, sort_keys=True) for b in bindings)
        check("watchdog restores configured bindings", signature(desktop("binds")), signature(native))
        run("omarchy", "plugin", "enable", PLUGIN)
        wait("reenabled ready", lambda: status().get("ready"))
        check("reenable preserves binding mode", status().get("bindings"), binding_mode)

        # Exercise a first Git installation's default shortcut mode while the
        # original is disabled, so two owners never compete for the chords.
        run("omarchy", "plugin", "disable", PLUGIN)
        wait("original disabled for Git acceptance", lambda: not plugin_bindings())
        repository = cache / "git-release"
        repository.mkdir()
        shutil.copytree(ROOT / "runtime", repository / "runtime")
        manifest = json.loads((ROOT / "manifest.json").read_text())
        manifest.update(id=probe)
        (repository / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
        for name in ["README.md", "README.en.md", "LICENSE", ".gitignore"]: shutil.copy2(ROOT / name, repository / name)
        def git(*command): return run("git", "-C", str(repository), *command)
        git("init", "-b", "main"); git("add", ".")
        git("-c", "user.name=Switchboard test", "-c", "user.email=test@example.invalid", "commit", "-m", "Release fixture")
        check("compiled JavaScript is tracked in Git", bool(git("ls-files", f"runtime/{manifest['buildId']}/generated/Logic.mjs")), True)
        run("omarchy", "plugin", "add", repository.as_uri(), "--enable", "--yes", timeout=45)
        wait("Git probe ready", lambda: status(probe).get("ready"))
        check("Git add uses runtime without building", status(probe).get("buildId"), manifest["buildId"])
        check("Git checkout retained", (installed / probe / ".git").is_dir(), True)
        check("first Git installation enables shortcuts", status(probe).get("bindings"), True)
        check("first Git installation registers six shortcuts", len(plugin_bindings()), 6)
        previous_id = manifest["buildId"]
        next_id = hashlib.sha256((previous_id + "fixture-update").encode()).hexdigest()[:24]
        (repository / "runtime" / previous_id).rename(repository / "runtime" / next_id)
        manifest.update(buildId=next_id, version="0.1.0+fixture.2", entryPoints={"overlay": f"runtime/{next_id}/Overlay.qml"})
        (repository / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
        git("add", "."); git("-c", "user.name=Switchboard test", "-c", "user.email=test@example.invalid", "commit", "-m", "Update fixture")
        run("omarchy", "plugin", "update", probe, "--yes", timeout=45)
        wait("updated runtime active", lambda: status(probe).get("buildId") == next_id and status(probe).get("ready"))
        check("Git update loads new runtime", status(probe).get("buildId"), next_id)
        run("omarchy", "plugin", "disable", probe)
        wait("Git disable restores native bindings", lambda: not plugin_bindings())
        check("Git disable removes runtime shortcuts", len(plugin_bindings()), 0)
        run("omarchy", "plugin", "enable", probe)
        wait("Git probe reenabled", lambda: status(probe).get("ready"))
        check("probe reenable preserves shortcut defaults", status(probe).get("bindings"), True)
        run("omarchy", "plugin", "remove", probe, "--yes")
        wait("Git probe removed", lambda: not (installed / probe).exists())
        check("Git remove removes checkout", (installed / probe).exists(), False)
        wait("Git remove restores native bindings", lambda: not plugin_bindings())
        check("Git remove restores configured shortcuts", signature(desktop("binds")), signature(native))
        run("omarchy", "plugin", "enable", PLUGIN)
        wait("original restored after Git acceptance", lambda: status().get("ready"))
        if args.restart_shell:
            print("Restarting shell and verifying the installed runtime", flush=True)
            run("omarchy", "restart", "shell", timeout=90)
            wait("shell restart ready", lambda: status().get("ready"), timeout=30)
            check("shell restart preserves binding mode", status().get("bindings"), binding_mode)
    except BaseException as failure:
        error = str(failure)
        print("Failure: " + error, flush=True)
    finally:
        for plugin in [probe, PLUGIN]: run("omarchy-shell", plugin, "cancel", required=False)
        try:
            if (installed / probe).exists(): run("omarchy", "plugin", "remove", probe, "--yes")
            current = json.loads(shell_config.read_text())
            current["plugins"] = [e for e in current.get("plugins", []) if e.get("id") != probe]
            entry = next(e for e in current["plugins"] if e.get("id") == PLUGIN)
            entry["enabled"] = was_enabled
            # Do not restore the complete snapshot: retain concurrent edits.
            temporary = shell_config.with_name(".switchboard-lifecycle-shell.json")
            temporary.write_text(json.dumps(current, ensure_ascii=False, indent=2) + "\n")
            temporary.chmod(shell_config.stat().st_mode & 0o777)
            temporary.replace(shell_config)
            run("omarchy-shell", "shell", "rescanPlugins")
            if was_enabled: wait("restored plugin ready", lambda: status().get("ready"))
            run("hyprctl", "reload")
            check("configuration errors after cleanup", run("hyprctl", "configerrors"), "")
            if was_enabled: wait("restored bindings", lambda: status().get("ready") and status().get("bindings") == binding_mode)
        except BaseException as failure: restoration_errors.append(str(failure))
        after = {name: desktop(name) for name in ["monitors", "workspaces", "clients", "activewindow"]}
        after["plugin"] = status()
        for name, data in after.items(): (cache / ("after-" + name + ".json")).write_text(json.dumps(data, ensure_ascii=False, indent=2))
        def layout(monitors): return [{k: m.get(k) for k in ["name", "width", "height", "x", "y", "scale", "transform"]} for m in monitors]
        def windows(clients): return sorted((c["address"], c["workspace"]["id"], c["monitor"]) for c in clients)
        restoration = {
            "errors": restoration_errors,
            "monitor_layout_preserved": layout(before["monitors"]) == layout(after["monitors"]),
            "active_workspaces_preserved": sorted((m["name"], m["activeWorkspace"]["id"], m["focused"]) for m in before["monitors"])
                == sorted((m["name"], m["activeWorkspace"]["id"], m["focused"]) for m in after["monitors"]),
            "workspace_ids_preserved": sorted(w["id"] for w in before["workspaces"]) == sorted(w["id"] for w in after["workspaces"]),
            "window_membership_preserved": windows(before["clients"]) == windows(after["clients"]),
            "focus_preserved": before["activewindow"].get("address") == after["activewindow"].get("address"),
            "probe_removed": not (installed / probe).exists(),
            "binding_mode_preserved": after["plugin"].get("bindings") == binding_mode,
            "plugin": after["plugin"],
        }
        (results / "restoration.json").write_text(json.dumps(restoration, ensure_ascii=False, indent=2) + "\n")
        (results / "results.json").write_text(json.dumps({"failure": error, "assertions": assertions}, ensure_ascii=False, indent=2) + "\n")
        report = ["# 插件安装与生命周期验收", "", "实际运行 Omarchy 官方管理命令与 Hyprland IPC。", "",
                  "已安装的原实例：部署、六个快捷键、重载、禁用/启用、Lua 租约过期" + ("、shell 重启。" if args.restart_shell else "。"),
                  "Git 安装/更新/移除：同一份发布运行代码使用独立测试 ID，默认开启快捷键；原实例在此期间停用，更新使用新的运行路径。",
                  "此测试不代表物理键盘按住/释放时序或真实多显示器行为通过。", "",
                  f"最终构建 ID：`{after['plugin'].get('buildId')}`。", "",
                  "- [实际断言](results.json)", "- [恢复核对](restoration.json)", "",
                  "私有桌面快照和命令日志仅保存于对应 `.cache/plugin-lifecycle/`。结果目录可在用户确认后删除。", "",
                  f"失败：{error or '无'}；清理错误：{restoration_errors or '无'}。"]
        (results / "README.md").write_text("\n".join(report) + "\n")
        print("Cleanup results: " + json.dumps({k: v for k, v in restoration.items() if k != "plugin"}), flush=True)
    return 1 if error or restoration_errors or any(v is False for v in restoration.values()) else 0


if __name__ == "__main__":
    raise SystemExit(main())
