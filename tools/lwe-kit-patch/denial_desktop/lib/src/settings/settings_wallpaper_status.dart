import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:denial_flutter_sdk/state.dart';
import 'package:denial_flutter_sdk/wallpaper.dart';

/// Only Appearance subscribes, so no shell scene or texture registry is started
/// in the standalone Settings process. Requests are sequential and read-only.
final settingsWallpaperStatusProvider = StreamProvider<WallpaperStatus>((
  ref,
) async* {
  final bridge = ref.watch(denialBridgeProvider);
  var disposed = false;
  ref.onDispose(() => disposed = true);
  while (!disposed) {
    WallpaperStatus status;
    try {
      status = WallpaperStatus.fromJson(await bridge.getWallpaperStatus());
    } on Object {
      status = const WallpaperStatus.unavailable();
    }
    if (disposed) return;
    yield status;
    await Future<void>.delayed(const Duration(seconds: 3));
  }
}, isAutoDispose: true);
