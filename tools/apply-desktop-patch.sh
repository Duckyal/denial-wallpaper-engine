#!/usr/bin/env bash
# apply-desktop-patch.sh — re-apply the Wallpaper Engine settings card to the
# denial_desktop plugin inside the user build-kit.
#
# denial-plugins prepare rebuilds the build-kit from the system runtime, which
# wipes this patch. Run this script after every `denial-plugins prepare`.
#
# The patch adds a "动态壁纸 (Wallpaper Engine)" card group below the official
# wallpaper card on the Settings > Appearance page. It wires the card to the
# denial_wallpaper_engine package (absolute path below), which must stay
# installed via `denial-plugins --local add` for composition builds to resolve.
set -euo pipefail

PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../plugins/denial_wallpaper_engine" && pwd)"
PATCH_SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/desktop-patch" && pwd)/settings_dynamic_wallpaper_card.dart"

# Newest build-kit wins; prepare recreates kit dirs with new hashes.
KIT="$(ls -dt "$HOME"/.local/state/denial/plugins/build-kits/*/ 2>/dev/null | head -1)"
if [[ -z "${KIT}" ]]; then
    echo "error: no build-kit found; run 'denial-plugins prepare' first" >&2
    exit 1
fi
DESKTOP="$KIT/runtime/plugins/denial_desktop"
WIDGETS="$DESKTOP/lib/src/settings/widgets"

if [[ ! -d "$DESKTOP" ]]; then
    echo "error: denial_desktop not found under $KIT" >&2
    exit 1
fi

echo "build-kit: $KIT"

# 1) Drop in the settings card widget.
cp "$PATCH_SRC" "$WIDGETS/settings_dynamic_wallpaper_card.dart"
echo "widget copied"

# 2) Register the plugin dependency in denial_desktop's pubspec.
python3 - "$DESKTOP/pubspec.yaml" "$PLUGIN_DIR" << 'EOF'
import sys
from pathlib import Path

pubspec = Path(sys.argv[1])
plugin = sys.argv[2]
text = pubspec.read_text()
needle = "  denial_flutter_sdk:\n    path: ../../packages/denial_flutter_sdk\n"
addition = needle + (
    "  denial_wallpaper_engine:\n"
    f"    path: {plugin}\n"
)
if "denial_wallpaper_engine:" in text:
    print("pubspec already patched")
elif needle in text:
    pubspec.write_text(text.replace(needle, addition))
    print("pubspec patched")
else:
    sys.exit("error: expected anchor not found in denial_desktop pubspec.yaml")
EOF

# 3) Import + insert the card into the Appearance page.
python3 - "$DESKTOP/lib/src/settings/widgets/settings_appearance_page.dart" << 'EOF'
import sys
from pathlib import Path

page = Path(sys.argv[1])
text = page.read_text()
if "LweDynamicWallpaperCard" in text:
    print("appearance page already patched")
    sys.exit(0)

old_import = "import 'settings_wallpaper_card.dart';\n"
new_import = old_import + "import 'settings_dynamic_wallpaper_card.dart';\n"
if old_import not in text:
    sys.exit("error: import anchor not found")
text = text.replace(old_import, new_import)

old_card = """        SettingsWallpaperCard(
          chooseKey: settingsWallpaperTriggerKey,
          wallpaper: widget.wallpaper,
          wallpaperApps: widget.wallpaperApps,
          outputName: widget.wallpaperOutputName,
          onChoose: widget.onOpenWallpaperSelector,
        ),
"""
new_card = old_card + "        const LweDynamicWallpaperCard(),\n"
if old_card not in text:
    sys.exit("error: wallpaper card anchor not found")
text = text.replace(old_card, new_card)
page.write_text(text)
print("appearance page patched")
EOF

# 4) Local SDK overrides so standalone pub get inside denial_desktop works.
if [[ ! -f "$DESKTOP/pubspec_overrides.yaml" ]]; then
    cat > "$DESKTOP/pubspec_overrides.yaml" << EOF
dependency_overrides:
  denial_sdk:
    path: ${KIT}runtime/packages/denial_sdk
  denial_flutter_sdk:
    path: ${KIT}runtime/packages/denial_flutter_sdk
EOF
    echo "pubspec_overrides written"
fi

# 5) Sync kit.json digests for every file this patch touched, so the
# plugin-manager's initialize check ("Build kit input changed") accepts the
# patched runtime. Without this, GUI add/plan fails after each prepare+patch.
python3 - "$KIT" << 'EOF'
import hashlib
import json
import os
import sys

kit = sys.argv[1].rstrip('/')
kit_json = os.path.join(kit, 'kit.json')
touched = [
    'runtime/plugins/denial_desktop/lib/src/settings/widgets/settings_dynamic_wallpaper_card.dart',
    'runtime/plugins/denial_desktop/lib/src/settings/widgets/settings_appearance_page.dart',
    'runtime/plugins/denial_desktop/lib/src/settings/widgets/settings_wallpaper_card.dart',
    'runtime/plugins/denial_desktop/pubspec.yaml',
    'runtime/plugins/denial_desktop/pubspec.lock',
    'runtime/plugins/denial_desktop/pubspec_overrides.yaml',
]
with open(kit_json) as f:
    data = json.load(f)
files = data.setdefault('files', {})
updated = 0
for rel in touched:
    p = os.path.join(kit, rel)
    if not os.path.isfile(p):
        continue
    with open(p, 'rb') as fh:
        digest = hashlib.sha256(fh.read()).hexdigest()
    if files.get(rel) != digest:
        files[rel] = digest
        updated += 1
with open(kit_json, 'w') as f:
    json.dump(data, f, indent=2)
print(f'kit.json digests synced ({updated} changed)')
EOF

echo "done. now run:"
echo "  cd '$PLUGIN_DIR' && denial-plugins plan"
echo "  denial-plugins build <id> && denial-plugins activate <id>"
