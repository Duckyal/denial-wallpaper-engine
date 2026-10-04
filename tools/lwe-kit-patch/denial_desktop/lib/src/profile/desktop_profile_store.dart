import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

class DesktopProfile {
  const DesktopProfile({this.displayName = '', this.avatar = ''});

  final String displayName;
  final String avatar;

  @override
  bool operator ==(Object other) =>
      other is DesktopProfile &&
      other.displayName == displayName &&
      other.avatar == avatar;

  @override
  int get hashCode => Object.hash(displayName, avatar);
}

/// Preferences owned by the reference desktop, shared with its Settings app.
/// The compositor's settings.json remains exclusively native-owned.
class DesktopProfileStore {
  DesktopProfileStore(this.directory);

  final Directory directory;
  File get _document => File('${directory.path}/profile.json');
  static final _avatarName = RegExp(r'^avatar-[0-9]+-[0-9]+\.png$');

  String? avatarPath(DesktopProfile profile) =>
      _avatarName.hasMatch(profile.avatar)
      ? '${directory.path}/${profile.avatar}'
      : null;

  Future<DesktopProfile> read() async {
    if (!await _document.exists()) return const DesktopProfile();
    try {
      if (await _document.length() > 65536) return const DesktopProfile();
      final value = jsonDecode(await _document.readAsString());
      if (value is! Map || value['schema'] != 1) return const DesktopProfile();
      final name = value['displayName'];
      final avatar = value['avatar'];
      return DesktopProfile(
        displayName: name is String && _validName(name) ? name.trim() : '',
        avatar: avatar is String && _avatarName.hasMatch(avatar) ? avatar : '',
      );
    } on FormatException {
      return const DesktopProfile();
    }
  }

  static bool _validName(String name) =>
      name.runes.length <= 200 && !RegExp(r'[\x00-\x1f\x7f]').hasMatch(name);

  Future<DesktopProfile> save({
    String? displayName,
    Uint8List? avatarPng,
    bool removeAvatar = false,
  }) async {
    final editedName = displayName?.trim();
    if (editedName != null && !_validName(editedName)) {
      throw const FormatException('Invalid display name');
    }
    if (avatarPng != null &&
        (avatarPng.isEmpty || avatarPng.length > 2 * 1024 * 1024)) {
      throw const FormatException('Invalid avatar size');
    }
    await directory.create(recursive: true);
    final current = await read();
    final name = editedName ?? current.displayName;
    final id = '${DateTime.now().microsecondsSinceEpoch}-$pid';
    var avatar = removeAvatar ? '' : current.avatar;
    File? image;
    final temporary = File('${directory.path}/profile-$id.tmp');
    try {
      if (avatarPng != null) {
        avatar = 'avatar-$id.png';
        image = File('${directory.path}/$avatar');
        await image.writeAsBytes(avatarPng, flush: true);
      }
      await temporary.writeAsString(
        jsonEncode({'schema': 1, 'displayName': name, 'avatar': avatar}),
        flush: true,
      );
      await temporary.rename(_document.path);
      // Immutable names avoid stale image caches in either process. Keep older
      // images available to any Settings preview that is still editing them.
      return DesktopProfile(displayName: name, avatar: avatar);
    } catch (_) {
      if (await temporary.exists()) await temporary.delete();
      if (image != null && await image.exists()) await image.delete();
      rethrow;
    }
  }

  Stream<DesktopProfile> watch() {
    late StreamController<DesktopProfile> controller;
    StreamSubscription<FileSystemEvent>? subscription;
    Timer? debounce;
    var closed = false;
    var generation = 0;
    Future<void> reload() async {
      final request = ++generation;
      try {
        final profile = await read();
        if (!closed && request == generation) controller.add(profile);
      } catch (error, stack) {
        if (!closed && request == generation) controller.addError(error, stack);
      }
    }

    controller = StreamController<DesktopProfile>(
      onListen: () async {
        try {
          await directory.create(recursive: true);
          if (closed) return;
          // Subscribe before the initial read to avoid missing a concurrent save.
          subscription = directory.watch().listen(
            (_) {
              debounce?.cancel();
              debounce = Timer(const Duration(milliseconds: 50), reload);
            },
            onError: (Object error, StackTrace stack) {
              if (!closed) controller.addError(error, stack);
            },
          );
          await reload();
        } catch (error, stack) {
          if (!closed) controller.addError(error, stack);
        }
      },
      onCancel: () async {
        closed = true;
        debounce?.cancel();
        await subscription?.cancel();
      },
    );
    return controller.stream.distinct();
  }
}
