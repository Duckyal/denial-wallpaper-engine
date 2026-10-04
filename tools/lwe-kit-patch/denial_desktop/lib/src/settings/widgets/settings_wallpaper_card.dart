import 'dart:io';

import 'package:denial_flutter_sdk/materials.dart';
import 'package:flutter/material.dart';

import 'package:denial_flutter_sdk/localization.dart';
import 'package:denial_flutter_sdk/wallpaper.dart';

import 'settings_controls.dart';

class SettingsWallpaperCard extends StatelessWidget {
  const SettingsWallpaperCard({
    required this.wallpaper,
    required this.wallpaperApps,
    required this.outputName,
    required this.onChoose,
    required this.chooseKey,
    super.key,
  });

  final WallpaperResource wallpaper;

  /// Null is unknown; an empty list confirms no app-managed background.
  final List<String>? wallpaperApps;
  final String? outputName;
  final VoidCallback onChoose;
  final Key chooseKey;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final apps = wallpaperApps;
    final external = apps != null && apps.isNotEmpty;
    final appNames =
        apps?.where((name) => name.trim().isNotEmpty).join(', ') ?? '';
    final theme = Theme.of(context).textTheme;
    final secondary = theme.bodyMedium?.copyWith(
      color: context.applicationColors.secondary,
      height: 1.5,
    );
    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          external ? l10n.settingsWallpaperLive : l10n.settingsWallpaperApplied,
          style: theme.labelLarge,
        ),
        if (external) ...[
          const SizedBox(height: 6),
          Text(
            appNames.isNotEmpty ? appNames : l10n.settingsWallpaperLive,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
        if (external || apps != null) ...[
          const SizedBox(height: 8),
          Text(
            external
                ? l10n.settingsWallpaperLiveDescription
                : l10n.settingsWallpaperDescription,
            style: secondary,
          ),
        ],
        if (outputName != null) ...[
          const SizedBox(height: 8),
          Text(l10n.settingsWallpaperDisplay(outputName!), style: secondary),
        ],
        const SizedBox(height: 16),
        Row(
          children: [
            SettingsTextButton(
              label: '设置壁纸',
              onPressed: () async {
                final home = Platform.environment['HOME'];
                if (home == null) return;
                final dir = Directory('$home/.config/denial-wallpaper-engine');
                await dir.create(recursive: true);
                await File(
                  '$home/.config/denial-wallpaper-engine/panel-open',
                ).writeAsString(DateTime.now().toIso8601String());
              },
            ),
            const SizedBox(width: 8),
            SettingsTextButton(
              key: chooseKey,
              label: external
                  ? l10n.settingsWallpaperChooseFallback
                  : l10n.settingsWallpaperChoose,
              onPressed: onChoose,
            ),
          ],
        ),
      ],
    );
    return SettingsCardGroup(
      key: const ValueKey('appearance-wallpaper-card'),
      title: l10n.settingsWallpaperTitle,
      children: [
        SettingsCardPadding(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final stacked =
                  constraints.maxWidth <
                  600 * (MediaQuery.textScalerOf(context).scale(14) / 14);
              final previewWidth = stacked
                  ? constraints.maxWidth.clamp(0.0, 360.0)
                  : 240.0;
              final preview = SizedBox(
                width: previewWidth,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _WallpaperPreview(
                      wallpaper: wallpaper,
                      width: previewWidth,
                      label: external
                          ? l10n.settingsWallpaperFallback
                          : l10n.settingsWallpaperPreviewSemantics,
                    ),
                    if (external) ...[
                      const SizedBox(height: 8),
                      Text(
                        l10n.settingsWallpaperFallback,
                        style: theme.bodySmall?.copyWith(
                          color: context.applicationColors.secondary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              );
              if (stacked) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [preview, const SizedBox(height: 20), details],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  preview,
                  const SizedBox(width: 24),
                  Expanded(child: details),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _WallpaperPreview extends StatelessWidget {
  const _WallpaperPreview({
    required this.wallpaper,
    required this.width,
    required this.label,
  });
  final WallpaperResource wallpaper;
  final double width;
  final String label;

  @override
  Widget build(BuildContext context) {
    final radius = DenialSurfaceGeometry.borderRadiusOf(context);
    return Semantics(
      image: true,
      label: label,
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Container(
          foregroundDecoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(color: context.applicationColors.separator),
          ),
          child: ClipRRect(
            borderRadius: radius,
            child: Image(
              image: wallpaperImageProvider(
                wallpaper,
                targetPixelSize:
                    Size(width, width * 9 / 16) *
                    MediaQuery.devicePixelRatioOf(context),
              ),
              fit: BoxFit.cover,
              excludeFromSemantics: true,
              errorBuilder: (_, _, _) => ColoredBox(
                color: context.applicationColors.control,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      context.l10n.settingsWallpaperPreviewUnavailable,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: context.applicationColors.secondary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
