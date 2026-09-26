#!/usr/bin/env python3
"""Synchronize the canonical dialogue JSON into Flutter's bundled mirror.

The dialogue engine owns route/scene data. Flutter cannot bundle assets from
that pure-Dart path dependency, so gatefall_flame/data is a generated mirror.

Usage:
  python3 tool/sync_dialogue_data.py         # update the mirror in place
  python3 tool/sync_dialogue_data.py --check # fail if the mirror is stale
"""

from __future__ import annotations

import argparse
import filecmp
import shutil
import sys
from pathlib import Path


APP_ROOT = Path(__file__).resolve().parents[1]
REPO_ROOT = APP_ROOT.parent
SOURCE = REPO_ROOT / "gatefall_dialogue_engine" / "data"
TARGET = APP_ROOT / "data"


def json_files(root: Path) -> dict[Path, Path]:
    return {
        path.relative_to(root): path
        for path in root.rglob("*.json")
        if path.is_file()
    }


def drift() -> tuple[list[Path], list[Path], list[Path]]:
    source = json_files(SOURCE)
    target = json_files(TARGET)

    missing = sorted(source.keys() - target.keys())
    extra = sorted(target.keys() - source.keys())
    changed = sorted(
        rel
        for rel in source.keys() & target.keys()
        if not filecmp.cmp(source[rel], target[rel], shallow=False)
    )
    return missing, extra, changed


def sync() -> None:
    source = json_files(SOURCE)
    target = json_files(TARGET)

    for rel in sorted(target.keys() - source.keys()):
        target[rel].unlink()

    for rel, src in sorted(source.items()):
        dst = TARGET / rel
        dst.parent.mkdir(parents=True, exist_ok=True)
        if not dst.exists() or not filecmp.cmp(src, dst, shallow=False):
            shutil.copy2(src, dst)

    # Remove empty directories left by stale scene groups.
    for directory in sorted(
        (p for p in TARGET.rglob("*") if p.is_dir()),
        key=lambda p: len(p.parts),
        reverse=True,
    ):
        try:
            directory.rmdir()
        except OSError:
            pass


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--check",
        action="store_true",
        help="report drift and exit non-zero instead of modifying files",
    )
    args = parser.parse_args()

    if not SOURCE.is_dir():
        print(f"Canonical dialogue data not found: {SOURCE}", file=sys.stderr)
        return 2

    if args.check:
        missing, extra, changed = drift()
        if not (missing or extra or changed):
            print("Dialogue data mirror is up to date.")
            return 0

        print("Dialogue data mirror is stale:", file=sys.stderr)
        for label, paths in (
            ("missing", missing),
            ("extra", extra),
            ("changed", changed),
        ):
            for path in paths:
                print(f"  {label}: {path.as_posix()}", file=sys.stderr)
        print(
            "Run: cd gatefall_flame && python3 tool/sync_dialogue_data.py",
            file=sys.stderr,
        )
        return 1

    sync()
    missing, extra, changed = drift()
    if missing or extra or changed:
        print("Mirror still differs after sync.", file=sys.stderr)
        return 1

    print("Dialogue data mirror synchronized.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
