# 存档系统设计

## 目标

第一版先做本地存档，覆盖两个需求：

1. 局外档案：设置、累计金币、累计击杀、最佳成绩、已解锁内容等长期数据。
2. 单局继续：玩家退出或刷新后，可以从最近一次稳定快照继续当前局。

本地存档统一使用 Godot 的 `user://` 路径。桌面和移动端会落在应用沙盒目录；Web 导出下由浏览器站点存储承载，清站点数据会清掉存档。

## 非目标

第一版不做云同步、账号、多存档位、加密反作弊，也不精确保存所有敌人、弹体和掉落物。吸血鬼 like 的场上瞬时对象很多，精确恢复会显著增加复杂度；MVP 先恢复玩家、局内成长和时间，让生成器按当前时间继续刷怪。

## 文件与 Autoload

新增 `SaveManager` autoload：

```text
autoload/save_manager.gd
```

建议文件：

```text
user://save_v1.json
user://save_v1.bak
```

`SaveManager` 对外只暴露高层 API，其他系统不要直接读写 JSON：

```gdscript
func load_or_create() -> void
func save_profile() -> bool
func save_run_snapshot(game: Node) -> bool
func clear_run_snapshot() -> bool
func has_resume_run() -> bool
func apply_resume_run(game: Node) -> bool
func get_profile_value(key: String, default_value = null)
func set_profile_value(key: String, value) -> bool
```

关键原则：

- 写入时先写临时文件，再替换正式文件，并保留上一版 `.bak`。
- 读档失败时尝试 `.bak`，仍失败则创建默认档案。
- 所有保存内容必须是 JSON 可序列化类型，不保存 `Texture2D`、`Node`、`Resource` 实例。
- 每个存档带 `schema_version`，后续通过迁移函数升级旧格式。

## 存档结构

```json
{
  "schema_version": 1,
  "app_version": "0.1.0",
  "updated_at": 1234567890,
  "profile": {
    "created_at": 1234567890,
    "total_gold": 0,
    "lifetime_kills": 0,
    "best_time": 0.0,
    "best_level": 1,
    "best_kills": 0,
    "unlocked_weapon_ids": ["melee_basic"],
    "settings": {
      "music_volume": 1.0,
      "sfx_volume": 1.0,
      "language": "zh_CN",
      "joystick_mode": "auto"
    }
  },
  "resume_run": null
}
```

有可继续单局时，`resume_run` 写入：

```json
{
  "seed": 0,
  "saved_at": 1234567890,
  "run": {
    "hp": 100,
    "max_hp": 100,
    "exp": 0,
    "level": 1,
    "exp_to_next_level": 15,
    "gold": 0,
    "run_time": 35.2,
    "kills": 12,
    "pickup_radius_bonus": 30.0,
    "enhancements": [
      {
        "id": "speed_up",
        "level": 2,
        "display_name": "疾风步",
        "description": "移动速度 +25"
      }
    ]
  },
  "player": {
    "position": [120.0, -80.0],
    "move_speed": 220.0
  },
  "weapons": [
    {
      "id": "melee_basic",
      "level": 3,
      "path_id": "berserker",
      "damage": 17,
      "cooldown": 0.74,
      "range": 90.0
    }
  ]
}
```

### 为什么武器要保存运行时数值

当前武器升级有两类来源：

- `WeaponBase.level_up()` 的基础成长和流派效果。
- `UpgradeSystem._apply_bonus()` 对 `_current_damage / _current_cooldown / _current_range` 的额外叠加。

如果只保存 `level` 和 `path_id`，读档时会丢失额外 bonus。因此第一版应保存运行时数值，或者保存完整升级历史。MVP 推荐保存运行时数值，简单且能保持手感一致。

### 为什么强化不保存图标资源

当前 `GameState.run["enhancements"]` 内会保存图标引用，但 JSON 不能保存 `Texture2D`。存档只保存强化 `id / level / display_name / description`，读档后 UI 图标默认使用 `GameState.STAT_UPGRADE_ICON`。如果以后角色强化资源化，再保存 `icon_path`。

## 恢复策略

第一版采用“干净场景恢复”：

1. 加载 `scenes/game/game.tscn`。
2. `GameState.start_new_run(seed)` 初始化。
3. 覆盖 `GameState.run` 中的可保存字段。
4. 恢复玩家位置、移动速度、HP 信号、EXP 信号、金币信号。
5. 清空玩家 `Weapons` 容器，根据 `weapons` 快照重新实例化武器场景。
6. 设置武器等级、流派、运行时伤害 / 冷却 / 范围。
7. 敌人、弹体、掉落物不恢复；生成器按 `run_time` 难度继续。

这样读档后不会出现“加载瞬间被旧弹体/旧敌人包围”的问题，也能避免第一版保存大量瞬时状态。

## 保存时机

稳定保存点：

- 游戏启动：`SaveManager.load_or_create()`。
- 开始新局：清掉旧 `resume_run`，新局进入后立即保存一次。
- 升级选择完成后：保存单局快照。
- 暂停菜单打开时：保存单局快照。
- 暂停菜单返回主菜单时：保存单局快照，再回主菜单。
- 游戏结束：更新局外档案，清掉 `resume_run`。
- 运行中每 15 秒：如果没有打开升级选择，则保存单局快照。

不建议在升级三选一弹窗打开期间保存，除非同时保存 pending options；否则读档可能丢失一次升级选择。

## UI 接入

主菜单：

- `ContinueButton.disabled = not SaveManager.has_resume_run()`
- 有快照时文本显示 `继续游戏`
- 点击后加载游戏场景，并在 `Game._ready()` 后调用 `SaveManager.apply_resume_run(self)`

暂停菜单：

- 打开暂停菜单时保存。
- 返回主菜单时保存。

结算页：

- `GameOver.show_stats()` 前后更新局外档案。
- 死亡后必须清除 `resume_run`，避免继续已经结束的局。

设置页后续新增时：

- 音量、语言、虚拟摇杆模式写入 `profile.settings`。
- 修改后立即保存 profile。

## 代码改造点

建议按以下顺序实现：

1. 新增 `autoload/save_manager.gd`，实现默认档案、读写、备份、schema 校验。
2. 在 `project.godot` 注册 `SaveManager` autoload。
3. 给 `GameState` 增加 JSON 友好的 `to_save_data()` / `apply_save_data()`。
4. 给 `WeaponBase` 增加 `to_save_data()` / `apply_save_data(data)`，具体武器有特殊状态时再覆写。
5. 在 `scripts/game/game.gd` 接入开始新局、继续游戏、结束清档。
6. 在 `scripts/ui/main_menu.gd` 接入继续按钮。
7. 在 `scripts/ui/pause_menu.gd` 和升级选择完成后触发快照保存。
8. 补充测试。

## 测试计划

新增测试覆盖：

- 缺失存档时创建默认 profile。
- JSON 损坏时回退 `.bak` 或默认档案。
- profile 保存后重新加载，设置和累计统计不丢。
- 死亡结算后 `resume_run` 被清空，最佳成绩和累计金币更新。
- 单局快照 round-trip 后，`GameState` 的 HP、等级、经验、金币、击杀、run_time、强化槽恢复一致。
- 武器 round-trip 后，武器数量、id、等级、流派和运行时伤害 / 冷却 / 范围恢复一致。
- 主菜单继续按钮根据 `has_resume_run()` 正确启用 / 禁用。
- 存档 JSON 中不包含 `Texture2D`、`Node`、`Resource` 字符串化对象。

实现阶段如果改到 `scripts/game/upgrade_system.gd` 或 `scripts/weapon/weapon_base.gd`，仍按项目规则运行：

```bash
./tests/run_tests.sh
```

## 后续扩展

- 多存档位：把 `save_v1.json` 拆为 `slot_0.json / slot_1.json / slot_2.json`。
- 精确恢复场上对象：为 Enemy、Drop、Projectile 增加轻量 `save_state()`。
- 云同步：把 `SaveManager` 底层拆成 `LocalSaveBackend` 和 `CloudSaveBackend`，上层 API 不变。
- 成就和局外成长：扩展 `profile`，避免写入单局 `run`。
