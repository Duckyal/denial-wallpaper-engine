# 能力对比：本插件 vs linux-wallpaperengine vs Wallpaper Engine

> 本文档基于对两个项目**源码的直接核查**（非二手资料），核查时间 2026-09-25。

## 一、Wallpaper Engine 官方壁纸类型（共 4 类）

| 类型 | 说明 | 渲染方 |
| --- | --- | --- |
| **Video** | mp4/webm 等视频循环 | 视频解码器 |
| **Scene** | 2D/3D 实时场景，含粒子、着色器、脚本 | WE 自带引擎 |
| **Web** | HTML/CSS/JS，Chromium 内核 | 内嵌 Chromium |
| **Application** | 注入外部程序窗口 | 外部程序 |

## 二、linux-wallpaperengine 实际支持情况

**源码证据**（`Almamu/linux-wallpaperengine`，C++，4.6k stars，默认分支 `main`）：

```
src/WallpaperEngine/Render/Wallpapers/CScene.cpp   ← Scene 渲染器
src/WallpaperEngine/Render/Wallpapers/CVideo.cpp   ← Video 渲染器
src/WallpaperEngine/Render/Wallpapers/CWeb.cpp     ← Web 渲染器
src/WallpaperEngine/WebBrowser/CEF/*               ← 内嵌 CEF (Chromium)
src/WallpaperEngine/VideoPlayback/MPV/*            ← MPV 视频解码
src/WallpaperEngine/Render/Objects/CParticle.cpp   ← 粒子系统
src/WallpaperEngine/Render/Shaders/*               ← GLSL 着色器
src/WallpaperEngine/Scripting/*                    ← JS 脚本引擎
```

**结论：支持 Video / Scene / Web 三类，不支持 Application。**

关键技术点：
- 用 **wlr-layer-shell-unstable** 协议在 Wayland 上铺底（与 denial 同类协议）
- Scene 是**真·3D 重放**：GLSL 着色器 + 粒子 + 材质 + 脚本，不是静态帧
- Web 用**真 CEF**（Chromium Embedded Framework），不是简单 iframe

## 三、本插件（denial-wallpaper-engine）实际支持情况

**源码证据**（`plugin/lib/src/`）：

```
backends/video_backend.dart   ← media_kit (libmpv) 视频后端
backends/gif_backend.dart     ← Flutter 内置多帧解码（GIF/WebP）
backends/web_backend.dart     ← 本地 HTTP + WebView 宿主（抽象接口）
```

| 类型 | 本插件 | 说明 |
| --- | --- | --- |
| Video | ✅ 支持 | media_kit/libmpv，与 linux-wallpaperengine 同源解码器 |
| Web | ⚠️ 半支持 | 需要宿主提供 WebView 实现（`WebViewHost` 抽象接口），非自带 CEF |
| Scene | ❌ 不支持 | 无 3D 引擎、无 GLSL 着色器、无粒子系统 |
| Application | ❌ 不支持 | 无窗口注入机制 |
| 静态图/GIF | ✅ 支持 | Flutter 原生解码，linux-wallpaperengine 也支持 |

## 四、诚实对比表

| 维度 | linux-wallpaperengine | 本插件 |
| --- | --- | --- |
| **Scene 壁纸（最核心差距）** | ✅ 真 3D 重放 | ❌ 完全不支持 |
| Video 壁纸 | ✅ MPV | ✅ media_kit(libmpv) |
| Web 壁纸 | ✅ 完整 CEF | ⚠️ 需宿主提供 WebView |
| Application 壁纸 | ❌ | ❌ |
| 音频可视化 | ✅ PulseAudio + FFTW3 | ❌ |
| 鼠标交互 | ✅ 有输入驱动 | ❌ |
| 多显示器独立壁纸 | ✅ `--screen-root` | ⚠️ 依赖 denial 的 output 配置 |
| 壁纸属性调节 | ✅ `--list-properties` | ⚠️ 仅 manifest 基础项 |
| 全屏自动暂停 | ✅ X11/Wayland 检测器 | ❌ |
| **集成方式** | 独立进程 + layer-shell | **denial 内嵌 Flutter 组件** |
| **与 denial 的关系** | 外部工具，与 denial 无耦合 | **原生插件，走官方扩展点** |
| 未来插件商店 | 不适用 | ✅ 可直接上架 |
| 资源占用 | 独立进程 + 独立 GL 上下文 | 复用 denial 已有 GL 上下文，更省 |
| 工坊壁纸导入 | 直接读原格式 | ✅ 自带 `we_importer.py` 转换器 |

## 五、结论

**直说：在壁纸类型覆盖度上，linux-wallpaperengine 明显强于本插件**，尤其是 **Scene 类型**（占创意工坊相当大比例）本插件完全无法渲染。

本插件的差异化价值在于：
1. **原生集成**：作为 denial 的 Flutter 组件运行，共享 GL 上下文，无独立进程开销
2. **官方扩展点**：走 `docs/CUSTOM_SHELLS.md` 规范，未来可上架 denial 插件商店
3. **可扩展架构**：`WebViewHost` 抽象接口预留了接入完整 CEF 的位置

**推荐组合方案**：
- 日常 Video/Web/GIF 壁纸 → 用本插件（省资源、原生集成）
- Scene 壁纸 → 用 linux-wallpaperengine（目前唯一选择）
- 两者可共存，互不冲突

## 六、补齐 Scene 支持的可行路径（后续规划）

若要追平 Scene 支持，有两条路：

1. **移植方案**：把 linux-wallpaperengine 的 `CScene`/`CParticle`/`Shader` 模块
   通过 FFI 嵌入 Flutter，渲染到 `Texture` 后交给本插件显示。
   工作量大（C++ 引擎 + OpenGL 上下文共享），但效果最好。
2. **静态帧方案**：解析 `scene.pkg`（PKGV 容器 + LZ4），提取主纹理作为静态背景。
   参考 `elysia395/dsh-wallpaper-engine` 的做法，可覆盖约 80% 的摄影/插画类 Scene 壁纸，
   但**没有动态效果**，属于降级方案。
