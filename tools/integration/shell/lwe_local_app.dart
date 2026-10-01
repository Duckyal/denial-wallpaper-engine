// Hosts Denial's settings UI inside the shell, with the Wallpaper Engine panel
// embedded in the stock Appearance > Wallpaper section.
//
// Why in-shell instead of inside the packaged Settings application:
//
//   * /usr/lib/denial/settings is a pacman-owned bundle whose engine runs in
//     product mode, so it only accepts a release-mode AOT snapshot. The pinned
//     denial SDK ships only debug and profile engines, and the fork's release
//     engine artifacts are not published, so a matching release build of
//     settings_app cannot be produced on this machine.
//   * `settings_application.dart` and `settings_appearance_page.dart` live in
//     denial_dart_shell, which *is* rebuilt here. Registering the settings UI
//     as a local Flutter application under `inShellSettingsAppId` makes the
//     shell open it instead of the packaged binary, so nothing under /usr/lib
//     is replaced, `denialctl ui restore` reverts everything, and a denial
//     upgrade cannot clobber it.
//
// Running in the shell process also means the panel can drive the wallpaper
// immediately instead of waiting for the config watcher to poll.

import 'package:denial_dart_shell/denial.dart';
import 'package:denial_dynamic_wallpaper/denial_dynamic_wallpaper.dart';
import 'package:flutter/material.dart';

import 'src/settings/settings_application.dart'
    show DenialSettingsApplication, inShellSettingsAppId;
import 'src/settings/widgets/settings_navigation.dart' show SettingsPageId;
import 'lwe_translucent_theme.dart';

/// Denial's settings, with the Wallpaper Engine panel in the wallpaper entry.
final LocalFlutterApplication lweSettingsLocalApplication =
    LocalFlutterApplication(
      id: inShellSettingsAppId,
      title: 'Settings',
      localizedTitle: _title,
      categories: <String>['settings', 'wallpaper', 'dynamic wallpaper'],
      localizedCategories: _categories,
      icon: Icons.tune_rounded,
      defaultSize: const Size(1000, 800),
      minimumSize: const Size(680, 520),
      builder: _build,
    );

String _title(BuildContext context) {
  return Localizations.localeOf(context).languageCode == 'zh' ? '设置' : 'Settings';
}

List<String> _categories(BuildContext context) {
  return Localizations.localeOf(context).languageCode == 'zh'
      ? <String>['设置', '壁纸', '动态壁纸', '创意工坊']
      : <String>['settings', 'wallpaper', 'dynamic wallpaper', 'workshop'];
}

Widget _build(BuildContext context, LocalFlutterWindowHandle window) {
  return LweTranslucentTheme(
    child: DenialSettingsApplication(
      initialPage: SettingsPageId.appearance,
      wallpaperSectionExtra: const LweSettingsSection(),
    ),
  );
}
