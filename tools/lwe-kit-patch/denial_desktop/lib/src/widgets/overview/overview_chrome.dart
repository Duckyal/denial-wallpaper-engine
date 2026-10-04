import 'package:flutter/widgets.dart';

import 'package:denial_flutter_sdk/motion.dart';
import 'package:denial_flutter_sdk/shell_theme.dart';
import 'package:denial_flutter_sdk/localization.dart';
import 'package:denial_flutter_sdk/rendering.dart';

class OverviewScrim extends StatelessWidget {
  const OverviewScrim({
    super.key,
    required this.progress,
    this.fadingOut = false,
    required this.onTap,
  });

  final Animation<double> progress;
  final bool fadingOut;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scrim = context.shellColors.overviewScrim;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: RepaintBoundary(
        child: FadeTransition(
          opacity: progress,
          child: AnimatedOpacity(
            opacity: fadingOut ? 0 : 1,
            duration: Motion.focusZoom,
            curve: Motion.standard,
            child: ColoredBox(color: scrim.withValues(alpha: scrim.a * 0.5)),
          ),
        ),
      ),
    );
  }
}

class EmptyOverviewState extends StatelessWidget {
  const EmptyOverviewState({super.key, required this.progress});

  final Animation<double> progress;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: RetainedTranslation(
        translation: Tween<Offset>(
          begin: const Offset(0, 28),
          end: Offset.zero,
        ).chain(CurveTween(curve: Motion.standard)).animate(progress),
        child: FadeTransition(
          opacity: progress.drive(
            CurveTween(curve: const Interval(0, 1 / 1.3)),
          ),
          child: Text(
            context.l10n.overviewNoWindows,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: context.shellColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w600,
              decoration: TextDecoration.none,
            ),
          ),
        ),
      ),
    );
  }
}
