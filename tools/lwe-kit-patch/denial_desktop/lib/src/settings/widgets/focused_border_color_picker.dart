import 'package:denial_flutter_sdk/materials.dart';

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:denial_flutter_sdk/localization.dart';
import 'package:denial_flutter_sdk/motion.dart';
import 'package:denial_flutter_sdk/shell_theme.dart';
import 'package:denial_flutter_sdk/tokens.dart';
import 'package:denial_flutter_sdk/settings.dart';

import 'hsv_color_wheel.dart';
import 'settings_color_value_editor.dart';

const settingsAccentColorPickerKey = ValueKey<String>(
  'settings-accent-color-picker',
);
const settingsAccentColorResetKey = ValueKey<String>(
  'settings-accent-color-reset',
);

class SettingsAccentColorPicker extends StatelessWidget {
  const SettingsAccentColorPicker({
    super.key,
    required this.color,
    required this.onChanged,
    required this.onReset,
    required this.onClose,
    this.title,
    this.routeLabel,
    this.wheelSemanticsLabel,
  });

  final Color color;
  final ValueChanged<Color> onChanged;
  final VoidCallback onReset;
  final VoidCallback onClose;
  final String? title;
  final String? routeLabel;
  final String? wheelSemanticsLabel;

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: (_, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.escape) {
          onClose();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onClose,
            child: ColoredBox(color: context.shellColors.overviewScrim),
          ),
          LayoutBuilder(
            builder: (context, constraints) =>
                _buildPanel(context, constraints),
          ),
        ],
      ),
    );
  }

  Widget _buildPanel(BuildContext context, BoxConstraints constraints) {
    final l10n = context.l10n;
    final panelWidth = math.min(
      400.0,
      math.max(0.0, constraints.maxWidth - 32.0),
    );
    final panelHeight = math.min(
      560.0,
      math.max(0.0, constraints.maxHeight - 32.0),
    );
    final wheelSize = math.max(0.0, math.min(210.0, panelWidth - 56.0));
    return Center(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {},
        child: SizedBox(
          width: panelWidth,
          height: panelHeight,
          child: _ColorPickerPanel(
            color: color,
            wheelSize: wheelSize,
            onChanged: onChanged,
            onReset: onReset,
            onClose: onClose,
            title: title ?? l10n.settingsColorPickerTitle,
            routeLabel: routeLabel ?? l10n.settingsColorPickerRouteLabel,
            wheelSemanticsLabel:
                wheelSemanticsLabel ?? l10n.settingsColorWheelSemanticsLabel,
          ),
        ),
      ),
    );
  }
}

class _ColorPickerPanel extends StatelessWidget {
  const _ColorPickerPanel({
    required this.color,
    required this.wheelSize,
    required this.onChanged,
    required this.onReset,
    required this.onClose,
    required this.title,
    required this.routeLabel,
    required this.wheelSemanticsLabel,
  });

  final Color color;
  final double wheelSize;
  final ValueChanged<Color> onChanged;
  final VoidCallback onReset;
  final VoidCallback onClose;
  final String title;
  final String routeLabel;
  final String wheelSemanticsLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      scopesRoute: true,
      namesRoute: true,
      explicitChildNodes: true,
      role: .dialog,
      label: routeLabel,
      child: DenialMaterial(
        role: DenialMaterialRole.dialog,
        inset: 16,
        child: Builder(
          builder: (context) => DenialSurfaceGeometry(
            radius: DenialSurfaceGeometry.nestedRadius(context, inset: 16),
            child: FocusScope(
              autofocus: true,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
                child: Builder(builder: _buildContent),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      children: <Widget>[
        _PickerHeader(
          color: color,
          hex: formatOpaqueColorHex(color),
          title: title,
          onClose: onClose,
        ),
        const SizedBox(height: 12),
        Expanded(child: _buildScrollableBody(context)),
        const SizedBox(height: 12),
        Row(
          children: <Widget>[
            _PickerButton(
              key: settingsAccentColorResetKey,
              label: l10n.settingsColorPickerReset,
              onPressed: onReset,
            ),
            const Spacer(),
            _PickerButton(
              label: l10n.settingsColorPickerDone,
              prominent: true,
              onPressed: onClose,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildScrollableBody(BuildContext context) {
    final l10n = context.l10n;
    return SingleChildScrollView(
      child: Column(
        children: <Widget>[
          SizedBox.square(
            dimension: wheelSize,
            child: HsvColorWheel(
              color: color,
              onChanged: onChanged,
              semanticsLabel: wheelSemanticsLabel,
            ),
          ),
          const SizedBox(height: 9),
          Text(
            l10n.settingsColorPickerInstructions,
            textAlign: TextAlign.center,
            style: ShellText.cardTitle.copyWith(
              color: context.applicationColors.secondary,
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 12),
          SettingsColorValueEditor(color: color, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _PickerHeader extends StatelessWidget {
  const _PickerHeader({
    required this.color,
    required this.hex,
    required this.title,
    required this.onClose,
  });

  final Color color;
  final String hex;
  final String title;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Row(
      children: [
        AnimatedContainer(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : Motion.tile,
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: context.shellColors.panelHighlight),
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: ShellText.cardTitle),
              const SizedBox(height: 2),
              Text(
                hex,
                style: ShellText.cardTitle.copyWith(
                  color: context.applicationColors.secondary,
                  fontFamily: ShellText.systemBarFontFamily,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
        _PickerIconButton(
          icon: Icons.close_rounded,
          semanticsLabel: l10n.settingsColorPickerCloseSemanticsLabel,
          onPressed: onClose,
        ),
      ],
    );
  }
}

class _PickerButton extends StatelessWidget {
  const _PickerButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.prominent = false,
  });
  final String label;
  final VoidCallback onPressed;
  final bool prominent;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: DenialSurfaceGeometry.borderRadiusOf(context),
    );
    return prominent
        ? FilledButton(
            onPressed: onPressed,
            style: FilledButton.styleFrom(
              minimumSize: const Size(44, 44),
              shape: shape,
            ),
            child: Text(label),
          )
        : TextButton(
            onPressed: onPressed,
            style: TextButton.styleFrom(
              minimumSize: const Size(44, 44),
              shape: shape,
            ),
            child: Text(label),
          );
  }
}

class _PickerIconButton extends StatelessWidget {
  const _PickerIconButton({
    required this.icon,
    required this.semanticsLabel,
    required this.onPressed,
  });
  final IconData icon;
  final String semanticsLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: semanticsLabel,
    onPressed: onPressed,
    icon: Icon(icon, size: 18),
    style: IconButton.styleFrom(
      minimumSize: const Size(44, 44),
      shape: RoundedRectangleBorder(
        borderRadius: DenialSurfaceGeometry.borderRadiusOf(context),
      ),
    ),
  );
}
