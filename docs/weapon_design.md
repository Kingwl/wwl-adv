# 武器系统设计文档

> 策划侧的武器种类、效果、流派和组合进化蓝图见 [`weapon_system_blueprint.md`](./weapon_system_blueprint.md)。

## 概述

武器系统是 WWL Adventure 的核心战斗系统。所有武器统一继承 `WeaponBase`，由 `WeaponData` 数据资源驱动，通过升级系统解锁、强化和选择流派。

当前实现状态：

- 16 种武器
- 每种武器均有独立 `.tscn` 场景
- 每种武器均有 `resources/weapons/*.tres` 数据资源
- 每种武器默认等级上限 8
- 已接入 3 条流派路径和 `special_tag` 特殊效果机制

## 武器分类

| 分类 | 英文 | 定位 | 当前武器 |
|------|------|------|----------|
| 攻击 | DAMAGE | 主动输出、范围伤害、弹幕、陷阱 | 基础利刃、弓箭精通、天雷引、散弹枪、火焰瓶、圣光棱镜、毒液罐、地雷、激光笔、回旋镖、电磁链、锯片陷阱、火箭背包 |
| 防御 | DEFENSE | 自保、控制、反伤 | 护盾球、荆棘护甲、冰霜环 |
| 增益 | BUFF | 治疗 / 辅助 | 预留；生命源泉已迁移为角色强化 |

分类标签已在升级选择、暂停菜单、结算界面和 StatsPanel 中展示。

## 武器数据定义

`WeaponData` (`scripts/data/weapon_data.gd`) 定义武器基础属性：

```gdscript
enum WeaponType { MELEE, PROJECTILE, AREA }
enum Category { DAMAGE, DEFENSE, BUFF }

@export var id: StringName
@export var display_name: String
@export_multiline var description: String
@export var weapon_type: WeaponType
@export var category: Category
@export var icon: Texture2D

@export_group("攻击属性")
@export var damage: int = 10
@export var cooldown: float = 1.0
@export var range: float = 50.0
@export var projectile_speed: float = 300.0
@export var projectile_count: int = 1
@export var pierce: int = 0

@export_group("特殊属性")
@export var heal_amount: int = 0
@export var orbit_count: int = 0
@export var reflect_percent: float = 0.0

@export var tags: Array[StringName] = []

@export_group("升级")
@export var max_level: int = 8
@export var paths: Array[WeaponPath] = []
```

`WeaponPath` 和 `WeaponPathLevel` 定义流派：

- `WeaponPath.path_id`：流派 ID，选择后写入 `WeaponBase.current_path_id`
- `WeaponPath.levels`：每个目标等级的效果列表
- `WeaponPathLevel.damage_bonus` / `cooldown_bonus` / `range_bonus`：数值修正
- `WeaponPathLevel.special_tag`：供具体武器脚本读取的特殊机制开关

## 武器基类

`WeaponBase` (`scripts/weapon/weapon_base.gd`) 提供统一生命周期和运行时属性：

- `_ready()`：调用 `_recalc_stats()` 初始化数值
- `_process(delta)`：默认冷却计时，到点调用 `_activate()`
- `_activate()`：具体武器实现攻击逻辑
- `level_up()`：检查 `max_level`，等级 +1，重算基础成长，应用当前流派效果
- `set_path(path_id)`：选择流派；已选择后不可切换
- `has_special_tag(tag)`：查询当前等级流派是否提供某个特殊效果
- `get_path_effect(level_target)`：读取目标等级的流派效果

基础成长公式：

| 属性 | 公式 |
|------|------|
| 伤害 | `round(weapon_data.damage * (1.0 + (level - 1) * 0.10))` |
| 冷却 | `max(0.1, weapon_data.cooldown * pow(0.92, level - 1))` |
| 范围 | `weapon_data.range + (level - 1) * 10.0` |

升级选项的 bonus 会在基础成长之后额外叠加；冷却最低锁定为 `0.1` 秒。

## 当前武器列表

| ID | 名称 | 分类 | 机制 |
|----|------|------|------|
| `melee_basic` | 基础利刃 | 攻击 | 扇形近战斩击 |
| `projectile_basic` | 弓箭精通 | 攻击 | 自动瞄准最近敌人的弹体 |
| `thunder` | 天雷引 | 攻击 | 随机选敌落雷范围伤害 |
| `orbit` | 护盾球 | 防御 | 围绕玩家旋转并持续碰撞伤害 |
| `thorns` | 荆棘护甲 | 防御 | 玩家受伤时范围反伤 |
| `shotgun` | 散弹枪 | 攻击 | 多弹丸扇形射击 |
| `fire_bottle` | 火焰瓶 | 攻击 | 投掷后留下火场 |
| `frost_ring` | 冰霜环 | 防御 | 周期性范围伤害和减速 |
| `holy_prism` | 圣光棱镜 | 攻击 | 范围伤害并治疗 |
| `poison_vial` | 毒液罐 | 攻击 | 投掷后留下毒雾 |
| `mine` | 地雷 | 攻击 | 布置陷阱，靠近爆炸 |
| `laser_pen` | 激光笔 | 攻击 | 直线穿透光束 |
| `boomerang` | 回旋镖 | 攻击 | 往返弹体 |
| `electromagnetic_chain` | 电磁链 | 攻击 | 多目标连锁弹跳 |
| `saw_blade` | 锯片陷阱 | 攻击 | 持续旋转锯片 |
| `rocket_pack` | 火箭背包 | 攻击 | 移动时留下火焰轨迹 |

## 升级系统联动

### 选项来源

`UpgradeSystem._generate_options()` 生成候选池：

1. 角色强化：疾风步、生命强化、磁力增幅、生命源泉
2. 未持有武器：从 `WEAPON_SCENES` 生成解锁选项，并从 `resources/weapons/{id}.tres` 读取名称、描述、图标
3. 已持有武器：
   - 若武器有路径、等级为 1 且尚未选流派，提供流派选择；卡片会展示选择后立即获得的 Lv.2 路径效果
   - 若武器已选流派，提供下一等级的 `WeaponPathLevel` 效果
   - 若武器无路径，回退到硬编码强化选项
4. 外部升级：追加 `DataManager.all_upgrades()`

### 过滤规则

- 已解锁武器不会再出现解锁选项
- 未解锁武器不会出现强化或流派选项
- 满级武器不会出现强化选项
- 同一轮选项中同一个 `weapon_id` 只出现一次
- 已选流派后不会再出现其他流派选项

### 生效方式

| 类型 | 行为 |
|------|------|
| `WEAPON_UNLOCK` | 实例化 `WEAPON_SCENES[weapon_id]` 并加入 `Player/Weapons` |
| `WEAPON_LEVEL` | 调用 `WeaponBase.level_up()`，再叠加 `UpgradeData` bonus |
| `WEAPON_PATH` | 调用 `set_path(path_id)`，然后升到 2 级并应用该路径 Lv.2 效果 |
| `PLAYER_STAT` | 修改玩家移速、最大 HP、当前 HP、拾取范围等；生命源泉会进入强化槽并由 `Game._process_passive_enhancements()` 定时恢复 |

## 数据资源文件

所有武器默认数据存放在 `resources/weapons/*.tres`：

```text
resources/weapons/
├── boomerang.tres
├── electromagnetic_chain.tres
├── fire_bottle.tres
├── frost_ring.tres
├── holy_prism.tres
├── laser_pen.tres
├── melee_basic.tres
├── mine.tres
├── orbit.tres
├── poison_vial.tres
├── projectile_basic.tres
├── rocket_pack.tres
├── saw_blade.tres
├── shotgun.tres
├── thorns.tres
└── thunder.tres
```

## 新增武器扩展指南

### 1. 创建数据资源

在 `resources/weapons/` 下新建 `.tres` 文件，填写 `WeaponData`。如果需要流派，补充 `paths: Array[WeaponPath]`。

### 2. 创建场景

在 `scenes/weapons/` 下新建 `.tscn`，根节点为 `Node`，挂载具体武器脚本，并把 `weapon_data` 指向对应 `.tres`。

```gdscript
[gd_scene load_steps=3 format=3]
[ext_resource type="Script" path="res://scripts/weapons/weapon_xxx.gd" id="1_xxx"]
[ext_resource type="Resource" path="res://resources/weapons/xxx.tres" id="2_data"]

[node name="WeaponXxx" type="Node"]
script = ExtResource("1_xxx")
weapon_data = ExtResource("2_data")
```

### 3. 编写脚本

继承 `WeaponBase`，实现 `_activate()`：

```gdscript
extends WeaponBase

func _activate() -> void:
	var dmg := get_damage()
	# 自定义攻击逻辑
```

持续型武器可重写 `_process(delta)`，自行处理状态更新和命中判定。

### 4. 注册解锁表

在 `scripts/game/upgrade_system.gd` 的 `WEAPON_SCENES` 添加映射：

```gdscript
const WEAPON_SCENES: Dictionary = {
	# ... 现有武器 ...
	&"xxx": "res://scenes/weapons/weapon_xxx.tscn",
}
```

### 5. 更新测试

武器相关改动必须运行：

```bash
./tests/run_tests.sh
```

新增行为未被覆盖时，在 `tests/auto_test.gd` 对应 phase 中补断言。

## 关键文件速查

| 文件 | 职责 |
|------|------|
| `scripts/weapon/weapon_base.gd` | 武器基类，生命周期、成长公式、流派效果 |
| `scripts/data/weapon_data.gd` | 武器数据资源定义 |
| `scripts/data/weapon_path.gd` | 武器流派定义 |
| `scripts/data/weapon_path_level.gd` | 流派等级效果定义 |
| `scripts/game/upgrade_system.gd` | 升级选项生成与武器强化应用 |
| `scripts/weapons/weapon_*.gd` | 各武器具体实现 |
| `resources/weapons/*.tres` | 各武器默认数据 |
| `scenes/weapons/*.tscn` | 各武器场景 |
