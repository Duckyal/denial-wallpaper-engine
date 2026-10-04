import 'dart:math' as math;

import 'package:denial_flutter_sdk/localization.dart';
import 'package:denial_flutter_sdk/models.dart';
import 'package:denial_flutter_sdk/motion.dart';
import 'package:denial_flutter_sdk/rendering.dart';
import 'package:denial_flutter_sdk/settings.dart';
import 'package:denial_flutter_sdk/shell_theme.dart';
import 'package:denial_flutter_sdk/system_services.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/clipboard_tray.dart';
import '../widgets/shade/range_bar.dart';
import 'desktop_audio_device_dropdown.dart';

class DashboardMixer extends ConsumerStatefulWidget {
  const DashboardMixer({super.key});

  @override
  ConsumerState<DashboardMixer> createState() => _DashboardMixerState();
}

class _DashboardMixerState extends ConsumerState<DashboardMixer> {
  final _focusNode = FocusNode(debugLabel: 'Dashboard mixer toggle');
  bool _expanded = false;
  bool _focused = false;
  bool _hovered = false;

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _toggle() {
    _focusNode.requestFocus();
    if (!_expanded) ref.read(appAudioProvider.notifier).refresh();
    setState(() => _expanded = !_expanded);
  }

  @override
  Widget build(BuildContext context) {
    final scale = ref.watch(
      shellSettingsProvider.select((s) => s.animations.durationScale),
    );
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : Duration(milliseconds: (250 * scale).round());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          button: true,
          expanded: _expanded,
          label: context.l10n.desktopMixerTitle,
          child: FocusableActionDetector(
            focusNode: _focusNode,
            mouseCursor: ShellMouseCursors.link,
            onShowFocusHighlight: (value) => setState(() => _focused = value),
            onShowHoverHighlight: (value) => setState(() => _hovered = value),
            shortcuts: const {
              SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
              SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
            },
            actions: <Type, Action<Intent>>{
              ActivateIntent: CallbackAction<ActivateIntent>(
                onInvoke: (_) {
                  _toggle();
                  return null;
                },
              ),
            },
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _toggle,
              child: DashboardAudioExpansionButtonSurface(
                hovered: _hovered,
                focused: _focused,
                expanded: _expanded,
                child: Row(
                  children: [
                    Icon(
                      Icons.tune_rounded,
                      size: 18,
                      color: ShellTheme.of(context).accentPalette.primary,
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        context.l10n.desktopMixerTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.shellTheme.text.cardTitle.copyWith(
                          color: context.shellColors.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    AnimatedRotation(
                      turns: _expanded ? .5 : 0,
                      duration: duration,
                      child: Icon(
                        Icons.expand_more_rounded,
                        size: 19,
                        color: ShellTheme.of(context).accentPalette.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        AnimatedSize(
          duration: duration,
          curve: Motion.md3EmphasizedDecelerate,
          alignment: Alignment.topCenter,
          child: _expanded
              ? const DashboardAudioExpansionCard(
                  child: _DashboardMixerStreams(),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}

class _DashboardMixerStreams extends ConsumerWidget {
  const _DashboardMixerStreams();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appAudioProvider);
    final controller = ref.read(appAudioProvider.notifier);
    if (state.streams.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
        child: state.loading
            ? Center(
                child: SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: ShellTheme.of(context).accent,
                  ),
                ),
              )
            : Text(
                state.error == null
                    ? context.l10n.desktopNoApplicationAudio
                    : context.l10n.desktopApplicationAudioUnavailable,
                style: context.shellTheme.text.cardTitle.copyWith(
                  color: context.shellColors.textSecondary,
                ),
              ),
      );
    }
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 280),
      child: ListView.separated(
        primary: false,
        shrinkWrap: true,
        padding: const EdgeInsets.all(5),
        itemCount: state.streams.length,
        separatorBuilder: (_, _) => const SizedBox(height: 3),
        itemBuilder: (context, index) {
          final stream = state.streams[index];
          return _AppVolumeRow(
            key: ValueKey<int>(stream.id),
            stream: stream,
            onChanged: (value) => controller.setVolume(stream.id, value),
            onChangeEnd: (value) => controller.commitVolume(stream.id, value),
          );
        },
      ),
    );
  }
}

class _AppVolumeRow extends StatefulWidget {
  const _AppVolumeRow({
    super.key,
    required this.stream,
    required this.onChanged,
    required this.onChangeEnd,
  });

  final AppAudioStream stream;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;

  @override
  State<_AppVolumeRow> createState() => _AppVolumeRowState();
}

class _AppVolumeRowState extends State<_AppVolumeRow> {
  final FocusNode _focusNode = FocusNode(debugLabel: 'app-volume-slider');
  bool _focused = false;

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _adjust(double delta) {
    widget.onChangeEnd(
      (widget.stream.level + delta).clamp(0.0, 1.0).toDouble(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final percent = (widget.stream.level * 100).round();
    final accent = ShellTheme.of(context).accent;
    final l10n = context.l10n;
    return Focus(
      focusNode: _focusNode,
      onFocusChange: (focused) => setState(() => _focused = focused),
      onKeyEvent: (_, event) {
        if (event is! KeyDownEvent) {
          return KeyEventResult.ignored;
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowLeft ||
            event.logicalKey == LogicalKeyboardKey.arrowDown) {
          _adjust(-0.05);
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowRight ||
            event.logicalKey == LogicalKeyboardKey.arrowUp) {
          _adjust(0.05);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Semantics(
        slider: true,
        label: l10n.desktopVolumeForApplication(widget.stream.name),
        value: l10n.settingsPercent(percent),
        increasedValue: l10n.settingsPercent(math.min(100, percent + 5)),
        decreasedValue: l10n.settingsPercent(math.max(0, percent - 5)),
        onIncrease: () => _adjust(0.05),
        onDecrease: () => _adjust(-0.05),
        child: Listener(
          onPointerDown: (_) => _focusNode.requestFocus(),
          child: AnimatedContainer(
            duration: Motion.pill,
            curve: Motion.standard,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: context.shellTheme.borderRadius(8),
              border: Border.all(color: _focused ? accent : Colors.transparent),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.stream.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.shellTheme.text.cardTitle.copyWith(
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      context.l10n.percentCompact(percent),
                      style: context.shellTheme.text.cardTitle.copyWith(
                        color: context.shellColors.textSecondary,
                        fontSize: 12,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                RangeBar(
                  value: widget.stream.level,
                  activeColor: accent,
                  inactiveColor: context.shellColors.volumeTrack,
                  onChanged: widget.onChanged,
                  onChangeEnd: widget.onChangeEnd,
                  height: 30,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
