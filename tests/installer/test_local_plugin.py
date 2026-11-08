import importlib.util
import contextlib
import io
import json
from pathlib import Path
import tempfile
import subprocess
from unittest.mock import patch
import unittest

spec = importlib.util.spec_from_file_location("local_plugin", Path(__file__).resolve().parents[2] / "scripts/local_plugin.py")
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class InstallerTests(unittest.TestCase):
    def setUp(self):
        self.output = contextlib.redirect_stdout(io.StringIO())
        self.output.__enter__()
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.fail_reload = False
        def run(args):
            if args[1:] == ["configerrors"]:
                return "test error" if self.fail_reload else ""
            if args[-1] == "status":
                build_id = json.loads((self.installer.plugin / "manifest.json").read_text())["developmentBuildId"]
                return json.dumps({"ready": True, "bindings": True, "buildId": build_id})
            return "ok"
        self.installer = module.Installer(self.root / "config", self.root / "state", run)
        module.atomic_write(self.installer.shell_config, json.dumps({"version": 1, "plugins": [{"id": "other", "enabled": True}], "custom": "keep"}))
        module.atomic_write(self.installer.bindings, '-- user bindings\no.bind("SUPER + Z", "test", "true")\n')

    def tearDown(self):
        self.temp.cleanup()
        self.output.__exit__(None, None, None)

    def test_reinstall_and_uninstall_keep_later_user_changes(self):
        original = self.installer.bindings.read_text()
        self.installer.install(True)
        self.installer.install(None)
        self.assertEqual(self.installer.bindings.read_text().count(module.BEGIN), 1)
        with self.installer.bindings.open("a") as stream:
            stream.write('-- user added after install\n')
        config = json.loads(self.installer.shell_config.read_text())
        config["custom"] = "edited later"
        config["plugins"].append({"id": "later", "enabled": True})
        module.atomic_write(self.installer.shell_config, json.dumps(config))
        self.installer.uninstall()
        self.assertEqual(self.installer.bindings.read_text(), original + '-- user added after install\n')
        config = json.loads(self.installer.shell_config.read_text())
        self.assertEqual(config["custom"], "edited later")
        self.assertEqual([e["id"] for e in config["plugins"]], ["other", "later"])
        self.assertFalse(self.installer.plugin.exists())
        self.installer.uninstall()

    def test_failure_restores_plugin_and_config(self):
        original = self.installer.shell_config.read_text()
        original_bindings = self.installer.bindings.read_text()
        self.fail_reload = True
        with self.assertRaises(RuntimeError):
            self.installer.install(True)
        self.assertEqual(self.installer.shell_config.read_text(), original)
        self.assertEqual(self.installer.bindings.read_text(), original_bindings)
        self.assertFalse(self.installer.plugin.exists())
        self.assertFalse(self.installer.metadata.exists())

    def test_preexisting_plugin_and_settings_are_restored(self):
        self.installer.plugin.mkdir(parents=True)
        (self.installer.plugin / "user.qml").write_text("existing plugin")
        original_entry = {"id": module.PLUGIN_ID, "enabled": False, "debug": False}
        module.atomic_write(self.installer.shell_config, json.dumps({"version": 1, "plugins": [original_entry]}))
        self.installer.install(True)
        config = json.loads(self.installer.shell_config.read_text())
        config["plugins"][0]["debug"] = True
        module.atomic_write(self.installer.shell_config, json.dumps(config))
        self.installer.uninstall()
        self.assertEqual((self.installer.plugin / "user.qml").read_text(), "existing plugin")
        entry = json.loads(self.installer.shell_config.read_text())["plugins"][0]
        self.assertFalse(entry["enabled"])
        self.assertTrue(entry["debug"])
        self.assertNotIn("bindingsEnabled", entry)

    def test_no_bindings_does_not_edit_bindings(self):
        original = self.installer.bindings.read_text()
        self.installer.install(False)
        self.assertEqual(self.installer.bindings.read_text(), original)
        self.installer.install(True)
        self.installer.install(False)
        self.assertEqual(self.installer.bindings.read_text(), original)
        self.installer.uninstall()

    def test_uninstall_works_when_shell_is_unavailable(self):
        self.installer.install(True)
        original_runner = self.installer.runner
        def offline(args):
            if args[0] == "omarchy-shell":
                raise subprocess.CalledProcessError(1, args)
            return original_runner(args)
        self.installer.runner = offline
        self.installer.uninstall()
        self.assertFalse(self.installer.plugin.exists())
        self.assertNotIn(module.BEGIN, self.installer.bindings.read_text())

    def test_update_waits_for_fresh_runtime_instead_of_cached_instance(self):
        self.installer.install(False)
        old_build = json.loads((self.installer.plugin / "manifest.json").read_text())["developmentBuildId"]
        original_runner = self.installer.runner
        calls = []
        def stale_once(args):
            if args[-1] == "status":
                calls.append(args)
                if len(calls) == 1:
                    return json.dumps({"ready": True, "bindings": True, "buildId": old_build})
            return original_runner(args)
        self.installer.runner = stale_once
        with patch.object(module.time, "sleep"):
            self.installer.install(False)
        self.assertEqual(len(calls), 2)
        manifest = json.loads((self.installer.plugin / "manifest.json").read_text())
        self.assertNotEqual(manifest["developmentBuildId"], old_build)
        self.assertTrue((self.installer.plugin / manifest["entryPoints"]["overlay"]).exists())

    def test_malformed_include_and_invalid_json_are_preserved(self):
        module.atomic_write(self.installer.bindings, module.BEGIN + '\n')
        with self.assertRaises(ValueError):
            self.installer.install(True)
        self.assertFalse(self.installer.plugin.exists())
        module.atomic_write(self.installer.shell_config, '{invalid')
        with self.assertRaises(ValueError):
            self.installer.install(False)
        self.assertEqual(self.installer.shell_config.read_text(), '{invalid')


if __name__ == '__main__':
    unittest.main()
