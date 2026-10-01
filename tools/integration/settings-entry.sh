#!/usr/bin/env bash
# Point the launcher Settings entry at the patched shell's settings window.
#
# ## Why
#
# The wallpaper panel lives in denial's own Appearance page, so it only exists
# inside the shell bundle this repository builds. The settings are registered as
# a local Flutter application (a real managed window, which is what makes the
# stock window shortcuts apply) with listedInLauncher: false, because launcher
# entries are namespaced by source and a local application can never displace
# the desktop entry that already fills that slot.
#
# That leaves the desktop entry as the single visible tile, and it has to be
# able to reach the window. The compositor only executes a desktop entry's Exec
# line, and CreateLocalWindow is a shell-to-compositor request, so the Exec has
# to point at a client that asks the shell instead.
#
# ## Where
#
#   system  /usr/share/applications/dev.denial.Settings.desktop   (default)
#           Requires root. A denial upgrade overwrites the file, so the launcher
#           reverts to the official entry by itself rather than silently keeping
#           a stale override. That is the reason to prefer this placement.
#
#   user    ~/.local/share/applications/dev.denial.Settings.desktop
#           Same filename, so it shadows the system entry through the XDG lookup
#           order. No root and no system file is touched, but a denial upgrade
#           will NOT remove it.
#
# Either way the entry never becomes a dead link: lwe-settings falls back to the
# packaged binary whenever the socket is absent, which is the normal state
# before `denial-ui prepare-profile` and after `denialctl ui restore`.
#
# ## After a denial upgrade
#
# The system entry is restored automatically but the shell bundle is not, so
# re-run this once to repoint Exec, and rebuild the bundle if the settings
# application itself was touched upstream:
#
#   denial-ui prepare-profile && denialctl ui profile
#   sudo tools/integration/settings-entry.sh system

set -euo pipefail

scope="${1:-system}"
entry="dev.denial.Settings.desktop"
stock="/usr/share/applications/$entry"

# sudo resets HOME to /root, so "$HOME/.local/bin" would resolve to a path that
# does not exist and the script would bail out before touching anything. Resolve
# the *invoking* user's home instead: SUDO_USER when elevated, HOME otherwise.
# LWE_HOME overrides both, for callers whose home is somewhere unusual.
resolve_home() {
  if [ -n "${LWE_HOME:-}" ]; then
    printf '%s' "$LWE_HOME"
    return
  fi
  if [ -n "${SUDO_USER:-}" ]; then
    getent passwd "$SUDO_USER" | cut -d: -f6
    return
  fi
  printf '%s' "$HOME"
}

home="$(resolve_home)"
client="${2:-$home/.local/bin/lwe-settings}"

if [ ! -x "$client" ]; then
  echo "error: $client is missing or not executable" >&2
  echo "hint: pass the client path explicitly:" >&2
  echo "  $0 ${scope} /path/to/lwe-settings" >&2
  exit 1
fi
if [ ! -f "$stock" ]; then
  echo "error: $stock not found; is denial installed?" >&2
  exit 1
fi

# Derive the override from the live system entry so the icon, translations and
# categories cannot drift from the installed version.
render() {
  sed -e "s|^Exec=.*|Exec=$client|" \
      -e "s|^TryExec=.*|TryExec=$client|" "$stock"
}

case "$scope" in
  system)
    if [ ! -w "$stock" ]; then
      echo "error: $stock is not writable; re-run with sudo:" >&2
      echo "  sudo $0 system" >&2
      exit 1
    fi
    render >"$stock"
    echo "wrote $stock"
    echo "a denial upgrade will restore the official entry on its own"
    ;;
  user)
    target="$home/.local/share/applications/$entry"
    mkdir -p "$(dirname "$target")"
    render >"$target"
    echo "wrote $target"
    echo "note: a denial upgrade will NOT remove this; use 'system' if you want"
    echo "      the launcher to revert on its own"
    ;;
  restore)
    rm -f "$home/.local/share/applications/$entry" &&
      echo "removed the user-level override" ||
      echo "no user-level override to remove"
    if ! grep -q "^Exec=$client$" "$stock"; then
      echo "the system entry is already official"
    elif [ -w "$stock" ]; then
      sed -i \
        -e "s|^Exec=$client\$|Exec=/usr/bin/denial-settings|" \
        -e "s|^TryExec=$client\$|TryExec=/usr/bin/denial-settings|" "$stock"
      echo "restored $stock"
    else
      echo "the system entry still points at $client; restore it with:" >&2
      echo "  sudo sed -i 's|^Exec=$client$|Exec=/usr/bin/denial-settings|;s|^TryExec=$client$|TryExec=/usr/bin/denial-settings|' $stock" >&2
    fi
    echo "note: run 'denialctl ui restore' to put the packaged UI back too."
    ;;
  *)
    echo "usage: $0 [system|user|restore]" >&2
    echo "  system   overwrite /usr/share (needs root; reverts on upgrade)" >&2
    echo "  user     shadow the system entry from ~/.local/share" >&2
    echo "  restore  put the official Exec back and drop the user override" >&2
    exit 1
    ;;
esac
