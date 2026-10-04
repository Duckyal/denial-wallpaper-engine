import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:denial_flutter_sdk/settings.dart';

import '../state/desktop_visibility.dart';

import 'package:denial_flutter_sdk/motion.dart';

/// Retains live window content while animating Show Desktop. A fixed logical
/// translation keeps popups moving with their parent, regardless of their size.
class DesktopVisibilityTransition extends ConsumerWidget {
  const DesktopVisibilityTransition({
    required this.child,
    this.separateSurfaceOpacity = false,
    super.key,
  });
  final Widget child;

  /// Decorated windows fade the surface and shadow independently. Grouping
  /// their overlapping paint bounds isolates glass in a transparent saveLayer.
  final bool separateSurfaceOpacity;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hidden = ref.watch(desktopVisibleProvider);
    final scale = ref.watch(
      shellSettingsProvider.select(
        (settings) => settings.animations.durationScale,
      ),
    );
    final base = hidden ? Motion.showDesktopHide : Motion.showDesktopRestore;
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : Duration(microseconds: (base.inMicroseconds * scale).round());
    final target = hidden ? 1.0 : 0.0;
    return IgnorePointer(
      ignoring: hidden,
      child: ExcludeFocus(
        excluding: hidden,
        child: ExcludeSemantics(
          excluding: hidden,
          child: TweenAnimationBuilder<double>(
            // Initially mounted windows start at the current presentation;
            // subsequent targets retarget from the in-flight value, without jumps.
            tween: Tween(begin: target, end: target),
            duration: duration,
            curve: hidden
                ? Motion.md3EmphasizedAccelerate
                : Motion.md3EmphasizedDecelerate,
            child: child,
            builder: (context, progress, child) => Offstage(
              offstage: progress >= 1,
              child: Transform.translate(
                offset: Offset(0, 20 * progress),
                child: separateSurfaceOpacity
                    ? DesktopPresentationOpacity(
                        opacity: 1 - progress,
                        child: child!,
                      )
                    : Opacity(opacity: 1 - progress, child: child),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Combines independent presentation fades before applying them separately to
/// the window surface and decorations. No offscreen opacity group is created.
class DesktopPresentationOpacity extends StatelessWidget {
  const DesktopPresentationOpacity({
    required this.opacity,
    required this.child,
    super.key,
  });

  final double opacity;
  final Widget child;

  @override
  Widget build(BuildContext context) => _DesktopVisibilityOpacity(
    opacity:
        opacity *
        (context
                .dependOnInheritedWidgetOfExactType<_DesktopVisibilityOpacity>()
                ?.opacity ??
            1),
    child: child,
  );
}

/// Apply the presentation fade at a single window surface or decoration.
/// WindowSurfaceLayer can absorb opacity after evaluating its glass material;
/// it must not share an opacity group with its overlapping shadow picture.
class DesktopVisibilityFade extends StatelessWidget {
  const DesktopVisibilityFade({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final opacity = context
        .dependOnInheritedWidgetOfExactType<_DesktopVisibilityOpacity>()
        ?.opacity;
    return Opacity(
      opacity: opacity ?? 1,
      child: _DesktopVisibilityOpacity(opacity: 1, child: child),
    );
  }
}

class _DesktopVisibilityOpacity extends InheritedWidget {
  const _DesktopVisibilityOpacity({
    required this.opacity,
    required super.child,
  });

  final double opacity;

  @override
  bool updateShouldNotify(_DesktopVisibilityOpacity oldWidget) =>
      opacity != oldWidget.opacity;
}
