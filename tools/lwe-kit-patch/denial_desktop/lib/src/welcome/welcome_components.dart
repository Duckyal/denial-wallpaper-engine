import 'package:denial_flutter_sdk/materials.dart';
import 'package:flutter/material.dart';

import 'welcome_contrast.dart';

class WelcomeIntro extends StatelessWidget {
  const WelcomeIntro(this.title, this.description, {super.key});
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.headlineMedium
              ?.copyWith(fontWeight: FontWeight.w600, letterSpacing: -.6),
        ),
        const SizedBox(height: 12),
        Text(
          description,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: context.applicationColors.secondary,
            height: 1.5,
          ),
        ),
      ],
    ),
  );
}

class WelcomeChoice extends StatelessWidget {
  const WelcomeChoice({
    required this.title,
    required this.selected,
    required this.onTap,
    required this.icon,
    this.description,
    super.key,
  });
  final String title;
  final String? description;
  final bool selected;
  final VoidCallback onTap;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    child: Card.outlined(
      color: context.applicationColors.raised,
      shape: RoundedRectangleBorder(
        borderRadius: DenialSurfaceGeometry.borderRadiusOf(context),
        side: BorderSide(
          color: selected
              ? Theme.of(context).colorScheme.primary
              : context.applicationColors.separator,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: DenialSurfaceGeometry.borderRadiusOf(context),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Icon(icon, size: 28),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    if (description != null) ...[
                      const SizedBox(height: 6),
                      Text(description!),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Icon(
                selected ? Icons.check_circle_rounded : Icons.circle_outlined,
                color: selected
                    ? Theme.of(context).colorScheme.primary
                    : context.applicationColors.secondary,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Opaque button fills guarantee readable labels over either the exposed
/// desktop or scrolling content. Commands have no glass wrapper.
class WelcomeCommand extends StatelessWidget {
  const WelcomeCommand({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.primary = false,
    super.key,
  });
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool primary;

  @override
  Widget build(BuildContext context) => FilledButton.icon(
    style: FilledButton.styleFrom(
      minimumSize: const Size(48, 48),
      backgroundColor: primary
          ? Theme.of(context).colorScheme.primary
          : context.applicationColors.control,
      foregroundColor: primary
          ? Theme.of(context).colorScheme.onPrimary
          : context.applicationColors.foreground,
      shape: RoundedRectangleBorder(
        borderRadius: DenialSurfaceGeometry.borderRadiusOf(context, inset: 16),
      ),
    ),
    onPressed: onPressed,
    icon: Icon(icon, size: 18),
    iconAlignment: primary ? IconAlignment.end : IconAlignment.start,
    label: Text(label, textAlign: TextAlign.center),
  );
}

class WelcomeProgress extends StatelessWidget {
  const WelcomeProgress({
    required this.labels,
    required this.current,
    super.key,
  });
  final List<String> labels;
  final int current;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final compact =
          constraints.maxWidth <
          620 * MediaQuery.textScalerOf(context).scale(14) / 14;
      return Row(
        children: [
          for (var index = 0; index < labels.length; index++) ...[
            if (index > 0)
              Expanded(
                child: Divider(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  indent: 8,
                  endIndent: 8,
                ),
              ),
            Semantics(
              label: '${index + 1} / ${labels.length}: ${labels[index]}',
              selected: index == current,
              child: ExcludeSemantics(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: index <= current
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest,
                      foregroundColor: index <= current
                          ? Color(
                              welcomeOnAccent(
                                Theme.of(context).colorScheme.primary
                                    .toARGB32(),
                              ),
                            )
                          : Theme.of(context).colorScheme.onSurface,
                      child: index < current
                          ? const Icon(Icons.check, size: 18)
                          : Text('${index + 1}'),
                    ),
                    if (!compact || index == current) ...[
                      const SizedBox(height: 6),
                      Text(labels[index]),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ],
      );
    },
  );
}
