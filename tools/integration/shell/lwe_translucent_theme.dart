// Translucent Material theme for the Wallpaper Engine panel.
//
// The shell provides `AnimatedShellTheme` but no Flutter `Theme`, so
// `Theme.of(context)` inside the panel falls back to the stock Material
// defaults: opaque `surfaceContainer*` colours, which is why the panel's
// cards and sections rendered as a white slab instead of picking up the
// desktop's blur and transparency.
//
// This wrapper builds a Theme from the shell's own resolution, so Material
// widgets resolve to the same translucent tokens the rest of the shell uses.
// It lives in the shell package because `ShellTheme` is only reachable from
// here; the plugin package stays theme-agnostic.

import 'package:denial_dart_shell/denial.dart';
import 'package:flutter/material.dart';

class LweTranslucentTheme extends StatelessWidget {
  const LweTranslucentTheme({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final shell = context.shellTheme;
    final colors = context.shellColors;
    final base = shell.toMaterialTheme();
    final scheme = base.colorScheme;

    // Resolve each surface through the shell's own opacity pipeline, then let
    // alpha carry the transparency. Cards keep their borders so they stay
    // legible against whatever is behind the settings window.
    Color surface(Color token) => shell.cardColor(token);

    return Theme(
      data: base.copyWith(
        scaffoldBackgroundColor: Colors.transparent,
        canvasColor: Colors.transparent,
        cardColor: Colors.transparent,
        dialogTheme: base.dialogTheme.copyWith(
          backgroundColor: surface(colors.surfaceContainerHigh),
          surfaceTintColor: Colors.transparent,
        ),
        colorScheme: scheme.copyWith(
          surface: Colors.transparent,
          surfaceTint: Colors.transparent,
          surfaceContainerLowest: Colors.transparent,
          surfaceContainerLow: surface(colors.surfaceContainerLow),
          surfaceContainer: surface(colors.surfaceContainer),
          surfaceContainerHigh: surface(colors.surfaceContainerHigh),
          surfaceContainerHighest: surface(colors.surfaceContainerHighest),
        ),
        cardTheme: base.cardTheme.copyWith(
          color: surface(colors.surfaceContainerLow),
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          margin: EdgeInsets.zero,
        ),
        dividerTheme: base.dividerTheme.copyWith(
          color: colors.hairlineSoft,
          space: 1,
          thickness: 1,
        ),
      ),
      child: child,
    );
  }
}
