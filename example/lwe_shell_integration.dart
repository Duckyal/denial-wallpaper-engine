// Shell-side integration for denial_dynamic_wallpaper.
//
// Drop this file into your denial UI workspace (default: ~/DenialUI) as
//   dart_shell/lib/lwe_shell_integration.dart
// and add [LweShellIntegration] to the desktop/mobile `overlays` list in
//   dart_shell/lib/src/features/default_shell/default_shell_app.dart
//
// ## Why so little code?
//
// Rendering is done by the external linux-wallpaperengine process, which
// anchors itself to the wlr-layer-shell bottom layer. Denial implements
// zwlr_layer_shell_v1, so the wallpaper composites behind windows without any
// compositor integration from us. All this widget does is start the process
// once the shell mounts, restoring whatever wallpaper was active last time.
//
// ## Why does it render nothing?
//
// It deliberately renders an empty box and swallows no pointer events. The
// desktop scene owns a large focus tree (window search fields, launcher
// search, text inputs). Grabbing focus or a full-screen hit area from an
// overlay would break typing in windows, so this widget stays inert and only
// performs a one-shot side effect.
//
// Settings are driven by the `denial-wp` CLI, which shares this plugin's
// config file (~/.config/denial-wallpaper-engine/config.json). The settings
// panel widget (LweSettingsPanel) stays available for a future GUI entry point.

import 'package:denial_wallpaper/denial_wallpaper.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Starts the Wallpaper Engine process when the shell mounts and restores the
/// wallpaper that was active in the previous session.
class LweShellIntegration extends ConsumerStatefulWidget {
  const LweShellIntegration({super.key});

  @override
  ConsumerState<LweShellIntegration> createState() =>
      _LweShellIntegrationState();
}

class _LweShellIntegrationState extends ConsumerState<LweShellIntegration> {
  @override
  void initState() {
    super.initState();
    debugPrint('LWE: LweShellIntegration mounted');
    // Start after the first frame so the shell finishes mounting before we
    // spawn a process.
    WidgetsBinding.instance.addPostFrameCallback((_) => _restore());
  }

  Future<void> _restore() async {
    if (!mounted) return;
    try {
      // The panel can be mounted in this same process (as a Denial local
      // application), so let it apply changes immediately instead of waiting
      // for the config watcher poll.
      ref.read(lweApplierProvider).attach(
        (id, settings) async {
          await ref.read(lweDriverProvider).apply(id, settings);
        },
        stop: () async {
          await ref.read(lweDriverProvider).stop();
        },
      );
      // Watch the shared config so edits made by the separate denial-wp CLI
      // also reach the wallpaper we own.
      ref.read(lweConfigWatcherProvider).start();
      await ref.read(lweBootstrapProvider).restoreOnStartup();
      // Rotation is owned by the shell: only the shell may restart the
      // wallpaper, and the settings panel runs in this same process, so the
      // period is read straight off the controller and re-armed when it
      // changes (including edits that arrive through the config file).
      void armRotation(LweState? state) {
        if (state == null) return;
        ref
            .read(lweRandomizerProvider)
            .startRotation(minutes: state.rotationMinutes);
      }

      armRotation(ref.read(lweControllerProvider).value);
      ref.listen(lweControllerProvider, (previous, next) {
        armRotation(next.value);
      });
    } on Object catch (error, stack) {
      // Never let a wallpaper failure take the shell down with it.
      debugPrint('LWE: startup failed: $error\n$stack');
    }
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
