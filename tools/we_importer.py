#!/usr/bin/env python3
"""Wallpaper Engine workshop importer for denial dynamic wallpapers.

Scans a Wallpaper Engine Steam workshop directory (project.json based
wallpaper projects), classifies each project, and installs it as a denial
dynamic wallpaper package with a generated manifest.json.

Usage:
    python3 we_importer.py --workshop ~/.steam/steam/steamapps/workshop/content/431960
    python3 we_importer.py --workshop <path> --dest ~/.local/share/denial/wallpapers/dynamic
    python3 we_importer.py --list            # dry run, no install

Only the Python standard library is required.
"""

from __future__ import annotations

import argparse
import json
import shutil
import sys
from pathlib import Path

VIDEO_EXTS = {".mp4", ".webm", ".mkv", ".mov"}
IMAGE_EXTS = {".png", ".jpg", ".jpeg", ".webp", ".bmp"}
ANIMATED_EXTS = {".gif", ".webp"}
WEB_EXTS = {".html", ".htm"}


def classify(project_dir: Path) -> tuple[str, str] | None:
    """Return (type, entry) for a workshop project, or None if unsupported."""
    # 1. Web wallpaper: index.html at project root.
    for name in ("index.html", "index.htm", "main.html"):
        candidate = project_dir / name
        if candidate.exists():
            return "web", name

    # 2. Video wallpaper: scene/video file (WE usually has exactly one).
    videos = sorted(p for p in project_dir.rglob("*") if p.suffix.lower() in VIDEO_EXTS)
    if videos:
        smallest = min(videos, key=lambda p: p.stat().st_size)
        entry = smallest.relative_to(project_dir).as_posix()
        return "video", entry

    # 3. Image wallpaper (animated gif preferred).
    gifs = sorted(p for p in project_dir.iterdir() if p.suffix.lower() in ANIMATED_EXTS)
    if gifs:
        entry = gifs[0].relative_to(project_dir).as_posix()
        return "image", entry
    images = sorted(p for p in project_dir.iterdir() if p.suffix.lower() in IMAGE_EXTS)
    if images:
        entry = images[0].relative_to(project_dir).as_posix()
        return "image", entry

    return None


def safe_id(project: dict, fallback: str) -> str:
    raw = str(project.get("title") or fallback).strip().lower()
    cleaned = "".join(c if (c.isalnum() or c in "-_") else "-" for c in raw)
    cleaned = cleaned.strip("-")
    return cleaned or fallback


def import_project(project_dir: Path, dest_root: Path, dry: bool) -> str:
    project_file = project_dir / "project.json"
    if not project_file.exists():
        return "SKIP (no project.json)"
    try:
        project = json.loads(project_file.read_text(encoding="utf-8", errors="replace"))
    except json.JSONDecodeError as exc:
        return f"SKIP (bad project.json: {exc})"

    result = classify(project_dir)
    if result is None:
        return "SKIP (no video/web/image content found)"
    wtype, entry = result

    wid = safe_id(project, project_dir.name)
    dest = dest_root / wid
    if dest.exists():
        return f"SKIP (already imported as {wid})"

    if dry:
        return f"WOULD INSTALL [{wtype}] {project.get('title', wid)} -> {dest}"

    dest.mkdir(parents=True, exist_ok=False)
    for item in project_dir.iterdir():
        if item.name == "project.json":
            continue
        target = dest / item.name
        if item.is_dir():
            shutil.copytree(item, target, dirs_exist_ok=True)
        else:
            shutil.copy2(item, target)

    # Entry files may live in nested dirs for video; flatten reference by
    # pointing manifest entry at the relative path (server/file access keeps
    # the directory structure).
    manifest = {
        "id": wid,
        "name": str(project.get("title", wid)),
        "type": wtype,
        "entry": entry,
        "options": {"loop": True, "mute": True, "volume": 0.0},
        "source": "wallpaper-engine-workshop",
        "sourceProjectId": str(project.get("fileId", "")),
    }
    (dest / "manifest.json").write_text(
        json.dumps(manifest, indent=2, ensure_ascii=False), encoding="utf-8"
    )
    return f"OK [{wtype}] {manifest['name']} -> {dest}"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--workshop", type=Path, help="Wallpaper Engine workshop content dir (431960)")
    parser.add_argument(
        "--dest",
        type=Path,
        default=Path.home() / ".local/share/denial/wallpapers/dynamic",
        help="denial dynamic wallpaper install root",
    )
    parser.add_argument("--list", action="store_true", help="dry run: report without installing")
    args = parser.parse_args()

    if args.workshop is None:
        parser.error("--workshop is required")
    if not args.workshop.exists():
        print(f"workshop dir not found: {args.workshop}", file=sys.stderr)
        return 1

    dest_root = args.dest
    if not args.list:
        dest_root.mkdir(parents=True, exist_ok=True)

    projects = sorted(p for p in args.workshop.iterdir() if p.is_dir())
    print(f"Found {len(projects)} workshop projects in {args.workshop}")
    ok = skipped = 0
    for project_dir in projects:
        status = import_project(project_dir, dest_root, dry=args.list)
        print(f"  {project_dir.name}: {status}")
        if status.startswith(("OK", "WOULD")):
            ok += 1
        else:
            skipped += 1
    print(f"\nDone: {ok} imported, {skipped} skipped.")
    if not args.list and ok:
        print(f"Wallpapers installed under: {dest_root}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
