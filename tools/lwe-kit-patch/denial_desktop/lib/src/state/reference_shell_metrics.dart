import 'package:flutter/widgets.dart';

class ReferenceShellMetrics {
  const ReferenceShellMetrics._();

  static const double gestureHitWidth = 176.0;
  static const double gestureHitHeight = 60.0;
  static const double gestureBottomInset = -8.0;
  static const double edgePanelGestureWidth = 220.0;
  static const double edgePanelGestureHeight = 18.0;
  static const double edgePanelMaxHeight = 368.0;
  static const double edgePanelOpenDistance = 86.0;
  static const double edgePanelDragDistance = edgePanelMaxHeight;
  static const double edgePanelScrollStripWidth = 18.0;
  static const double edgePanelScrollMultiplier = 1.15;

  /// Visual gutter between the outgoing and incoming windows during a
  /// horizontal app switch. The switch animation must travel `width + this`
  /// so the incoming window lands exactly centred.
  static const double appSwitchGap = 18.0;
  static const double statusBarHeight = 48.0;
  static const double appStatusBarHeight = statusBarHeight;
  static const double statusDragHeight = statusBarHeight;
  static const double quickSettingsPanelHeight = 488.0;
  static const double quickSettingsDragDistance = quickSettingsPanelHeight;

  /// ColorOS-style split shades occupy the complete output while their
  /// internal controls and notification list keep their own safe-area insets.
  static double quickSettingsPanelExtent(Size viewSize) =>
      viewSize.height.clamp(1.0, double.infinity).toDouble();

  static double quickSettingsDragScale(Size viewSize) =>
      quickSettingsDragDistance / quickSettingsPanelExtent(viewSize);

  static Rect gestureRect(Size viewSize) {
    final width = gestureHitWidth.clamp(0.0, viewSize.width);
    final left = (viewSize.width - width) / 2.0;
    final top = viewSize.height - gestureHitHeight - gestureBottomInset;
    return Rect.fromLTWH(left, top, width, gestureHitHeight);
  }

  static Rect edgePanelGestureRect(Size viewSize) {
    final width = edgePanelGestureWidth.clamp(0.0, viewSize.width);
    final top = viewSize.height - edgePanelGestureHeight - gestureBottomInset;
    return Rect.fromLTWH(
      viewSize.width - width,
      top,
      width,
      edgePanelGestureHeight,
    );
  }

  static double edgePanelHeight(Size viewSize) {
    if (viewSize.height <= 0.0) {
      return 0.0;
    }
    final maxHeight = viewSize.height < edgePanelMaxHeight
        ? viewSize.height
        : edgePanelMaxHeight;
    return (viewSize.height * 0.30).clamp(0.0, maxHeight).toDouble();
  }

  static Rect edgePanelRect(Size viewSize, double progress) {
    final height = edgePanelHeight(viewSize) * progress.clamp(0.0, 1.0);
    return Rect.fromLTWH(0, viewSize.height - height, viewSize.width, height);
  }

  static Rect edgePanelScrollStripRect(Size viewSize) {
    final width = edgePanelScrollStripWidth.clamp(0.0, viewSize.width);
    final panelHeight = edgePanelHeight(viewSize);
    return Rect.fromLTWH(
      viewSize.width - width,
      0,
      width,
      (viewSize.height - panelHeight).clamp(0.0, viewSize.height).toDouble(),
    );
  }

  static List<Rect> softwareKeyboardRegions(
    Size viewSize, {
    required double progress,
    required bool scrollStripVisible,
  }) {
    final panel = edgePanelRect(viewSize, progress);
    return <Rect>[
      if (panel.height > 0.0) panel,
      if (scrollStripVisible) edgePanelScrollStripRect(viewSize),
    ];
  }

  static Rect statusRect(Size viewSize) {
    return Rect.fromLTWH(
      0,
      0,
      viewSize.width,
      statusDragHeight.clamp(0.0, viewSize.height),
    );
  }
}
