# 崩溃与异常监控

项目预留了 Sentry 接入，用于收集导出包中的崩溃、GDScript / 引擎错误、平台与版本标签。

## 当前策略

- `autoload/crash_reporter.gd` 是 Native / 本地 Godot SDK 的轻量封装。没有安装官方 `addons/sentry` 或没有配置 DSN 时不会初始化，也不会影响本地开发和测试。
- Web / GitHub Pages 不使用 Sentry Godot GDExtension。Web 侧通过 `tools/configure_sentry_web.py` 在导出后的 `index.html` 注入 Sentry Browser SDK，并挂接 Godot `onPrintError`。
- 官方 Sentry Godot addon 体积较大，不提交到仓库；需要验证 Native SDK 时可通过 `tools/install_sentry_godot.py` 本地安装。
- 默认不发送 PII，不附带截图，不采集局部变量；Web 侧会发送 JS 异常、unhandled rejection 和 Godot `printErr` 文本。
- Web 侧会过滤 Godot 退出阶段的资源释放噪声，例如 `leaked at exit`、`resources still in use at exit`、`ObjectDB instances leaked at exit` 和 `PagedAllocator` 退出日志；这些日志保留在浏览器 console，不进入 Sentry issue。

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

CI 会在 Web 导出后执行：

```bash
python3 tools/configure_sentry_web.py \
  --html build/web/index.html \
  --dsn "$SENTRY_DSN" \
  --environment production \
  --release "wwl-adventure@$GITHUB_SHA"
```

Web 导出保持 `variant/extensions_support=false`。不要在 GitHub Pages 上启用 Sentry Godot GDExtension；它会让 Godot Web 进入动态链接模式，生成 `index.side.wasm` 并在 Pages 上卡在 `loadDylibs`。

如果本机残留了未提交的 `addons/sentry/`，Godot 可能仍会在本地 Web HTML 中写入 `gdextensionLibs` 和 `libsentry.web*.wasm`。`configure_sentry_web.py` 会清掉这些 Sentry Godot addon 残留，CI 也会检查最终产物里没有 `.side.wasm` / `libsentry.web*.wasm`。

如果 `SENTRY_DSN` 未配置，Sentry 会保持关闭，构建继续通过。

## 运行时接口

Native / 本地 Godot SDK 可使用 `CrashReporter` 提供的少量游戏侧接口：

```gdscript
CrashReporter.add_breadcrumb("boss_spawned", "game", {"enemy": "boss_warlord"})
CrashReporter.capture_warning("unexpected empty upgrade options")
CrashReporter.capture_error("failed to load profile")
CrashReporter.set_tag("run_state", "battle")
```

自动采集的错误由对应平台的 Sentry SDK 负责；这些接口只用于补充业务上下文。Web 侧当前只能从 JS 与 Godot console error 进入 Sentry，GDScript 内主动调用 `CrashReporter.capture_*` 在 Web 上会保持 no-op。
