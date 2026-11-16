#!/usr/bin/env python3
"""Prepare a bounded still-wallpaper thumbnail outside the shell's UI thread."""
from __future__ import annotations

import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile

MAX_EDGE = 960
CACHE_ENTRIES = 4
VIDEO_SUFFIXES = {".mp4", ".m4v", ".mov", ".webm", ".mkv", ".avi"}
CACHE_NAME = re.compile(r"[a-f0-9]{64}\.png\Z")


def identity(link: Path) -> tuple[Path, str] | None:
    try:
        source = link.resolve(strict=True)
        stat = source.stat()
        if not source.is_file() or source.suffix.lower() in VIDEO_SUFFIXES:
            return None
    except OSError:
        return None
    fingerprint = json.dumps(["v1", str(source), stat.st_dev, stat.st_ino,
                              stat.st_size, stat.st_mtime_ns, stat.st_ctime_ns, MAX_EDGE])
    return source, hashlib.sha256(fingerprint.encode()).hexdigest()


def prune(cache: Path, current: Path) -> None:
    entries = []
    for path in cache.iterdir():
        if CACHE_NAME.fullmatch(path.name):
            try:
                entries.append((path.stat().st_mtime_ns, path))
            except FileNotFoundError:
                pass
    # Only our thumbnail names are eligible; concurrent readers can hold their
    # decoded image even after an older disk entry is evicted.
    entries.sort(reverse=True)
    others = [path for _, path in entries if path != current]
    for path in others[CACHE_ENTRIES - 1:]:
        path.unlink(missing_ok=True)


def prepare(link: Path, cache: Path) -> dict[str, str | bool]:
    before = identity(link)
    if before is None:
        return {"source": "", "path": ""}
    source, key = before
    cache.mkdir(parents=True, exist_ok=True)
    target = cache / (key + ".png")
    if not target.is_file() or target.stat().st_size == 0:
        fd, name = tempfile.mkstemp(prefix=".background-", suffix=".png", dir=cache)
        os.close(fd)
        temporary = Path(name)
        try:
            subprocess.run(["magick", "-limit", "thread", "2", str(source) + "[0]",
                            "-auto-orient", "-thumbnail", f"{MAX_EDGE}x{MAX_EDGE}>",
                            "-strip", "-depth", "8", "PNG:" + str(temporary)],
                           check=True, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, timeout=20)
            if identity(link) != before:
                # A theme switch can replace the file while it is decoding.
                # Never publish that obsolete thumbnail; let the caller retry.
                return {"source": "", "path": "", "retry": True}
            os.replace(temporary, target)
        finally:
            temporary.unlink(missing_ok=True)
    if identity(link) != before:
        return {"source": "", "path": "", "retry": True}
    prune(cache, target)
    return {"source": str(source), "path": str(target)}


def main() -> int:
    try:
        result = prepare(Path(sys.argv[1]), Path(sys.argv[2]))
    except (OSError, subprocess.SubprocessError) as error:
        print("Switchboard wallpaper cache: " + type(error).__name__, file=sys.stderr)
        print(json.dumps({"source": "", "path": ""}))
        return 1
    print(json.dumps(result))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
