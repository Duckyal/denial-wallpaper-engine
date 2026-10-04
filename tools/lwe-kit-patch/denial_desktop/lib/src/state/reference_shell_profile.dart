import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:denial_flutter_sdk/environment.dart';

enum ReferenceShellProfile {
  mobile,
  desktop;

  /// Selects the mobile shell only when it was requested explicitly.
  ///
  /// The compositor is a desktop product, so a missing or malformed
  /// environment must never make a direct `deniald` launch fall back to the
  /// mobile development shell.
  static ReferenceShellProfile fromEnvironment(
    Map<String, String> environment,
  ) {
    return denialEnvironmentValue(environment, 'DENIAL_SHELL_PROFILE') ==
            'mobile'
        ? ReferenceShellProfile.mobile
        : ReferenceShellProfile.desktop;
  }
}

final referenceShellProfileProvider = Provider<ReferenceShellProfile>((ref) {
  return ReferenceShellProfile.fromEnvironment(
    ref.watch(startupEnvironmentProvider).values,
  );
});
