from pathlib import Path
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[2]
HARNESS = ROOT / "tests/fixtures/bindings_harness.lua"


class BindingTests(unittest.TestCase):
    def test_six_bindings_preserve_other_keys_and_fallback(self):
        subprocess.run(["lua", str(HARNESS), str(ROOT / "dist/plugin/bindings.lua"), "plugin"], check=True)

    def test_unavailable_api_keeps_original_bindings(self):
        subprocess.run(["lua", str(HARNESS), str(ROOT / "dist/plugin/bindings.lua"), "unavailable"], check=True)


if __name__ == "__main__":
    unittest.main()
