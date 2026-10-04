import 'package:denial_flutter_sdk/materials.dart';
import 'package:flutter/material.dart';

import 'package:denial_flutter_sdk/localization.dart';
import 'package:denial_flutter_sdk/glass_configuration.dart';

import 'settings_controls.dart';

/// Detailed effects inside the Appearance card's single advanced disclosure.
class SettingsGlassTuningControls extends StatelessWidget {
  const SettingsGlassTuningControls({
    required this.configuration,
    required this.onChanged,
    required this.opacityThreshold,
    required this.onOpacityThresholdChanged,
    super.key,
  });
  final ShellGlassConfiguration configuration;
  final ValueChanged<ShellGlassConfiguration> onChanged;
  final double opacityThreshold;
  final ValueChanged<double> onOpacityThresholdChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    String percent(double value) => l10n.settingsPercent((value * 100).round());
    String signedPercent(double value) {
      final amount = (value * 100).round();
      return '${amount > 0 ? '+' : ''}$amount%';
    }

    return FocusTraversalGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _EffectSectionHeading(l10n.settingsAppearanceColorEffects),
          const SizedBox(height: 16),
          SettingsSlider(
            label: l10n.settingsGlassSaturation,
            value: configuration.saturation,
            minimum: ShellGlassConfiguration.minimumSaturation,
            maximum: ShellGlassConfiguration.maximumSaturation,
            divisions: 150,
            valueLabel: percent(configuration.saturation),
            onChanged: (value) =>
                onChanged(configuration.copyWith(saturation: value)),
          ),
          const SizedBox(height: 12),
          SettingsSlider(
            label: l10n.settingsGlassAccentTint,
            value: configuration.tintStrength,
            minimum: ShellGlassConfiguration.minimumTintStrength,
            maximum: ShellGlassConfiguration.maximumTintStrength,
            divisions: 40,
            valueLabel: percent(configuration.tintStrength),
            onChanged: (value) =>
                onChanged(configuration.copyWith(tintStrength: value)),
          ),
          const SizedBox(height: 12),
          SettingsSlider(
            label: l10n.settingsGlassBrightness,
            value: configuration.brightness,
            minimum: ShellGlassConfiguration.minimumBrightness,
            maximum: ShellGlassConfiguration.maximumBrightness,
            divisions: 40,
            valueLabel: signedPercent(configuration.brightness),
            onChanged: (value) =>
                onChanged(configuration.copyWith(brightness: value)),
          ),
          const SizedBox(height: 20),
          Divider(color: context.applicationColors.separator),
          const SizedBox(height: 16),
          _EffectSectionHeading(l10n.settingsAppearanceOptics),
          const SizedBox(height: 16),
          SettingsSlider(
            label: l10n.settingsGlassThickness,
            value: configuration.thickness,
            minimum: ShellGlassConfiguration.minimumThickness,
            maximum: ShellGlassConfiguration.maximumThickness,
            divisions: 44,
            valueLabel: l10n.settingsPixels(configuration.thickness.round()),
            onChanged: (value) =>
                onChanged(configuration.copyWith(thickness: value)),
          ),
          const SizedBox(height: 12),
          SettingsSlider(
            label: l10n.settingsGlassRefraction,
            value: configuration.refraction,
            minimum: ShellGlassConfiguration.minimumRefraction,
            maximum: ShellGlassConfiguration.maximumRefraction,
            divisions: 100,
            valueLabel: percent(configuration.refraction),
            onChanged: (value) =>
                onChanged(configuration.copyWith(refraction: value)),
          ),
          const SizedBox(height: 12),
          SettingsSlider(
            label: l10n.settingsGlassDispersion,
            value: configuration.dispersion,
            minimum: ShellGlassConfiguration.minimumDispersion,
            maximum: ShellGlassConfiguration.maximumDispersion,
            divisions: 100,
            valueLabel: percent(configuration.dispersion),
            onChanged: (value) =>
                onChanged(configuration.copyWith(dispersion: value)),
          ),
          const SizedBox(height: 12),
          SettingsSlider(
            key: const ValueKey('settings-glass-bevelWidthScale'),
            label: l10n.settingsGlassBevelWidth,
            value: configuration.bevelWidthScale,
            minimum: ShellGlassConfiguration.minimumBevelWidthScale,
            maximum: ShellGlassConfiguration.maximumBevelWidthScale,
            divisions: 55,
            valueLabel: l10n.settingsPercent(
              (configuration.bevelWidthScale * 100).round(),
            ),
            onChanged: (value) =>
                onChanged(configuration.copyWith(bevelWidthScale: value)),
          ),
          const SizedBox(height: 12),
          SettingsSlider(
            key: const ValueKey('settings-glass-refractionDepthScale'),
            label: l10n.settingsGlassRefractionDepth,
            value: configuration.refractionDepthScale,
            minimum: ShellGlassConfiguration.minimumRefractionDepthScale,
            maximum: ShellGlassConfiguration.maximumRefractionDepthScale,
            divisions: 55,
            valueLabel: l10n.settingsPercent(
              (configuration.refractionDepthScale * 100).round(),
            ),
            onChanged: (value) =>
                onChanged(configuration.copyWith(refractionDepthScale: value)),
          ),
          const SizedBox(height: 20),
          Divider(color: context.applicationColors.separator),
          const SizedBox(height: 16),
          _EffectSectionHeading(l10n.settingsAppearanceLighting),
          const SizedBox(height: 16),
          SettingsSlider(
            label: l10n.settingsGlassLightAngle,
            value: configuration.lightAngle,
            minimum: ShellGlassConfiguration.minimumLightAngle,
            maximum: ShellGlassConfiguration.maximumLightAngle,
            divisions: 72,
            valueLabel: '${configuration.lightAngle.round()}°',
            onChanged: (value) =>
                onChanged(configuration.copyWith(lightAngle: value)),
          ),
          const SizedBox(height: 12),
          SettingsSlider(
            label: l10n.settingsGlassLightIntensity,
            value: configuration.lightIntensity,
            minimum: ShellGlassConfiguration.minimumLightIntensity,
            maximum: ShellGlassConfiguration.maximumLightIntensity,
            divisions: 150,
            valueLabel: percent(configuration.lightIntensity),
            onChanged: (value) =>
                onChanged(configuration.copyWith(lightIntensity: value)),
          ),
          const SizedBox(height: 12),
          SettingsSlider(
            label: l10n.settingsGlassEdgeStrength,
            value: configuration.edgeStrength,
            minimum: ShellGlassConfiguration.minimumEdgeStrength,
            maximum: ShellGlassConfiguration.maximumEdgeStrength,
            divisions: 150,
            valueLabel: percent(configuration.edgeStrength),
            onChanged: (value) =>
                onChanged(configuration.copyWith(edgeStrength: value)),
          ),
          const SizedBox(height: 12),
          SettingsSlider(
            key: const ValueKey('settings-glass-rimWidth'),
            label: l10n.settingsGlassRimWidth,
            value: configuration.rimWidth,
            minimum: ShellGlassConfiguration.minimumRimWidth,
            maximum: ShellGlassConfiguration.maximumRimWidth,
            divisions: 55,
            valueLabel: l10n.settingsGlassRimPixels(
              configuration.rimWidth.toStringAsFixed(1),
            ),
            onChanged: (value) =>
                onChanged(configuration.copyWith(rimWidth: value)),
          ),
          const SizedBox(height: 12),
          SettingsSlider(
            key: const ValueKey('settings-glass-rimFalloff'),
            label: l10n.settingsGlassRimFalloff,
            value: configuration.rimFalloff,
            minimum: ShellGlassConfiguration.minimumRimFalloff,
            maximum: ShellGlassConfiguration.maximumRimFalloff,
            divisions: 290,
            valueLabel: configuration.rimFalloff.toStringAsFixed(2),
            onChanged: (value) =>
                onChanged(configuration.copyWith(rimFalloff: value)),
          ),
          const SizedBox(height: 12),
          SettingsSlider(
            key: const ValueKey('settings-glass-oppositeLightStrength'),
            label: l10n.settingsGlassOppositeLight,
            value: configuration.oppositeLightStrength,
            minimum: ShellGlassConfiguration.minimumOppositeLightStrength,
            maximum: ShellGlassConfiguration.maximumOppositeLightStrength,
            divisions: 150,
            valueLabel: l10n.settingsPercent(
              (configuration.oppositeLightStrength * 100).round(),
            ),
            onChanged: (value) =>
                onChanged(configuration.copyWith(oppositeLightStrength: value)),
          ),
          const SizedBox(height: 20),
          Divider(color: context.applicationColors.separator),
          const SizedBox(height: 16),
          _EffectSectionHeading(l10n.settingsAppearanceRendering),
          const SizedBox(height: 16),
          SettingsSlider(
            label: l10n.settingsGlassQuality,
            value: configuration.quality,
            minimum: ShellGlassConfiguration.minimumQuality,
            maximum: ShellGlassConfiguration.maximumQuality,
            divisions: 3,
            valueLabel: percent(configuration.quality),
            onChanged: (value) =>
                onChanged(configuration.copyWith(quality: value)),
          ),
          const SizedBox(height: 12),
          SettingsSlider(
            key: const ValueKey('settings-backdrop-blur-opacity-threshold'),
            label: l10n.settingsBackdropBlurOpacityThreshold,
            value: opacityThreshold,
            minimum: 0,
            maximum: 1,
            divisions: 100,
            valueLabel: l10n.settingsPercent((opacityThreshold * 100).round()),
            onChanged: onOpacityThresholdChanged,
          ),
        ],
      ),
    );
  }
}

/// Section titles must read above the regular-weight labels of their sliders.
class _EffectSectionHeading extends StatelessWidget {
  const _EffectSectionHeading(this.title);

  final String title;

  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    child: Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
        color: context.applicationColors.foreground,
      ),
    ),
  );
}
