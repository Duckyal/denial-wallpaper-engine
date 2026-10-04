import 'package:flutter/widgets.dart';

import 'package:denial_flutter_sdk/input.dart';

import 'package:denial_flutter_sdk/models.dart';
import 'package:denial_flutter_sdk/platform.dart';

import 'reference_shell_state.dart';
import 'reference_shell_metrics.dart';

/// Publishes the mobile shell's immutable native input-routing snapshot.
class ReferenceInputLayoutCoordinator {
  ReferenceInputLayoutCoordinator(this._bridge);

  final DenialBridge _bridge;
  int _inputLayoutEpoch = 0;
  InputLayoutSnapshot? _lastInputLayoutSnapshot;

  void invalidate() {
    _lastInputLayoutSnapshot = null;
  }

  void publish({
    required ReferenceShellState state,
    required Size viewSize,
    required ShellInteractionSnapshot interactions,
  }) {
    if (viewSize.width <= 0 || viewSize.height <= 0) {
      return;
    }

    final quickSettingsActive =
        state.quickSettingsVisible || state.quickSettingsDragProgress > 0.0;
    final edgePanelActive =
        state.edgePanelVisible || state.edgePanelDragProgress > 0.0;
    final edgePanelProgress = state.edgePanelDragProgress;
    final edgePanelRect = ReferenceShellMetrics.edgePanelRect(
      viewSize,
      edgePanelProgress,
    );
    final softwareKeyboardRegions =
        ReferenceShellMetrics.softwareKeyboardRegions(
          viewSize,
          progress: edgePanelProgress,
          scrollStripVisible: state.edgePanelVisible,
        );
    if (state.lockLayerVisible) {
      final lockBackgroundWindow = state.primaryWindow;
      _publishInputLayout(
        viewSize: viewSize,
        shellRegions: <Rect>[Offset.zero & viewSize],
        windows: <InputWindowRegion>[
          if (lockBackgroundWindow != null)
            InputWindowRegion(
              window: lockBackgroundWindow,
              rect: Offset.zero & viewSize,
              sourceRect: Offset.zero & viewSize,
              z: 0,
              hitTest: false,
            ),
        ],
        softwareKeyboardRegions: softwareKeyboardRegions,
        keyboardCapture: true,
        exclusiveShellMode: true,
      );
      return;
    }

    final contentOffset = edgePanelActive
        ? (edgePanelRect.height - state.edgePanelViewportScroll)
              .clamp(0.0, edgePanelRect.height)
              .toDouble()
        : 0.0;
    final inputBottom = edgePanelActive
        ? edgePanelRect.top.clamp(0.0, viewSize.height).toDouble()
        : viewSize.height;
    final inputWindow = state.inputWindow;
    final canvas = Offset.zero & viewSize;
    final shellRegions = <Rect>[
      if (inputWindow == null ||
          state.overviewVisible ||
          state.launchTransitionActive ||
          quickSettingsActive ||
          interactions.capturesFullScene)
        canvas
      else if (edgePanelActive) ...[
        ReferenceShellMetrics.statusRect(viewSize),
        if (edgePanelRect.height > 0.0) edgePanelRect,
        if (state.edgePanelVisible)
          ReferenceShellMetrics.edgePanelScrollStripRect(viewSize),
      ] else ...[
        ReferenceShellMetrics.statusRect(viewSize),
        ReferenceShellMetrics.gestureRect(viewSize),
        ReferenceShellMetrics.edgePanelGestureRect(viewSize),
      ],
      for (final region in interactions.childRegions)
        if (!region.intersect(canvas).isEmpty) region.intersect(canvas),
    ];

    final inputRegions = inputWindow == null
        ? const <InputWindowRegion>[]
        : _inputRegionsForWindow(
            window: inputWindow,
            viewSize: viewSize,
            contentOffset: contentOffset,
            inputBottom: inputBottom,
          );

    _publishInputLayout(
      viewSize: viewSize,
      shellRegions: shellRegions,
      windows: inputRegions,
      softwareKeyboardRegions: softwareKeyboardRegions,
      keyboardCapture: quickSettingsActive || interactions.capturesKeyboard,
      exclusiveShellMode: interactions.compositorExclusive,
    );
  }

  List<InputWindowRegion> _inputRegionsForWindow({
    required DenialWindow window,
    required Size viewSize,
    required double contentOffset,
    required double inputBottom,
  }) {
    final frame = window.presentationCoordinateRect;
    final content = window.contentCoordinateRect;
    if (frame.isEmpty || content.isEmpty) {
      return const <InputWindowRegion>[];
    }
    // Match the texture's top-centred BoxFit.cover, including the interval
    // between an output configure and the client's replacement buffer.
    final widthScale = viewSize.width / frame.width;
    final heightScale = viewSize.height / frame.height;
    final scale = widthScale > heightScale ? widthScale : heightScale;
    final frameLeft = (viewSize.width - frame.width * scale) / 2.0;
    final frameTop = -contentOffset;
    final fullContentRect = Rect.fromLTWH(
      frameLeft,
      frameTop,
      frame.width * scale,
      frame.height * scale,
    );
    final clientRect = Rect.fromLTWH(
      frameLeft + (content.left - frame.left) * scale,
      frameTop + (content.top - frame.top) * scale,
      content.width * scale,
      content.height * scale,
    );
    final clip = Rect.fromLTRB(0, 0, viewSize.width, inputBottom);
    final rect = clientRect.intersect(clip);
    if (rect.isEmpty) {
      return const <InputWindowRegion>[];
    }
    final sourceRect = Rect.fromLTWH(
      content.left + (rect.left - clientRect.left) / scale,
      content.top + (rect.top - clientRect.top) / scale,
      rect.width / scale,
      rect.height / scale,
    );
    final regions = <InputWindowRegion>[];
    for (final popup in window.popupRootsFrontToBack) {
      final popupRect = window.mapSurfaceRect(popup, fullContentRect);
      final clipped = popupRect.intersect(rect);
      if (clipped.isEmpty ||
          popupRect.width <= 0.0 ||
          popupRect.height <= 0.0) {
        continue;
      }
      final scaleX = popup.surfaceWidth / popupRect.width;
      final scaleY = popup.surfaceHeight / popupRect.height;
      regions.add(
        InputWindowRegion(
          window: window,
          surfaceId: popup.surfaceId,
          rect: clipped,
          sourceRect: Rect.fromLTWH(
            (clipped.left - popupRect.left) * scaleX,
            (clipped.top - popupRect.top) * scaleY,
            clipped.width * scaleX,
            clipped.height * scaleY,
          ),
          z: popup.compositionOrder + 1,
          geometryLocked: true,
        ),
      );
    }
    regions.add(
      InputWindowRegion(
        window: window,
        // Route through the toplevel root so native hit testing can select an
        // input-capable subsurface rather than the current primary texture.
        surfaceId: window.objectId,
        rect: rect,
        sourceRect: sourceRect,
        z: 0,
        geometryLocked: true,
      ),
    );
    return regions;
  }

  void _publishInputLayout({
    required Size viewSize,
    required List<Rect> shellRegions,
    required List<InputWindowRegion> windows,
    List<Rect> softwareKeyboardRegions = const <Rect>[],
    bool keyboardCapture = false,
    bool exclusiveShellMode = false,
  }) {
    if (viewSize.width <= 0 || viewSize.height <= 0) {
      return;
    }

    final visibleSurfaceIds = <int>{};
    DenialWindow? previousWindow;
    for (final region in windows) {
      // Popup regions share their toplevel's complete surface tree. Traverse
      // it once for adjacent regions instead of once per popup.
      if (!identical(region.window, previousWindow)) {
        visibleSurfaceIds.addAll(region.window.visibleSurfaceIds);
        previousWindow = region.window;
      }
    }
    final snapshot = InputLayoutSnapshot(
      epoch: _inputLayoutEpoch + 1,
      shellRegions: shellRegions,
      windows: windows,
      softwareKeyboardRegions: softwareKeyboardRegions,
      visibleSurfaceIds: visibleSurfaceIds.toList(growable: false),
      keyboardCapture: keyboardCapture,
      exclusiveShellMode: exclusiveShellMode,
    );
    if (_lastInputLayoutSnapshot?.hasSameRoutingAs(snapshot) ?? false) {
      return;
    }

    if (!_bridge.publishInputLayout(snapshot)) {
      return;
    }
    _inputLayoutEpoch = snapshot.epoch;
    _lastInputLayoutSnapshot = snapshot;
  }
}
