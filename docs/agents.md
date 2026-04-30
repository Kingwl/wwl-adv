# WWL Adventure — Agent 引导文档

本文档面向 AI Agent（Claude / Cursor / Copilot 等），帮助快速理解项目上下文和常见修改路径。

## 快速定位

| 你想改什么 | 先看哪里 |
|-----------|---------|
| 玩家手感（移速、无敌时间、受击反馈） | `scripts/player/player.gd` |
| 敌人生成频率/波次曲线 | `scripts/enemy/enemy_spawner.gd` |
| 敌人属性（HP、速度、伤害、掉落） | `scripts/enemy/enemy.gd` + `scripts/data/enemy_data.gd` |
| 武器伤害/范围/冷却 | `scripts/weapons/weapon_*.gd` + `scripts/weapon/weapon_base.gd` |
| 新武器类型 | 参考 `scripts/weapons/weapon_melee.gd` 继承 `WeaponBase`，添加到 `scenes/weapons/` |
| 升级选项/效果 | `scripts/game/upgrade_system.gd` |
| 升级UI样式 | `scenes/ui/upgrade_select.tscn` + `scripts/ui/upgrade_select.gd` |
| HUD 显示内容 | `scripts/ui/hud.gd` + `scenes/ui/hud.tscn` |
| 输入映射 | `project.godot` `[input]` 段 |
| 碰撞层级 | `project.godot` `[layer_names]` 段 |
| 全局数值（初始HP、经验公式等） | `autoload/game_state.gd` |
| 本地数值存档 | `autoload/save_manager.gd` + `autoload/game_state.gd` + `scripts/game/game.gd` |
| 崩溃 / 异常监控 | `autoload/crash_reporter.gd` + `docs/monitoring.md` |
| 新数据资源（角色/武器/敌人/升级） | `scripts/data/character_data.gd` / `weapon_data.gd` / `enemy_data.gd` / `upgrade_data.gd` |
| UI 字体子集缺字 | `tools/subset_ui_font.py` + `.github/workflows/deploy-web.yml` |

## 项目基本事实

- **引擎**: Godot 4.x (GL Compatibility 渲染器；当前项目配置为 4.6，最近测试使用 4.6.2)
- **目标平台**: Web / Android / iOS
- **分辨率**: 720x1280，`canvas_items` 拉伸模式
- **视角**: 2D 俯视角
- **核心玩法**: 吸血鬼幸存者 like — 控制移动、自动攻击、击杀升级
- **当前武器数**: 20
- **当前角色数**: 4（全部默认可选，暂不做解锁）
- **当前角色强化槽**: 6（生命源泉为被动恢复强化，不占武器槽）
- **当前敌人数**: 8（小鬼 / 疾行者 / 蛮兵 / 突袭者 / 邪教射手 / 精英蛮兵 / 精英秘法师 / 北境督军 Boss，均来自 `resources/enemies/*.tres`，并配置动画条带）
- **输入**: 键盘 WASD/方向键 + 触屏虚拟摇杆
- **Web CI**: `.github/workflows/deploy-web.yml` 使用 Godot 4.6.2 导出并部署 GitHub Pages；CI preset 来自 `ci/export_presets.web.cfg`
- **字体子集**: CI 每次 Web 导出前都会下载完整 `NotoSansCJKsc-Regular.otf`，扫描 `project.godot` / `autoload` / `scripts` / `scenes` / `resources` 文本后重建 `assets/fonts/NotoSansCJKsc-WWL-Subset.otf`

## 添加新内容的标准流程

### 添加一种新武器

1. 在 `scripts/weapons/` 创建脚本，继承 `WeaponBase`
2. 实现 `_activate()` 方法定义攻击逻辑；持续型武器可重写 `_process()`
3. 在 `scenes/weapons/` 创建 `.tscn` 场景（根节点为 `Node`）
4. 在 `resources/weapons/` 创建对应 `WeaponData` `.tres`，填写图标、数值、分类、流派
5. 在 `scripts/game/upgrade_system.gd` 的 `WEAPON_SCENES` 注册 `weapon_id -> scene_path`
6. 在 `tests/auto_test.gd` 补充必要断言，并运行 `./tests/run_tests.sh`

### 添加一种新敌人

1. 在 `scripts/data/enemy_data.gd` 了解已有字段
2. 在 `resources/enemies/` 创建 `.tres` 资源文件
3. 通过 `behavior_id` 选择追踪 / 高速 / 肉盾 / 突袭 / 远程等轻量行为
4. 配置 `animation_sheet`、`animation_frame_size`、`animation_columns`，运行时会拆成 walk / hit / death 动画
5. 配置 `spawn_weight`、`min_spawn_time`、`max_spawn_time`、`pack_size`，生成器会自动按时间池和权重选择

### 添加一种升级选项

1. 简单角色强化可在 `scripts/game/upgrade_system.gd` 的 `_generate_options()` / helper 方法中创建 `UpgradeData`
2. 武器解锁和强化使用 `WEAPON_UNLOCK` / `WEAPON_LEVEL`，武器流派选择使用 `WEAPON_PATH`
3. 武器流派每级效果优先写入 `WeaponPathLevel`，由 `WeaponBase._apply_path_effects()` 应用
4. 角色强化使用 `PLAYER_STAT`，并在 `_apply_stat_upgrade()` 中处理新的属性类型
5. 也可以在 `resources/upgrades/` 放外部升级资源，`DataManager.all_upgrades()` 会被加入候选池

## 测试规范

### 武器相关改动必须同步更新测试

任何修改以下文件的变更，**必须同步更新测试并验证通过**：

- `scripts/weapon/weapon_base.gd` — 武器基类生命周期或属性计算
- `scripts/weapons/weapon_*.gd` — 任一具体武器的攻击逻辑
- `scripts/data/weapon_data.gd` — 武器数据字段增减
- `scripts/game/upgrade_system.gd` — 武器解锁/强化选项或效果
- `resources/weapons/*.tres` — 武器默认数值调整

**执行方式**：

```bash
./tests/run_tests.sh
```

CI 或自定义安装路径可通过 `GODOT_BIN=/path/to/godot ./tests/run_tests.sh` 指定 Godot 可执行文件。

测试必须全部通过（`0 failed`）才能视为完成。如果新行为未覆盖，在 `tests/auto_test.gd` 的对应 phase 中补充断言。

### 当前测试覆盖

- 场景加载验证（Player / HUD / UI 系统存在）
- 升级三选一（选项生成、UI 点击、效果生效、同轮去重、满级过滤）
- **每种武器的增加** — 遍历 `WEAPON_SCENES` 逐一解锁，验证 `weapon_data`、图标和初始等级
- **武器使用** — 运行多帧后验证所有武器基础数值、触发逻辑和持续型武器状态
- 武器流派系统（路径选择、等级上限、special_tag 效果）
- 敌人受伤、掉落、状态效果、碰撞伤害和生成器曲线
- 敌人数据资源、专属动画条带和运行时取帧
- 玩家移动、受击无敌、治疗、死亡结算
- 角色数据加载、主菜单角色选择、所选角色开局属性 / 初始武器 / 被动修正
- HUD、StatsPanel、暂停菜单、游戏结束界面同步
- 弹体穿透、射程销毁、环绕球、恢复和反伤等专项行为

## 已知限制

- 武器和敌人已经 `.tres` 资源化；通用升级资源仍待内容化
- 已有武器攻击音效系统；受击、拾取、升级、按钮和 BGM 仍待补
- 存档当前只保存局外数值，不保存或恢复战斗状态
- 移动端安全区、发布包体和真机性能仍待验证

## 项目进度记录

有重要进展（新增系统、完成阶段性目标、通过关键测试）时，**同步更新 `docs/milestone.md`**。

- 已完成项打 `[x]`，待完成项保持 `[ ]`
- 新增武器、敌人、UI 系统时，在对应分类下补充条目
- 测试覆盖率变化时，更新"统计"表格中的 passed / failed 数值

## 扩展阅读

- [architecture.md](./architecture.md) — 技术架构、场景树、信号流
- [game_design.md](./game_design.md) — 核心循环、数值设计、未来规划
- [milestone.md](./milestone.md) — 项目里程碑与待办事项
