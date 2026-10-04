import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:denial_flutter_sdk/localization.dart';
import 'package:denial_flutter_sdk/settings.dart';
import 'package:denial_flutter_sdk/glass_configuration.dart';

import 'welcome_components.dart';

class WelcomeLayout extends ConsumerWidget {
  const WelcomeLayout({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final layout = ref.watch(
      shellSettingsProvider.select((s) => s.layout.windowLayout),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        WelcomeIntro(l10n.welcomeLayoutTitle, l10n.welcomeInstant),
        for (final (value, title, description, icon) in [
          (
            DesktopWindowLayout.stacking,
            l10n.settingsWindowLayoutStacking,
            l10n.welcomeStackingDescription,
            Icons.filter_none_rounded,
          ),
          (
            DesktopWindowLayout.dwindle,
            l10n.settingsWindowLayoutDwindle,
            l10n.welcomeDwindleDescription,
            Icons.space_dashboard_outlined,
          ),
          (
            DesktopWindowLayout.scrolling,
            l10n.settingsWindowLayoutScrolling,
            l10n.welcomeScrollingDescription,
            Icons.view_carousel_outlined,
          ),
        ])
          WelcomeChoice(
            title: title,
            description: description,
            icon: icon,
            selected: value == layout,
            onTap: () => ref
                .read(shellSettingsProvider.notifier)
                .setDesktopWindowLayout(value),
          ),
      ],
    );
  }
}

class WelcomeAppearance extends ConsumerWidget {
  const WelcomeAppearance({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final appearance = ref.watch(
      shellSettingsProvider.select((s) => s.appearance),
    );
    final controller = ref.read(shellSettingsProvider.notifier);
    final light = appearance.transparencyMode == ShellTransparencyMode.glass
        ? appearance.glass.appearance == ShellGlassAppearance.light
        : appearance.colorSchemePreference ==
              DesktopColorSchemePreference.preferLight;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        WelcomeIntro(l10n.welcomeAppearanceTitle, l10n.welcomeInstant),
        Text(
          l10n.welcomeMaterial,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        for (final (mode, title, icon) in [
          (
            ShellTransparencyMode.glass,
            l10n.welcomeGlass,
            Icons.auto_awesome_outlined,
          ),
          (ShellTransparencyMode.blur, l10n.welcomeBlur, Icons.blur_on_rounded),
          (
            ShellTransparencyMode.off,
            l10n.welcomeNothing,
            Icons.crop_square_rounded,
          ),
        ])
          WelcomeChoice(
            title: title,
            selected: appearance.transparencyMode == mode,
            icon: icon,
            onTap: () => controller.setTransparencyMode(mode),
          ),
        const SizedBox(height: 24),
        Text(l10n.welcomeTheme, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        for (final (isLight, title, icon) in [
          (true, l10n.welcomeLight, Icons.light_mode_outlined),
          (false, l10n.welcomeDark, Icons.dark_mode_outlined),
        ])
          WelcomeChoice(
            title: title,
            selected: light == isLight,
            icon: icon,
            onTap: () {
              controller.setColorSchemePreference(
                isLight
                    ? DesktopColorSchemePreference.preferLight
                    : DesktopColorSchemePreference.preferDark,
              );
              controller.setGlassConfiguration(
                appearance.glass.copyWith(
                  appearance: isLight
                      ? ShellGlassAppearance.light
                      : ShellGlassAppearance.dark,
                ),
              );
            },
          ),
      ],
    );
  }
}
