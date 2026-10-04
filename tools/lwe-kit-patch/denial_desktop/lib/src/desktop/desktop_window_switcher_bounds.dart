import 'package:denial_flutter_sdk/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../state/desktop_window_switcher.dart';
import 'desktop_workspace.dart';

/// Resolves the source output bounds for window-switcher presentation.
Rect desktopWindowSwitcherStageBounds({
  required Size viewSize,
  required DisplayLayout? displayLayout,
  required DesktopWorkspaceState desktop,
  required DesktopWindowSwitcherState switcher,
}) {
  final canvas = Offset.zero & viewSize;
  final sourcePlacement =
      desktop.placements[switcher.sourceObjectId ?? switcher.selectedObjectId];
  if (sourcePlacement == null) {
    return canvas;
  }
  final outputs = displayLayout?.outputs ?? const <DisplayOutput>[];
  for (final output in outputs) {
    if (output.monitorId == sourcePlacement.monitorId) {
      final bounds = output.logicalRect.intersect(canvas);
      if (!bounds.isEmpty) {
        return bounds;
      }
    }
  }
  for (final output in outputs) {
    if (output.logicalRect.contains(sourcePlacement.frame.center)) {
      final bounds = output.logicalRect.intersect(canvas);
      if (!bounds.isEmpty) {
        return bounds;
      }
    }
  }
  return canvas;
}
