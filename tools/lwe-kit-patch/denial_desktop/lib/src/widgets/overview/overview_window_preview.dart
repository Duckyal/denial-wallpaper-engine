import 'package:denial_desktop/src/state/reference_shell_metrics.dart';

import 'package:flutter/widgets.dart';

import 'package:denial_flutter_sdk/localization.dart';
import 'package:denial_flutter_sdk/models.dart';
import 'package:denial_flutter_sdk/shell_theme.dart';
import 'package:denial_flutter_sdk/rendering.dart';

/// The retained texture shared by portrait and landscape recents.
class OverviewWindowPreview extends StatelessWidget {
  const OverviewWindowPreview({
    super.key,
    required this.previewKey,
    required this.window,
    required this.size,
  });

  final Key previewKey;
  final DenialWindow window;
  final Size size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: localizedWindowTitle(context, window),
      child: RepaintBoundary(
        child: SizedBox(
          key: previewKey,
          width: size.width,
          height: size.height,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(
              context.shellTheme.windowRadius,
            ),
            child: FittedBox(
              fit: BoxFit.fill,
              child: SizedBox.fromSize(
                size: MediaQuery.sizeOf(context),
                child: WindowSurface(
                  window: window,
                  contentPadding: const EdgeInsets.only(
                    top: ReferenceShellMetrics.appStatusBarHeight,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
