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
    if (id != null) {
      // Spawning the engine during the shell's first-frame window (deniald
      // waits up to 20s for the initial frame) makes the two GPU clients race
      // and the UI never presents, so deniald restores the packaged shell.
      // Defer past that window; the desktop is stable by then.
      lweLog('restore: deferring apply past the first-frame window');
      Timer(const Duration(seconds: 25), () async {
        try {
          await driver.reapStaleInstances();
          await driver.apply(id, state.settings);
          lweLog('delayed apply finished');
        } on Object catch (error) {
          lweLog('delayed apply failed: $error');
        }
      });
    }
  }
}

final lweBootstrapProvider = Provider<LweBootstrap>((ref) {
  return LweBootstrap(
    controller: ref.watch(lweControllerProvider.notifier),
    driver: ref.watch(lweDriverProvider),
  );
});
