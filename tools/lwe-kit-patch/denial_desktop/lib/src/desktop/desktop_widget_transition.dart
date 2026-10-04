import 'package:denial_flutter_sdk/motion.dart';
import 'package:flutter/material.dart';

class DesktopWidgetVerticalTransition extends StatefulWidget {
  const DesktopWidgetVerticalTransition({
    super.key,
    required this.entering,
    required this.exiting,
    required this.duration,
    required this.child,
  });

  final bool entering;
  final bool exiting;
  final Duration duration;
  final Widget child;

  @override
  State<DesktopWidgetVerticalTransition> createState() =>
      _DesktopWidgetVerticalTransitionState();
}

class _DesktopWidgetVerticalTransitionState
    extends State<DesktopWidgetVerticalTransition>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _progress;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      value: widget.entering ? 0.0 : 1.0,
      vsync: this,
    );
    _progress = _controller.drive(
      CurveTween(curve: Motion.md3EmphasizedDecelerate),
    );
    if (widget.entering) {
      _controller.forward();
    } else if (widget.exiting) {
      _controller.reverse();
    }
  }

  @override
  void didUpdateWidget(covariant DesktopWidgetVerticalTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.duration != widget.duration) {
      _controller.duration = widget.duration;
    }
    if (!oldWidget.entering && widget.entering) {
      _controller.forward(from: 0.0);
    } else if (!oldWidget.exiting && widget.exiting) {
      _controller.reverse(from: 1.0);
    } else if (!widget.entering && !widget.exiting) {
      _controller.value = 1.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _progress,
      child: widget.child,
      builder: (context, child) => FractionalTranslation(
        translation: Offset(0, -1.0 + _progress.value),
        child: child,
      ),
    );
  }
}
