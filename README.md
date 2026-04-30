# WWL Adventure

Godot 4.x 开发的 2D 俯视角实时生存 Roguelike，玩法方向参考 Vampire Survivors：玩家移动走位，武器自动攻击，击杀敌人掉落经验和金币，升级时进行三选一构筑。

目标平台：

- **Web** (HTML5 / WebAssembly)
- **Android**
- **iOS**

## 当前状态

项目已进入可玩的 MVP 阶段。打开 Godot 导入此目录后，按 <kbd>F5</kbd> 运行，主菜单点击“开始游戏”即可进入战斗。

已实现内容：

- 玩家移动、受击、死亡结算、相机跟随
- 4 个默认可选角色，支持不同初始属性、初始武器和轻量被动
- 基础追踪敌人和随时间增强的生成器
- 经验 / 金币掉落与拾取
- 升级三选一，支持角色强化、武器解锁、武器强化和武器流派
- 20 种武器，均有 `.tscn` 场景、`resources/weapons/*.tres` 数据资源和 3 条流派路径
- 角色强化与武器槽分离，生命源泉作为被动恢复强化
- 本地数值存档（累计金币、累计击杀、最佳成绩）
- HUD、暂停菜单、属性面板、升级选择、游戏结束界面、虚拟摇杆、1x / 2x 倍速切换
- 角色、敌人、武器特效、掉落物、UI 图标等美术资源接入
- Headless Godot 自动化集成测试

当前主要缺口：

- 仍只有 1 种基础敌人，敌人资源目录尚未内容化
- 没有音效系统
- 设置页与设置持久化仍未实现
- 移动端安全区、触屏细节和发布包体仍需打磨

## 快速启动

1. 使用 Godot 4.x 打开项目目录。
2. 按 <kbd>F5</kbd> 运行。
3. 在主菜单点击“开始游戏”。
4. 战斗中使用 WASD / 方向键移动；移动端 / Web 环境会显示虚拟摇杆。

## 测试

修改武器、升级、敌人、掉落或 UI 流程后，建议运行：

```bash
./tests/run_tests.sh
```

当前最近一次验证结果：`653 passed, 0 failed`。

## 目录结构

```text
.
├── project.godot              # Godot 项目配置，主场景指向主菜单
├── scenes/
│   ├── game/                  # 游戏主场景
│   ├── player/                # 玩家场景
│   ├── enemy/                 # 敌人和生成器
│   ├── weapons/               # 20 种武器及弹体/区域子场景
│   ├── drops/                 # 经验球、金币
│   └── ui/                    # 主菜单、HUD、升级、暂停、结算、属性面板等
├── scripts/
│   ├── game/                  # 游戏流程与升级系统
│   ├── player/                # 玩家控制、受击、动画
│   ├── enemy/                 # 敌人 AI、状态、掉落
│   ├── weapon/                # WeaponBase
│   ├── weapons/               # 具体武器逻辑
│   ├── drops/                 # 拾取物逻辑
│   ├── ui/                    # UI 行为
│   └── data/                  # WeaponData / EnemyData / UpgradeData 等资源类
├── autoload/                  # GameState、DataManager 等全局单例
├── resources/
│   ├── characters/            # 4 个角色 .tres 数据资源
│   ├── weapons/               # 20 个武器 .tres 数据资源
│   ├── enemies/               # 预留：敌人资源
│   └── upgrades/              # 预留：外部升级资源
├── assets/                    # 角色、敌人、武器、特效、UI 美术资源
├── tests/                     # 自动化集成测试
└── docs/                      # Agent、架构、设计、里程碑文档
```

## 核心数据类型

- `WeaponData` — 武器基础数值、分类、图标、流派列表
- `CharacterData` — 角色基础属性、初始武器和被动修正
- `WeaponPath` / `WeaponPathLevel` — 武器流派和每级效果
- `EnemyData` — 敌人 HP、速度、伤害、掉落、生成权重
- `UpgradeData` — 升级选项类型和 bonus 数值
- `PlayerData` — 玩家基础属性预留

`DataManager` 会扫描 `resources/characters/`、`resources/weapons/`、`resources/enemies/`、`resources/upgrades/` 下的 `.tres` 资源。当前角色和武器已经资源化；敌人与大部分升级选项仍主要由代码提供。

## 常用文档

- [`docs/agents.md`](./docs/agents.md) — Agent 协作入口、修改路径、测试规范
- [`docs/architecture.md`](./docs/architecture.md) — 场景树、信号流、碰撞层级、数据结构
- [`docs/game_design.md`](./docs/game_design.md) — 核心循环、数值、未来规划
- [`docs/save_system_design.md`](./docs/save_system_design.md) — 本地数值存档、schema 和测试计划
- [`docs/milestone.md`](./docs/milestone.md) — 已完成内容和待办

## 跨平台导出

### Web

1. 编辑器 → **Project → Export → Add → Web**
2. 首次需 **Manage Export Templates** 下载模板
3. 输出 `index.html` + `.wasm` + `.pck`
4. 命令行导出：

```bash
mkdir -p build/web
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --export-release Web build/web/index.html
```

5. GitHub Pages 自动部署：
   - `.github/workflows/deploy-web.yml` 会在 `main` push 或手动触发时下载 Godot 4.6.2、安装 export templates、运行集成测试、导出 `build/web` 并发布到 Pages。
   - 根目录 `export_presets.cfg` 不提交，CI 使用 `ci/export_presets.web.cfg` 生成 Web-only preset。
   - 仓库 Settings → Pages → Build and deployment → Source 需要选择 **GitHub Actions**。

6. Godot 4 Web 如启用多线程，需要部署服务设置：
   - `Cross-Origin-Opener-Policy: same-origin`
   - `Cross-Origin-Embedder-Policy: require-corp`

   当前 Web preset 关闭了 `variant/thread_support`，可以直接部署到 GitHub Pages。

### Android

1. 安装 JDK 17、Android Studio 和 Android SDK/NDK
2. 编辑器 → **Editor → Editor Settings → Export → Android** 填写 SDK/NDK/JDK 路径
3. **Project → Install Android Build Template**
4. **Project → Export → Add → Android** 配置 keystore
5. 输出 APK / AAB

### iOS

1. 需要 macOS + Xcode
2. 准备 Apple Developer Team、Bundle ID 与签名证书
3. 编辑器 → **Project → Export → Add → iOS** 配置 Team ID、Bundle Identifier、签名方式
4. 输出 Xcode 工程，再用 Xcode 真机打包或上架

## 后续 TODO

- [ ] 音效系统（攻击、受击、升级、背景音乐）
- [x] 本地数值存档（设计见 `docs/save_system_design.md`）
- [ ] 设置页与设置持久化
- [ ] 移动端适配（安全区、触屏细节、性能）
- [ ] 敌人数据资源文件化和更多敌人类型
- [ ] Boss 战、地图机制和更多关卡目标
- [ ] Web / Android / iOS 发布优化
