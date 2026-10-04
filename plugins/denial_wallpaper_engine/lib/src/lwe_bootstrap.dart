import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'lwe_controller.dart';
import 'lwe_debug.dart';
import 'lwe_driver.dart';

/// Handles startup restoration of the last active wallpaper.
class LweBootstrap {
  LweBootstrap({required this.controller, required this.driver});

  final LweController controller;
  final LweDriver driver;
  bool _restored = false;

  Future<void> restoreOnStartup() async {
    // The scene can mount the surface more than once (desktop scene rebuilds,
    // additional output environments); only the first mount spawns a process.
    if (_restored) {
      lweLog('restore skipped (already ran this session)');
      return;
    }
    _restored = true;
    final state = await controller.current();
    final id = state.currentWallpaperId;
    lweLog('restore: enabled=${state.enabled} id=$id');
    // Honor a persisted disable: turning the wallpaper off before a reboot
    // must keep it off after the reboot. The panel toggle reads this same
    // flag, so spawning anyway left it showing "off" over a live wallpaper.
    if (!state.enabled || id == null) return;
    // Spawning the engine during the shell's first-frame window (deniald
    // waits up to 20s for the initial frame) makes the two GPU clients race
    // and the UI never presents, so deniald restores the packaged shell.
    // Defer past that window; the desktop is stable by then.
    lweLog('restore: deferring apply past the first-frame window');
    unawaited(
      driver
          .scheduleApply(
            const Duration(seconds: 25),
            id,
            state.settings,
            shouldRun: () async => (await controller.current()).enabled,
          )
          .then(
            (_) => lweLog('delayed apply finished'),
            onError: (Object error, StackTrace _) {
              lweLog('delayed apply failed: $error');
            },
          ),
    );
  }
}

final lweBootstrapProvider = Provider<LweBootstrap>((ref) {
  return LweBootstrap(
    controller: ref.watch(lweControllerProvider.notifier),
    driver: ref.watch(lweDriverProvider),
  );
});
