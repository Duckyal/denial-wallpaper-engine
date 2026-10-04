import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'lwe_debug.dart';

/// Process driver for linux-wallpaperengine.
///
/// Handles process lifecycle and argv building. The wallpaper renders via
/// wlr-layer-shell; this class only manages the external process.
class LweDriver {
  LweDriver({required this.configPath});

  final String configPath;
  Process? _process;
  int? _lastPid;
  int _pendingStarts = 0;
  Future<void> _applyQueue = Future<void>.value();
  String? _cachedWaylandDisplay;

  /// True while a scheduled startup apply has not fired yet. The panel-open
  /// sync defers to it: the engine being absent during the first-frame
  /// window is intentional and must not read as "stopped".
  bool get hasScheduledStart => _pendingStarts > 0;

  /// The compositor's Wayland socket name. deniald itself is the compositor
  /// server, so its environment carries no WAYLAND_DISPLAY; children spawned
  /// from the shell need it pointed at the session socket to connect.
  ///
  /// The result is cached after the first call because the Wayland socket
  /// does not change during a session.
  String? _waylandDisplay() {
    if (_cachedWaylandDisplay != null) return _cachedWaylandDisplay;
    final runtime = Platform.environment['XDG_RUNTIME_DIR'];
    if (runtime == null) return null;
    final dir = Directory(runtime);
    final sockets =
        dir
            .listSync()
            .whereType<File>()
            .map((entry) => entry.uri.pathSegments.last)
            .where(
              (name) => name.startsWith('wayland-') && !name.endsWith('.lock'),
            )
            .toList()
          ..sort();
    _cachedWaylandDisplay = sockets.isEmpty ? null : sockets.last;
    return _cachedWaylandDisplay;
  }

  /// Starts the wallpaper process with the given wallpaper ID and settings.
  ///
  /// Applies are serialized so a second call while one is starting still
  /// reaps the process it replaces instead of racing it.
  Future<void> apply(String id, LweSettings settings) {
    final task = _applyQueue.then((_) => _apply(id, settings));
    _applyQueue = task.catchError((Object _) {});
    return task;
  }

  Future<void> _apply(String id, LweSettings settings) async {
    await stop();
    final args = _buildArgs(id, settings);
    lweLog('apply: linux-wallpaperengine $args');
    try {
      final environment = {
        ...Platform.environment,
        if (_waylandDisplay() != null) 'WAYLAND_DISPLAY': _waylandDisplay()!,
      };
      _process = await Process.start(
        'linux-wallpaperengine',
        args,
        environment: environment,
      );
      _lastPid = _process!.pid;
      lweLog('apply: started pid=${_process!.pid}');
    } on Object catch (error) {
      lweLog('apply: start failed: $error');
      rethrow;
    }
    final process = _process!;
    process.stdout.drain<void>();
    process.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) => lweLog('engine stderr: $line'));
    unawaited(
      process.exitCode.then(
        (code) => lweLog('engine pid=${process.pid} exited code=$code'),
      ),
    );
  }

  /// Whether a wallpaper engine process is actually rendering right now.
  ///
  /// Checks our tracked child first, then any engine instance pgrep can see
  /// — the latter covers processes from an earlier shell instance or started
  /// externally, which the in-memory fields miss. This is the ground truth
  /// the panel sync reconciles the persisted `enabled` flag against.
  Future<bool> isRendering() async {
    final process = _process;
    if (process != null) {
      // Zero-timeout probe: the future only completes once the process has
      // exited, so the timeout sentinel means "still running".
      const running = -0x100000;
      final exit = await process.exitCode.timeout(
        Duration.zero,
        onTimeout: () => running,
      );
      if (exit == running) return true;
    }
    try {
      final result = await Process.run('pgrep', [
        '-f',
        'linux-wallpaperengine',
      ]);
      return result.exitCode == 0;
    } on Object {
      return false;
    }
  }

  /// Schedules the startup apply after [delay] — the compositor's
  /// first-frame window must pass before a second GPU client may spawn —
  /// reaping leftover instances just before the spawn. [shouldRun] is
  /// re-checked at fire time so a disable landing inside the delay window
  /// still prevents the start.
  Future<void> scheduleApply(
    Duration delay,
    String id,
    LweSettings settings, {
    Future<bool> Function()? shouldRun,
  }) {
    final done = Completer<void>();
    _pendingStarts++;
    Timer(delay, () async {
      try {
        if (shouldRun != null && !await shouldRun()) {
          lweLog('scheduled apply skipped: disabled since schedule');
          if (!done.isCompleted) done.complete();
          return;
        }
        await reapStaleInstances();
        await apply(id, settings);
        if (!done.isCompleted) done.complete();
      } on Object catch (error, stack) {
        if (!done.isCompleted) done.completeError(error, stack);
      } finally {
        _pendingStarts--;
      }
    });
    return done.future;
  }

  /// Stops the current wallpaper process.
  ///
  /// linux-wallpaperengine ignores SIGTERM, so escalate to SIGKILL. A stale
  /// pid from a previous session is also reaped here via reapStaleInstances.
  Future<void> stop() async {
    final process = _process;
    _process = null;
    final lastPid = _lastPid;
    _lastPid = null;
    if (process == null && lastPid == null) return;
    if (process != null) {
      process.kill(ProcessSignal.sigkill);
      await process.exitCode.timeout(
        const Duration(seconds: 2),
        onTimeout: () => 0,
      );
    } else if (lastPid != null) {
      Process.run('kill', ['-9', '$lastPid'], runInShell: false);
    }
  }

  /// Kills any stale linux-wallpaperengine instances from previous sessions.
  Future<void> reapStaleInstances() async {
    final result = await Process.run('pgrep', ['-f', 'linux-wallpaperengine']);
    if (result.exitCode != 0) return;
    final pids = (result.stdout as String)
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty && int.tryParse(line) != null);
    for (final pid in pids) {
      await Process.run('kill', ['-9', pid]);
    }
  }

  List<String> _buildArgs(String id, LweSettings settings) {
    final args = <String>[
      // An output selector is mandatory: without one the engine renders into
      // a plain window instead of the wlr-layer-shell background layer.
      if (settings.screenRoot.isNotEmpty) ...[
        '--screen-root',
        settings.screenRoot,
      ],
      '--bg',
      id,
      '--fps',
      settings.fps.toString(),
    ];

    if (settings.silent) {
      args.add('--silent');
    } else {
      args.addAll(['--volume', settings.volume.toString()]);
    }

    if (settings.fullscreenPause) {
      if (settings.fullscreenPauseOnlyActive) {
        args.add('--fullscreen-pause-only-active');
      }
    } else {
      args.add('--no-fullscreen-pause');
    }

    if (settings.disableMouse) args.add('--disable-mouse');
    if (settings.disableParticles) args.add('--disable-particles');
    if (settings.disableParallax) args.add('--disable-parallax');
    if (!settings.audioProcessing) args.add('--no-audio-processing');
    if (!settings.automute) args.add('--noautomute');
    if (settings.layer != 'bottom') args.addAll(['--layer', settings.layer]);
    if (settings.scaling != 'default') {
      args.addAll(['--scaling', settings.scaling]);
    }

    return args;
  }
}

/// Settings for the wallpaper process.
class LweSettings {
  const LweSettings({
    this.silent = true,
    this.volume = 0,
    this.fps = 30,
    this.fullscreenPause = true,
    this.fullscreenPauseOnlyActive = false,
    this.disableMouse = false,
    this.disableParticles = false,
    this.disableParallax = false,
    this.audioProcessing = true,
    this.automute = true,
    this.layer = 'bottom',
    this.scaling = 'default',
    this.screenRoot = '',
  });

  final bool silent;
  final int volume;
  final int fps;
  final bool fullscreenPause;
  final bool fullscreenPauseOnlyActive;
  final bool disableMouse;
  final bool disableParticles;
  final bool disableParallax;
  final bool audioProcessing;
  final bool automute;
  final String layer;
  final String scaling;
  final String screenRoot;

  LweSettings copyWith({
    bool? silent,
    int? volume,
    int? fps,
    bool? fullscreenPause,
    bool? fullscreenPauseOnlyActive,
    bool? disableMouse,
    bool? disableParticles,
    bool? disableParallax,
    bool? audioProcessing,
    bool? automute,
    String? layer,
    String? scaling,
    String? screenRoot,
  }) {
    return LweSettings(
      silent: silent ?? this.silent,
      volume: volume ?? this.volume,
      fps: fps ?? this.fps,
      fullscreenPause: fullscreenPause ?? this.fullscreenPause,
      fullscreenPauseOnlyActive:
          fullscreenPauseOnlyActive ?? this.fullscreenPauseOnlyActive,
      disableMouse: disableMouse ?? this.disableMouse,
      disableParticles: disableParticles ?? this.disableParticles,
      disableParallax: disableParallax ?? this.disableParallax,
      audioProcessing: audioProcessing ?? this.audioProcessing,
      automute: automute ?? this.automute,
      layer: layer ?? this.layer,
      scaling: scaling ?? this.scaling,
      screenRoot: screenRoot ?? this.screenRoot,
    );
  }

  Map<String, dynamic> toJson() => {
    'silent': silent,
    'volume': volume,
    'fps': fps,
    'fullscreenPause': fullscreenPause,
    'fullscreenPauseOnlyActive': fullscreenPauseOnlyActive,
    'disableMouse': disableMouse,
    'disableParticles': disableParticles,
    'disableParallax': disableParallax,
    'audioProcessing': audioProcessing,
    'automute': automute,
    'layer': layer,
    'scaling': scaling,
    'screenRoot': screenRoot,
  };

  factory LweSettings.fromJson(Map<String, dynamic> json) => LweSettings(
    silent: json['silent'] as bool? ?? true,
    volume: json['volume'] as int? ?? 0,
    fps: json['fps'] as int? ?? 30,
    fullscreenPause: json['fullscreenPause'] as bool? ?? true,
    fullscreenPauseOnlyActive:
        json['fullscreenPauseOnlyActive'] as bool? ?? false,
    disableMouse: json['disableMouse'] as bool? ?? false,
    disableParticles: json['disableParticles'] as bool? ?? false,
    disableParallax: json['disableParallax'] as bool? ?? false,
    audioProcessing: json['audioProcessing'] as bool? ?? true,
    automute: json['automute'] as bool? ?? true,
    layer: json['layer'] as String? ?? 'bottom',
    scaling: json['scaling'] as String? ?? 'default',
    screenRoot: json['screenRoot'] as String? ?? '',
  );
}

/// Provider for the LweDriver.
final lweDriverProvider = Provider<LweDriver>((ref) {
  final home = Platform.environment['HOME'] ?? '/';
  return LweDriver(
    configPath: '$home/.config/denial-wallpaper-engine/config.json',
  );
});