#!/usr/bin/env bash
# Re-apply the Wallpaper Engine integration onto a Denial UI workspace.
#
# Denial upgrades replace ~/DenialUI with a clean checkout, so the five patched
# files and three added files have to be replayed. This script does that
# idempotently: safe to run on a workspace that is already patched.
#
#   ./apply-to-workspace.sh [WORKSPACE]     # default: $DENIAL_UI_WORKSPACE or ~/DenialUI
#
# What it touches, and why each piece exists:
#
#   denial-integration.patch   the five denial source files. Each hunk is a
#                              thin extension point, not a behavioural change:
#                                main.dart                  register the local app
#                                desktop_shell.dart         prefer the in-shell
#                                                         settings window
#                                settings_application.dart  forward the slot
#                                settings_appearance_page.dart  the Wallpaper slot
#                                default_shell_app.dart     start the wallpaper
#   lwe_shell_integration.dart starts the wallpaper process and the config
#                              watcher from the shell scene
#   lwe_local_app.dart        hosts denial's settings UI with the panel
#                              embedded in Appearance > Wallpaper
#   lwe_translucent_theme.dart makes the panel use denial's translucent tokens
#   pubspec.yaml               path dependency on this plugin
#
# If Denial lands a real plugin API, the patch becomes unnecessary and only the
# plugin package needs to keep building. See docs/PLUGIN_API_NOTES.md.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
PROJECT="$(cd "$HERE/../.." && pwd)"
PLUGIN="${LWE_PLUGIN_PATH:-$PROJECT/plugin}"
WORKSPACE="${1:-${DENIAL_UI_WORKSPACE:-$HOME/DenialUI}}"
SHELL_DIR="$WORKSPACE/dart_shell"

if [[ ! -f "$SHELL_DIR/pubspec.yaml" ]]; then
    cat >&2 <<EOF
error: no Flutter workspace at $SHELL_DIR

Create it first:
    sudo pacman -S denial-ui-development
    denialctl ui setup
EOF
    exit 1
fi

if [[ ! -f "$PLUGIN/pubspec.yaml" ]]; then
    echo "error: plugin not found at $PLUGIN" >&2
    exit 1
fi

echo "==> workspace: $WORKSPACE"
echo "==> plugin:    $PLUGIN"

# 1. Added files. Copied unconditionally; they are ours, not denial's.
echo "==> copying integration files"
for file in lwe_shell_integration.dart lwe_local_app.dart lwe_translucent_theme.dart; do
    install -m 644 "$HERE/shell/$file" "$SHELL_DIR/lib/$file"
    echo "    lib/$file"
done

# 2. Patched denial sources. Skip hunks that already applied; report rejects so
#    a Denial refactor is visible instead of silently dropped.
echo "==> applying patch to denial sources"
if git -C "$WORKSPACE" apply --check --3way "$HERE/denial-integration.patch" 2>/dev/null; then
    git -C "$WORKSPACE" apply --3way "$HERE/denial-integration.patch"
    echo "    applied cleanly"
else
    # Either already applied, or the context moved. Distinguish the two.
    if git -C "$WORKSPACE" apply --reverse --check "$HERE/denial-integration.patch" 2>/dev/null; then
        echo "    already applied; nothing to do"
    else
        git -C "$WORKSPACE" apply --3way "$HERE/denial-integration.patch" || {
            echo >&2
            echo "error: patch does not apply cleanly. Denial's sources changed." >&2
            echo "Resolve manually, then re-run this script (it is idempotent):" >&2
            echo "    git -C $WORKSPACE apply --3way $HERE/denial-integration.patch" >&2
            exit 1
        }
        echo "    applied with fuzz; review the hunks above"
    fi
fi

# 3. Plugin dependency.
echo "==> wiring the plugin dependency"
if ! grep -q 'denial_dynamic_wallpaper:' "$SHELL_DIR/pubspec.yaml"; then
    python3 - "$SHELL_DIR/pubspec.yaml" "$PLUGIN" <<'PY'
import sys, pathlib
pubspec, plugin = pathlib.Path(sys.argv[1]), sys.argv[2]
text = pubspec.read_text()
anchor = "dev_dependencies:"
addition = (
    "  # Wallpaper Engine integration. Drives the external\n"
    "  # linux-wallpaperengine process through wlr-layer-shell.\n"
    f"  denial_dynamic_wallpaper:\n    path: {plugin}\n"
)
if anchor not in text:
    raise SystemExit(f"error: no dev_dependencies: anchor in {pubspec}")
pubspec.write_text(text.replace(anchor, addition + "\n" + anchor, 1))
print(f"    added path dependency -> {plugin}")
PY
else
    # Keep the recorded path in sync when the plugin moves.
    python3 - "$SHELL_DIR/pubspec.yaml" "$PLUGIN" <<'PY'
import re, sys, pathlib
pubspec, plugin = pathlib.Path(sys.argv[1]), sys.argv[2]
text = pubspec.read_text()
updated = re.sub(
    r"(denial_dynamic_wallpaper:\n\s*path: )\S+",
    lambda m: m.group(1) + plugin,
    text,
    count=1,
)
if updated != text:
    pubspec.write_text(updated)
    print(f"    refreshed plugin path -> {plugin}")
else:
    print("    already declared")
PY
fi

echo "==> resolving dependencies"
(cd "$SHELL_DIR" && flutter pub get >/dev/null)

cat <<EOF

Done. Next:

    cd $WORKSPACE && denial-ui prepare-profile
    denialctl ui profile

Check what changed against upstream:

    git -C $WORKSPACE diff --stat
EOF
