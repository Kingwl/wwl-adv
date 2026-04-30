#!/usr/bin/env python3
"""Inject Sentry Godot SDK runtime settings into project.godot."""

from __future__ import annotations

import argparse
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
PROJECT_FILE = ROOT / "project.godot"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project", type=Path, default=PROJECT_FILE)
    parser.add_argument("--dsn", required=True)
    parser.add_argument("--release", default="")
    parser.add_argument("--environment", default="production")
    return parser.parse_args()


def godot_string(value: str) -> str:
    return json.dumps(value, ensure_ascii=False)


def update_section(text: str, section: str, updates: dict[str, str]) -> str:
    lines = text.splitlines()
    header = f"[{section}]"
    start = None
    end = len(lines)

    for index, line in enumerate(lines):
        if line.strip() == header:
            start = index
            break

    if start is None:
        if lines and lines[-1].strip():
            lines.append("")
        lines.append(header)
        for key, value in updates.items():
            lines.append(f"{key}={value}")
        return "\n".join(lines) + "\n"

    for index in range(start + 1, len(lines)):
        stripped = lines[index].strip()
        if stripped.startswith("[") and stripped.endswith("]"):
            end = index
            break

    existing = {line.split("=", 1)[0]: i for i, line in enumerate(lines[start + 1 : end], start + 1) if "=" in line}
    insert_at = end
    for key, value in updates.items():
        if key in existing:
            lines[existing[key]] = f"{key}={value}"
        else:
            lines.insert(insert_at, f"{key}={value}")
            insert_at += 1
    return "\n".join(lines) + "\n"


def main() -> int:
    args = parse_args()
    if not args.dsn.strip():
        raise ValueError("--dsn must not be empty")

    updates = {
        "options/auto_init": "false",
        "options/dsn": godot_string(args.dsn.strip()),
        "options/environment": godot_string(args.environment.strip() or "production"),
    }
    if args.release.strip():
        updates["options/release"] = godot_string(args.release.strip())

    text = args.project.read_text(encoding="utf-8")
    args.project.write_text(update_section(text, "sentry", updates), encoding="utf-8")
    print(f"Configured Sentry settings in {args.project}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
