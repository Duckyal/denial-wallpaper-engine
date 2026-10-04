# denial-wallpaper-engine

把 **Wallpaper Engine** 的百万壁纸库接进 **denial** 桌面（Wayland 合成器）。

> **当前状态：已重构为 denial 官方插件格式。**
> 遵循 [denial-plugins](https://github.com/denialwm/denial-plugins) 规范。

---

## 一、这套东西做什么

```
┌──────────────────────────────────────────────┐
│  denial 壁纸管理面板（ShellSurface）          │
│  壁纸预览网格 · 声音 · 音量 · 帧率 · 缩放      │
│  轮换间隔 · 鼠标交互 · 全屏暂停                │
└────────────────┬─────────────────────────────┘
                 │  本插件（集成层）
                 │  · 自动发现工坊壁纸
                 │  · 设置持久化
                 │  · 随机/定时轮换
                 │  · 进程生命周期管理
                 ▼
┌──────────────────────────────────────────────┐
│  linux-wallpaperengine（渲染核心）             │
│  Scene / Video / Web 全类型支持                │
│  通过 wlr-layer-shell 贴到 bottom 层           │
└──────────────────────────────────────────────┘
```

**分工原则**：渲染交给成熟的 linux-wallpaperengine（4.6k stars，
真 3D Scene 引擎 + CEF + MPV），本插件只做集成层。

**关键设计**：denial 实现了 `zwlr_layer_shell_v1`，而
linux-wallpaperengine 默认 `--layer bottom`。所以壁纸是**独立进程自己
贴到 bottom 层**，denial 会把它合成在窗口后面——**不需要改合成器源码**。

---

## 二、特性

- **工坊自动发现**：扫描 Steam 各安装形态（原生 / Flatpak / Snap / 自定义库）
  的 `steamapps/workshop/content/431960`，自动列出已订阅壁纸
- **全类型支持**：Scene（真 3D）、Video、Web，由渲染核心负责
- **播放控制**：声音开关、音量、帧率上限、全屏暂停（可选仅焦点窗口）、
  鼠标交互、粒子、视差、音量自动避让
- **缩放模式**：default / fit / fill / stretch
- **目标输出**：通过设置中的 `screenRoot` 指定输出名（对应 `--screen-root`），
  未指定时引擎会退化为普通窗口，因此生产环境建议显式配置
- **随机 / 定时轮换**：可选定间隔自动换壁纸，支持自定义轮换播放列表
- **设置持久化**：`~/.config/denial-wallpaper-engine/config.json`，
  外部改动会被监听并热应用到正在运行的渲染进程
- **开机自动恢复**：随 shell 挂载，自动拉起上次使用的壁纸

---

## 三、依赖

| 依赖 | 说明 |
| --- | --- |
| denial | 提供 `zwlr_layer_shell_v1` 与插件运行时的 Wayland 合成器 |
| linux-wallpaperengine | 渲染核心（AUR：`linux-wallpaperengine-git`），需在 `PATH` 中可执行 |
| Steam + Wallpaper Engine | 且至少订阅下载过一个创意工坊壁纸 |

---

## 四、项目结构

```
denial-wallpaper-engine/
├── plugins.yaml                     # 插件目录清单（供 Denial 发现本仓库）
├── AGENTS.md                        # 代理执行规则
├── README.md
├── LICENSE
├── docs/
│   ├── DEVELOPMENT.md              # 开发、校验、本地安装流程
│   ├── STARTUP.md                  # 开机自动生效链路说明
│   ├── INTEGRATION.md              # 与 denial 官方壁纸设置的集成方案
│   ├── COMPARISON.md               # 与 linux-wallpaperengine / WE 的能力对比
│   └── PLUGIN_STORE.md             # 插件商店上线后的适配指南
├── plugins/
│   └── denial_wallpaper_engine/     # 插件包（可独立发布的 Dart 包）
│       ├── pubspec.yaml            # 包清单 + denial_plugin 元数据
│       ├── pubspec_overrides.yaml.example  # 本地 SDK 覆盖示例
│       ├── README.md               # 插件自身的英文说明
│       ├── LICENSE
│       └── lib/
│           ├── denial_wallpaper_engine.dart  # @Plugin() 入口与 @Provides 声明
│           └── src/
│               ├── lwe_panel.dart            # 壁纸管理面板 UI
│               ├── lwe_panel_bus.dart        # 面板开/关/随机的跨组件事件总线
│               ├── lwe_controller.dart       # 状态 + 配置持久化 + 提交草稿
│               ├── lwe_driver.dart           # 渲染进程驱动（启停/命令行/清理）
│               ├── lwe_config_watcher.dart   # 外部改动的配置文件监听
│               ├── lwe_bootstrap.dart        # 启动时恢复上次壁纸
│               ├── lwe_debug.dart            # 日志开关
│               └── workshop_discovery.dart   # Steam 工坊自动发现
├── tools/
│   ├── we_importer.py              # 把工坊壁纸导入 denial 动态壁纸目录
│   ├── apply-desktop-patch.sh      # 应用 denial_desktop 集成补丁
│   ├── desktop-patch/              # 官方壁纸设置面板的补丁片段
│   ├── integration/                # 工作区集成脚本与 patch
│   └── lwe-kit-patch/              # 参考用的 denial_desktop 源码快照
├── examples/
│   └── ocean-waves/                # 示例动态壁纸
└── install.sh                      # 旧版手动安装脚本
```

---

## 五、安装

### 通过 Denial 的 Plugins 应用安装（推荐）

1. 运行 Plugins 应用
2. 点击右上角“添加插件 / Add Plugins”按钮
3. 复制粘贴本仓库地址
4. 点击“搜索插件 / Find plugins”按钮

### 通过 denial-plugins CLI

```sh
denial-plugins add https://github.com/Duckyal/linux-wallpaperengine-for-Denial.git
denial-plugins plan
denial-plugins build CANDIDATE_ID
denial-plugins activate CANDIDATE_ID
```

### 本地开发安装

在仓库根目录执行：

```sh
denial-plugins --local add "$PWD"
denial-plugins plan
denial-plugins build CANDIDATE_ID
denial-plugins activate CANDIDATE_ID
```

---

## 六、日常使用

### GUI 面板（推荐入口）

按 **Super + B** 打开 / 关闭壁纸管理面板。

该快捷键由插件在首次挂载时自动注册到 `denial_wallpaper_engine.togglePanel`；
若已在设置里绑定过其它键，会保留你的配置，也可以在 Denial 的键盘设置中自行改绑。

关闭面板的方式：

- 再按一次 **Super + B**
- 按 **Esc**
- 按系统原本的**关闭窗口**快捷键（如 Super + Q）：面板打开期间会临时借用该绑定，
  关闭后原样归还，插件异常退出时也会在下次启动时自动修复

面板内的调整先进草稿，点“应用参数”后一次性写入配置并热生效。

### Shell Actions

可在 Denial 的键盘设置里绑定：

| Action ID | 说明 |
| --- | --- |
| `denial_wallpaper_engine.togglePanel` | 打开 / 关闭管理面板 |
| `denial_wallpaper_engine.randomWallpaper` | 随机应用一个已安装的 Workshop 壁纸 |
| `denial_wallpaper_engine.closePanel` | 关闭面板（面板内部借用，不建议常驻绑定） |

### 配置文件

```json
// ~/.config/denial-wallpaper-engine/config.json
{
  "currentWallpaperId": "3421515583",
  "enabled": true,
  "rotationMinutes": 0,
  "playlist": [],
  "settings": {
    "silent": true,
    "volume": 0,
    "fps": 30,
    "scaling": "default",
    "fullscreenPause": true,
    "fullscreenPauseOnlyActive": false,
    "disableMouse": false,
    "disableParticles": false,
    "disableParallax": false,
    "audioProcessing": true,
    "automute": true,
    "layer": "bottom",
    "screenRoot": ""
  }
}
```

---

## 七、辅助工具

```sh
# 把工坊壁纸导入 denial 的动态壁纸目录
python3 tools/we_importer.py --workshop ~/.steam/steam/steamapps/workshop/content/431960 \
  --dest ~/.local/share/denial/wallpapers/dynamic

# 在 Settings > Appearance 页面挂上「动态壁纸」卡片（需要 CLI 工作区集成）
# 注意：每次 `denial-plugins prepare` 重建构建包后都需要重新执行
./tools/apply-desktop-patch.sh
```

---

## 八、开发

完整流程（prepare、本地 SDK 覆盖、`analyze --fatal-infos`、构建与激活）
见 [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md)。

```sh
cd plugins/denial_wallpaper_engine
"$DENIAL_PLUGIN_FLUTTER" pub get
"$DENIAL_PLUGIN_DART" format --output=none --set-exit-if-changed lib
"$DENIAL_PLUGIN_DART" analyze --fatal-infos lib
```

---

## 九、许可证

GPL-3.0-or-later
