import 'package:flutter/material.dart';

import 'package:denial_flutter_sdk/localization.dart';

import '../widgets/denial_wordmark.dart';
import 'welcome_components.dart';

class WelcomeLanding extends StatelessWidget {
  const WelcomeLanding({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 24),
        const Center(
          child: SizedBox(
            width: 240,
            child: AspectRatio(
              aspectRatio: denialWordmarkAspectRatio,
              child: DenialWordmark(semanticsLabel: 'Denial'),
            ),
          ),
        ),
        const SizedBox(height: 40),
        WelcomeIntro(l10n.welcomeTitle, l10n.welcomeStartDescription),
      ],
    );
  }
}
