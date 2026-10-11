# Denial Wallpaper Engine Plugin

A Denial plugin that integrates Wallpaper Engine wallpapers via linux-wallpaperengine.

## Features

- **Auto-discovery**: Automatically finds Wallpaper Engine workshop wallpapers from Steam
- **Multi-format support**: Scene (3D), Video, GIF, and Web wallpapers
- **Playback controls**: Sound toggle, volume, FPS limiting, fullscreen pause
- **Scaling modes**: stretch, fit, fill, default
- **Multi-screen support**: Single-screen or span across multiple outputs
- **Random/timed rotation**: Automatic wallpaper cycling
- **Settings persistence**: Shared config file with CLI tool
- **Shell integration**: Full integration with Denial's settings and actions

## Installation

Add the plugin to your denial workspace's `pubspec.yaml`:

```yaml
dependencies:
  denial_wallpaper_engine:
    path: /path/to/denial-wallpaper-engine/plugins/denial_wallpaper_engine
```

## Usage

### Programmatic API

```dart
import 'package:denial_wallpaper_engine/denial_wallpaper_engine.dart';

// Get the controller
final controller = ref.read(lweControllerProvider.notifier);

// Set a wallpaper
await controller.setWallpaper('wallpaper_id');

// Update settings
await controller.updateSettings(LweSettings(
  fps: 60,
  volume: 0.5,
  scaling: 'fill',
));

// Get all wallpapers
final discovery = ref.read(workshopDiscoveryProvider);
final wallpapers = await discovery.getWallpapers();
```

### Keyboard Shortcut

The plugin auto-registers **Super+B** on first mount to toggle the wallpaper
manager panel. If you have already bound a different key to
`denial_wallpaper_engine.togglePanel` in Denial's keyboard settings, your
binding is preserved.

To close the panel:

- Press **Super+B** again
- Press **Esc**
- Press the system **close-window** shortcut (e.g. Super+Q) — the panel
  borrows it while open and returns it on close

### Shell Actions

| Action ID | Description |
| --- | --- |
| `denial_wallpaper_engine.togglePanel` | Toggle the wallpaper manager panel |

### Settings

Settings are persisted in `~/.config/denial-wallpaper-engine/config.json`:

```json
{
  "currentWallpaperId": "3421515583",
  "settings": {
    "silent": true,
    "volume": 0,
    "fps": 30,
    "fullscreenPause": true,
    "disableMouse": false,
    "scaling": "default",
    "screenRoot": "",
    "screenSpan": "",
    "audioProcessing": true,
    "automute": true,
    "layer": "bottom"
  }
}
```

## Requirements

- Denial shell (Wayland compositor)
- linux-wallpaperengine (from AUR: `linux-wallpaperengine-git`)
- Steam with Wallpaper Engine installed
- At least one wallpaper downloaded from Steam Workshop

## Development

See the main project README for development setup and integration instructions.

## License

GPL-3.0-or-later