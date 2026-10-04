import 'package:denial_flutter_sdk/materials.dart';
import 'package:flutter/material.dart';

import 'welcome_contrast.dart';

/// Welcome's accent contrast does not change other applications' themes.
ThemeData welcomeTheme(BuildContext context) {
  final base = context.applicationTheme.materialTheme;
  final colors = context.applicationColors;
  final accent = base.colorScheme.primary;
  final readableAccent = Color(
    welcomeReadableAccent(accent.toARGB32(), [
      colors.canvas.toARGB32(),
      colors.raised.toARGB32(),
      colors.control.toARGB32(),
    ]),
  );
  final foreground = WidgetStateProperty.resolveWith<Color>(
    (states) => states.contains(WidgetState.disabled)
        ? colors.secondary
        : readableAccent,
  );
  return base.copyWith(
    colorScheme: base.colorScheme.copyWith(
      onPrimary: Color(welcomeOnAccent(accent.toARGB32())),
    ),
    textButtonTheme: TextButtonThemeData(
      style: (base.textButtonTheme.style ?? const ButtonStyle()).copyWith(
        foregroundColor: foreground,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: (base.outlinedButtonTheme.style ?? const ButtonStyle()).copyWith(
        foregroundColor: foreground,
      ),
    ),
  );
}
