import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Discovers wallpapers from the Steam Workshop.
class WorkshopDiscovery {
  WorkshopDiscovery({this.customRoots = const []});

  /// Extra workshop roots to scan first (user configured).
  final List<String> customRoots;

  static const workshopAppId = '431960';

  /// Steam installation roots to probe, relative to $HOME.
  ///
  /// Covers the native install, the compatibility symlink Steam keeps, and the
  /// Flatpak and Snap sandboxes, which are entirely separate trees: a machine
  /// can have the native client and the Flatpak one side by side, each with its
  /// own workshop downloads, and scanning only ~/.steam and ~/.local/share
  /// silently misses whichever the user is not looking at.
  static const steamRootCandidates = <String>[
    '.local/share/Steam',
    '.steam/steam',
    '.steam/root',
    '.var/app/com.valvesoftware.Steam/.local/share/Steam',
    '.var/app/com.valvesoftware.Steam/.steam/steam',
    'snap/steam/common/.local/share/Steam',
    'snap/steam/common/.steam/steam',
  ];

  /// Every workshop content directory to scan, in priority order.
  ///
  /// Resolves to *all* of them rather than the first that exists. Two
  /// independent reasons, both of which used to be bugs here:
  ///
  ///  * A single machine can run several Steam clients (native plus Flatpak,
  ///    or Snap), each with its own workshop library.
  ///  * One client can have many libraries. `libraryfolders.vdf` lists them all,
  ///    and games on a second drive is the normal case, so stopping at the
  ///    first existing root hid every wallpaper the user had downloaded to it.
  Future<List<WorkshopWallpaper>> getWallpapers() async {
    final home = Platform.environment['HOME'] ?? '.';
    final roots = <String>[];
    final seen = <String>{};

    void add(String path) {
      // ~/.steam/steam is normally a symlink into ~/.local/share/Steam, so the
      // same tree arrives several times. Canonicalising collapses those.
      final key = _canonical(path);
      if (seen.add(key)) roots.add(path);
    }

    for (final custom in customRoots) {
      add('$custom/steamapps/workshop/content/$workshopAppId');
    }

    for (final candidate in steamRootCandidates) {
      final steamRoot = '$home/$candidate';
      if (!await Directory(steamRoot).exists()) continue;

      // The install root is itself a library.
      add('$steamRoot/steamapps/workshop/content/$workshopAppId');

      for (final library in await _libraryFolders(steamRoot)) {
        add('$library/steamapps/workshop/content/$workshopAppId');
      }
    }

    final existing = <String>[];
    for (final root in roots) {
      if (await Directory(root).exists()) existing.add(root);
    }
    return _scanWallpapers(existing);
  }

  Future<List<String>> _libraryFolders(String steamRoot) async {
    final file = File('$steamRoot/steamapps/libraryfolders.vdf');
    if (!await file.exists()) return const [];

    String text;
    try {
      text = await file.readAsString();
    } on FileSystemException {
      return const [];
    }

    final libraries = <String>[];
    final installPath = _canonical(steamRoot);

    // Current format: an explicit "path" key.
    for (final match in RegExp('"path"\\s+"([^"]*)"').allMatches(text)) {
      final path = match.group(1);
      if (path == null || path.isEmpty) continue;
      final canonical = _canonical(path);
      if (canonical == installPath) continue;
      libraries.add(path);
    }

    if (libraries.isEmpty) {
      // Legacy format: "1"  "/mnt/games/SteamLibrary" with no "path" key.
      for (final match in RegExp('"\\d+"\\s+(?:"([^"]*)")').allMatches(text)) {
        final path = match.group(1);
        if (path == null || path.isEmpty) continue;
        if (!path.startsWith('/')) continue;
        final canonical = _canonical(path);
        if (canonical == installPath) continue;
        libraries.add(path);
      }
    }
    return libraries;
  }

  static String _canonical(String path) {
    try {
      return File(path).resolveSymbolicLinksSync();
    } on FileSystemException {
      return path;
    }
  }

  Future<List<WorkshopWallpaper>> _scanWallpapers(List<String> roots) async {
    final result = <WorkshopWallpaper>[];
    final seenIds = <String>{};

    for (final root in roots) {
      await for (final entity in Directory(root).list(followLinks: false)) {
        if (entity is! Directory) continue;
        final wallpaper = await _inspect(entity);
        if (wallpaper == null) continue;
        if (!seenIds.add(wallpaper.id)) continue;
        result.add(wallpaper);
      }
    }
    result.sort(
      (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
    );
    return result;
  }

  Future<WorkshopWallpaper?> _inspect(Directory dir) async {
    final id = dir.path.split('/').last;
    final projectFile = File(dir.path + '/project.json');

    var title = id;
    var type = 'unknown';

    if (await projectFile.exists()) {
      try {
        final json = jsonDecode(
          await projectFile.readAsString(),
        ) as Map<String, dynamic>;
        final file = json['file'];
        if (file is String) {
          final lower = file.toLowerCase();
          if (lower.endsWith('.json') || lower.endsWith('.pkg')) {
            type = 'scene';
          } else if (lower.endsWith('.mp4') ||
              lower.endsWith('.webm') ||
              lower.endsWith('.mov') ||
              lower.endsWith('.avi') ||
              lower.endsWith('.m4v') ||
              lower.endsWith('.mkv')) {
            type = 'video';
          } else if (lower.endsWith('.html') || lower.endsWith('.htm')) {
            type = 'web';
          }
        }
        final titleJson = json['title'];
        if (titleJson is String && titleJson.trim().isNotEmpty) {
          title = titleJson.trim();
        }
      } on FormatException {
        // Keep defaults for broken project.json.
      }
    }

    // Preview art for the picker; any of the three engine-default names.
    String? preview;
    for (final name in const ['preview.jpg', 'preview.png', 'preview.gif']) {
      final candidate = dir.path + '/' + name;
      if (File(candidate).existsSync()) {
        preview = candidate;
        break;
      }
    }

    return WorkshopWallpaper(
      id: id,
      title: title,
      type: type,
      path: dir.path,
      preview: preview,
    );
  }
}

/// Cached list of installed workshop wallpapers for picker UIs.
final lweWallpapersProvider = FutureProvider<List<WorkshopWallpaper>>(
  (ref) => ref.watch(workshopDiscoveryProvider).getWallpapers(),
);

/// A discovered workshop wallpaper.
class WorkshopWallpaper {
  const WorkshopWallpaper({
    required this.id,
    required this.title,
    required this.type,
    required this.path,
    this.preview,
  });

  final String id;
  final String title;
  final String type;
  final String path;

  /// Absolute path of preview.jpg/png/gif, or null when the item ships none.
  final String? preview;
}

final workshopDiscoveryProvider = Provider<WorkshopDiscovery>(
  (ref) => WorkshopDiscovery(),
);
