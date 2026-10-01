#!/usr/bin/env bash
# denial-wallpaper-engine installer.
#
# 1. Copies example wallpapers into the denial dynamic wallpaper root.
# 2. Optionally imports Wallpaper Engine workshop wallpapers.
# 3. Prints next steps for wiring the custom shell entry point.
set -euo pipefail

DEST="${HOME}/.local/share/denial/wallpapers/dynamic"
HERE="$(cd "$(dirname "$0")" && pwd)"

mkdir -p "$DEST"

if [ -d "$HERE/examples/ocean-waves" ]; then
  cp -r "$HERE/examples/ocean-waves" "$DEST/"
  echo "[ok] installed example wallpaper: ocean-waves"
fi

if [ -n "${1:-}" ]; then
  echo "[..] importing Wallpaper Engine workshop wallpapers from: $1"
  python3 "$HERE/tools/we_importer.py" --workshop "$1" --dest "$DEST"
fi

cat <<EOF

denial-wallpaper-engine installed.

Next steps:
  1. Add the plugin to your shell's pubspec.yaml:

       dependencies:
         denial_dynamic_wallpaper:
           path: $HERE/plugin

  2. Use the canvas in your custom shell (see example/custom_dynamic_shell.dart):

       import 'package:denial_dynamic_wallpaper/denial_dynamic_wallpaper.dart';

       Stack(children: [DynamicWallpaperCanvas(), ...your desktop widgets])

  3. Activate a wallpaper:

       echo ocean-waves > ~/.local/share/denial/wallpapers/dynamic/.active

EOF
