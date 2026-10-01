import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:denial_wallpaper_engine/denial_wallpaper_engine.dart';

import 'settings_controls.dart';

/// Dynamic wallpaper (Wallpaper Engine) section for the Appearance page.
///
/// The card edits the same persisted state the shell-side panel manages:
/// rotation playlist, engine parameters (saved, not applied live), and a
/// shortcut that opens the full-screen panel in the shell via a trigger file.
class LweDynamicWallpaperCard extends ConsumerWidget {
  const LweDynamicWallpaperCard({super.key});

  Future<void> _openPanel() async {
    final file = panelTriggerFile();
    await file.parent.create(recursive: true);
    await file.writeAsString(DateTime.now().toIso8601String());
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(lweControllerProvider);

    return state.when(
      loading: () => const SettingsCardGroup(
        title: '动态壁纸 (Wallpaper Engine)',
        children: [
          SettingsCardPadding(
            child: Center(child: CircularProgressIndicator()),
          ),
        ],
      ),
      error: (error, _) => SettingsCardGroup(
        title: '动态壁纸 (Wallpaper Engine)',
        description: '读取配置失败：$error',
        children: const [SizedBox.shrink()],
      ),
      data: (state) => _buildStateful(context, ref, state),
    );
  }

  Widget _buildStateful(
    BuildContext context,
    WidgetRef ref,
    LweState state,
  ) {
    final settings = state.settings;
    final controller = ref.read(lweControllerProvider.notifier);
    final wallpapers = ref.watch(lweWallpapersProvider);
    final activeId = state.currentWallpaperId;

    return SettingsCardGroup(
      title: '动态壁纸 (Wallpaper Engine)',
      description: '由 linux-wallpaperengine 渲染 Workshop 动态壁纸，'
          '静态壁纸在其上层仍然生效。',
      children: [
        SettingsCardPadding(
          child: Row(
            children: [
              SettingsTextButton(label: '打开管理面板', onPressed: _openPanel),
              const SizedBox(width: 8),
              Text(
                state.enabled
                    ? (activeId != null ? '运行中' : '已启用（未选择壁纸）')
                    : '已停止',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
        SettingsCardPadding(
          child: SettingsToggle(
            label: '启用动态壁纸',
            description: state.enabled
                ? '登录后自动恢复并应用轮换'
                : '动态壁纸已停止，打开开关立即恢复',
            value: state.enabled,
            onChanged: (value) => controller.setEnabled(value),
          ),
        ),
        SettingsCardPadding(
          child: _WallpaperGrid(
            wallpapers: wallpapers,
            playlist: state.playlist,
            activeId: activeId,
            enabled: state.enabled,
            onToggle: controller.togglePlaylistItem,
          ),
        ),
        SettingsCardPadding(
          child: SettingsSlider(
            label: '轮换间隔',
            value: state.rotationMinutes.toDouble(),
            minimum: 0,
            maximum: 120,
            divisions: 24,
            valueLabel: state.rotationMinutes <= 0
                ? '关闭'
                : '${state.rotationMinutes} 分钟',
            onChanged: (value) =>
                controller.setRotationMinutes(value.round()),
          ),
        ),
        SettingsCardPadding(
          child: SettingsSlider(
            label: '帧率上限',
            value: settings.fps.toDouble(),
            minimum: 5,
            maximum: 120,
            divisions: 23,
            valueLabel: '${settings.fps} FPS',
            onChanged: (value) =>
                controller.updateSettings(settings.copyWith(fps: value.round())),
          ),
        ),
        SettingsCardPadding(
          child: SettingsToggle(
            label: '静音',
            description: '静音同时停用音频分析；关闭后可用音量控制',
            value: settings.silent,
            onChanged: (value) =>
                controller.updateSettings(settings.copyWith(silent: value)),
          ),
        ),
        if (!settings.silent)
          SettingsCardPadding(
            child: SettingsSlider(
              label: '音量',
              value: settings.volume.toDouble(),
              minimum: 0,
              maximum: 128,
              divisions: 32,
              valueLabel: '${settings.volume}',
              onChanged: (value) => controller.updateSettings(
                settings.copyWith(volume: value.round()),
              ),
            ),
          ),
        SettingsCardPadding(
          child: SettingsSelect<String>(
            label: '缩放模式',
            description: 'default 跟随引擎；fit 留边、fill 裁切、stretch 拉伸',
            value: settings.scaling,
            choices: const [
              SettingsChoice('default', 'default'),
              SettingsChoice('fit', 'fit'),
              SettingsChoice('fill', 'fill'),
              SettingsChoice('stretch', 'stretch'),
            ],
            onChanged: (value) =>
                controller.updateSettings(settings.copyWith(scaling: value)),
          ),
        ),
        SettingsCardPadding(
          child: SettingsToggle(
            label: '全屏时暂停',
            description: '前台应用全屏时暂停动态壁纸以节省资源',
            value: settings.fullscreenPause,
            onChanged: (value) =>
                controller.updateSettings(settings.copyWith(fullscreenPause: value)),
          ),
        ),
        SettingsCardPadding(
          child: SettingsToggle(
            label: '禁用鼠标交互',
            description: '阻止壁纸响应指针事件',
            value: settings.disableMouse,
            onChanged: (value) =>
                controller.updateSettings(settings.copyWith(disableMouse: value)),
          ),
        ),
        SettingsCardPadding(
          child: SettingsControlRow(
            label: '应用参数',
            description: '参数仅保存；点击后以当前参数重启壁纸进程',
            control: SettingsTextButton(
              label: '应用参数',
              onPressed: () => controller.applySettingsNow(),
            ),
          ),
        ),
      ],
    );
  }
}

class _WallpaperGrid extends ConsumerWidget {
  const _WallpaperGrid({
    required this.wallpapers,
    required this.playlist,
    required this.activeId,
    required this.enabled,
    required this.onToggle,
  });

  final AsyncValue<List<WorkshopWallpaper>> wallpapers;
  final List<String> playlist;
  final String? activeId;
  final bool enabled;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context);
    return wallpapers.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 18),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Text(
        '读取 Workshop 壁纸失败：$error',
        style: colors.textTheme.bodyMedium,
      ),
      data: (items) {
        if (items.isEmpty) {
          return Text(
            '未找到 Workshop 壁纸。请先在 Steam 的 Wallpaper Engine 创意工坊订阅并下载至少一个壁纸。',
            style: colors.textTheme.bodyMedium,
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                  '轮换列表（${playlist.length}/${items.length}）',
                  style: colors.textTheme.titleSmall,
                ),
                const SizedBox(width: 12),
                Text(
                  '单击勾选加入/移出轮换',
                  style: colors.textTheme.bodySmall?.copyWith(
                    color: colors.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                const minTile = 148.0;
                final columns =
                    (constraints.maxWidth / minTile).floor().clamp(2, 6);
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 16 / 11,
                  ),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final inPlaylist = playlist.contains(item.id);
                    final active = item.id == activeId;
                    return _WallpaperTile(
                      item: item,
                      inPlaylist: inPlaylist,
                      active: active,
                      enabled: enabled,
                      onTap: () => onToggle(item.id),
                    );
                  },
                );
              },
            ),
          ],
        );
      },
    );
  }
}

class _WallpaperTile extends StatelessWidget {
  const _WallpaperTile({
    required this.item,
    required this.inPlaylist,
    required this.active,
    required this.enabled,
    required this.onTap,
  });

  final WorkshopWallpaper item;
  final bool inPlaylist;
  final bool active;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final borderRadius = BorderRadius.circular(12);
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: InkWell(
        borderRadius: borderRadius,
        onTap: enabled ? onTap : null,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: borderRadius,
            border: Border.all(
              color: active
                  ? colors.primary
                  : inPlaylist
                  ? colors.primary.withValues(alpha: .55)
                  : colors.outlineVariant,
              width: active ? 2 : 1,
            ),
          ),
          child: ClipRRect(
            borderRadius: borderRadius,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (item.preview != null)
                  Image.file(
                    File(item.preview!),
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) =>
                        ColoredBox(color: colors.surfaceContainerHighest),
                  )
                else
                  ColoredBox(color: colors.surfaceContainerHighest),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          colors.surface.withValues(alpha: 0),
                          colors.surface.withValues(alpha: 0.92),
                        ],
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(8, 14, 8, 6),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelMedium,
                            ),
                          ),
                          if (inPlaylist)
                            Icon(
                              Icons.loop_rounded,
                              size: 13,
                              color: colors.primary,
                            ),
                          if (active) ...[
                            const SizedBox(width: 4),
                            Icon(
                              Icons.check_circle_rounded,
                              size: 14,
                              color: colors.primary,
                            ),
                          ],
                        ],
                      ),
                    ),
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
