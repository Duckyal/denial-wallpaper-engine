import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'lwe_debug.dart';
import 'lwe_driver.dart';
import 'workshop_discovery.dart';

/// Absolute path of the shared plugin config file.
String configPath() {
  final home = Platform.environment['HOME'] ?? '/';
  return '$home/.config/denial-wallpaper-engine/config.json';
}

/// Content of the most recent config write by THIS process. The config
/// watcher compares against it so our own saves (panel tweaks) don't look
/// like external edits and trigger a spurious engine restart.
///
/// Owned by [LweController] so the watcher can read it without a global
/// mutable variable.
String? lastConfigWrite;

/// Absolute path of the cross-process panel trigger. The settings app (a
/// separate binary) creates this file to ask the shell-side panel to open.
File panelTriggerFile() {
  final home = Platform.environment['HOME'] ?? '/';
  return File('$home/.config/denial-wallpaper-engine/panel-open');
}

/// Persistent state and configuration for the Wallpaper Engine plugin.
class LweController extends AsyncNotifier<LweState> {
  @override
  Future<LweState> build() async {
    ref.onDispose(() {
      _rotationTimer?.cancel();
    });
    return _load();
  }

  Timer? _rotationTimer;
  final _SerialQueue _applyQueue = _SerialQueue();

  /// Current state once the initial load finished; awaited by callers that
  /// need the persisted values before acting. Keeps [future]'s protected
  /// access encapsulated inside the notifier.
  Future<LweState> current() => future;

  Future<LweState> _load() async {
    final file = File(configPath());
    if (!await file.exists()) {
      return const LweState();
    }
    final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    return LweState.fromJson(json);
  }

  Future<void> _save(LweState state) async {
    final file = File(configPath());
    await file.parent.create(recursive: true);
    final content = jsonEncode(state.toJson());
    await file.writeAsString(content);
    lastConfigWrite = content;
  }

  /// One-shot commit of the panel draft: persists everything, restarts the
  /// engine only when the wallpaper or settings actually changed, and syncs
  /// the rotation timer. Nothing applies before this is called.
  Future<void> commitPanel({
    String? wallpaperId,
    List<String>? playlist,
    LweSettings? settings,
    int? rotationMinutes,
  }) async {
    final current = await future;
    final settingsChanged = settings != null && settings != current.settings;
    final idChanged =
        wallpaperId != null && wallpaperId != current.currentWallpaperId;
    var newState = current.copyWith(
      playlist: playlist,
      settings: settings,
      rotationMinutes: rotationMinutes,
    );
    if (wallpaperId != null) {
      newState = newState.copyWith(
        enabled: true,
        currentWallpaperId: wallpaperId,
      );
    }
    await _save(newState);
    state = AsyncData(newState);
    _startRotationTimer(newState.rotationMinutes);
    if (newState.enabled &&
        newState.currentWallpaperId != null &&
        (idChanged || settingsChanged)) {
      await _applyQueue.run(
        () => ref
            .read(lweDriverProvider)
            .apply(newState.currentWallpaperId!, newState.settings),
      );
    }
  }

  /// Applies [id] now and persists it as the startup wallpaper.
  Future<void> applyWallpaper(String id) async {
    final current = await future;
    final newState = current.copyWith(enabled: true, currentWallpaperId: id);
    await _save(newState);
    state = AsyncData(newState);
    await _applyQueue.run(
      () => ref.read(lweDriverProvider).apply(id, newState.settings),
    );
  }

  /// Applies a random wallpaper: the rotation playlist when set, otherwise
  /// every installed wallpaper. Prefers the cached provider to avoid a full
  /// disk scan on every rotation tick.
  Future<void> applyRandom() async {
    final current = await future;
    var pool = current.playlist;
    if (pool.isEmpty) {
      // Riverpod 3 移除了 AsyncValue.valueOrNull，可空值直接读 .value。
      final cached = ref.read(lweWallpapersProvider).value;
      if (cached != null) {
        pool = [for (final item in cached) item.id];
      } else {
        final all = await ref.read(workshopDiscoveryProvider).getWallpapers();
        pool = [for (final item in all) item.id];
      }
    }
    pool = pool.where((id) => id != current.currentWallpaperId).toList();
    if (pool.isEmpty) return;
    final pick = pool[Random().nextInt(pool.length)];
    await applyWallpaper(pick);
  }

  /// Stops the running wallpaper and keeps the selection for later.
  Future<void> stopWallpaper() async {
    final current = await future;
    final newState = current.copyWith(enabled: false);
    await _save(newState);
    state = AsyncData(newState);
    _rotationTimer?.cancel();
    _rotationTimer = null;
    await _applyQueue.run(() => ref.read(lweDriverProvider).stop());
  }

  /// Reconciles the persisted `enabled` flag with the engine's ACTUAL state.
  ///
  /// Called when the panel opens: the toggle must show whether a wallpaper
  /// is really rendering, not what the config last claimed — a crash, a
  /// manual engine start, or an older boot can drift the two apart. The
  /// reconciled value is persisted so the next boot restores honestly.
  Future<void> syncRenderingState() async {
    try {
      final driver = ref.read(lweDriverProvider);
      // The deferred startup apply has not fired yet: the engine being
      // absent right now is intentional, so neither direction may flip.
      if (driver.hasScheduledStart) {
        lweLog('sync: startup apply pending, skipping');
        return;
      }
      final rendering = await driver.isRendering();
      final current = await future;
      if (rendering == current.enabled) return;
      final newState = current.copyWith(enabled: rendering);
      await _save(newState);
      state = AsyncData(newState);
      if (rendering) {
        _startRotationTimer(newState.rotationMinutes);
      } else {
        _rotationTimer?.cancel();
        _rotationTimer = null;
      }
      lweLog('sync: enabled -> $rendering');
    } on Object catch (error, stack) {
      lweLog('sync failed: $error\n$stack');
    }
  }

  /// Re-enables the stored wallpaper or disables the running one.
  Future<void> setEnabled(bool enabled) async {
    final current = await future;
    final newState = current.copyWith(enabled: enabled);
    await _save(newState);
    state = AsyncData(newState);
    final driver = ref.read(lweDriverProvider);
    final id = newState.currentWallpaperId;
    if (enabled && id != null) {
      await _applyQueue.run(() => driver.apply(id, newState.settings));
    } else {
      _rotationTimer?.cancel();
      _rotationTimer = null;
      await _applyQueue.run(driver.stop);
    }
  }

  /// Persists [settings] WITHOUT restarting the engine, so tweaking values
  /// never interrupts the wallpaper. Call [applySettingsNow] to restart the
  /// engine with the new values.
  Future<void> updateSettings(LweSettings settings) async {
    final current = await future;
    final newState = current.copyWith(settings: settings);
    await _save(newState);
    state = AsyncData(newState);
  }

  /// Restarts the wallpaper process with the current settings.
  Future<void> applySettingsNow() async {
    final current = await future;
    final id = current.currentWallpaperId;
    if (!current.enabled || id == null) return;
    await _applyQueue.run(
      () => ref.read(lweDriverProvider).apply(id, current.settings),
    );
  }

  Future<void> setWallpaper(String id) async {
    final current = await future;
    final newState = current.copyWith(currentWallpaperId: id);
    await _save(newState);
    state = AsyncData(newState);
  }

  /// Adds [id] to / removes it from the rotation playlist.
  Future<void> togglePlaylistItem(String id) async {
    final current = await future;
    final playlist = [...current.playlist];
    if (!playlist.remove(id)) playlist.add(id);
    final newState = current.copyWith(playlist: playlist);
    await _save(newState);
    state = AsyncData(newState);
  }

  /// Persists the rotation interval and (re)starts the timer. 0 disables.
  Future<void> setRotationMinutes(int minutes) async {
    final current = await future;
    final newState = current.copyWith(rotationMinutes: minutes);
    await _save(newState);
    state = AsyncData(newState);
    _startRotationTimer(minutes);
  }

  /// Starts the rotation timer from the persisted interval (login restore).
  void ensureRotation() {
    future.then((state) {
      _startRotationTimer(state.enabled ? state.rotationMinutes : 0);
    });
  }

  void _startRotationTimer(int minutes) {
    _rotationTimer?.cancel();
    _rotationTimer = null;
    if (minutes <= 0) return;
    lweLog('rotation started: every $minutes min');
    _rotationTimer = Timer.periodic(Duration(minutes: minutes), (_) {
      applyRandom();
    });
  }
}

/// Serializes engine spawns so concurrent callers reap each other's process
/// instead of racing it.
class _SerialQueue {
  Future<void> _tail = Future<void>.value();

  Future<void> run(Future<void> Function() task) {
    final run = _tail.then((_) => task());
    _tail = run.catchError((Object error) {
      lweLog('SerialQueue task failed: $error');
    });
    return run;
  }
}

/// Persistent state for the plugin.
class LweState {
  const LweState({
    this.enabled = true,
    this.currentWallpaperId,
    this.playlist = const [],
    this.rotationMinutes = 0,
    this.settings = const LweSettings(),
  });

  final bool enabled;
  final String? currentWallpaperId;
  final List<String> playlist;
  final int rotationMinutes;
  final LweSettings settings;

  LweState copyWith({
    bool? enabled,
    String? currentWallpaperId,
    List<String>? playlist,
    int? rotationMinutes,
    LweSettings? settings,
  }) {
    return LweState(
      enabled: enabled ?? this.enabled,
      currentWallpaperId: currentWallpaperId ?? this.currentWallpaperId,
      playlist: playlist ?? this.playlist,
      rotationMinutes: rotationMinutes ?? this.rotationMinutes,
      settings: settings ?? this.settings,
    );
  }

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'currentWallpaperId': currentWallpaperId,
    'playlist': playlist,
    'rotationMinutes': rotationMinutes,
    'settings': settings.toJson(),
  };

  factory LweState.fromJson(Map<String, dynamic> json) {
    final settingsJson = json['settings'] as Map<String, dynamic>? ?? const {};
    return LweState(
      enabled: json['enabled'] as bool? ?? true,
      currentWallpaperId: json['currentWallpaperId'] as String?,
      playlist: (json['playlist'] as List<dynamic>?)?.cast<String>() ?? [],
      rotationMinutes: json['rotationMinutes'] as int? ?? 0,
      settings: LweSettings.fromJson(settingsJson),
    );
  }
}

final lweControllerProvider = AsyncNotifierProvider<LweController, LweState>(
  LweController.new,
);