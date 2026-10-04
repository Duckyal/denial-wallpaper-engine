/// Denial x Wallpaper Engine integration plugin.
///
/// Drives linux-wallpaperengine as a live desktop background via
/// wlr-layer-shell. The plugin contributes a [ShellSurface] for wallpaper
/// process lifecycle management, a manager panel surface, and [ShellAction]s
/// for shortcut access. Contribution classes must be declared in this entry
/// library for the composition generator to discover them.
@Plugin()
library;

import 'dart:async';
import 'dart:io';

import 'package:denial_sdk/composition.dart';
import 'package:denial_flutter_sdk/actions.dart';
import 'package:denial_flutter_sdk/input.dart';
import 'package:denial_flutter_sdk/models.dart';
import 'package:denial_flutter_sdk/state.dart';
import 'package:denial_flutter_sdk/surfaces.dart';
import 'package:flutter/services.dart'
    show
        HardwareKeyboard,
        KeyDownEvent,
        KeyEvent,
        KeyEventResult,
        LogicalKeyboardKey;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'src/lwe_bootstrap.dart';
import 'src/lwe_config_watcher.dart';
import 'src/lwe_controller.dart';
import 'src/lwe_debug.dart';
import 'src/lwe_panel.dart';

export 'src/lwe_driver.dart';
export 'src/lwe_controller.dart';
export 'src/lwe_config_watcher.dart';
export 'src/lwe_bootstrap.dart';
export 'src/lwe_panel.dart';
export 'src/lwe_panel_bus.dart';
export 'src/workshop_discovery.dart';

/// Manages the linux-wallpaperengine process lifecycle as a desktop surface.
///
/// The wallpaper itself is rendered by the external process via
/// wlr-layer-shell; this surface is an invisible controller that starts,
/// stops, and restores the wallpaper on shell mount.
@Provides(ShellSurface)
final class LweWallpaperSurface implements ShellSurface {
  const LweWallpaperSurface();

  @override
  String get id => 'denial_wallpaper_engine.wallpaper';

  @override
  ShellSurfaceLayer get layer => ShellSurfaceLayer.desktop;

  @override
  ShellSurfacePlacement? place(ShellSurfaceEnvironment environment) {
    // Only manage the wallpaper on the main output to avoid duplicate processes.
    if (!environment.isMainOutput) return null;
    // Must mount to run the startup restore, so cover the work area but keep
    // the content a zero-size SizedBox that never intercepts pointer events.
    // A zero-size placement itself crashes the host's layout pass.
    return ShellSurfacePlacement(bounds: environment.workArea);
  }

  @override
  Widget build(BuildContext context, {required ShellSurfaceContext surface}) {
    return const _LweWallpaperController();
  }
}

class _LweWallpaperController extends ConsumerStatefulWidget {
  const _LweWallpaperController();

  @override
  ConsumerState<_LweWallpaperController> createState() =>
      _LweWallpaperControllerState();
}

class _LweWallpaperControllerState
    extends ConsumerState<_LweWallpaperController> {
  bool _shortcutsRegistered = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _restore();
      await _registerShortcut();
    });
  }

  Future<void> _restore() async {
    lweLog('surface mounted');
    if (!mounted) return;
    try {
      // Start the config watcher so external config edits reach the process.
      ref.read(lweConfigWatcherProvider).start();
      lweLog('watcher started');
      // Restore the last active wallpaper on startup.
      await ref.read(lweBootstrapProvider).restoreOnStartup();
      ref.read(lweControllerProvider.notifier).ensureRotation();
      lweLog('restore finished');
    } on Object catch (error, stack) {
      // Never let a wallpaper failure take the shell down.
      lweLog('startup failed: $error\n$stack');
      debugPrint('LWE: startup failed: $error\n$stack');
    }
  }

  Future<void> _registerShortcut() async {
    if (_shortcutsRegistered) return;
    _shortcutsRegistered = true;
    try {
      final bridge = ref.read(denialBridgeProvider);
      final config = await bridge.readShortcutConfiguration();
      const actionId = 'denial_wallpaper_engine.togglePanel';
      final alreadyBound = config.shortcuts.any(
        (b) =>
            b.shortcut == 'Meta+b' ||
            (b.target is DenialShortcutPluginActionTarget &&
                (b.target as DenialShortcutPluginActionTarget).id == actionId),
      );
      if (alreadyBound) {
        lweLog('shortcut Meta+b already bound to togglePanel');
        return;
      }
      await bridge.addShortcut(
        expectedRevision: config.revision,
        shortcut: const DenialShortcutBinding(
          shortcut: 'Meta+b',
          target: DenialShortcutPluginActionTarget(actionId),
        ),
      );
      lweLog('registered Meta+b -> denial_wallpaper_engine.togglePanel');
    } on Object catch (error) {
      lweLog('shortcut registration failed: $error');
    }
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

/// Full-screen wallpaper manager overlay, toggled by shell actions.
///
/// Mounted on the aboveWindows layer so it draws over application windows and
/// accepts pointer input while visible; otherwise it renders nothing and
/// stays out of the way.
@Provides(ShellSurface)
final class LwePanelSurface implements ShellSurface {
  const LwePanelSurface();

  @override
  String get id => 'denial_wallpaper_engine.panel';

  @override
  ShellSurfaceLayer get layer => ShellSurfaceLayer.aboveWindows;

  @override
  ShellSurfacePlacement? place(ShellSurfaceEnvironment environment) {
    if (!environment.isMainOutput) return null;
    // Cover the FULL output (not the work area) so the panel hides the top
    // bar and dock while open; the input region captures the whole screen.
    return ShellSurfacePlacement(bounds: environment.output.logicalRect);
  }

  @override
  Widget build(BuildContext context, {required ShellSurfaceContext surface}) {
    return const _LwePanelHost();
  }
}

class _LwePanelHost extends ConsumerStatefulWidget {
  const _LwePanelHost();

  @override
  ConsumerState<_LwePanelHost> createState() => _LwePanelHostState();
}

class _LwePanelHostState extends ConsumerState<_LwePanelHost> {
  StreamSubscription<LwePanelEvent>? _subscription;
  StreamSubscription<FileSystemEvent>? _triggerSubscription;
  bool _visible = false;

  /// The shell's own "close window" bindings ("Meta+q" …). The panel is a
  /// surface, not a window, so the compositor has nothing to close — it has
  /// to honour those keys itself or it feels stuck on screen.
  List<String> _closeShortcuts = const [];

  @override
  void initState() {
    super.initState();
    lweLog('panel host mounted');
    _subscription = LwePanelBus.instance.events.listen(_onEvent);
    _listenPanelTrigger();
  }

  Future<void> _loadCloseShortcuts() async {
    try {
      final bridge = ref.read(denialBridgeProvider);
      final config = await bridge.readShortcutConfiguration();
      if (!mounted) return;
      setState(() {
        _closeShortcuts = [
          for (final binding in config.shortcuts)
            if (binding.target is DenialShortcutActionTarget &&
                (binding.target as DenialShortcutActionTarget).action ==
                    DenialShortcutAction.closeWindow)
              binding.shortcut,
        ];
      });
      lweLog('close-window shortcuts: $_closeShortcuts');
    } on Object catch (error) {
      lweLog('close shortcut lookup failed: $error');
    }
  }

  /// "Meta+q" → meta down + "q", with modifiers that are NOT part of the
  /// binding required to be up so Meta+Shift+Q doesn't close the panel.
  bool _matchesShortcut(String shortcut, KeyEvent event) {
    final parts = shortcut
        .split('+')
        .map((part) => part.trim().toLowerCase())
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return false;
    final key = parts.removeLast();
    final modifiers = parts.toSet();
    final keyboard = HardwareKeyboard.instance;
    final wantMeta = modifiers.contains('meta') ||
        modifiers.contains('super') ||
        modifiers.contains('cmd');
    final wantCtrl =
        modifiers.contains('ctrl') || modifiers.contains('control');
    final wantAlt = modifiers.contains('alt');
    final wantShift = modifiers.contains('shift');
    if (wantMeta != keyboard.isMetaPressed) return false;
    if (wantCtrl != keyboard.isControlPressed) return false;
    if (wantAlt != keyboard.isAltPressed) return false;
    if (wantShift != keyboard.isShiftPressed) return false;
    return event.logicalKey.keyLabel.toLowerCase() == key;
  }

  /// The settings app runs in its own process; it requests the panel by
  /// creating the trigger file, which we consume and remove.
  void _listenPanelTrigger() {
    try {
      final dir = panelTriggerFile().parent;
      if (!dir.existsSync()) dir.createSync(recursive: true);
      _triggerSubscription = dir
          .watch(events: FileSystemEvent.create | FileSystemEvent.modify)
          .listen((event) {
            if (!event.path.endsWith('panel-open')) return;
            panelTriggerFile().deleteSync();
            if (mounted && !_visible) {
              _showPanel();
            }
          });
    } on Object catch (error) {
      lweLog('panel trigger watch failed: $error');
    }
  }

  Future<void> _onEvent(LwePanelEvent event) async {
    switch (event) {
      case LwePanelEvent.toggle:
        if (_visible) {
          setState(() => _visible = false);
        } else {
          _showPanel();
        }
      case LwePanelEvent.close:
        if (_visible) setState(() => _visible = false);
      case LwePanelEvent.random:
        await ref.read(lweControllerProvider.notifier).applyRandom();
    }
  }

  void _showPanel() {
    setState(() => _visible = true);
    // Re-read on every open: the binding may have changed in settings.
    unawaited(_loadCloseShortcuts());
    // The enable toggle shows the ENGINE's real state, not just the config's
    // claim; query once per open so a drifted flag (crash, external engine
    // start, an older boot) reconciles before the user reads it.
    unawaited(ref.read(lweControllerProvider.notifier).syncRenderingState());
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _triggerSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    lweLog('panel build visible=$_visible');
    // Register with the compositor while visible: without this the shell's
    // input registry has no entry for the panel, so pointers and keys fall
    // through to the windows underneath.
    return ShellInputRegion(
      debugLabel: 'Wallpaper Engine panel',
      active: _visible,
      pointerPolicy: ShellPointerPolicy.fullScene,
      keyboardPolicy: ShellKeyboardPolicy.capture,
      compositorPolicy: ShellCompositorPolicy.exclusive,
      child: Focus(
        autofocus: _visible,
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent) {
            if (event.logicalKey == LogicalKeyboardKey.escape) {
              setState(() => _visible = false);
              return KeyEventResult.handled;
            }
            for (final shortcut in _closeShortcuts) {
              if (_matchesShortcut(shortcut, event)) {
                setState(() => _visible = false);
                return KeyEventResult.handled;
              }
            }
          }
          return KeyEventResult.ignored;
        },
        child: !_visible
            ? const SizedBox.shrink()
            : LweWallpaperPanel(
                onClose: () => setState(() => _visible = false),
              ),
      ),
    );
  }
}

/// Toggles the Wallpaper Engine manager panel. Bind this to a shortcut in
/// Denial's keyboard settings for one-key access.
@Provides(ShellAction)
final class LweTogglePanelAction implements ShellAction {
  const LweTogglePanelAction();

  @override
  String get id => 'denial_wallpaper_engine.togglePanel';

  @override
  String get provider => 'Wallpaper Engine';

  @override
  String label(BuildContext context) => 'Wallpaper Engine Panel';

  @override
  String description(BuildContext context) => '打开或关闭动态壁纸管理面板';

  @override
  Future<void> invoke(ShellActionContext context) async {
    LwePanelBus.instance.togglePanel();
  }
}

/// Applies a random workshop wallpaper immediately.
@Provides(ShellAction)
final class LweRandomWallpaperAction implements ShellAction {
  const LweRandomWallpaperAction();

  @override
  String get id => 'denial_wallpaper_engine.randomWallpaper';

  @override
  String get provider => 'Wallpaper Engine';

  @override
  String label(BuildContext context) => 'Random Wallpaper';

  @override
  String description(BuildContext context) => '随机应用一个已安装的 Workshop 壁纸';

  @override
  Future<void> invoke(ShellActionContext context) async {
    LwePanelBus.instance.requestRandom();
  }
}
