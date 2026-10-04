import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Discovers wallpapers from the Steam Workshop.
class WorkshopDiscovery {
  WorkshopDiscovery({this.customRoots = const []});

  final List<String> customRoots;

  static const workshopAppId = '431960';

  static const steamRootCandidates = <String>[
    '.local/share/Steam',
    '.steam/steam',
    '.steam/root',
    '.var/app/com.valvesoftware.Steam/.local/share/Steam',
    '.var/app/com.valvesoftware.Steam/.steam/steam',
    'snap/steam/common/.local/share/Steam',
    'snap/steam/common/.steam/steam',
  ];

  List<WorkshopWallpaper>? _cache;
  DateTime? _cacheTime;
  static const _cacheTtl = Duration(minutes: 5);

  Future<List<WorkshopWallpaper>> getWallpapers() async {
    if (_cache != null &&
        _cacheTime != null &&
        DateTime.now().difference(_cacheTime!) < _cacheTtl) {
      return _cache!;
    }
    final result = await _scan();
    _cache = result;
    _cacheTime = DateTime.now();
    return result;
  }

  Future<List<WorkshopWallpaper>> _scan() async {
    final home = Platform.environment['HOME'] ?? '.';
    final roots = <String>[];
    final seen = <String>{};

    void add(String path) {
      final key = _canonical(path);
      if (seen.add(key)) roots.add(path);
    }

    for (final custom in customRoots) {
      add('$custom/steamapps/workshop/content/$workshopAppId');
    }

    for (final candidate in steamRootCandidates) {
      final steamRoot = '$home/$candidate';
      if (!await Directory(steamRoot).exists()) continue;

      add('$steamRoot/steamapps/workshop/content/$workshopAppId');

      for (final library in await _libraryFolders(steamRoot)) {
        add('$library/steamapps/workshop/content/$workshopAppId');
      }
    }

    final existing = (await Future.wait(
      roots.map((r) => Directory(r).exists().then((e) => (r, e))),
    ))
        .where((p) => p.$2)
        .map((p) => p.$1)
        .toList();
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

    for (final match in RegExp('"path"\\s+"([^"]*)"').allMatches(text)) {
      final path = match.group(1);
      if (path == null || path.isEmpty) continue;
      final canonical = _canonical(path);
      if (canonical == installPath) continue;
      libraries.add(path);
    }

    if (libraries.isEmpty) {
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
      final entities = Directory(root).list(followLinks: false);
      final dirs = <Directory>[];
      await for (final entity in entities) {
        if (entity is Directory) dirs.add(entity);
      }
      final wallpapers = await Future.wait(dirs.map(_inspect));
      for (final wallpaper in wallpapers) {
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

    String? preview;
    for (final name in const ['preview.jpg', 'preview.png', 'preview.gif']) {
      final candidate = dir.path + '/' + name;
      if (await File(candidate).exists()) {
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

final lweWallpapersProvider = FutureProvider<List<WorkshopWallpaper>>(
  (ref) => ref.watch(workshopDiscoveryProvider).getWallpapers(),
);

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

  final String? preview;
}

final workshopDiscoveryProvider = Provider<WorkshopDiscovery>(
  (ref) => WorkshopDiscovery(),
);