#!/usr/bin/env python3
"""Download and install the official Sentry Godot addon.

The official release archive contains native libraries for every supported
platform and is intentionally not committed to this repository. This script
extracts only addons/sentry into the local project or CI workspace.
"""

from __future__ import annotations

import argparse
import hashlib
import os
import shutil
import sys
import urllib.request
import zipfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_VERSION = "1.6.0"
DEFAULT_BUILD = "4e3e3e5"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--version", default=os.environ.get("SENTRY_GODOT_VERSION", DEFAULT_VERSION))
    parser.add_argument("--build", default=os.environ.get("SENTRY_GODOT_BUILD", DEFAULT_BUILD))
    parser.add_argument("--url", default=os.environ.get("SENTRY_GODOT_URL", ""))
    parser.add_argument("--force", action="store_true", help="replace an existing addons/sentry directory")
    parser.add_argument(
        "--cache-dir",
        type=Path,
        default=Path(os.environ.get("SENTRY_GODOT_CACHE_DIR", ROOT / "tmp" / "sentry-godot")),
    )
    parser.add_argument("--sha256", default=os.environ.get("SENTRY_GODOT_SHA256", ""))
    return parser.parse_args()


def release_asset_name(version: str, build: str) -> str:
    return f"sentry-godot-{version}+{build}.zip"


def release_url(version: str, build: str) -> str:
    asset = release_asset_name(version, build).replace("+", "%2B")
    return f"https://github.com/getsentry/sentry-godot/releases/download/{version}/{asset}"


def download(url: str, target: Path) -> None:
    target.parent.mkdir(parents=True, exist_ok=True)
    if target.is_file() and target.stat().st_size > 0:
        print(f"Using cached {target}")
        return
    tmp = target.with_suffix(target.suffix + ".part")
    print(f"Downloading {url}")
    with urllib.request.urlopen(url, timeout=60) as response, tmp.open("wb") as out:
        shutil.copyfileobj(response, out, length=1024 * 1024)
    tmp.replace(target)


def verify_sha256(path: Path, expected: str) -> None:
    if not expected:
        return
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    actual = digest.hexdigest()
    if actual.lower() != expected.lower():
        raise RuntimeError(f"sha256 mismatch for {path}: expected {expected}, got {actual}")


def addon_relative_path(zip_name: str) -> Path | None:
    marker = "addons/sentry/"
    normalized = zip_name.replace("\\", "/")
    index = normalized.find(marker)
    if index < 0:
        return None
    relative = normalized[index + len(marker) :]
    if not relative:
        return None
    return Path(relative)


def extract_addon(zip_path: Path, target_dir: Path, force: bool) -> None:
    if target_dir.exists():
        if not force:
            print(f"{target_dir} already exists; use --force to reinstall")
            return
        shutil.rmtree(target_dir)

    tmp_dir = target_dir.with_name(target_dir.name + ".tmp")
    if tmp_dir.exists():
        shutil.rmtree(tmp_dir)
    tmp_dir.mkdir(parents=True)

    extracted = 0
    with zipfile.ZipFile(zip_path) as archive:
        for info in archive.infolist():
            relative = addon_relative_path(info.filename)
            if relative is None:
                continue
            if relative.is_absolute() or ".." in relative.parts:
                raise RuntimeError(f"unsafe path in archive: {info.filename}")
            destination = tmp_dir / relative
            if info.is_dir():
                destination.mkdir(parents=True, exist_ok=True)
                continue
            destination.parent.mkdir(parents=True, exist_ok=True)
            with archive.open(info) as source, destination.open("wb") as out:
                shutil.copyfileobj(source, out)
            extracted += 1

    if extracted == 0:
        shutil.rmtree(tmp_dir)
        raise RuntimeError(f"addons/sentry was not found in {zip_path}")

    tmp_dir.replace(target_dir)
    print(f"Installed Sentry Godot addon to {target_dir} ({extracted} files)")


def main() -> int:
    args = parse_args()
    url = args.url or release_url(args.version, args.build)
    zip_path = args.cache_dir / release_asset_name(args.version, args.build)
    download(url, zip_path)
    verify_sha256(zip_path, args.sha256)
    extract_addon(zip_path, ROOT / "addons" / "sentry", args.force)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
