# 与 denial 官方壁纸设置的集成方案

> 基于对 `wallpaper_controller.dart` 与 `wallpaper_selector_surface.dart` 的源码核查（2026-09-25）。

## 现状核查结论

denial 官方壁纸设置的来源列表是**硬编码**的：

```dart
// dart_shell/lib/src/wallpaper/state/wallpaper_controller.dart
final wallpaperSourcesProvider = Provider<List<WallpaperProvider>>((ref) {
  return <WallpaperProvider>[
    ref.watch(localWallpaperSourceProvider),      // 本地图片
    ref.watch(wallhavenWallpaperSourceProvider),  // Wallhaven 在线
  ];
});
```

且官方规范（`docs/CUSTOM_SHELLS.md`）明确要求第三方代码不得 import `lib/src`，
官方 `WallpaperResource` 目前只有 `asset:` / `file:` 静态图两种。因此：

**不改官方代码的前提下，动态壁纸无法直接出现在原版设置面板里。**

## 三条集成路径

### 路径 A：自定义外壳覆盖 Provider（现在就能用）

在自定义外壳的 `ProviderScope` 里覆盖 `wallpaperSourcesProvider`（公开 Riverpod
provider，属于可覆盖范围），把我们的来源注册进去：

```dart
ProviderScope(
  overrides: [
    // 原版两个来源 + 动态壁纸来源
    wallpaperSourcesProvider.overrideWith((ref) => [
      ref.watch(localWallpaperSourceProvider),
      ref.watch(wallhavenWallpaperSourceProvider),
      DynamicWallpaperSourceAdapter(...),  // plugin/lib/src/denial_source_adapter.dart
    ]),
  ],
  child: runDenialShell(...),
)
```

限制：面板里能看到动态壁纸的**预览图**，但点击后官方控制器只会设置静态资源。
真正的动态画布由本插件的 `DynamicWallpaperCanvas` 负责（两者可叠加）。等上游给
`WallpaperResource` 增加 dynamic 类型后即完全打通。

### 路径 B：给官方提 PR（推荐长期方案）

改动极小，核心是两处：

1. `wallpaper.dart` 的 `WallpaperResource` 增加 `dynamic:` kind：

```dart
enum WallpaperResourceKind { asset, file, dynamic }

static WallpaperResource? fromPersistenceValue(String value) {
  // ...现有 asset:/file: 分支...
  if (value.startsWith('dynamic:')) {
    return WallpaperResource._dynamic(path);
  }
  return null;
}
```

2. `wallpaper_controller.dart` 的 `wallpaperSourcesProvider` 增加来源扩展点：

```dart
final wallpaperSourcesProvider = Provider<List<WallpaperProvider>>((ref) {
  return [
    ref.watch(localWallpaperSourceProvider),
    ref.watch(wallhavenWallpaperSourceProvider),
    ...ref.watch(externalWallpaperSourcesProvider),  // 新增扩展点
  ];
});

final externalWallpaperSourcesProvider =
    Provider<List<WallpaperProvider>>((ref) => const []);
```

3. `shell_wallpaper.dart` 的 `WallpaperScene` 遇到 `dynamic` 资源时渲染
   `DynamicWallpaperLayer`（由本插件提供）。

这三处加起来不到 50 行，配合本插件已经写好的 `denial_source_adapter.dart`，
PR 接受后动态壁纸就会原生出现在官方选择器里。

### 路径 C：维持外部工具（现状兼容）

如果您继续用 `wp-random.sh` + linux-wallpaperengine 的组合，本插件不影响它，
两者共存。本插件自带的 `WallpaperRandomizer`（`wallpaper_randomizer.dart`）
就是 `wp-random.sh` 的原生替代：随机挑选 + 定时轮换 + 记忆当前选择，不再需要
cron 和 shell 脚本。

## 对应您当前工作流的迁移对照

| 现在的习惯 | 插件内的等价物 |
| --- | --- |
| `wp-random.sh` 随机选 | `WallpaperRandomizer.next()` |
| `~/.config/wallpaper_id` 记录 | `~/.local/share/denial/wallpapers/dynamic/.active` |
| cron/定时换壁纸 | `startRotation(interval: Duration(hours: 1))` |
| `--fps 30` 限帧 | manifest `options.playbackRate` / 后端限帧 |
| `--screen-root eDP-1` | denial 原生 output 配置 |

## 结论

- **能集成，但分两步**：现在走路径 A（自定义外壳覆盖），将来走路径 B（上游 PR，改动 < 50 行）
- denial 的 Riverpod 架构天然支持 provider 覆盖，这是它比传统 Linux DE 更适合插件化的地方
- 官方插件商店上线后，路径 B 的形态就是商店插件的标准形态
