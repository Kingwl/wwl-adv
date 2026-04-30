# 技能与掉落物视觉整理

本次资源按 `generate2dsprite` 流程重做：原始生成图和处理器输出保留在导出排除目录 `tmp/skill_pack_2026/`，运行时只接入下方列出的最终 PNG，避免 Web 包体被中间素材放大。

## 资源策略

| 类型 | 策略 | 原因 |
|------|------|------|
| 武器 / 被动图标 | 独立透明 PNG | UI 中需要稳定缩放；同类技能避免复用同一图标 |
| 火焰 / 毒雾场地 | 32px tile 横向 4 帧循环，运行时重复铺满半径 | 避免整张拉伸导致像素糊、边缘变形和覆盖范围误读 |
| 冲击波 / 冰霜环 / 旋风斩 | 128px、4 帧范围特效，运行时按技能半径等比缩放并淡出 | 范围爆发持续约 0.3-0.5s，帧动画比单张缩放更能表达扩散过程 |
| 火花弹弹体 | 64px、4 帧循环弹体，运行时旋转或自转 | 弹体在场时间足够长，静态单帧会显得像 UI 图标 |
| 火箭背包尾焰 | start / mid / end 三段各 32px、4 帧循环 | 动态长度由分段数量决定，帧动画负责火焰闪烁，避免拉伸变糊 |
| 投掷斧弹体 | 独立弹体 PNG，运行时旋转或自转 | 斧头轮廓明确，飞行自转已经提供运动感 |
| 经验 / 金币掉落 | 32px、5 帧循环 | 比旧 16px 更易读，同时保持现有脚本读取规则 |

## 主动武器图标

运行时图标写回 `assets/art/weapons/icons_sliced/icon_00.png` 到 `icon_20.png`，并同步 32px 命名副本到 `assets/art/weapons/icons/`。

| 武器 | 图标 |
|------|------|
| 基础利刃 | `assets/art/weapons/icons_sliced/icon_00.png` |
| 弓箭精通 | `assets/art/weapons/icons_sliced/icon_01.png` |
| 天雷引 | `assets/art/weapons/icons_sliced/icon_02.png` |
| 护盾球 | `assets/art/weapons/icons_sliced/icon_03.png` |
| 荆棘护甲 | `assets/art/weapons/icons_sliced/icon_04.png` |
| 散弹枪 | `assets/art/weapons/icons_sliced/icon_06.png` |
| 火焰瓶 | `assets/art/weapons/icons_sliced/icon_07.png` |
| 冰霜环 | `assets/art/weapons/icons_sliced/icon_08.png` |
| 圣光棱镜 | `assets/art/weapons/icons_sliced/icon_09.png` |
| 毒液罐 | `assets/art/weapons/icons_sliced/icon_10.png` |
| 地雷 | `assets/art/weapons/icons_sliced/icon_11.png` |
| 激光笔 | `assets/art/weapons/icons_sliced/icon_12.png` |
| 回旋镖 | `assets/art/weapons/icons_sliced/icon_13.png` |
| 电磁链 | `assets/art/weapons/icons_sliced/icon_14.png` |
| 锯片陷阱 | `assets/art/weapons/icons_sliced/icon_15.png` |
| 火箭背包 | `assets/art/weapons/icons_sliced/icon_16.png` |
| 旋风斩 | `assets/art/weapons/icons_sliced/icon_17.png` |
| 投掷斧 | `assets/art/weapons/icons_sliced/icon_18.png` |
| 冲击波 | `assets/art/weapons/icons_sliced/icon_19.png` |
| 火花弹 | `assets/art/weapons/icons_sliced/icon_20.png` |

## 局内被动图标

`UpgradeSystem` 已给 10 种局内被动设置专属图标，路径为 `assets/art/upgrades/icons/`。

| 被动 | 图标 | 效果 |
|------|------|------|
| 疾风步 | `speed_up.png` | 移动速度 +25 |
| 生命强化 | `hp_up.png` | 最大生命 +30，立即治疗 +30 |
| 磁力增幅 | `pickup_up.png` | 拾取范围 +30 |
| 生命源泉 | `regen.png` | 立即治疗，并周期恢复 |
| 强攻 | `might.png` | 全武器伤害 +8% |
| 专注 | `focus.png` | 全武器冷却 -6% |
| 扩张 | `expansion.png` | 全武器范围 +8% |
| 余烬延续 | `field_duration.png` | 火焰 / 毒雾等持续场地持续时间 +12% |
| 坚韧 | `tenacity.png` | 受到伤害 -8% |
| 历练 | `training.png` | 经验获取 +10% |

## 技能效果接入

| 效果 | 新资源 | 接入点 |
|------|--------|--------|
| 火焰场地 tile | `assets/art/effects/dynamic/fx_fire_tile_sheet.png` | `scripts/weapons/fire_field.gd` |
| 毒雾场地 tile | `assets/art/effects/dynamic/fx_poison_tile_sheet.png` | `scripts/weapons/poison_field.gd` |
| 护盾球循环 | `assets/art/effects/by_type/fx_orb/orb_01.png` 到 `orb_04.png` | `scripts/weapons/weapon_orbit.gd` |
| 荆棘反伤 | `assets/art/effects/by_type/fx_thorns/thorns_01.png` 到 `thorns_04.png` | `scripts/weapons/weapon_thorns.gd` |
| 生命恢复 | `assets/art/effects/by_type/fx_regen/regen_01.png` 到 `regen_04.png` | `scripts/game/game.gd` / `scripts/weapons/weapon_holy_prism.gd` |
| 地雷待机 | `assets/art/effects/by_type/fx_mine_blink/mine_blink_01.png` 到 `mine_blink_04.png` | `scripts/weapons/mine_trap.gd` |
| 火瓶投掷轨迹 | `assets/art/effects/by_type/fx_fire_trail/fire_trail_01.png` 到 `fire_trail_04.png` | `scripts/weapons/weapon_fire_bottle.gd` |
| 毒瓶投掷轨迹 | `assets/art/effects/by_type/fx_poison_trail/poison_trail_01.png` 到 `poison_trail_04.png` | `scripts/weapons/weapon_poison_vial.gd` |
| 圣光棱镜射线 | `assets/art/effects/dynamic/fx_holy_ray_{start,mid,end}.png` | `scripts/weapons/weapon_holy_prism.gd` |
| 冰霜环 | `assets/art/effects/by_type/fx_frost_ring/frost_01.png` 到 `frost_04.png` | `scripts/weapons/weapon_frost_ring.gd` |
| 冲击波 | `assets/art/effects/by_type/fx_shockwave/shockwave_01.png` 到 `shockwave_04.png` | `scripts/weapons/weapon_shockwave.gd` |
| 火花弹弹体 | `assets/art/weapons/projectiles/spark_bomb_01.png` 到 `spark_bomb_04.png` | `scripts/weapons/weapon_spark_bomb.gd` |
| 投掷斧弹体 | `assets/art/weapons/projectiles/throwing_axe.png` | `scripts/weapons/weapon_throwing_axe.gd` |
| 旋风斩弧线 | `assets/art/effects/by_type/fx_whirlwind/whirlwind_arc_01.png` 到 `whirlwind_arc_04.png` | `scripts/weapons/weapon_whirlwind.gd` |
| 火箭背包尾焰 | `assets/art/effects/by_type/fx_rocket_flame_{start,mid,end}/flame_*_01.png` 到 `_04.png` | `scripts/weapons/weapon_rocket_pack.gd` |

## 掉落物

脚本仍按旧规则读取 5 帧：

| 掉落物 | 帧路径 | 单帧 |
|--------|--------|------|
| 经验球 | `assets/art/effects/by_type/drop_exp_orb/exp_orb_01.png` 到 `exp_orb_05.png` | 32x32 |
| 金币 | `assets/art/effects/by_type/drop_gold_coin/gold_01.png` 到 `gold_05.png` | 32x32 |

静态预览图同步更新为：

- `assets/art/drops/exp_orb.png`
- `assets/art/drops/gold_coin.png`
