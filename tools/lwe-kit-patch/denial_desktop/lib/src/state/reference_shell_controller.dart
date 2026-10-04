import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:denial_flutter_sdk/input.dart';
import 'package:denial_flutter_sdk/lifecycle.dart';
import 'package:denial_flutter_sdk/models.dart';
import 'package:denial_flutter_sdk/platform.dart';
import 'package:denial_flutter_sdk/state.dart';

import 'reference_shell_state.dart';
import 'reference_shell_metrics.dart';
import 'reference_shell_profile.dart';
import 'reference_input_layout_coordinator.dart';

final referenceShellProvider =
    NotifierProvider<ReferenceShellController, ReferenceShellState>(
      ReferenceShellController.new,
    );

/// Owns the reference desktop/mobile presentation over the shared native state.
/// It never registers another native window callback or creates another bridge.
class ReferenceShellController extends Notifier<ReferenceShellState>
    with NotifierLifecycle<ReferenceShellState> {
  late ShellController _platform;

  @override
  ReferenceShellState build() {
    _bridge = ref.watch(denialBridgeProvider);
    final platform = ref.read(shellControllerProvider);
    _platform = ref.read(shellControllerProvider.notifier);
    _resetBuildFields();
    _automaticSoftwareKeyboard =
        ref.watch(referenceShellProfileProvider) ==
        ReferenceShellProfile.mobile;
    _buildGeneration = beginBuildGeneration();
    final generation = _buildGeneration;
    ref.listen<ShellState>(shellControllerProvider, (_, next) {
      if (isBuildGenerationActive(generation)) _synchronizePlatform(next);
    });
    _textInputStateSubscription = _bridge.textInputStates.listen((input) {
      if (isBuildGenerationActive(generation)) _handleTextInputState(input);
    });
    ref.onDispose(() {
      _automaticSoftwareKeyboardCloseTimer?.cancel();
      _automaticSoftwareKeyboardCloseTimer = null;
      _launchRequestTimer?.cancel();
      _launchRequestTimer = null;
      unawaited(_textInputStateSubscription?.cancel());
      _textInputStateSubscription = null;
    });
    return ReferenceShellState.initial(platform);
  }

  // Large enough that the vertical swipe tracks the finger across the whole
  // screen (the home/recents hero needs the real travel, not a capped value).
  static const double _gestureVisualDistance = 1600.0;
  static const double _gestureHorizontalVisualDistance = 4096.0;
  static const double _gestureAxisLockDistance = 14.0;
  static const double _gestureAxisLockRatio = 1.18;
  static const double _quickSettingsOpenDistance = 126.0;
  static const double _quickSettingsFlickVelocity = 520.0;
  static const double _edgePanelFlickVelocity = 520.0;
  static const Duration _launchRequestTimeout = Duration(seconds: 15);
  static const Duration _automaticSoftwareKeyboardCloseGrace = Duration(
    milliseconds: 24,
  );

  late DenialBridge _bridge;
  late int _buildGeneration;
  late ReferenceInputLayoutCoordinator _inputLayoutCoordinator;
  Offset _rawGestureDrag = Offset.zero;
  Offset _gestureLockOrigin = Offset.zero;
  _GestureAxis _gestureAxis = _GestureAxis.undecided;
  bool _quickSettingsDragStartedOpen = false;
  bool _quickSettingsDragMoved = false;
  bool _edgePanelDragStartedOpen = false;
  bool _edgePanelDragMoved = false;
  int? _edgePanelDismissalSerial;
  DenialTextInputState? _lastTextInput;
  int _nextLaunchRequestId = 1;
  Timer? _launchRequestTimer;
  bool _automaticSoftwareKeyboard = false;
  final Set<String> _legacyTextInputAppIds = <String>{};
  final Set<String> _backgroundLaunchAppIds = <String>{};
  Timer? _automaticSoftwareKeyboardCloseTimer;
  StreamSubscription<DenialTextInputState>? _textInputStateSubscription;

  void _resetBuildFields() {
    _lastTextInput = null;
    _edgePanelDismissalSerial = null;
    _automaticSoftwareKeyboardCloseTimer?.cancel();
    _automaticSoftwareKeyboardCloseTimer = null;
    unawaited(_textInputStateSubscription?.cancel());
    _textInputStateSubscription = null;
    _inputLayoutCoordinator = ReferenceInputLayoutCoordinator(_bridge);
    _rawGestureDrag = Offset.zero;
    _gestureLockOrigin = Offset.zero;
    _gestureAxis = _GestureAxis.undecided;
    _quickSettingsDragStartedOpen = false;
    _quickSettingsDragMoved = false;
    _edgePanelDragStartedOpen = false;
    _edgePanelDragMoved = false;
    _nextLaunchRequestId = 1;
    _launchRequestTimer = null;
    _legacyTextInputAppIds.clear();
    _backgroundLaunchAppIds.clear();
  }

  void _handleTextInputState(DenialTextInputState input) {
    _lastTextInput = input;
    if (!_automaticSoftwareKeyboard) {
      return;
    }
    if (input.inputPanelVisible) {
      final foregroundAppId = AppLaunchRequest.normalizeAppId(
        state.foregroundWindow?.appId ?? '',
      );
      if (input.legacy && !_legacyTextInputAppIds.contains(foregroundAppId)) {
        closeEdgePanel();
        return;
      }
      _automaticSoftwareKeyboardCloseTimer?.cancel();
      _automaticSoftwareKeyboardCloseTimer = null;
      openEdgePanel();
    } else {
      // Flutter retires the old TextInputClient just before registering the
      // next one during a field-to-field focus transfer. Preserve the panel
      // across that short protocol gap; a replacement editor cancels this
      // close before any visible keyboard motion begins.
      _automaticSoftwareKeyboardCloseTimer?.cancel();
      final generation = _buildGeneration;
      _automaticSoftwareKeyboardCloseTimer = Timer(
        _automaticSoftwareKeyboardCloseGrace,
        () {
          _automaticSoftwareKeyboardCloseTimer = null;
          if (isBuildGenerationActive(generation)) {
            closeEdgePanel();
          }
        },
      );
    }
  }

  void registerLegacyTextInputAppIds(Iterable<String> appIds) {
    _legacyTextInputAppIds.addAll(
      appIds
          .map(AppLaunchRequest.normalizeAppId)
          .where((identity) => identity.isNotEmpty),
    );
  }

  void lock() {
    _platform.lock();
  }

  /// Secures the session first, then asks the compositor to blank its outputs.
  /// Both commands use Denial's native channels; no external power daemon is
  /// involved.
  void lockAndBlankDisplays() {
    _platform.lockAndBlankDisplays();
  }

  void requestUnlock() {
    _platform.requestUnlock();
  }

  void completeUnlockTransition() {
    if (state.locked || !state.lockLayerVisible) {
      return;
    }

    _inputLayoutCoordinator.invalidate();
    state = state.copyWith(lockLayerVisible: false);
  }

  void _resetSecurePresentation() {
    _rawGestureDrag = Offset.zero;
    _gestureLockOrigin = Offset.zero;
    _gestureAxis = _GestureAxis.undecided;
    _quickSettingsDragStartedOpen = false;
    _quickSettingsDragMoved = false;
    _edgePanelDragStartedOpen = false;
    _edgePanelDragMoved = false;
    _launchRequestTimer?.cancel();
    _launchRequestTimer = null;

    state = state.copyWith(
      lockLayerVisible: true,
      overviewVisible: false,
      gestureDrag: Offset.zero,
      quickSettingsVisible: false,
      quickSettingsDrag: Offset.zero,
      quickSettingsDragActive: false,
      edgePanelVisible: false,
      edgePanelDrag: Offset.zero,
      edgePanelDragActive: false,
      edgePanelViewportScroll: 0.0,
      homeTransitionActive: false,
      clearLaunchingObjectId: true,
      clearLaunchRequest: true,
    );
  }

  void _synchronizePlatform(ShellState platform) {
    final previous = state.platform;
    final windowsChanged =
        !identical(previous.windows, platform.windows) ||
        !identical(previous.layerSurfaces, platform.layerSurfaces);
    state = state.copyWith(platform: platform);
    if (previous.locked != platform.locked) _resetSecurePresentation();
    if (windowsChanged) _reconcileWindowSnapshot();
    if (previous.activationRevision != platform.activationRevision) {
      final window = platform.foregroundWindow;
      if (window != null) _handleNativeWindowActivated(window.windowId);
    }
  }

  void _reconcileWindowSnapshot() {
    final request = state.launchRequest;
    final launchWindow = request == null
        ? null
        : _matchingLaunchWindow(state.windows, request);
    if (launchWindow != null) {
      final shouldActivate = state.launchingObjectId != launchWindow.objectId;
      _rawGestureDrag = Offset.zero;
      _gestureLockOrigin = Offset.zero;
      _gestureAxis = _GestureAxis.undecided;
      state = state.copyWith(
        overviewVisible: false,
        gestureDrag: Offset.zero,
        quickSettingsDragActive: false,
        edgePanelVisible: false,
        edgePanelDrag: Offset.zero,
        edgePanelDragActive: false,
        foregroundObjectId: launchWindow.objectId,
        launchingObjectId: launchWindow.objectId,
      );
      if (shouldActivate) _platform.focusWindow(launchWindow);
      return;
    }
    state = state.copyWith(
      clearForegroundObjectId:
          state.windowByObjectId(state.foregroundObjectId) == null,
      clearLaunchingObjectId:
          state.windowByObjectId(state.launchingObjectId) == null,
    );
  }

  DenialWindow? _matchingLaunchWindow(
    List<DenialWindow> windows,
    AppLaunchRequest request,
  ) {
    final boundObjectId = state.launchingObjectId;
    if (boundObjectId != null) {
      for (final window in windows) {
        if (window.objectId == boundObjectId && request.matchesWindow(window)) {
          return window;
        }
      }
    }

    for (final window in windows) {
      if (request.matchesWindow(window)) {
        return window;
      }
    }
    return null;
  }

  int? beginAppLaunch({
    required String appName,
    required String? iconPath,
    required Iterable<String> expectedAppIds,
  }) {
    return _beginLauncherTransition(
      appName: appName,
      iconPath: iconPath,
      expectedAppIds: expectedAppIds,
    );
  }

  /// Focuses an already-open application through the same coherent launcher
  /// transition used for a newly-created application window.
  int? activateAppFromLauncher({
    required DenialWindow window,
    required String appName,
    required String? iconPath,
    Rect? sourceRect,
  }) {
    if (!window.isUserApp) {
      return null;
    }
    return _beginLauncherTransition(
      appName: appName,
      iconPath: iconPath,
      expectedAppIds: <String>[window.appId],
      targetWindow: window,
      sourceRect: sourceRect,
    );
  }

  int? _beginLauncherTransition({
    required String appName,
    required String? iconPath,
    required Iterable<String> expectedAppIds,
    DenialWindow? targetWindow,
    Rect? sourceRect,
  }) {
    if (state.lockLayerVisible || state.launchRequest != null) {
      return null;
    }

    final requestId = _nextLaunchRequestId++;
    final request = AppLaunchRequest(
      requestId: requestId,
      appName: appName,
      iconPath: iconPath,
      expectedAppIds: expectedAppIds,
      existingObjectIds: state.openAppWindows.map((window) => window.objectId),
      targetObjectId: targetWindow?.objectId,
      sourceRect: sourceRect,
    );

    _rawGestureDrag = Offset.zero;
    _gestureLockOrigin = Offset.zero;
    _gestureAxis = _GestureAxis.undecided;
    _launchRequestTimer?.cancel();
    final generation = _buildGeneration;
    _launchRequestTimer = Timer(_launchRequestTimeout, () {
      if (isBuildGenerationActive(generation)) {
        failAppLaunch(requestId);
      }
    });

    state = state.copyWith(
      launchRequest: request,
      foregroundObjectId: targetWindow?.objectId,
      launchingObjectId: targetWindow?.objectId,
      clearLaunchingObjectId: targetWindow == null,
      overviewVisible: false,
      gestureDrag: Offset.zero,
      quickSettingsVisible: false,
      quickSettingsDrag: Offset.zero,
      quickSettingsDragActive: false,
      edgePanelVisible: false,
      edgePanelDrag: Offset.zero,
      edgePanelDragActive: false,
      homeTransitionActive: false,
    );
    if (targetWindow != null) {
      _backgroundLaunchAppIds.remove(
        AppLaunchRequest.normalizeAppId(targetWindow.appId),
      );
      _platform.focusWindow(targetWindow);
    }
    return requestId;
  }

  void failAppLaunch(int requestId) {
    if (state.launchRequest?.requestId != requestId) {
      return;
    }
    _launchRequestTimer?.cancel();
    _launchRequestTimer = null;
    state = state.copyWith(
      clearLaunchRequest: true,
      clearLaunchingObjectId: true,
    );
  }

  void openOverview() {
    if (!state.overviewVisible) {
      _rawGestureDrag = Offset.zero;
      _gestureLockOrigin = Offset.zero;
      _gestureAxis = _GestureAxis.undecided;
      state = state.copyWith(
        overviewVisible: true,
        homeTransitionActive: false,
        gestureDrag: Offset.zero,
        quickSettingsVisible: false,
        quickSettingsDrag: Offset.zero,
        quickSettingsDragActive: false,
        edgePanelVisible: false,
        edgePanelDrag: Offset.zero,
        edgePanelDragActive: false,
      );
    }
  }

  /// Begins the "fly away to home" transition. The fullscreen primary stage is
  /// hidden via [ReferenceShellState.homeTransitionActive] while the overview layer
  /// animates the current thumbnail off-screen, then calls
  /// [completeHomeTransition].
  void goHome() {
    if (state.homeTransitionActive) {
      return;
    }
    _rawGestureDrag = Offset.zero;
    _gestureLockOrigin = Offset.zero;
    _gestureAxis = _GestureAxis.undecided;
    final launchRequest = state.launchRequest;
    if (launchRequest != null) {
      _launchRequestTimer?.cancel();
      _launchRequestTimer = null;
      _backgroundLaunchAppIds.addAll(launchRequest.expectedAppIds);
      state = state.copyWith(
        clearLaunchRequest: true,
        clearLaunchingObjectId: true,
        clearForegroundObjectId: true,
        homeTransitionActive: false,
        overviewVisible: false,
        gestureDrag: Offset.zero,
        quickSettingsVisible: false,
        quickSettingsDrag: Offset.zero,
        quickSettingsDragActive: false,
        edgePanelVisible: false,
        edgePanelDrag: Offset.zero,
        edgePanelDragActive: false,
      );
      return;
    }
    // Clear the foreground now so home shows immediately beneath the flying
    // thumbnail; the overview layer keeps the app texture for the fly-away.
    state = state.copyWith(
      homeTransitionActive: true,
      overviewVisible: false,
      gestureDrag: Offset.zero,
      quickSettingsVisible: false,
      quickSettingsDrag: Offset.zero,
      quickSettingsDragActive: false,
      edgePanelVisible: false,
      edgePanelDrag: Offset.zero,
      edgePanelDragActive: false,
      clearForegroundObjectId: true,
    );
  }

  void completeHomeTransition() {
    if (!state.homeTransitionActive) {
      return;
    }
    state = state.copyWith(homeTransitionActive: false);
  }

  void closeOverview() {
    if (state.overviewVisible) {
      _rawGestureDrag = Offset.zero;
      _gestureLockOrigin = Offset.zero;
      _gestureAxis = _GestureAxis.undecided;
      state = state.copyWith(
        overviewVisible: false,
        gestureDrag: Offset.zero,
        quickSettingsDragActive: false,
        edgePanelVisible: false,
        edgePanelDrag: Offset.zero,
        edgePanelDragActive: false,
        clearForegroundObjectId: true,
      );
    }
  }

  void closeWindow(DenialWindow window) {
    if (state.overviewVisible && state.openAppWindowCount <= 1) {
      closeOverview();
    }
    _platform.closeWindow(window);
  }

  void focusWindow(DenialWindow window) {
    if (!window.isUserApp) {
      return;
    }

    _backgroundLaunchAppIds.remove(
      AppLaunchRequest.normalizeAppId(window.appId),
    );
    _activateWindowInShell(window);
    _platform.focusWindow(window);
  }

  /// Mirrors the compositor dropping keyboard focus after this window is
  /// minimized. A later native activation remains authoritative.
  void releaseWindowFocus(DenialWindow window) {
    _platform.releaseWindowFocus(window);
    if (state.foregroundObjectId != window.objectId) {
      return;
    }
    state = state.copyWith(clearForegroundObjectId: true);
  }

  void _activateWindowInShell(DenialWindow window) {
    _rawGestureDrag = Offset.zero;
    _gestureLockOrigin = Offset.zero;
    _gestureAxis = _GestureAxis.undecided;
    state = state.copyWith(
      foregroundObjectId: window.objectId,
      homeTransitionActive: false,
      overviewVisible: false,
      gestureDrag: Offset.zero,
      quickSettingsVisible: false,
      quickSettingsDrag: Offset.zero,
      quickSettingsDragActive: false,
      edgePanelVisible: false,
      edgePanelDrag: Offset.zero,
      edgePanelDragActive: false,
    );
  }

  void _handleNativeWindowActivated(int windowId) {
    // Closing the native focused window can activate its neighbor. Recents
    // keeps ownership of presentation until the user selects a card or leaves;
    // an automatic focus fallback must not interrupt the removal reflow.
    if (state.overviewVisible) {
      return;
    }
    for (final window in state.windows) {
      if (window.windowId == windowId && window.isUserApp) {
        final appId = AppLaunchRequest.normalizeAppId(window.appId);
        if (_backgroundLaunchAppIds.remove(appId)) {
          return;
        }
        _activateWindowInShell(window);
        return;
      }
    }
  }

  void switchAdjacentWindow(int direction) {
    completeAdjacentWindowSwitch(direction);
  }

  void completeAdjacentWindowSwitch(int direction) {
    final target = state.adjacentOpenAppWindow(direction);
    if (target == null) {
      resetGestureDrag();
      return;
    }

    _rawGestureDrag = Offset.zero;
    _gestureLockOrigin = Offset.zero;
    _gestureAxis = _GestureAxis.undecided;
    state = state.copyWith(
      foregroundObjectId: target.objectId,
      overviewVisible: false,
      gestureDrag: Offset.zero,
      quickSettingsVisible: false,
      quickSettingsDrag: Offset.zero,
      quickSettingsDragActive: false,
      edgePanelVisible: false,
      edgePanelDrag: Offset.zero,
      edgePanelDragActive: false,
      clearLaunchingObjectId: true,
    );
    _platform.focusWindow(target);
  }

  void completeLaunchTransition(int requestId, int objectId) {
    if (state.launchRequest?.requestId != requestId ||
        state.launchingObjectId != objectId) {
      return;
    }

    _launchRequestTimer?.cancel();
    _launchRequestTimer = null;
    state = state.copyWith(
      clearLaunchRequest: true,
      clearLaunchingObjectId: true,
    );
  }

  void updateGestureDrag(Offset delta) {
    if (delta == Offset.zero) {
      return;
    }

    _rawGestureDrag += delta;
    _lockGestureAxis();
    final visualDrag = _visualGestureDrag(_rawGestureDrag);
    if (visualDrag == state.gestureDrag) {
      return;
    }

    state = state.copyWith(gestureDrag: visualDrag);
  }

  void resetGestureDrag() {
    _rawGestureDrag = Offset.zero;
    _gestureLockOrigin = Offset.zero;
    _gestureAxis = _GestureAxis.undecided;
    if (state.gestureDrag != Offset.zero) {
      state = state.copyWith(gestureDrag: Offset.zero);
    }
  }

  void setGestureDragForAnimation(Offset drag) {
    _rawGestureDrag = drag;
    _gestureLockOrigin = Offset.zero;
    _gestureAxis = _GestureAxis.horizontal;
    final visualDrag = _visualGestureDrag(_rawGestureDrag);
    if (visualDrag == state.gestureDrag) {
      return;
    }

    state = state.copyWith(gestureDrag: visualDrag);
  }

  void openQuickSettings() {
    if (state.quickSettingsVisible &&
        state.quickSettingsDrag == Offset.zero &&
        !state.quickSettingsDragActive) {
      return;
    }

    _rawGestureDrag = Offset.zero;
    _gestureLockOrigin = Offset.zero;
    _gestureAxis = _GestureAxis.undecided;
    state = state.copyWith(
      quickSettingsVisible: true,
      quickSettingsDrag: Offset.zero,
      quickSettingsDragActive: false,
      overviewVisible: false,
      gestureDrag: Offset.zero,
      edgePanelVisible: false,
      edgePanelDrag: Offset.zero,
      edgePanelDragActive: false,
    );
  }

  void closeQuickSettings() {
    if (!state.quickSettingsVisible &&
        state.quickSettingsDrag == Offset.zero &&
        !state.quickSettingsDragActive) {
      return;
    }

    state = state.copyWith(
      quickSettingsVisible: false,
      quickSettingsDrag: Offset.zero,
      quickSettingsDragActive: false,
    );
  }

  void startQuickSettingsDrag({double? progress}) {
    // A drag can interrupt the settling spring. Continue from the painted
    // position supplied by the shade rather than jumping to its target state.
    final initialProgress = (progress ?? state.quickSettingsDragProgress).clamp(
      0.0,
      1.0,
    );
    _quickSettingsDragStartedOpen = initialProgress >= 1.0;
    _quickSettingsDragMoved = false;
    state = state.copyWith(
      quickSettingsDrag: Offset(
        0,
        initialProgress * ReferenceShellMetrics.quickSettingsDragDistance,
      ),
      quickSettingsVisible: false,
      quickSettingsDragActive: true,
    );
  }

  void updateQuickSettingsDrag(Offset delta) {
    if (delta == Offset.zero) {
      return;
    }

    _quickSettingsDragMoved = true;
    final current = state.quickSettingsVisible
        ? ReferenceShellMetrics.quickSettingsDragDistance
        : state.quickSettingsDrag.dy;
    final dy = (current + delta.dy)
        .clamp(0.0, ReferenceShellMetrics.quickSettingsDragDistance)
        .toDouble();
    if (dy == state.quickSettingsDrag.dy) {
      return;
    }

    state = state.copyWith(
      quickSettingsVisible: false,
      quickSettingsDrag: Offset(0.0, dy),
      quickSettingsDragActive: true,
      overviewVisible: false,
      gestureDrag: Offset.zero,
      edgePanelVisible: false,
      edgePanelDrag: Offset.zero,
      edgePanelDragActive: false,
    );
  }

  void endQuickSettingsDrag(double velocity) {
    final drag = state.quickSettingsVisible && !_quickSettingsDragMoved
        ? ReferenceShellMetrics.quickSettingsDragDistance
        : state.quickSettingsDrag.dy;
    final flickOpen = velocity >= _quickSettingsFlickVelocity;
    final flickClose = velocity <= -_quickSettingsFlickVelocity;
    final shouldOpen =
        !flickClose &&
        ((_quickSettingsDragStartedOpen && !_quickSettingsDragMoved) ||
            drag >= _quickSettingsOpenDistance ||
            flickOpen);
    _quickSettingsDragStartedOpen = false;
    _quickSettingsDragMoved = false;
    if (shouldOpen) {
      openQuickSettings();
    } else {
      closeQuickSettings();
    }
  }

  void openEdgePanel() {
    if (state.edgePanelVisible &&
        state.edgePanelDrag == Offset.zero &&
        !state.edgePanelDragActive) {
      return;
    }

    _rawGestureDrag = Offset.zero;
    _gestureLockOrigin = Offset.zero;
    _gestureAxis = _GestureAxis.undecided;
    state = state.copyWith(
      edgePanelVisible: true,
      edgePanelDrag: Offset.zero,
      edgePanelDragActive: false,
      overviewVisible: false,
      gestureDrag: Offset.zero,
      quickSettingsVisible: false,
      quickSettingsDrag: Offset.zero,
      quickSettingsDragActive: false,
    );
  }

  void closeEdgePanel() {
    if (!state.edgePanelVisible &&
        state.edgePanelDrag == Offset.zero &&
        !state.edgePanelDragActive) {
      return;
    }

    state = state.copyWith(
      edgePanelVisible: false,
      edgePanelDrag: Offset.zero,
      edgePanelDragActive: false,
    );
  }

  void updateEdgePanelViewportScroll(double delta, double maxScroll) {
    if (!state.edgePanelVisible || delta == 0.0 || maxScroll <= 0.0) {
      return;
    }

    final next = (state.edgePanelViewportScroll + delta)
        .clamp(0.0, maxScroll)
        .toDouble();
    if (next == state.edgePanelViewportScroll) {
      return;
    }

    state = state.copyWith(edgePanelViewportScroll: next);
  }

  void startEdgePanelDrag() {
    _edgePanelDismissalSerial = _lastTextInput?.active == true
        ? _lastTextInput!.activationSerial
        : null;
    _edgePanelDragStartedOpen =
        state.edgePanelVisible || state.edgePanelDragProgress >= 1.0;
    _edgePanelDragMoved = false;
    state = state.copyWith(
      edgePanelDrag: Offset.zero,
      edgePanelVisible: state.edgePanelVisible,
      edgePanelDragActive: true,
    );
  }

  void updateEdgePanelDrag(Offset delta) {
    if (delta == Offset.zero) {
      return;
    }

    _edgePanelDragMoved = true;
    final current = state.edgePanelVisible
        ? ReferenceShellMetrics.edgePanelDragDistance
        : state.edgePanelDrag.dy;
    final dy = (current - delta.dy)
        .clamp(0.0, ReferenceShellMetrics.edgePanelDragDistance)
        .toDouble();
    if (dy == state.edgePanelDrag.dy) {
      return;
    }

    state = state.copyWith(
      edgePanelVisible: false,
      edgePanelDrag: Offset(0.0, dy),
      edgePanelDragActive: true,
      overviewVisible: false,
      gestureDrag: Offset.zero,
      quickSettingsVisible: false,
      quickSettingsDrag: Offset.zero,
      quickSettingsDragActive: false,
    );
  }

  void endEdgePanelDrag(double velocity) {
    final drag = state.edgePanelVisible && !_edgePanelDragMoved
        ? ReferenceShellMetrics.edgePanelDragDistance
        : state.edgePanelDrag.dy;
    final flickOpen = velocity <= -_edgePanelFlickVelocity;
    final flickClose = velocity >= _edgePanelFlickVelocity;
    final shouldOpen =
        !flickClose &&
        ((_edgePanelDragStartedOpen && !_edgePanelDragMoved) ||
            drag >= ReferenceShellMetrics.edgePanelOpenDistance ||
            flickOpen);
    // Only a completed user dismissal sends feedback. Automatic hides and
    // animation frames must not ask the application to dismiss another editor.
    if (!shouldOpen &&
        _edgePanelDragStartedOpen &&
        _edgePanelDismissalSerial != null) {
      _bridge.dismissKeyboardPanel(_edgePanelDismissalSerial!);
    }
    _edgePanelDismissalSerial = null;
    _edgePanelDragStartedOpen = false;
    _edgePanelDragMoved = false;
    if (shouldOpen) {
      openEdgePanel();
    } else {
      closeEdgePanel();
    }
  }

  Offset _visualGestureDrag(Offset rawDrag) {
    return switch (_gestureAxis) {
      _GestureAxis.horizontal => Offset(
        (rawDrag.dx - _gestureLockOrigin.dx)
            .clamp(
              -_gestureHorizontalVisualDistance,
              _gestureHorizontalVisualDistance,
            )
            .toDouble(),
        0.0,
      ),
      _GestureAxis.vertical => Offset(
        0.0,
        rawDrag.dy
            .clamp(-_gestureVisualDistance, _gestureVisualDistance)
            .toDouble(),
      ),
      _GestureAxis.undecided => Offset.zero,
    };
  }

  void _lockGestureAxis() {
    if (_gestureAxis != _GestureAxis.undecided) {
      return;
    }

    if (state.overviewVisible) {
      _gestureAxis = _GestureAxis.vertical;
      return;
    }

    final dx = _rawGestureDrag.dx.abs();
    final dy = _rawGestureDrag.dy.abs();
    if (dx < _gestureAxisLockDistance && dy < _gestureAxisLockDistance) {
      return;
    }

    if (dx > dy * _gestureAxisLockRatio) {
      _gestureAxis = _GestureAxis.horizontal;
      _gestureLockOrigin = _rawGestureDrag;
    } else if (dy > dx * _gestureAxisLockRatio) {
      _gestureAxis = _GestureAxis.vertical;
    }
  }

  void publishInputLayout(
    Size viewSize,
    ShellInteractionSnapshot interactions,
  ) {
    _inputLayoutCoordinator.publish(
      state: state,
      viewSize: viewSize,
      interactions: interactions,
    );
  }
}

enum _GestureAxis { undecided, horizontal, vertical }
