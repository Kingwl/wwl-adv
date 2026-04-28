# 技术架构

## 整体结构

```text
WWL Adventure/
├── autoload/          # 全局单例
│   ├── game_state.gd       # 单局游戏状态（HP、经验、金币、时间、击杀等）
│   └── data_manager.gd     # 扫描 resources/ 下的 .tres 并提供查询
├── scenes/            # Godot 场景 (.tscn)
│   ├── game/
│   │   └── game.tscn       # 游戏主场景，协调所有子系统
│   ├── player/
│   │   └── player.tscn     # 玩家角色（CharacterBody2D）
│   ├── enemy/
│   │   ├── enemy.tscn      # 基础敌人（CharacterBody2D）
│   │   └── enemy_spawner.tscn
│   ├── weapons/            # 16 种武器、弹体、区域效果子场景
│   ├── drops/              # 经验球、金币
│   └── ui/                 # 主菜单、HUD、升级、暂停、结算、属性面板、摇杆、血条
├── scripts/
│   ├── data/          # Resource 类型：WeaponData、WeaponPath、EnemyData、UpgradeData 等
│   ├── player/
│   ├── enemy/
│   ├── weapon/        # WeaponBase
│   ├── weapons/       # 具体武器实现
│   ├── drops/
│   ├── game/          # Game、UpgradeSystem
│   └── ui/
└── resources/
    ├── weapons/       # 16 个武器 .tres 数据资源
    ├── enemies/       # 预留：敌人资源
    └── upgrades/      # 预留：外部升级资源
```

## 场景树（运行时）

```text
Game (Node2D)
├── Background (TextureRect)        # ground_tile 平铺背景
├── Enemies (Node2D)                # 敌人容器
├── Drops (Node2D)                  # 掉落物容器
├── Projectiles (Node2D)            # 弹体容器
├── Player (CharacterBody2D)        # 玩家
│   ├── CollisionShape2D
│   ├── AnimatedSprite2D            # idle / run / hit / death
│   ├── HealthBar                   # 头顶血条
│   ├── Camera2D                    # 跟随摄像机
│   └── Weapons (Node)              # 运行时创建，开局加入 WeaponMelee
├── EnemySpawner (Node)             # 敌人生成器
├── UpgradeSystem (Node)            # 升级逻辑
├── HUD (CanvasLayer)               # 游戏内状态
├── UpgradeSelect (CanvasLayer)     # 升级选择弹窗
├── VirtualJoystick (CanvasLayer)   # 移动端 / Web 摇杆
├── GameOver (CanvasLayer)          # 结算界面
├── PauseMenu (CanvasLayer)         # 暂停界面
└── StatsPanel (CanvasLayer)        # 属性 / 武器详情面板
```

## Autoload 单例

| 单例 | 职责 | 关键信号 |
|------|------|---------|
| `GameState` | 单局状态管理 | `run_started`, `run_ended`, `hp_changed`, `exp_changed`, `level_up`, `gold_changed` |
| `DataManager` | 扫描 `resources/weapons`、`resources/enemies`、`resources/upgrades` | 无 |

## 主信号流

```text
Enemy.take_damage()
  └── HP <= 0 → Enemy._die()
        ├── GameState.add_kill()
        ├── 生成 ExpOrb + GoldPickup 到 Drops
        └── 播放死亡动画后 queue_free()

ExpOrb / GoldPickup.body_entered(Player)
  ├── GameState.add_exp() / GameState.add_gold()
  └── HUD 监听 GameState 信号同步显示

GameState.add_exp()
  └── 经验满 → GameState.level_up
        └── UpgradeSystem._on_level_up()
              ├── get_tree().paused = true
              └── UpgradeSelect.show_options()
                    └── 玩家选择 → UpgradeSystem._apply_upgrade()
                          └── get_tree().paused = false

Enemy._physics_process()
  └── 碰撞 Player → Player.take_damage()
        └── GameState.take_damage()
              └── HP = 0 → GameState.run_ended
                    └── Game._on_run_ended()
                          ├── get_tree().paused = true
                          └── GameOver.show_stats()
```

## 碰撞层级

| Layer | 名称 | 用途 |
|-------|------|------|
| 1 | Player | 玩家物理体 |
| 2 | Enemy | 敌人物理体 |
| 3 | Projectile | 玩家弹体 |
| 4 | Drop | 经验球 / 金币（Area2D） |

碰撞掩码：

- Player: 与 Enemy 碰撞（layer 1 mask 2）
- Enemy: 与 Player + Projectile 碰撞（layer 2 mask 3）
- Projectile: 与 Enemy 碰撞（layer 3 mask 2）
- Drop: 与 Player 碰撞（layer 4 mask 1）

## 数据资源类

所有数据资源继承自 Godot `Resource`，使用 `@export` 暴露属性，便于在编辑器中维护 `.tres`。

| 类名 | 基类 | 用途 |
|------|------|------|
| `WeaponData` | Resource | 武器属性、分类、图标、等级上限、流派列表 |
| `WeaponPath` | Resource | 武器流派名称、描述、图标、每级效果 |
| `WeaponPathLevel` | Resource | 某一级的伤害 / 冷却 / 范围 bonus 和 `special_tag` |
| `EnemyData` | Resource | 敌人 HP、速度、伤害、掉落、生成权重 |
| `UpgradeData` | Resource | 升级选项类型、关联武器、bonus 数值 |
| `PlayerData` | Resource | 角色基础属性预留 |

当前状态：

- `resources/weapons/` 已有 16 个武器数据资源
- `resources/enemies/` 和 `resources/upgrades/` 目录存在，但当前核心敌人和大多数升级选项仍由代码提供
- `DataManager` 启动时会扫描上述目录，`UpgradeSystem` 会把外部升级资源加入候选池

## 武器系统

武器继承链：`Node` → `WeaponBase` → 具体武器脚本。

`WeaponBase` 提供：

- `level`：当前等级，默认 1
- `weapon_data: WeaponData`：基础数值和资源信息
- `current_path_id`：已选择的流派，选择后不可切换
- `_process(delta)`：默认冷却计时，自动调用 `_activate()`
- `level_up()`：检查 `max_level`，重算基础成长并应用当前流派效果
- `has_special_tag()` / `get_path_effect()`：供具体武器读取流派特殊效果

基础成长公式：

| 属性 | 公式 |
|------|------|
| 伤害 | `round(weapon_data.damage * (1.0 + (level - 1) * 0.10))` |
| 冷却 | `max(0.1, weapon_data.cooldown * pow(0.92, level - 1))` |
| 范围 | `weapon_data.range + (level - 1) * 10.0` |

升级来源：

- 解锁：`UpgradeData.WEAPON_UNLOCK` 实例化 `WEAPON_SCENES[weapon_id]`
- 强化：`UpgradeData.WEAPON_LEVEL` 调用 `level_up()` 并叠加 bonus
- 流派：`UpgradeData.WEAPON_PATH` 设置 `current_path_id` 后升到 2 级，并应用该流派 Lv.2 效果
- 属性：`UpgradeData.PLAYER_STAT` 修改玩家移速、HP、拾取范围等

## 敌人和掉落

- `EnemySpawner` 以玩家为中心，在可视区外的视口半对角线 + `80~300` 像素环形区域生成敌人
- 生成间隔随时间缩短，最低 0.3 秒
- 敌人 HP、伤害按 `1.0 + elapsed_time / 120.0` 缩放
- 敌人速度单独按 `1.0 + elapsed_time / 300.0` 缩放，并封顶到 `1.75x`
- 若 `resources/enemies/` 有可用 `EnemyData`，生成器会按 `spawn_weight` 加权选择
- 敌人死亡后生成经验球和金币，掉落物受玩家拾取范围 bonus 影响

## 输入系统

| 输入 | 桌面 | 移动端 / Web |
|------|------|--------------|
| 移动 | WASD / 方向键 | 虚拟摇杆（左半屏） |
| 属性面板 | `toggle_stats`（当前绑定 Tab） | HUD 上的“属性”按钮 |

Player._physics_process 中合并键盘和摇杆输入：

```gdscript
input_dir.x = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
input_dir.y = Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
input_dir += joystick.get_direction()
```

虚拟摇杆在 `OS.has_feature("android/ios/web")` 时自动显示，桌面端默认隐藏。
