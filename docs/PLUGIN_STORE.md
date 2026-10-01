# 未来适配指南（denial 插件商店上线后）

> 本文档写给「将来的自己」和「将来的老板」。
> 现在不用做任何事，等商店出来再打开这份文档。

---

## 一、当前状态快照

**代码状态**：整合完成，功能齐全，未实装。

**为什么未实装**：denial 处于快速开发期，内部 API 可能变动。
提前编译的外壳包需跟随更新反复重编，不划算。

**已就绪的部分**：

| 模块 | 文件 | 是否依赖 denial 内部 API |
| --- | --- | --- |
| 工坊发现 | `workshop_discovery.dart` | ❌ 纯 Dart IO |
| 进程驱动 | `lwe_driver.dart` | ❌ 纯 Dart IO |
| 状态持久化 | `lwe_controller.dart` | ❌ 纯 Dart IO |
| 随机轮换 | `lwe_randomizer.dart` | ❌ 纯 Dart IO |
| 启动恢复 | `lwe_bootstrap.dart` | ❌ 纯 Dart IO |
| 设置面板 UI | `lwe_settings_panel.dart` | ⚠️ 仅 Flutter + Riverpod |
| 外壳接线 | `example/custom_dynamic_shell.dart` | ✅ 用官方公开 API |

**关键优势**：除外壳接线外，所有模块都只依赖 Flutter 标准生态，
不碰 denial 内部实现。这意味着 denial 怎么改，核心逻辑都不用动。

---

## 二、商店上线后的适配步骤

### 步骤 1：对照官方插件规范

拿到官方插件规范后，逐项核对：

- [ ] 插件清单格式（预计需要 `author` / `license` / `screenshot` 字段）
- [ ] 打包格式（预计 `tar.zst` 或官方指定）
- [ ] 签名流程
- [ ] 目录结构约定
- [ ] 依赖声明方式（我们依赖 `denial_dart_shell`）

### 步骤 2：调整 pubspec.yaml

当前 `plugin/pubspec.yaml` 用 git 依赖：

```yaml
dependencies:
  denial_dart_shell:
    git:
      url: https://github.com/denialwm/denial.git
      path: dart_shell
```

商店版本可能需要改成官方发布的包名/版本约束。

### 步骤 3：检查外壳接线 API

打开 `example/custom_dynamic_shell.dart`，核对这两个 API 是否变了：

```dart
runDenialShell(shell: DenialShell(...))   // 进程引导
DenialShellScene(content: ...)            // 场景配置
```

如果变了，按官方 `docs/CUSTOM_SHELLS.md` 的最新写法调整。
**这是唯一可能需要改的地方**，其余模块不受影响。

### 步骤 4：接入设置面板入口

把 `LweSettingsPanel()` 挂到 denial 的设置界面里。
具体挂法取决于商店提供的注册机制。

### 步骤 5：打包提交

按官方格式打包 `plugin/` + `examples/`，签名后提交。

---

## 三、可能的变化与应对

### 情况 A：官方增加了「动态壁纸资源类型」

如果 denial 给 `WallpaperResource` 加了 dynamic 类型，
那么可以走 `docs/INTEGRATION.md` 里的路径 B，让动态壁纸
**原生出现在官方壁纸选择器里**（而不是独立面板）。

改动点：
1. `legacy_fallback/denial_source_adapter.dart` 已经写好了适配器
2. 按官方新接口微调（预计几行）

### 情况 B：官方提供了壁纸来源扩展点

如果 `wallpaperSourcesProvider` 开放了扩展注册，
直接把我们的来源注册进去即可，参考 `docs/INTEGRATION.md` 路径 A。

### 情况 C：官方 API 大改

只有外壳接线部分需要改（步骤 3）。
核心逻辑（发现/驱动/持久化/轮换）是纯 Dart，不受影响。

---

## 四、降级方案（legacy_fallback/）

`legacy_fallback/` 里是早期写的**自研渲染后端**：

- `backends/video_backend.dart` - media_kit 视频
- `backends/gif_backend.dart` - GIF/动图
- `backends/web_backend.dart` - 网页（需宿主提供 WebView）

**用途**：在没装 linux-wallpaperengine 的机器上作为兜底。

**注意**：这些后端**不支持 Scene 壁纸**，能力远弱于
linux-wallpaperengine。默认路径应该是 LWE 集成，
降级后端只在检测不到 LWE 时启用。

---

## 五、CLI 工具的长期价值

`tools/denial-wp` 不是临时产物，它有长期价值：

1. **无 GUI 环境**（SSH、脚本、开机钩子）下管理壁纸
2. **与插件共用配置**，两边设置互通
3. **调试工具**：排查插件问题时用 CLI 对照验证
4. **给不用 denial 的用户**：任何 Linux 桌面都能用

建议保留并持续维护。

---

## 六、快速验证清单

适配完成后，按这个清单验证：

```bash
# 1. CLI 能列出壁纸
denial-wp list

# 2. 能应用壁纸
denial-wp set <id>

# 3. 设置能生效
denial-wp config fps 60

# 4. 插件面板能打开、能选壁纸、能改设置

# 5. 重启 denial 后壁纸自动恢复

# 6. 关闭 denial 后壁纸进程自动结束
pgrep -f linux-wallpaperengine   # 应该没有输出
```

---

## 七、给将来接手的人

**核心设计原则**（改动时请保持）：

1. **渲染交给 linux-wallpaperengine**，不要自研 Scene 引擎
2. **不 import denial 的 `lib/src`**，只用公开 API
3. **所有命令行参数必须从源码核实**，不要凭印象写
4. **配置格式保持兼容**，CLI 和插件共用

**代码风格**：

- 每个类都有文档注释说明用途
- 参数映射集中在 `LwePlaybackSettings.buildArgs()`
- 状态持久化集中在 `LweController`

**测试方式**：

- 模拟工坊目录 + 伪造 `linux-wallpaperengine` 二进制
- 断言实际收到的命令行参数
- 参考历史验证脚本的断言逻辑
