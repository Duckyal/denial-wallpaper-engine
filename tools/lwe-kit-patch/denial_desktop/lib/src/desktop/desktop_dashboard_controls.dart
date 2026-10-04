import 'package:denial_flutter_sdk/motion.dart';
import 'package:denial_flutter_sdk/rendering.dart';
import 'package:denial_flutter_sdk/shell_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class DashboardIconButton extends StatefulWidget {
  const DashboardIconButton({
    required this.semanticLabel,
    required this.icon,
    required this.onTap,
    this.active = false,
    this.busy = false,
    this.enabled = true,
    this.focusNode,
    super.key,
  });

  final String semanticLabel;
  final IconData icon;
  final VoidCallback onTap;
  final bool active;
  final bool busy;
  final bool enabled;
  final FocusNode? focusNode;

  @override
  State<DashboardIconButton> createState() => _DashboardIconButtonState();
}

class _DashboardIconButtonState extends State<DashboardIconButton> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final accent = ShellTheme.of(context).accentPalette;
    return Semantics(
      button: true,
      enabled: widget.enabled,
      label: widget.semanticLabel,
      child: FocusableActionDetector(
        focusNode: widget.focusNode,
        enabled: widget.enabled && !widget.busy,
        onShowFocusHighlight: (value) => setState(() => _focused = value),
        onShowHoverHighlight: (value) => setState(() => _hovered = value),
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
        },
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              if (widget.enabled && !widget.busy) widget.onTap();
              return null;
            },
          ),
        },
        mouseCursor: widget.busy
            ? ShellMouseCursors.working
            : widget.enabled
            ? ShellMouseCursors.link
            : ShellMouseCursors.normal,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.enabled && !widget.busy ? widget.onTap : null,
          child: AnimatedContainer(
            duration: Motion.pill,
            curve: Motion.standard,
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: widget.active
                  ? accent.container
                  : _hovered || _focused
                  ? context.shellColors.surfaceContainerHighest
                  : context.shellColors.surfaceContainerHigh,
              borderRadius: context.shellTheme.borderRadius(12),
              border: _focused
                  ? Border.all(color: accent.primary, width: 1.5)
                  : null,
            ),
            child: widget.busy
                ? Padding(
                    padding: const EdgeInsets.all(9),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: accent.primary,
                    ),
                  )
                : Icon(
                    widget.icon,
                    size: 18,
                    color: widget.enabled
                        ? widget.active
                              ? accent.onContainer
                              : context.shellColors.textPrimary
                        : context.shellColors.glyphInactive,
                  ),
          ),
        ),
      ),
    );
  }
}

class DashboardCard extends StatelessWidget {
  const DashboardCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.shellTheme.cardColor(
          context.shellColors.surfaceContainerLow,
        ),
        borderRadius: context.shellTheme.borderRadius(20),
        border: Border.all(color: context.shellColors.hairlineSoft),
      ),
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    );
  }
}
