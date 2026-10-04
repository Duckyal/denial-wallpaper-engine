import 'dart:io';

import 'package:denial_flutter_sdk/environment.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'desktop_profile_store.dart';
export 'desktop_profile_store.dart';

final desktopProfileStoreProvider = Provider<DesktopProfileStore>((ref) {
  final environment = ref.watch(startupEnvironmentProvider);
  final configured = environment['XDG_CONFIG_HOME']?.trim();
  final home = environment['HOME']?.trim();
  final root = configured != null && configured.startsWith('/')
      ? configured
      : home != null && home.startsWith('/')
      ? '$home/.config'
      : '/nonexistent';
  return DesktopProfileStore(
    Directory('$root/denial/plugins/denial_desktop/profile'),
  );
});

final desktopProfileProvider = StreamProvider<DesktopProfile>(
  (ref) => ref.watch(desktopProfileStoreProvider).watch(),
);

final desktopAccountNameProvider = Provider<String?>((ref) {
  final environment = ref.watch(startupEnvironmentProvider);
  return [environment['USER'], environment['LOGNAME']]
      .whereType<String>()
      .map((name) => name.trim())
      .where((name) => name.isNotEmpty)
      .firstOrNull;
});
