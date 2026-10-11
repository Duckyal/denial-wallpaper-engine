# denial-wallpaper-engine

Bring **Wallpaper Engine**'s massive wallpaper library into the **denial** desktop (Wayland compositor).

> **Current status: restructured into the official Denial plugin format.**
> Follows the [denial-wallpaper-engine](https://github.com/Duckyal/denial-wallpaper-engine) spec.

[中文](README.md)

---

## 1. What does this do?

```
┌──────────────────────────────────────────────┐
│  Denial wallpaper manager panel (ShellSurface)│
│  Preview grid · sound · volume · FPS · scale  │
│  Rotation interval · mouse interaction ·      │
│  fullscreen pause                             │
└────────────────┬─────────────────────────────┘
                 │  This plugin (integration layer)
                 │  · Auto-discover workshop wallpapers
                 │  · Settings persistence
                 │  · Random / timed rotation
                 │  · Process lifecycle management
                 ▼
┌──────────────────────────────────────────────┐
│  linux-wallpaperengine (rendering core)       │
│  Scene / Video / Web — all types supported    │
│  Composites via wlr-layer-shell on bottom     │
└──────────────────────────────────────────────┘
```

**Design principle**: Rendering is delegated to the mature linux-wallpaperengine
(4.6k stars, real 3D Scene engine + CEF + MPV). This plugin is purely an
integration layer.

**Key insight**: denial implements `zwlr_layer_shell_v1`, and
linux-wallpaperengine defaults to `--layer bottom`. The wallpaper is an
**independent process that composites itself onto the bottom layer** — denial
places it behind windows automatically. **No compositor source changes needed.**

---

## 2. Features

- **Workshop auto-discovery**: Scans all Steam installation layouts
  (native / Flatpak / Snap / custom library) for
  `steamapps/workshop/content/431960` and lists subscribed wallpapers
- **Full type support**: Scene (real 3D), Video, Web — handled by the rendering core
- **Playback controls**: Sound toggle, volume, FPS cap, fullscreen pause
  (optionally only for the focused window), mouse interaction, particles,
  parallax, auto-duck
- **Scaling modes**: default / fit / fill / stretch
- **Target output**: Specify an output name via `screenRoot` in settings
  (maps to `--screen-root`); if unset the engine falls back to a normal window,
  so explicit configuration is recommended in production
- **Random / timed rotation**: Optionally cycle wallpapers at a fixed interval,
  with a custom rotation playlist
- **Settings persistence**: `~/.config/denial-wallpaper-engine/config.json`;
  external edits are watched and hot-applied to the running renderer
- **Startup restore**: Mounts with the shell and automatically restores the last
  active wallpaper

---

## 3. Dependencies

| Dependency | Description |
| --- | --- |
| denial | Wayland compositor providing `zwlr_layer_shell_v1` and the plugin runtime |
| linux-wallpaperengine | Rendering core (AUR: `linux-wallpaperengine-git`), must be in `PATH` |
| Steam + Wallpaper Engine | With at least one subscribed Workshop wallpaper downloaded |

---

## 4. Project Structure

```
denial-wallpaper-engine/
├── plugins.yaml                     # Plugin catalog (for Denial discovery)
├── AGENTS.md                        # Agent execution rules
├── README.md                        # Chinese README
├── README.en.md                     # English README
├── LICENSE
├── docs/
│   ├── DEVELOPMENT.md              # Dev, validation, local install workflow
│   ├── STARTUP.md                  # Startup auto-activation chain
│   ├── INTEGRATION.md              # Integration with Denial's wallpaper settings
│   ├── COMPARISON.md               # Capability comparison vs linux-wallpaperengine / WE
│   └── PLUGIN_STORE.md             # Plugin store onboarding guide
├── plugins/
│   └── denial_wallpaper_engine/     # Plugin package (independently publishable Dart package)
│       ├── pubspec.yaml            # Package manifest + denial_plugin metadata
│       ├── pubspec_overrides.yaml.example  # Local SDK override example
│       ├── README.md               # Plugin-level English docs
│       ├── LICENSE
│       └── lib/
│           ├── denial_wallpaper_engine.dart  # @Plugin() entry & @Provides declarations
│           └── src/
│               ├── lwe_panel.dart            # Wallpaper manager panel UI
│               ├── lwe_panel_bus.dart        # Panel open/close event bus
│               ├── lwe_controller.dart       # State + config persistence + draft commit
│               ├── lwe_driver.dart           # Renderer process driver (start/stop/CLI/cleanup)
│               ├── lwe_config_watcher.dart   # External config file watcher
│               ├── lwe_bootstrap.dart        # Startup wallpaper restore
│               ├── lwe_debug.dart            # Log toggle
│               └── workshop_discovery.dart   # Steam Workshop auto-discovery
├── tools/
│   ├── we_importer.py              # Import workshop wallpapers into Denial's dynamic dir
│   ├── apply-desktop-patch.sh      # Apply denial_desktop integration patch
│   ├── desktop-patch/              # Official wallpaper settings panel patch snippets
│   ├── integration/                # Workspace integration scripts & patches
│   └── lwe-kit-patch/              # Reference denial_desktop source snapshot
├── examples/
│   └── ocean-waves/                # Example dynamic wallpaper
└── install.sh                      # Legacy manual install script
```

---

## 5. Installation

### Via Denial's Plugins app (recommended)

1. Open the Plugins app
2. Click "Add Plugins" in the top-right corner
3. Paste this repository's URL
4. Click "Find plugins"

### Via denial-plugins CLI

```sh
denial-plugins add https://github.com/Duckyal/denial-wallpaper-engine.git
denial-plugins plan
denial-plugins build CANDIDATE_ID
denial-plugins activate CANDIDATE_ID
```

### Local development install

Run from the repository root:

```sh
denial-plugins --local add "$PWD"
denial-plugins plan
denial-plugins build CANDIDATE_ID
denial-plugins activate CANDIDATE_ID
```

---

## 6. Usage

### Keyboard Shortcut

The plugin auto-registers **Super+B** on first mount to
`denial_wallpaper_engine.togglePanel`, which opens/closes the wallpaper
manager panel. If you have already bound a different key in Denial's keyboard
settings, your binding is preserved. You can also rebind it there at any time.

Ways to close the panel:

- Press **Super+B** again
- Press **Esc**
- Press the system **close-window** shortcut (e.g. Super+Q): the panel borrows
  this binding while open and returns it on close. If the plugin crashes
  mid-panel, borrowed shortcuts are automatically repaired on next startup.

Edits inside the panel go into a draft first; pressing "Apply" writes them to
the config file and hot-applies them in one shot.

### Shell Actions

| Action ID | Description |
| --- | --- |
| `denial_wallpaper_engine.togglePanel` | Toggle the wallpaper manager panel |

### Config File

```json
// ~/.config/denial-wallpaper-engine/config.json
{
  "currentWallpaperId": "3421515583",
  "enabled": true,
  "rotationMinutes": 0,
  "playlist": [],
  "settings": {
    "silent": true,
    "volume": 0,
    "fps": 30,
    "scaling": "default",
    "fullscreenPause": true,
    "fullscreenPauseOnlyActive": false,
    "disableMouse": false,
    "disableParticles": false,
    "disableParallax": false,
    "audioProcessing": true,
    "automute": true,
    "layer": "bottom",
    "screenRoot": ""
  }
}
```

---

## 7. Auxiliary Tools

```sh
# Import workshop wallpapers into Denial's dynamic wallpaper directory
python3 tools/we_importer.py --workshop ~/.steam/steam/steamapps/workshop/content/431960 \
  --dest ~/.local/share/denial/wallpapers/dynamic

# Hook a "Dynamic Wallpaper" card into Settings > Appearance (requires CLI workspace integration)
# Note: re-run after every `denial-plugins prepare` rebuild
./tools/apply-desktop-patch.sh
```

---

## 8. Development

Full workflow (prepare, local SDK overrides, `analyze --fatal-infos`, build & activate)
is in [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md).

```sh
cd plugins/denial_wallpaper_engine
"$DENIAL_PLUGIN_FLUTTER" pub get
"$DENIAL_PLUGIN_DART" format --output=none --set-exit-if-changed lib
"$DENIAL_PLUGIN_DART" analyze --fatal-infos lib
```

---

## 9. License

GPL-3.0-or-later