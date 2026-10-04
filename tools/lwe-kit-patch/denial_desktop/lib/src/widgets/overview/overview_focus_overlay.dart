import 'package:denial_desktop/src/state/reference_shell_metrics.dart';

import 'package:flutter/widgets.dart';

import 'package:denial_flutter_sdk/models.dart';
import 'package:denial_flutter_sdk/shell_theme.dart';
import 'package:denial_flutter_sdk/rendering.dart';
import 'package:denial_flutter_sdk/motion.dart';

/// Morphs a tapped overview card back to full screen before focusing it.
class OverviewFocusOverlay extends StatelessWidget {
  const OverviewFocusOverlay({
    super.key,
    required this.controller,
    required this.window,
    required this.startRect,
  });

  final AnimationController controller;
  final DenialWindow window;
  final Rect startRect;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: RetainedWindowMotion(
          progress: controller,
          begin: startRect,
          end: Offset.zero & MediaQuery.sizeOf(context),
          beginRadius: context.shellTheme.windowRadius,
          curve: Motion.standard,
          child: WindowSurface(
            window: window,
            contentPadding: const EdgeInsets.only(
              top: ReferenceShellMetrics.appStatusBarHeight,
            ),
          ),
        ),
      ),
    );
  }
}
