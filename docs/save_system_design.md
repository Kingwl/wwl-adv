# 存档系统设计

## 目标

第一版本地存档只保存局外数值档案，不保存当前战斗现场。

覆盖内容：

1. 累计金币、累计击杀、总局数、最佳成绩、最近一局摘要。
2. 已解锁内容和后续设置项。
3. 写盘失败时保留上一版存档，避免损坏正式文件。

本地存档统一使用 Godot 的 `user://` 路径。桌面和移动端会落在应用沙盒目录；Web 导出下由浏览器站点存储承载，清站点数据会清掉存档。

## 非目标

第一版不做云同步、账号、多存档位、加密反作弊，也不做“继续当前战斗”。玩家位置、HP、EXP、武器等级、强化、敌人、弹体和掉落物都属于单局战斗状态，刷新或重启后从主菜单重新开始一局。

## 文件与 Autoload

`SaveManager` autoload：

```text
autoload/save_manager.gd
```

使用文件：

```text
user://save_v1.json
user://save_v1.bak
```

`SaveManager` 对外只暴露高层 API，其他系统不要直接读写 JSON：

```gdscript
func load_or_create() -> void
func save_profile() -> bool
func add_total_gold(amount: int) -> bool
func add_lifetime_kills(amount: int = 1) -> bool
func record_run_finished() -> bool
func get_profile_value(key: String, default_value = null)
func set_profile_value(key: String, value) -> bool
func get_profile() -> Dictionary
```

关键原则：

- 写入时先写临时文件，再替换正式文件，并保留上一版 `.bak`。
- 读档失败时尝试 `.bak`，仍失败则创建默认档案。
- 所有保存内容必须是 JSON 可序列化类型，不保存 `Texture2D`、`Node`、`Resource` 实例。
- 每个存档带 `schema_version`，后续通过迁移函数升级旧格式。
- 旧版本如果存在 `resume_run`，加载后会丢弃该字段。

## 存档结构

```json
{
  "schema_version": 1,
  "app_version": "0.1.0",
  "created_at": 1234567890,
  "updated_at": 1234567890,
  "profile": {
    "created_at": 1234567890,
    "total_runs": 0,
    "total_gold": 0,
    "lifetime_kills": 0,
    "best_time": 0.0,
    "best_level": 1,
    "best_kills": 0,
    "unlocked_weapon_ids": ["melee_basic"],
    "last_run": {
      "ended_at": 1234567890,
      "time": 99.0,
      "level": 5,
      "kills": 12,
      "gold": 18
    },
    "settings": {
      "music_volume": 1.0,
      "sfx_volume": 1.0,
      "language": "zh_CN",
      "joystick_mode": "auto"
    }
  }
}
```

## 保存时机

稳定保存点：

- 游戏启动：`SaveManager.load_or_create()`。
- 获得金币：`GameState.add_gold()` 同步调用 `SaveManager.add_total_gold(amount)` 更新内存 profile，并标记待写盘。
- 击杀敌人：`GameState.add_kill()` 同步调用 `SaveManager.add_lifetime_kills(1)` 更新内存 profile，并标记待写盘。
- 运行中：如果 profile 有变更，`SaveManager` 每 5 秒节流写盘一次，避免后期击杀过多造成频繁 IO。
- 游戏结束：`SaveManager.record_run_finished()` 更新总局数、最佳成绩和最近一局摘要，并立即写盘。
- 返回主菜单：调用 `SaveManager.save_profile()` 刷新 `updated_at` 并确保 profile 落盘。
- 设置页后续新增时：设置变更后调用 `SaveManager.set_profile_value()` 或更新 `profile.settings` 后保存。

## UI 接入

主菜单：

- 只保留 `开始游戏` 入口。
- `ContinueButton` 保留在场景中但隐藏，避免当前版本暗示可以继续当前战斗。

暂停菜单：

- 暂停只负责恢复游戏或返回主菜单，不保存战斗状态。

结算页：

- `GameOver.show_stats()` 前调用 `SaveManager.record_run_finished()`。
- 结算只记录数值摘要，不生成可继续单局。

## 已实现改造点

1. 新增 `autoload/save_manager.gd`，实现默认档案、读写、备份、schema 校验。
2. 在 `project.godot` 注册 `SaveManager` autoload。
3. `GameState.add_gold()` 和 `GameState.add_kill()` 即时同步局外累计数值，并由 `SaveManager` 节流落盘。
4. `scripts/game/game.gd` 在游戏结束时更新总局数、最佳成绩和最近一局摘要。
5. 主菜单隐藏继续按钮，不提供战斗恢复入口。
6. `tests/auto_test.gd` 覆盖数值持久化、不保存战斗状态和主菜单隐藏继续按钮。

## 测试计划

测试覆盖：

- 缺失存档时创建默认 profile。
- JSON 损坏时回退 `.bak` 或默认档案。
- profile 保存后重新加载，设置和累计统计不丢。
- 金币拾取后累计金币更新。
- 击杀后累计击杀更新。
- 死亡结算后最佳成绩、总局数和最近一局摘要更新。
- 存档 JSON 中不包含 `Texture2D`、`Node`、`Resource` 字符串化对象。
- 存档 JSON 中不包含玩家位置、武器、HP、EXP 等战斗状态。
- 主菜单继续按钮保持隐藏。

实现阶段如果改到 `scripts/game/upgrade_system.gd` 或 `scripts/weapon/weapon_base.gd`，仍按项目规则运行：

```bash
./tests/run_tests.sh
```

## 后续扩展

- 多存档位：把 `save_v1.json` 拆为 `slot_0.json / slot_1.json / slot_2.json`。
- 局外成长：扩展 `profile`，增加角色、武器解锁和永久升级。
- 设置页：把音量、语言、虚拟摇杆模式写入 `profile.settings`。
- 云同步：把 `SaveManager` 底层拆成 `LocalSaveBackend` 和 `CloudSaveBackend`，上层 API 不变。
