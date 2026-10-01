import 'package:denial_dart_shell/denial.dart';
import 'package:denial_dynamic_wallpaper/denial_dynamic_wallpaper.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A denial custom shell that drives Wallpaper Engine wallpapers through
/// linux-wallpaperengine, with the plugin's settings panel available.
///
/// This is the official extension point documented in
/// docs/CUSTOM_SHELLS.md of the denial repository.
///
/// Run with:
///   flutter run -t example/custom_dynamic_shell.dart
///
/// Startup behaviour (no systemd, no cron, no autostart entry needed):
/// denial launches this shell -> the shell restores the last active wallpaper
/// -> the wallpaper process is a child of denial and dies with it.
void main() {
  runDenialShell(
    shell: const DenialShell(
      mobile: DenialShellScene(content: DynamicMobileShell()),
      desktop: DenialShellScene(content: DynamicDesktopShell()),
    ),
  );
}

/// Restores the persisted wallpaper once, right after the shell mounts.
///
/// Placed in the widget tree so it runs exactly once per denial session and
/// has access to the plugin's Riverpod providers.
class _WallpaperStartup extends ConsumerStatefulWidget {
  const _WallpaperStartup();

  @override
  ConsumerState<_WallpaperStartup> createState() => _WallpaperStartupState();
}

class _WallpaperStartupState extends ConsumerState<_WallpaperStartup> {
  @override
  void initState() {
    super.initState();
    // Restore the last active wallpaper (resolves AUTO_SPAN, checks that
    // linux-wallpaperengine is installed, then relaunches it).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(lweBootstrapProvider).restoreOnStartup();
    });
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class DynamicMobileShell extends StatelessWidget {
  const DynamicMobileShell({super.key});

  @override
  Widget build(BuildContext context) {
    return const Stack(
      fit: StackFit.expand,
      children: [
        DynamicWallpaperCanvas(),
        _WallpaperStartup(),
      ],
    );
  }
}

class DynamicDesktopShell extends StatelessWidget {
  const DynamicDesktopShell({super.key});

  @override
  Widget build(BuildContext context) {
    return const Stack(
      fit: StackFit.expand,
      children: [
        DynamicWallpaperCanvas(),
        _WallpaperStartup(),
      ],
    );
  }
}
