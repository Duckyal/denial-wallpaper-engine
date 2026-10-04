# denial-wallpaper-engine

把 **Wallpaper Engine** 的百万壁纸库接进 **denial** 桌面（Wayland 合成器）。

> **当前状态：已重构为 denial 官方插件格式。**
> 遵循 [denial-plugins](https://github.com/denialwm/denial-plugins) 规范。

---

## 一、这套东西做什么

```
┌──────────────────────────────────────────────┐
│  denial 设置面板（ShellAction）               │
│  壁纸预览网格 · 声音 · 音量 · 帧率 · 缩放      │
│  跨屏 · 鼠标交互 · 全屏暂停                    │
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

## 二、项目结构

```
denial-wallpaper-engine/
├── plugins.yaml                    # 插件目录清单
├── AGENTS.md                       # 代理执行规则
├── docs/
│   └── DEVELOPMENT.md             # 开发文档
├── plugins/
│   └── denial_wallpaper_engine/    # 插件包
│       ├── pubspec.yaml           # 包清单
│       ├── .gitignore
│       ├── .vscode/settings.json
│       └── lib/
│           ├── denial_wallpaper_engine.dart   # @Plugin() 导出
│           └── src/
│               ├── lwe_surface.dart           # @Provides(ShellSurface)
│               ├── lwe_actions.dart           # @Provides(ShellAction)
│               ├── lwe_driver.dart            # 进程驱动
│               ├── lwe_controller.dart        # 状态 + 配置持久化
│               ├── lwe_config_watcher.dart    # 配置监听
│               ├── lwe_randomizer.dart        # 随机/定时轮换
│               ├── lwe_bootstrap.dart         # 启动恢复
│               └── workshop_discovery.dart    # 工坊自动发现
├── tools/
│   └── denial-wp                    # CLI 工具
└── README.md
```

---

## 三、安装

### 通过 Denial 的 Plugins 应用安装：

- 运行 Plugins 应用
- 应用右上角点击“添加插件/Add Plugins”按钮
- 复制粘贴本项目链接
- 点击“搜索插件/Find plugins”按钮
- 
### 通过 denial-plugins CLI

```sh
denial-plugins --path plugins/denial_wallpaper_engine add https://github.com/denialwm/denial-plugins.git
denial-plugins plan
denial-plugins build CANDIDATE_ID
denial-plugins activate CANDIDATE_ID
```

### 本地开发

```sh
denial-plugins --local add "$PWD"
denial-plugins plan
denial-plugins build CANDIDATE_ID
denial-plugins activate CANDIDATE_ID
```

---

## 四、日常使用

### GUI 面板（推荐入口）

通过快捷键 **super+B** 打开面板

### CLI 工具

```bash
cp tools/denial-wp ~/.local/bin/
chmod +x ~/.local/bin/denial-wp

denial-wp list              # 列出所有工坊壁纸
denial-wp random            # 随机换壁纸
denial-wp config fps 60     # 改设置，立即生效
```

---

## 五、开发

详见 [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md)。

---

## 六、许可证

GPL-3.0-or-later
