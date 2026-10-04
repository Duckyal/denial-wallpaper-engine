import 'package:denial_flutter_sdk/materials.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:denial_flutter_sdk/localization.dart';
import 'package:denial_flutter_sdk/models.dart';
import 'package:denial_flutter_sdk/settings.dart';

import '../settings/widgets/settings_shortcut_presentation.dart';

import 'package:denial_flutter_sdk/state.dart';

import 'welcome_components.dart';

/// Preserve every configured alternative; never substitute defaults for a
/// binding the user removed or changed.
List<DenialShortcutBinding> welcomeBindings(
  DenialShortcutConfiguration configuration,
  DenialShortcutAction action,
) => configuration.shortcuts
    .where((binding) {
      final target = binding.target;
      return target is DenialShortcutActionTarget && target.action == action;
    })
    .toList(growable: false);

class WelcomeShortcuts extends ConsumerWidget {
  const WelcomeShortcuts({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final state = ref.watch(shortcutConfigurationProvider);
    final layout = ref.watch(shellSettingsProvider.select((s) => s.layout));
    final configuration = state.configuration;
    final desktop = <_ShortcutEntry>[
      (label: l10n.welcomeResize, bindings: [l10n.welcomeResizeGesture]),
      (label: l10n.welcomeMove, bindings: [l10n.welcomeMoveGesture]),
    ];
    _ShortcutEntry entry(DenialShortcutAction action) => (
      label: action == DenialShortcutAction.closeWindow
          ? l10n.welcomeKill
          : settingsShortcutActionLabel(context, action),
      bindings: [
        if (configuration != null)
          for (final binding in welcomeBindings(configuration, action))
            settingsShortcutDisplay(context, binding.shortcut),
      ],
    );
    if (configuration != null) {
      desktop.addAll(
        [
          DenialShortcutAction.closeWindow,
          DenialShortcutAction.minimizeWindow,
          DenialShortcutAction.openOverview,
          DenialShortcutAction.windowSwitcher,
          DenialShortcutAction.toggleMaximize,
          DenialShortcutAction.toggleFullscreen,
        ].map(entry),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        WelcomeIntro(l10n.welcomeIntro, l10n.welcomeShortcutsDescription),
        _ShortcutSection(title: l10n.welcomeDesktopUsage, entries: desktop),
        const SizedBox(height: 8),
        Text(
          l10n.welcomePointerHint,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        if (state.loading)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (state.error != null || configuration == null) ...[
          const SizedBox(height: 16),
          Text(l10n.welcomeShortcutsError),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: OutlinedButton(
              onPressed: () =>
                  ref.read(shortcutConfigurationProvider.notifier).refresh(),
              child: Text(l10n.welcomeRetry),
            ),
          ),
        ],
        if (configuration != null) ...[
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Divider(height: 1, thickness: 1),
          ),
          _ShortcutSection(
            title: l10n.welcomeWorkspaces,
            entries: [
              for (final action in [
                DenialShortcutAction.previousWorkspace,
                DenialShortcutAction.nextWorkspace,
                DenialShortcutAction.moveToPreviousWorkspace,
                DenialShortcutAction.moveToNextWorkspace,
                ...DenialShortcutAction.values.where(
                  (a) =>
                      a.workspaceNumber != null &&
                      a.workspaceNumber! <= layout.workspaceCount,
                ),
              ])
                entry(action),
            ],
          ),
          if (!layout.workspacesEnabled)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(l10n.welcomeWorkspaceDisabled),
            ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Divider(height: 1, thickness: 1),
          ),
          _ShortcutSection(
            title: l10n.welcomeTiling,
            entries: [
              for (final action in [
                DenialShortcutAction.resizeShrinkWidth,
                DenialShortcutAction.resizeGrowWidth,
                DenialShortcutAction.resizeShrinkHeight,
                DenialShortcutAction.resizeGrowHeight,
                DenialShortcutAction.swapLeft,
                DenialShortcutAction.swapRight,
                DenialShortcutAction.swapUp,
                DenialShortcutAction.swapDown,
                DenialShortcutAction.focusLeft,
                DenialShortcutAction.focusRight,
                DenialShortcutAction.focusUp,
                DenialShortcutAction.focusDown,
              ])
                entry(action),
            ],
          ),
        ],
      ],
    );
  }
}

typedef _ShortcutEntry = ({String label, List<String> bindings});

class _ShortcutSection extends StatelessWidget {
  const _ShortcutSection({required this.title, required this.entries});
  final String title;
  final List<_ShortcutEntry> entries;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Semantics(
        header: true,
        child: Text(title, style: Theme.of(context).textTheme.titleMedium),
      ),
      const SizedBox(height: 16),
      LayoutBuilder(
        builder: (context, constraints) {
          final twoColumns =
              constraints.maxWidth >=
              720 * MediaQuery.textScalerOf(context).scale(14) / 14;
          final width = twoColumns
              ? (constraints.maxWidth - 32) / 2
              : constraints.maxWidth;
          return Wrap(
            spacing: 32,
            runSpacing: 20,
            children: [
              for (final entry in entries)
                SizedBox(
                  width: width,
                  child: _ShortcutRow(entry: entry),
                ),
            ],
          );
        },
      ),
    ],
  );
}

class _ShortcutRow extends StatelessWidget {
  const _ShortcutRow({required this.entry});
  final _ShortcutEntry entry;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(entry.label, style: Theme.of(context).textTheme.bodyMedium),
      const SizedBox(height: 6),
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final binding in entry.bindings)
            DecoratedBox(
              decoration: BoxDecoration(
                color: context.applicationColors.control,
                borderRadius: DenialSurfaceGeometry.borderRadiusOf(context),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                child: Text(
                  binding,
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ),
            ),
          if (entry.bindings.isEmpty) Text(context.l10n.welcomeUnbound),
        ],
      ),
    ],
  );
}
