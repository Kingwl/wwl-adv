#!/usr/bin/env python3
"""Build the UI font subset from current Godot source text."""

from __future__ import annotations

import argparse
import os
import subprocess
import sys
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_OUTPUT = ROOT / "assets/fonts/NotoSansCJKsc-WWL-Subset.otf"
DEFAULT_SCAN_ROOTS = [
    ROOT / "project.godot",
    ROOT / "autoload",
    ROOT / "scripts",
    ROOT / "scenes",
    ROOT / "resources",
]
TEXT_SUFFIXES = {
    ".cfg",
    ".gd",
    ".godot",
    ".import",
    ".json",
    ".md",
    ".tres",
    ".tscn",
    ".txt",
}
STATIC_CHARS = (
    "\n\t "
    + "".join(chr(codepoint) for codepoint in range(0x20, 0x7F))
    + "，。！？；：、（）【】《》「」『』·…"
    + "￥+-×÷=%/\\|_<>[]{}"
)


def iter_text_files(paths: list[Path]):
    for path in paths:
        if path.is_file():
            if path.suffix in TEXT_SUFFIXES:
                yield path
            continue
        if not path.is_dir():
            continue
        for child in path.rglob("*"):
            if child.is_file() and child.suffix in TEXT_SUFFIXES:
                yield child


def collect_chars(scan_paths: list[Path]) -> str:
    chars = set(STATIC_CHARS)
    for path in iter_text_files(scan_paths):
        try:
            text = path.read_text(encoding="utf-8")
        except UnicodeDecodeError:
            continue
        chars.update(text)
    return "".join(sorted(chars))


def build_subset(source: Path, output: Path, chars: str) -> None:
    if not source.is_file():
        raise FileNotFoundError(f"source font not found: {source}")
    output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile("w", encoding="utf-8", delete=False) as chars_file:
        chars_file.write(chars)
        chars_path = Path(chars_file.name)
    try:
        cmd = [
            sys.executable,
            "-m",
            "fontTools.subset",
            str(source),
            f"--output-file={output}",
            f"--text-file={chars_path}",
            "--layout-features=*",
            "--glyph-names",
            "--symbol-cmap",
            "--legacy-cmap",
            "--notdef-glyph",
            "--notdef-outline",
            "--recommended-glyphs",
            "--name-IDs=*",
            "--name-legacy",
            "--name-languages=*",
        ]
        subprocess.run(cmd, check=True)
    finally:
        chars_path.unlink(missing_ok=True)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--source",
        default=os.environ.get("WWL_FONT_SOURCE", ""),
        help="Full source font path. Can also be provided via WWL_FONT_SOURCE.",
    )
    parser.add_argument("--output", default=str(DEFAULT_OUTPUT))
    parser.add_argument("--print-chars", action="store_true")
    args = parser.parse_args()

    chars = collect_chars(DEFAULT_SCAN_ROOTS)
    if args.print_chars:
        print(chars)
        return 0

    if not args.source:
        parser.error("--source or WWL_FONT_SOURCE is required")

    build_subset(Path(args.source), Path(args.output), chars)
    print(f"subset font written: {args.output} ({len(chars)} chars)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
