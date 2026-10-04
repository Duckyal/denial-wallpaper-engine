import 'package:denial_flutter_sdk/materials.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:denial_flutter_sdk/localization.dart';
import 'package:denial_flutter_sdk/settings.dart';

import '../settings/settings_standalone_app.dart';
import 'welcome_components.dart';
import 'welcome_landing.dart';
import 'welcome_preferences.dart';
import 'welcome_shortcuts.dart';
import 'welcome_store.dart';
import 'welcome_support.dart';
import 'welcome_theme.dart';

/// Shares the synchronized settings/theme host, but has its own native app ID,
/// launcher entry, window, navigation, and persisted onboarding lifecycle.
class DenialWelcomeStandaloneApp extends StatelessWidget {
  const DenialWelcomeStandaloneApp({super.key});

  @override
  Widget build(BuildContext context) => DenialSettingsStandaloneApp(
    title: 'Welcome to Denial',
    applicationBuilder: (_) => const WelcomeApplication(),
  );
}

class WelcomeApplication extends ConsumerStatefulWidget {
  const WelcomeApplication({super.key});

  @override
  ConsumerState<WelcomeApplication> createState() => _WelcomeApplicationState();
}

class _WelcomeApplicationState extends ConsumerState<WelcomeApplication> {
  static const _channel = MethodChannel('denial/settings_activation');
  final _store = WelcomeStore();
  int _step = 0;
  bool _finishing = false;
  String? _error;

  Future<void> _finish() async {
    if (_finishing) return;
    setState(() {
      _finishing = true;
      _error = null;
    });
    try {
      await ref.read(shellSettingsProvider.notifier).flush();
      await _store.complete();
      await _channel.invokeMethod<void>('closeWindow');
    } on Object {
      if (mounted) setState(() => _error = context.l10n.welcomeSaveError);
    } finally {
      if (mounted) setState(() => _finishing = false);
    }
  }

  Future<void> _exitSetup() async {
    final l10n = context.l10n;
    final exit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.welcomeExitSetup),
        content: Text(l10n.welcomeExitMessage),
        actions: [
          OutlinedButton(
            autofocus: true,
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.welcomeCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.welcomeExit),
          ),
        ],
      ),
    );
    if (exit == true && mounted) await _finish();
  }

  Future<void> _openUrl(String url) async {
    try {
      await _channel.invokeMethod<void>('openUrl', url);
    } on Object {
      if (mounted) setState(() => _error = context.l10n.welcomeLinkError);
    }
  }

  void _goTo(int step) => setState(() {
    _step = step;
    _error = null;
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final step = _step;
    final scale = MediaQuery.textScalerOf(context);
    final commandClearance = scale.scale(40) + 56;
    final theme = welcomeTheme(context);
    return Theme(
      data: theme,
      child: DefaultTextStyle(
        style: theme.textTheme.bodyMedium!,
        child: FocusTraversalGroup(
          child: SafeArea(
            child: Stack(
              fit: StackFit.expand,
              children: [
                DenialApplicationFrame(
                  horizontalNavigation: true,
                  navigation: DenialMaterial(
                    role: DenialMaterialRole.toolbar,
                    preserveGlassEffects: true,
                    floating: true,
                    inset: DenialApplicationFrame.defaultInset,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: WelcomeProgress(
                        labels: [
                          l10n.welcomeStart,
                          l10n.welcomeShortcuts,
                          l10n.welcomeLayout,
                          l10n.welcomeAppearance,
                          l10n.welcomeSupport,
                        ],
                        current: _step,
                      ),
                    ),
                  ),
                  toolbar: const SizedBox.shrink(),
                  content: DenialContentSwitcher(
                    contentKey: ValueKey(_step),
                    duration: MediaQuery.disableAnimationsOf(context)
                        ? Duration.zero
                        : const Duration(milliseconds: 160),
                    child: DenialContentPane(
                      key: ValueKey(_step),
                      sliversBuilder: (context, width) {
                        final inset = width < 560 ? 24.0 : 32.0;
                        final side = ((width - 1040) / 2).clamp(
                          inset,
                          double.infinity,
                        );
                        return [
                          SliverPadding(
                            padding: EdgeInsets.fromLTRB(
                              side,
                              28,
                              side,
                              commandClearance,
                            ),
                            sliver: SliverToBoxAdapter(
                              child: switch (step) {
                                0 => const WelcomeLanding(),
                                1 => const WelcomeShortcuts(),
                                2 => const WelcomeLayout(),
                                3 => const WelcomeAppearance(),
                                _ => WelcomeSupport(onOpenUrl: _openUrl),
                              },
                            ),
                          ),
                        ];
                      },
                    ),
                  ),
                ),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 16,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: DenialMaterial(
                            role: DenialMaterialRole.card,
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Semantics(
                                liveRegion: true,
                                child: Text(_error!),
                              ),
                            ),
                          ),
                        ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Flexible(
                            child: WelcomeCommand(
                              label: _step == 0
                                  ? l10n.welcomeExitSetup
                                  : l10n.welcomePrevious,
                              icon: _step == 0
                                  ? Icons.close_rounded
                                  : Icons.arrow_back_rounded,
                              onPressed: _finishing
                                  ? null
                                  : _step == 0
                                  ? _exitSetup
                                  : () => _goTo(_step - 1),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Flexible(
                            child: WelcomeCommand(
                              primary: true,
                              label: _step == 4
                                  ? l10n.welcomeFinish
                                  : _step == 0
                                  ? l10n.welcomeGetStarted
                                  : l10n.welcomeNext,
                              icon: _step == 4
                                  ? Icons.check_rounded
                                  : Icons.arrow_forward_rounded,
                              onPressed: _finishing
                                  ? null
                                  : _step == 4
                                  ? _finish
                                  : () => _goTo(_step + 1),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
