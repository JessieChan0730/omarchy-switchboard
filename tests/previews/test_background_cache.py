import importlib.util
import os
from pathlib import Path
import struct
import subprocess
import tempfile
import unittest
from unittest import mock
import zlib

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("background_cache", ROOT / "previews/background_cache.py")
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


def png(width, height, rgb=(255, 0, 0)):
    def chunk(kind, data):
        return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data))
    scanlines = (b"\0" + bytes(rgb) * width) * height
    return (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0))
            + chunk(b"IDAT", zlib.compress(scanlines)) + chunk(b"IEND", b""))


class BackgroundCacheTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.directory = Path(self.temporary.name)
        self.cache = self.directory / "cache"
        self.source = self.directory / "wallpaper.png"
        self.source.write_bytes(png(1200, 900))
        self.link = self.directory / "background"
        self.link.symlink_to(self.source)

    def test_thumbnail_is_bounded_and_reused_without_decoding(self):
        result = module.prepare(self.link, self.cache)
        path = Path(result["path"])
        self.assertEqual(result["source"], str(self.source))
        self.assertEqual(struct.unpack(">II", path.read_bytes()[16:24]), (960, 720))
        with mock.patch.object(module.subprocess, "run") as converter:
            self.assertEqual(module.prepare(self.link, self.cache), result)
            converter.assert_not_called()

    def test_same_path_replacement_with_same_mtime_refreshes_cache(self):
        original = module.prepare(self.link, self.cache)
        stat = self.source.stat()
        self.source.write_bytes(png(1200, 900, (0, 0, 255)))
        os.utime(self.source, ns=(stat.st_atime_ns, stat.st_mtime_ns))
        replacement = module.prepare(self.link, self.cache)
        self.assertEqual(replacement["source"], original["source"])
        self.assertNotEqual(replacement["path"], original["path"])
        self.assertNotEqual(Path(replacement["path"]).read_bytes(), Path(original["path"]).read_bytes())

    def test_change_during_decode_never_publishes_obsolete_image(self):
        replacement = self.directory / "other.png"
        replacement.write_bytes(png(16, 16, (0, 0, 255)))
        real_run = subprocess.run

        def switch_after_decode(*args, **kwargs):
            result = real_run(*args, **kwargs)
            self.link.unlink()
            self.link.symlink_to(replacement)
            return result

        with mock.patch.object(module.subprocess, "run", side_effect=switch_after_decode):
            self.assertEqual(module.prepare(self.link, self.cache), {"source": "", "path": "", "retry": True})
        self.assertEqual(list(self.cache.iterdir()), [])
        self.assertEqual(module.prepare(self.link, self.cache)["source"], str(replacement))

    def test_failure_leaves_no_partial_cache_file(self):
        with mock.patch.object(module.subprocess, "run", side_effect=subprocess.CalledProcessError(1, "magick")):
            with self.assertRaises(subprocess.CalledProcessError):
                module.prepare(self.link, self.cache)
        self.assertEqual(list(self.cache.iterdir()), [])

    def test_cache_is_bounded_and_preserves_unowned_files(self):
        self.cache.mkdir()
        unrelated = self.cache / "user-file.png"
        unrelated.write_bytes(b"keep")
        for index in range(7):
            source = self.directory / f"wallpaper-{index}.png"
            source.write_bytes(png(16, 16, (index, 0, 0)))
            self.link.unlink()
            self.link.symlink_to(source)
            current = module.prepare(self.link, self.cache)
        owned = [path for path in self.cache.iterdir() if module.CACHE_NAME.fullmatch(path.name)]
        self.assertEqual(len(owned), module.CACHE_ENTRIES)
        self.assertIn(Path(current["path"]), owned)
        self.assertEqual(unrelated.read_bytes(), b"keep")

    def test_missing_and_video_backgrounds_do_not_decode(self):
        self.source.unlink()
        self.assertEqual(module.prepare(self.link, self.cache), {"source": "", "path": ""})
        video = self.directory / "wallpaper.MP4"
        video.write_bytes(b"video")
        self.link.unlink()
        self.link.symlink_to(video)
        with mock.patch.object(module.subprocess, "run") as converter:
            self.assertEqual(module.prepare(self.link, self.cache), {"source": "", "path": ""})
            converter.assert_not_called()

    def test_paths_with_shell_characters_are_literal(self):
        source = self.directory / "wallpaper '$(touch injected)' # ?.png"
        source.write_bytes(png(16, 16))
        self.link.unlink()
        self.link.symlink_to(source)
        result = module.prepare(self.link, self.cache)
        self.assertEqual(result["source"], str(source))
        self.assertTrue(Path(result["path"]).exists())
        self.assertFalse((ROOT / "injected").exists())


if __name__ == "__main__":
    unittest.main()
