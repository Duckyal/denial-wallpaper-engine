import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'lwe_controller.dart';
import 'lwe_driver.dart';

/// Watches the shared config file for changes made by OUTSIDE processes
/// (the denial-wp CLI, scripts, the settings app).
///
/// Writes performed by this process (panel saves) record their content in
/// [lastConfigWrite]; a reload that reads back exactly that content is our
/// own echo and must not restart the engine. External `enabled: false`
/// stops the wallpaper instead of resurrecting it.
///
/// Additionally tracks the file's modification time so a same-content write
/// (e.g. an external `touch` followed by a revert) does not trigger a
/// spurious engine restart.
class LweConfigWatcher {
  LweConfigWatcher({required this.driver});

  final LweDriver driver;
  StreamSubscription<FileSystemEvent>? _subscription;
  Timer? _debounce;
  DateTime? _lastModified;

  void start() {
    final file = File(configPath());
    _subscription = file.parent.watch(events: FileSystemEvent.modify).listen((
      _,
    ) {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 500), _reload);
    });
  }

  Future<void> _reload() async {
    try {
      final file = File(configPath());
      final stat = await file.stat();
      if (stat.modified == _lastModified) return;
      _lastModified = stat.modified;
      final content = await file.readAsString();
      if (content == lastConfigWrite) return;
      final json = jsonDecode(content) as Map<String, dynamic>;
      final state = LweState.fromJson(json);
      if (!state.enabled) {
        await driver.stop();
        return;
      }
      final id = state.currentWallpaperId;
      if (id != null && id.isNotEmpty) {
        await driver.apply(id, state.settings);
      }
    } on Object catch (error) {
      debugPrint('LWE: config reload failed: $error');
    }
  }

  void stop() {
    _subscription?.cancel();
    _debounce?.cancel();
  }
}

final lweConfigWatcherProvider = Provider<LweConfigWatcher>((ref) {
  return LweConfigWatcher(driver: ref.watch(lweDriverProvider));
});