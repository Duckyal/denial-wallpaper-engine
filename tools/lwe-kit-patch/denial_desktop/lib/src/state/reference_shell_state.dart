import 'package:flutter/widgets.dart';
import 'package:denial_flutter_sdk/models.dart';
import 'package:denial_flutter_sdk/state.dart' show ShellState;

import 'reference_shell_metrics.dart';

/// Reference UI state over the shared SDK snapshot. Gesture updates reuse its
/// native indexes; presentation focus may differ while home or recents is shown.
class ReferenceShellState {
  const ReferenceShellState._({
    required this.platform,
    required this.overviewVisible,
    required this.gestureDrag,
    required this.quickSettingsVisible,
    required this.quickSettingsDrag,
    required this.quickSettingsDragActive,
    required this.edgePanelVisible,
    required this.edgePanelDrag,
    required this.edgePanelDragActive,
    required this.edgePanelViewportScroll,
    required this.lockLayerVisible,
    required this.foregroundObjectId,
    required this.launchingObjectId,
    required this.launchRequest,
    required this.homeTransitionActive,
  });

  factory ReferenceShellState.initial(ShellState platform) {
    return ReferenceShellState._(
      platform: platform,
      overviewVisible: false,
      gestureDrag: Offset.zero,
      quickSettingsVisible: false,
      quickSettingsDrag: Offset.zero,
      quickSettingsDragActive: false,
      edgePanelVisible: false,
      edgePanelDrag: Offset.zero,
      edgePanelDragActive: false,
      edgePanelViewportScroll: 0.0,
      lockLayerVisible: platform.locked,
      foregroundObjectId: platform.foregroundObjectId,
      launchingObjectId: null,
      launchRequest: null,
      homeTransitionActive: false,
    );
  }

  final ShellState platform;
  List<DenialWindow> get windows => platform.windows;
  List<DenialWindow> get openAppWindows => platform.openAppWindows;
  Map<int, DenialWindow> get openAppWindowsByObjectId =>
      platform.openAppWindowsByObjectId;
  List<DenialWindow> get positionedPopupSurfaces =>
      platform.positionedPopupSurfaces;
  List<DenialWindow> get layerSurfaces => platform.layerSurfaces;
  int get windowSnapshotSequence => platform.windowSnapshotSequence;
  bool get locked => platform.locked;

  final bool overviewVisible;
  final Offset gestureDrag;
  final bool quickSettingsVisible;
  final Offset quickSettingsDrag;
  final bool quickSettingsDragActive;
  final bool edgePanelVisible;
  final Offset edgePanelDrag;
  final bool edgePanelDragActive;
  final double edgePanelViewportScroll;
  final bool lockLayerVisible;
  final int? foregroundObjectId;
  final int? launchingObjectId;
  final AppLaunchRequest? launchRequest;

  /// True while the foreground app is flying away to reveal home, so the
  /// fullscreen primary stage stays hidden until the transition resolves.
  final bool homeTransitionActive;

  double get overviewDragProgress {
    if (overviewVisible) {
      return 1.0;
    }

    return (-gestureDrag.dy / 280.0).clamp(0.0, 1.0).toDouble();
  }

  double get quickSettingsDragProgress {
    if (quickSettingsVisible) {
      return 1.0;
    }

    return (quickSettingsDrag.dy /
            ReferenceShellMetrics.quickSettingsDragDistance)
        .clamp(0.0, 1.0)
        .toDouble();
  }

  double get edgePanelDragProgress {
    if (edgePanelVisible) {
      return 1.0;
    }

    return (edgePanelDrag.dy / ReferenceShellMetrics.edgePanelDragDistance)
        .clamp(0.0, 1.0)
        .toDouble();
  }

  ReferenceShellState copyWith({
    ShellState? platform,
    bool? overviewVisible,
    Offset? gestureDrag,
    bool? quickSettingsVisible,
    Offset? quickSettingsDrag,
    bool? quickSettingsDragActive,
    bool? edgePanelVisible,
    Offset? edgePanelDrag,
    bool? edgePanelDragActive,
    double? edgePanelViewportScroll,
    bool? lockLayerVisible,
    int? foregroundObjectId,
    bool clearForegroundObjectId = false,
    int? launchingObjectId,
    bool clearLaunchingObjectId = false,
    AppLaunchRequest? launchRequest,
    bool clearLaunchRequest = false,
    bool? homeTransitionActive,
  }) {
    return ReferenceShellState._(
      platform: platform ?? this.platform,
      overviewVisible: overviewVisible ?? this.overviewVisible,
      gestureDrag: gestureDrag ?? this.gestureDrag,
      quickSettingsVisible: quickSettingsVisible ?? this.quickSettingsVisible,
      quickSettingsDrag: quickSettingsDrag ?? this.quickSettingsDrag,
      quickSettingsDragActive:
          quickSettingsDragActive ?? this.quickSettingsDragActive,
      edgePanelVisible: edgePanelVisible ?? this.edgePanelVisible,
      edgePanelDrag: edgePanelDrag ?? this.edgePanelDrag,
      edgePanelDragActive: edgePanelDragActive ?? this.edgePanelDragActive,
      edgePanelViewportScroll:
          edgePanelViewportScroll ?? this.edgePanelViewportScroll,
      lockLayerVisible: lockLayerVisible ?? this.lockLayerVisible,
      foregroundObjectId: clearForegroundObjectId
          ? null
          : foregroundObjectId ?? this.foregroundObjectId,
      launchingObjectId: clearLaunchingObjectId
          ? null
          : launchingObjectId ?? this.launchingObjectId,
      launchRequest: clearLaunchRequest
          ? null
          : launchRequest ?? this.launchRequest,
      homeTransitionActive: homeTransitionActive ?? this.homeTransitionActive,
    );
  }

  DenialWindow? get foregroundWindow {
    final window = windowByObjectId(foregroundObjectId);
    return window != null && window.isUserApp ? window : null;
  }

  DenialWindow? get launchingWindow {
    final window = windowByObjectId(launchingObjectId);
    return window != null && window.isUserApp ? window : null;
  }

  bool get launchTransitionActive => launchRequest != null;

  DenialWindow? get primaryWindow {
    if (launchTransitionActive) {
      return null;
    }

    return foregroundWindow;
  }

  DenialWindow? get inputWindow {
    if (lockLayerVisible || launchTransitionActive || overviewVisible) {
      return null;
    }

    return primaryWindow;
  }

  int get openAppWindowCount => openAppWindows.length;

  DenialWindow? get appSwitchTargetWindow {
    if (lockLayerVisible ||
        overviewVisible ||
        quickSettingsDragProgress > 0.0 ||
        edgePanelDragProgress > 0.0) {
      return null;
    }

    final dx = gestureDrag.dx;
    if (dx == 0.0) {
      return null;
    }

    return adjacentOpenAppWindow(dx > 0.0 ? -1 : 1);
  }

  DenialWindow? adjacentOpenAppWindow(int direction) =>
      platform.adjacentAppWindow(foregroundObjectId, direction);

  DenialWindow? windowByObjectId(int? objectId) =>
      platform.windowByObjectId(objectId);
  DenialWindow? windowByWindowId(int windowId) =>
      platform.windowByWindowId(windowId);
}
