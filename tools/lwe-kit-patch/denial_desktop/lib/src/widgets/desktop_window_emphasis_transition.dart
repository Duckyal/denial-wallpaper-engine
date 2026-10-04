import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:denial_flutter_sdk/settings.dart';

import '../state/window_emphasis.dart';

import 'package:denial_flutter_sdk/motion.dart';

import 'desktop_visibility_transition.dart';

/// Fade each window plane after glass evaluation, independently of its shadow.
/// Popups pass their owning window ID and fade as a single surface instead.
class DesktopWindowEmphasisTransition extends ConsumerWidget {
  const DesktopWindowEmphasisTransition({
    required this.windowId,
    required this.separateSurfaceOpacity,
    required this.child,
    super.key,
  });

  final int windowId;
  final bool separateSurfaceOpacity;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final faded = ref.watch(windowDeemphasizedProvider(windowId));
    final scale = ref.watch(
      shellSettingsProvider.select(
        (settings) => settings.animations.durationScale,
      ),
    );
    final target = faded ? 0.25 : 1.0;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: target, end: target),
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : Duration(
              microseconds: (Motion.windowEmphasis.inMicroseconds * scale)
                  .round(),
            ),
      curve: Motion.standard,
      child: child,
      builder: (context, opacity, child) => DesktopPresentationOpacity(
        opacity: opacity,
        child: separateSurfaceOpacity
            ? child!
            : DesktopVisibilityFade(child: child!),
      ),
    );
  }
}
