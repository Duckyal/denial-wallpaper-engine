@Plugin()
library;

import 'src/features/default_shell/default_shell_app.dart';

import 'package:denial_flutter_sdk/application.dart';
import 'package:denial_flutter_sdk/surfaces.dart';
import 'package:denial_flutter_sdk/launcher.dart';
import 'package:denial_flutter_sdk/actions.dart';
import 'package:denial_sdk/composition.dart';
import 'package:flutter/widgets.dart';

/// Reference scene mounts plugin-declared surfaces through the SDK.
@Provides(ShellApplication)
class ReferenceDesktop implements ShellApplication {
  const ReferenceDesktop({
    this.surfaces = const [],
    this.workArea,
    this.launcher,
    this.actions = const [],
  });
  final List<ShellSurface> surfaces;
  final ShellWorkArea? workArea;
  final ShellLauncher? launcher;
  final List<ShellAction> actions;

  @override
  Widget createShell() => DenialShellApp(
    desktopSurfaces: surfaces,
    desktopWorkArea: workArea,
    desktopLauncher: launcher,
    actions: actions,
  );
}
