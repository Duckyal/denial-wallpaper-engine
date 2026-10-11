# Denial Wallpaper Engine Plugin

A Denial plugin that integrates Wallpaper Engine wallpapers via linux-wallpaperengine.

## Repository workflow

Trusted development lands on `dev` first. Run validation before pushing.

For plugin development, refer to `docs/DEVELOPMENT.md` (if present) or the
[Denial plugin development guide](https://github.com/denialwm/denial/blob/dev/docs/PLUGIN_DEVELOPMENT.md).

## Plugin structure

This repository follows the [denial-wallpaper-engine](https://github.com/Duckyal/denial-wallpaper-engine)
collection format:

- `plugins/denial_wallpaper_engine/` — the installable Dart package
- `plugins.yaml` — discovery catalog for Denial's Plugin Manager
- `tools/` — CLI utilities (denial-wp)

## Development

### Prerequisites

```sh
denial-plugins prepare
```

### Local SDK overrides

Create `pubspec_overrides.yaml` in `plugins/denial_wallpaper_engine/`:

```yaml
dependency_overrides:
  denial_sdk:
    path: /ABSOLUTE/RUNTIME/packages/denial_sdk
  denial_flutter_sdk:
    path: /ABSOLUTE/RUNTIME/packages/denial_flutter_sdk
```

### Validate

```sh
cd plugins/denial_wallpaper_engine
"$DENIAL_PLUGIN_FLUTTER" pub get
"$DENIAL_PLUGIN_DART" format --output=none --set-exit-if-changed lib
"$DENIAL_PLUGIN_DART" analyze --fatal-infos lib
```

### Install and apply

```sh
denial-plugins --local add "$PWD"
denial-plugins plan
denial-plugins build CANDIDATE_ID
denial-plugins activate CANDIDATE_ID
```

## Graphical session control

Never log out, terminate, restart, or otherwise stop the user's local graphical
session on the user's behalf. When testing requires a fresh local Denial session,
tell the user that a restart is required and wait for the user to log off and
return to their display manager themselves.

## User-owned visual validation

The user performs all visual validation. Never capture or inspect screenshots,
judge rendered output, launch applications for visual inspection, or create UI
state for visual QA without explicit user authorization.