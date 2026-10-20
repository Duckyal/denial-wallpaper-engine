import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'lwe_debug.dart';

/// Update-check + install helper for the host `linux-wallpaperengine` binary.
///
/// The plugin only renders the wallpaper; the binary itself is installed by the
/// system (AUR/pkg, a distro package, or built from source). This module
/// detects that installation, compares against the latest upstream release, and
/// exposes everything the panel needs to show a "有更新" banner and run the
/// install. When no automated path exists it falls back to opening the GitHub
/// releases page so the user can update manually.
///
/// All shell-outs are best-effort: a failure yields [LweUpdateResult.error] or
/// [LweUpdateResult.unknown] instead of throwing, because the rest of the
/// panel must never break when the network or the package manager is absent.
class LweUpdater {
  const LweUpdater();

  /// The GitHub repo that ships the binary's source + releases.
  static const String releasesUrl =
      'https://github.com/linux-wallpaperengine/linux-wallpaperengine/releases';

  /// Resolves the binary and reports, in priority order, whether an update is
  /// available. Returns one of the [LweUpdateResult] subtypes.
  Future<LweUpdateResult> checkForUpdate() async {
    final binary = await which('linux-wallpaperengine');
    if (binary == null) {
      return const LweUpdateNotInstalled();
    }

    final localVersion = await _readLocalVersion(binary);
    final pkg = await _packageManager();
    final latest = await _queryLatestVersion(pkg, binary, localVersion);

    if (latest == null) {
      // We know the binary exists but could not resolve "latest" (offline,
      // unknown package manager, or a non-git build with no remote).
      return LweUpdateUnknown(localVersion: localVersion, packageManager: pkg);
    }

    final local = localVersion?.normalized;
    final remote = latest.normalized;
    if (local != null && local == remote) {
      return LweUpdateUpToDate(
        localVersion: localVersion!,
        latestVersion: latest,
        packageManager: pkg,
      );
    }
    if (local != null && !_isNewer(remote, local)) {
      // Local build looks newer than the channel we query (e.g. a -git build
      // ahead of the last tagged release); treat as up to date.
      return LweUpdateUpToDate(
        localVersion: localVersion!,
        latestVersion: latest,
        packageManager: pkg,
      );
    }
    return LweUpdateAvailable(
      localVersion: localVersion,
      latestVersion: latest,
      packageManager: pkg,
    );
  }

  /// Installs / upgrades the binary. Returns the shell result so the caller can
  /// show success or a detailed failure toast.
  Future<LweInstallResult> installUpdate() async {
    final pkg = await _packageManager();
    var command = pkg?.upgradeCommand ?? [];
    if (command.isEmpty) {
      return LweInstallResult(
        success: false,
        command: null,
        message: '没有可自动执行的更新命令，请在终端手动更新。',
      );
    }
    // Distro packages need root; AUR helpers escalate themselves, so only
    // prepend sudo for the distro-package path when not already root.
    if (pkg?.method == LweInstallMethod.distroPackage &&
        !_isRoot() &&
        command.first != 'sudo') {
      command = ['sudo', ...command];
    }
    try {
      lweLog('updater: running ${command.join(' ')}');
      final result = await Process.run(
        command.first,
        command.skip(1).toList(),
        runInShell: false,
      );
      final stdout = (result.stdout as String? ?? '').trim();
      final stderr = (result.stderr as String? ?? '').trim();
      final output = [stdout, stderr].where((s) => s.isNotEmpty).join('\n');
      final ok = result.exitCode == 0;
      return LweInstallResult(
        success: ok,
        command: command.join(' '),
        message: ok
            ? (output.isNotEmpty ? output : '更新完成。')
            : (output.isNotEmpty ? output : '更新失败（退出码 ${result.exitCode}）。'),
      );
    } on Object catch (error) {
      return LweInstallResult(
        success: false,
        command: command.join(' '),
        message: '执行更新失败：$error',
      );
    }
  }

  /// Opens the GitHub releases page in the user's default handler. Best-effort;
  /// returns false if no opener could run, in which case the caller should
  /// surface the URL some other way (e.g. copy it to the clipboard).
  Future<bool> openReleasesPage() async {
    for (final opener in const ['xdg-open', 'gnome-open', 'kde-open']) {
      final path = await which(opener);
      if (path == null) continue;
      try {
        final result = await Process.run(path, [releasesUrl]);
        if (result.exitCode == 0) return true;
      } on Object {
        // Try the next opener.
      }
    }
    return false;
  }

  /// Copies [text] to the clipboard via a variety of backends (best-effort).
  Future<bool> copyToClipboard(String text) async {
    // `wl-copy` takes the text as an argument; `xclip`/`xsel` read it from
    // stdin, so we `Process.start` and pipe the bytes for those.
    final candidates = const [
      ('wl-copy', ['__TEXT__']),
      ('xclip', ['-selection', 'clipboard', '-in']),
      ('xsel', ['--clipboard', '--input']),
    ];
    for (final (bin, baseArgs) in candidates) {
      final path = await which(bin);
      if (path == null) continue;
      try {
        if (bin == 'wl-copy') {
          final result = await Process.run(path, [text]);
          if (result.exitCode == 0) return true;
        } else {
          final process = await Process.start(path, baseArgs);
          process.stdin.write(text);
          await process.stdin.flush();
          await process.stdin.close();
          if (await process.exitCode == 0) return true;
        }
      } on Object {
        // Try the next backend.
      }
    }
    return false;
  }

  Future<LweVersion?> _readLocalVersion(String binary) async {
    try {
      final result = await Process.run(binary, ['--version']);
      if (result.exitCode != 0) return null;
      final text = (result.stdout as String? ?? '').trim();
      if (text.isEmpty) return null;
      return LweVersion.parse(text);
    } on Object {
      return null;
    }
  }

  /// Determines the installed package manager / install method.
  Future<LwePackageManager?> _packageManager() async {
    // 1. AUR helpers (arch-like, the most common install path for this binary).
    for (final helper in const ['yay', 'paru', 'aura', 'pikaur']) {
      final path = await which(helper);
      if (path != null) {
        return LwePackageManager(
          name: helper,
          upgradeCommand: [
            helper,
            '-S',
            '--noconfirm',
            'linux-wallpaperengine',
          ],
          method: LweInstallMethod.aurHelper,
        );
      }
    }

    // 2. A distro package (query the system DB for what owns the binary).
    final distro = await _distroPackage();
    if (distro != null) return distro;

    // 3. Built from source via the upstream install script: detect a recently
    //    installed binary under a known prefix and offer a rebuild/upgrade.
    final source = await _sourceBuild();
    if (source != null) return source;

    return null;
  }

  Future<LwePackageManager?> _distroPackage() async {
    // Debian/Ubuntu: dpkg -S <binary>
    final dpkg = await which('dpkg');
    if (dpkg != null) {
      final r = await Process.run(dpkg, ['-S', 'linux-wallpaperengine']);
      if (r.exitCode == 0) {
        final pkg = (r.stdout as String).split(':').first.trim();
        if (pkg.isNotEmpty) {
          final apt = await which('apt-get');
          if (apt != null) {
            return LwePackageManager(
              name: 'apt',
              packageName: pkg,
              upgradeCommand: [apt, 'install', '--yes', pkg],
              method: LweInstallMethod.distroPackage,
            );
          }
        }
      }
    }
    // Fedora/RHEL: rpm -qf <binary>
    final rpm = await which('rpm');
    if (rpm != null) {
      final r = await Process.run(rpm, ['-qf', 'linux-wallpaperengine']);
      if (r.exitCode == 0) {
        final pkg = (r.stdout as String).split('\n').first.trim();
        if (pkg.isNotEmpty) {
          final dnf = await which('dnf');
          if (dnf != null) {
            return LwePackageManager(
              name: 'dnf',
              packageName: pkg,
              upgradeCommand: [dnf, 'upgrade', '--assumeyes', pkg],
              method: LweInstallMethod.distroPackage,
            );
          }
        }
      }
    }
    return null;
  }

  Future<LwePackageManager?> _sourceBuild() async {
    final home = Platform.environment['HOME'] ?? '/';
    // The upstream install script drops the binary into a `bin` next to a
    // build dir named after the repo. If such a layout exists we assume a
    // source install and offer to re-run the upstream installer.
    final candidates = [
      '$home/.local/bin/linux-wallpaperengine',
      '/usr/local/bin/linux-wallpaperengine',
    ];
    for (final candidate in candidates) {
      if (await File(candidate).exists()) {
        // No clean automated rebuild we can safely run unattended; fall back
        // to the GitHub release page for a manual upgrade.
        return LwePackageManager(
          name: 'source',
          packageName: null,
          upgradeCommand: const [],
          method: LweInstallMethod.sourceBuild,
        );
      }
    }
    return null;
  }

  /// Resolves "latest" per how the binary was installed. Returns null when no
  /// automated comparison is possible (offline, unknown method, or a git build
  /// we can't meaningfully diff against a release tag).
  Future<LweVersion?> _queryLatestVersion(
    LwePackageManager? pkg,
    String binary,
    LweVersion? localVersion,
  ) async {
    // For a distro package or AUR helper we can ask the system what it WOULD
    // install; that respects enabled repos and is more accurate than a web
    // fetch.
    if (pkg != null && pkg.method == LweInstallMethod.distroPackage) {
      final latest = await _queryRepoLatest(pkg);
      if (latest != null) return latest;
    }

    // Source/git builds don't map to a release tag we can compare, so we don't
    // fabricate a version; the panel shows a "manual check" fallback instead.
    if (pkg != null && pkg.method == LweInstallMethod.sourceBuild) {
      return null;
    }

    // Fallback: query the GitHub releases API for the newest tag.
    return _queryGitHubLatest(localVersion);
  }

  Future<LweVersion?> _queryRepoLatest(LwePackageManager pkg) async {
    final pkgName = pkg.packageName;
    if (pkgName == null) return null;
    final apt = pkg.name == 'apt' ? await which('apt-get') : null;
    if (apt != null) {
      final r = await Process.run(apt, ['list', '--upgradable', pkgName]);
      // apt-get list prints "<pkg>/<suite> <ver> ..." for upgradable packages.
      final lines = (r.stdout as String? ?? '').split('\n');
      for (final line in lines) {
        if (!line.startsWith(pkgName)) continue;
        final m = RegExp(r'(\d+\.\d+\.\d+)').firstMatch(line);
        if (m != null) return LweVersion.parse(m.group(1)!);
      }
      return null;
    }
    final dnf = pkg.name == 'dnf' ? await which('dnf') : null;
    if (dnf != null) {
      final r = await Process.run(dnf, ['list', '--upgrades', pkgName]);
      final lines = (r.stdout as String? ?? '').split('\n');
      for (final line in lines) {
        if (!line.startsWith(pkgName)) continue;
        final parts = line.split(RegExp(r'\s+'));
        if (parts.length >= 2) {
          final v = RegExp(r'(\d+\.\d+\.\d+)').firstMatch(parts[1]);
          if (v != null) return LweVersion.parse(v.group(1)!);
        }
      }
      return null;
    }
    return null;
  }

  Future<LweVersion?> _queryGitHubLatest(LweVersion? localVersion) async {
    try {
      final http = await which('curl') ?? await which('wget');
      if (http == null) return null;
      final uri = Uri.parse(
        'https://api.github.com/repos/linux-wallpaperengine/'
        'linux-wallpaperengine/releases/latest',
      );
      late final ProcessResult result;
      if (http.endsWith('curl')) {
        result = await Process.run(http, [
          '-sSL',
          '--max-time',
          '10',
          uri.toString(),
        ]);
      } else {
        result = await Process.run(http, [
          '-qO-',
          '--timeout=10',
          uri.toString(),
        ]);
      }
      if (result.exitCode != 0) return null;
      final body = (result.stdout as String? ?? '').trim();
      if (body.isEmpty) return null;
      final json = jsonDecode(body) as Map<String, dynamic>;
      final tag = json['tag_name'] as String?;
      if (tag == null || tag.isEmpty) return null;
      // Tags are like "v2.0.0" or "2.0.0"; strip a leading "v".
      final cleaned = tag.startsWith('v') ? tag.substring(1) : tag;
      return LweVersion.parse(cleaned);
    } on Object {
      return null;
    }
  }

  /// True when [candidate] is strictly newer than [current] under a
  /// best-effort semver comparison. Non-numeric components compare as equal so
  /// a git-commit build (no dots) never reports a bogus update.
  static bool _isNewer(String candidate, String current) {
    final a = _parse(candidate);
    final b = _parse(current);
    for (var i = 0; i < 3; i++) {
      if (a[i] > b[i]) return true;
      if (a[i] < b[i]) return false;
    }
    return false;
  }

  static List<int> _parse(String v) {
    final nums = v.split('.').map((p) {
      final n = int.tryParse(RegExp(r'\d+').stringMatch(p) ?? '');
      return n ?? 0;
    }).toList();
    while (nums.length < 3) nums.add(0);
    return nums.take(3).toList();
  }
}

/// True when the current process runs as uid 0 (root).
///
/// Never shells out synchronously: the plugin's first frame must not be
/// blocked by a process spawn, so we only consult the environment here.
bool _isRoot() =>
    (Platform.environment['USER'] == 'root') ||
    (Platform.environment['EUID'] == '0');

/// Whether `linux-wallpaperengine` can be found in the PATH.
Future<String?> which(String command) async {
  if (command.contains('/')) {
    return await File(command).exists() ? command : null;
  }
  final path = Platform.environment['PATH'];
  if (path == null) return null;
  for (final dir in path.split(':')) {
    final candidate = '$dir/$command';
    if (await File(candidate).exists()) return candidate;
  }
  return null;
}

/// How the binary was installed, and the command that upgrades it.
class LwePackageManager {
  const LwePackageManager({
    required this.name,
    required this.method,
    required this.upgradeCommand,
    this.packageName,
  });

  final String name;
  final LweInstallMethod method;
  final List<String> upgradeCommand;
  final String? packageName;
}

enum LweInstallMethod { aurHelper, distroPackage, sourceBuild, none }

/// A best-effort normalized version string (semver-ish). We don't validate
/// strictly: any output line is accepted, and `.normalized` yields a comparable
/// "x.y.z" form.
class LweVersion {
  LweVersion(this.raw);

  final String raw;

  /// Parses whatever `--version` printed; keeps the raw text for display and
  /// derives a normalized "x.y.z" for comparison.
  factory LweVersion.parse(String text) {
    final match = RegExp(r'(\d+\.\d+(?:\.\d+)?)').firstMatch(text);
    final raw = match?.group(1) ?? text.trim();
    return LweVersion(raw);
  }

  String get normalized {
    final nums = raw.split('.').map((p) {
      final n = int.tryParse(RegExp(r'\d+').stringMatch(p) ?? '');
      return n ?? 0;
    }).toList();
    while (nums.length < 3) nums.add(0);
    return nums.take(3).join('.');
  }

  @override
  String toString() => raw;
}

/// Sealed-ish result of a single update check.
sealed class LweUpdateResult {
  const LweUpdateResult({this.localVersion, this.packageManager});

  final LweVersion? localVersion;
  final LwePackageManager? packageManager;

  bool get hasUpdate => false;
  bool get actionable => false;
}

class LweUpdateAvailable extends LweUpdateResult {
  const LweUpdateAvailable({
    super.localVersion,
    required this.latestVersion,
    super.packageManager,
  });

  final LweVersion latestVersion;

  @override
  bool get hasUpdate => true;

  /// An automated upgrade command exists (AUR helper / distro package).
  @override
  bool get actionable => packageManager?.upgradeCommand.isNotEmpty ?? false;
}

class LweUpdateUpToDate extends LweUpdateResult {
  const LweUpdateUpToDate({
    super.localVersion,
    required this.latestVersion,
    super.packageManager,
  });

  final LweVersion latestVersion;
}

class LweUpdateUnknown extends LweUpdateResult {
  const LweUpdateUnknown({super.localVersion, super.packageManager});
}

class LweUpdateNotInstalled extends LweUpdateResult {
  const LweUpdateNotInstalled();
}

/// Outcome of [LweUpdater.installUpdate].
class LweInstallResult {
  const LweInstallResult({
    required this.success,
    this.command,
    required this.message,
  });

  final bool success;
  final String? command;
  final String message;
}

final lweUpdaterProvider = Provider<LweUpdater>((ref) => const LweUpdater());
