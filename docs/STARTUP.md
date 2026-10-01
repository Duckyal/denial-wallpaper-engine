# 开机自动生效链路说明

> 直接回答：**不需要开机自启，不需要 cron，不需要 systemd 服务。**
> 但需要一次性接线（把插件挂进 denial 的外壳入口），之后永久自动生效。

## 一、完整开机链路

```
系统开机
   │
   ▼
系统会话启动 denial（denial-session / 登录会话，系统原有机制）
   │
   ▼
denial 启动 Flutter 外壳（runDenialShell）
   │
   ▼
外壳挂载插件（一次性接线，见下文）
   │
   ▼
插件读取 ~/.config/denial-wallpaper-engine/config.json
   │
   ▼
有 last activeId → 自动重新拉起 linux-wallpaperengine
   │
   ▼
壁纸显示（进程是 denial 的子进程）
```

**关键点**：壁纸进程是 denial 的**子进程**，denial 退出时它自动结束。
不需要任何额外的守护进程或自启配置。

## 二、为什么不需要开机自启

| 传统做法（wp-random.sh） | 本插件 |
| --- | --- |
| 在 `.bashrc` / `.xinitrc` / systemd user unit 里加启动项 | ❌ 不需要 |
| 用 cron 定时换壁纸 | ❌ 不需要（内置 Timer） |
| 脚本里 `sleep` 等 Wayland 就绪 | ❌ 不需要（denial 启动时 Wayland 必然就绪） |
| 手动管理进程存活 | ❌ 不需要（子进程随 denial 生命周期） |

## 三、需要的一次性接线

按 denial 官方 `docs/CUSTOM_SHELLS.md` 规范，第三方外壳通过
`runDenialShell` 的入口挂载。本插件已经把这个入口写好了，见
`example/custom_dynamic_shell.dart`。

接线内容就两件事：

1. **挂载壁纸画布**：`DynamicWallpaperCanvas()` 放进场景的 `content`；
2. **挂载启动恢复**：`_WallpaperStartup()` 放进同一个 Stack，它在
   `initState` 里调用 `ref.read(lweBootstrapProvider).restoreOnStartup()`。

```dart
class DynamicDesktopShell extends StatelessWidget {
  const DynamicDesktopShell({super.key});

  @override
  Widget build(BuildContext context) {
    return const Stack(
      fit: StackFit.expand,
      children: [
        DynamicWallpaperCanvas(),   // 壁纸画布
        _WallpaperStartup(),        // 启动时恢复上次壁纸
      ],
    );
  }
}
```

## 四、怎么让 denial 用这个外壳

有三种方式，按官方文档的信任边界选择：

### 方式 1：开发调试（最直接）

```bash
flutter run -t example/custom_dynamic_shell.dart
```

### 方式 2：构建替代外壳包（推荐，官方支持）

官方文档明确说明「An independently built replacement bundle remains trusted
session code」，即独立构建的外壳包属于受信任的会话代码：

```bash
flutter build linux -t example/custom_dynamic_shell.dart
# 产物替换 denial 的 dart_shell bundle
```

调试期间官方提供了回滚命令：`denialctl ui restore`。

### 方式 3：等官方插件商店（长期）

denial 负责人已表示后期会做插件商店。届时按商店规范打包上架，
用户一键安装即可，无需手动接线。本插件的架构（走公开 API、不碰 `lib/src`）
就是为这条路准备的，详见 `PLUGIN_STORE.md`。

## 五、设置面板怎么打开

接线完成后，在自定义外壳里把 `LweSettingsPanel()` 挂到设置入口即可：

```dart
Navigator.of(context).push(MaterialPageRoute(
  builder: (_) => const LweSettingsPanel(),
));
```

面板里可以选壁纸、调声音/音量/帧率/缩放/跨屏/鼠标/全屏暂停，
改动即时生效并持久化。

## 六、一句话总结

- **不用开机自启**：denial 启动 = 壁纸启动
- **不用 cron**：内置定时轮换
- **要一次性接线**：把插件挂进外壳入口（示例已写好）
- **接线后永久自动**：重启、注销、换壁纸都自动记忆和恢复
