# 崩溃与异常监控

项目预留了 Sentry Godot SDK 接入，用于收集导出包中的崩溃、GDScript / 引擎错误、平台与版本标签。

## 当前策略

- `autoload/crash_reporter.gd` 是轻量封装。没有安装官方 `addons/sentry` 或没有配置 DSN 时不会初始化，也不会影响本地开发和测试。
- 官方 Sentry Godot addon 体积较大，不提交到仓库；本地或 CI 通过 `tools/install_sentry_godot.py` 安装。
- Web 部署 CI 只有在仓库 Secret `SENTRY_DSN` 存在时才安装 SDK 并注入 DSN。
- 默认不发送 PII，不附带截图，不采集局部变量；会附带日志、场景 tag、平台、Godot 版本和游戏版本。

## 本地启用

1. 在 Sentry 创建 Godot 项目，复制 Project Settings > Client Keys (DSN) 中的 DSN。
2. 安装官方 addon：

```bash
python3 tools/install_sentry_godot.py
```

3. 配置当前导出 / 本地运行的 DSN：

```bash
SENTRY_DSN="https://..." /Applications/Godot.app/Contents/MacOS/Godot --path .
```

也可以把 DSN 写入本地未提交的 `export_presets.cfg` / `project.godot`，但不要把真实 DSN 提交到仓库。

## GitHub Pages 启用

在 GitHub 仓库设置中添加 Secret：

| Secret | 用途 |
|--------|------|
| `SENTRY_DSN` | Web 导出包运行时使用的 Sentry DSN |

CI 会在导出前执行：

```bash
python3 tools/install_sentry_godot.py
python3 tools/configure_sentry_project.py \
  --dsn "$SENTRY_DSN" \
  --environment production \
  --release "wwl-adventure@$GITHUB_SHA"
```

`configure_sentry_project.py` 会同时把临时 `export_presets.cfg` 的 `variant/extensions_support` 打开，因为 Sentry Godot 依赖 GDExtension。仓库内的基础 Web preset 仍保持关闭，未配置 `SENTRY_DSN` 时不会引入 Sentry addon，也不会额外开启 GDExtension。

如果 `SENTRY_DSN` 未配置，Sentry 会保持关闭，构建继续通过。

## 运行时接口

`CrashReporter` 提供少量游戏侧接口：

```gdscript
CrashReporter.add_breadcrumb("boss_spawned", "game", {"enemy": "boss_warlord"})
CrashReporter.capture_warning("unexpected empty upgrade options")
CrashReporter.capture_error("failed to load profile")
CrashReporter.set_tag("run_state", "battle")
```

自动采集的错误仍由 Sentry Godot addon 负责；这些接口只用于补充业务上下文。
