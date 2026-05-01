# 美术资源需求清单（含帧动画规格）

> UI 信息架构和界面布局设计见 [`ui_design.md`](./ui_design.md)。
> 武器设计见 [`weapon_design.md`](./weapon_design.md)。

**风格**：2D 俯视角像素风。
**引擎**：Godot 4.x GL Compatibility（支持 PNG / WebP / JPEG / SVG，推荐 PNG）。
**帧动画方案**：Sprite Sheet（横向排列）+ Godot `AnimatedSprite2D` 或 `Sprite2D + AtlasTexture`。

---

## 目录结构建议

```
assets/art/
├── characters/          # 玩家、敌人角色（含帧动画 sprite sheet）
├── weapons/             # 武器图标、弹体、攻击特效（sprite sheet）
├── drops/               # 掉落物（经验、金币，含帧动画）
├── ui/                  # 界面元素、图标、按钮
├── environment/         # 背景、地面纹理
└── effects/             # 通用特效（受击闪烁、爆炸、升级光环等）
```

---

## 当前已生成素材

| 资源名 | 当前位置 | 尺寸 | 备注 |
|--------|----------|------|------|
| `player_idle.png` | `assets/art/characters/player_idle.png` | 64x64 | 玩家角色站立图（直接按最终显示尺寸绘制） |
| `enemy_basic.png` | `assets/art/characters/enemy_basic.png` | 64x64 | 基础敌人（直接按最终显示尺寸绘制） |
| `exp_orb.png` | `assets/art/drops/exp_orb.png` | 32x32 | 经验球 |
| `gold_coin.png` | `assets/art/drops/gold_coin.png` | 32x32 | 金币 |
| `projectile_arrow.png` | `assets/art/weapons/projectile_arrow.png` | 16x16 | 远程弹体 |
| `mvp_preview.png` | `assets/art/mvp_preview.png` | 1216x370 | MVP 素材预览 |
| `characters_animation_atlas.png` | `assets/art/sheets/characters_animation_atlas.png` | 1536x1024 | 角色动画雪碧图，透明背景 |
| `weapon_icons_atlas.png` | `assets/art/sheets/weapon_icons_atlas.png` | 待更新 | 20 个武器图标 + 生命源泉强化图标雪碧图，透明背景 |
| `combat_effects_projectiles_atlas.png` | `assets/art/sheets/combat_effects_projectiles_atlas.png` | 1536x1024 | 战斗特效/弹体/掉落物雪碧图，透明背景 |
| `dynamic_scalable_effects_atlas.png` | `assets/art/sheets/dynamic_scalable_effects_atlas.png` | 1536x1024 | 动态缩放特效雪碧图，透明背景 |
| `ui_environment_atlas.png` | `assets/art/sheets/ui_environment_atlas.png` | 1536x1024 | UI/环境素材雪碧图，透明背景 |
| `generated_atlas_preview.png` | `assets/art/sheets/generated_atlas_preview.png` | 792x596 | 透明雪碧图预览 |
| `dynamic_scalable_effects_preview.png` | `assets/art/sheets/dynamic_scalable_effects_preview.png` | 768x550 | 动态缩放特效预览 |

---

## 一、角色（Characters）

### 1. 玩家角色

当前实现：`scenes/player/player.tscn` 使用 `AnimatedSprite2D` 播放玩家帧动画；下表作为后续重绘 / 补帧规格。

| 资源名 | 用途 | 帧数 | 单帧尺寸 | 总尺寸 | FPS | 循环 | 备注 |
|--------|------|------|----------|--------|-----|------|------|
| `player_idle_sheet.png` | 站立呼吸 | 4 | 64x64 | 256x64 | 4 | 是 | 轻微上下起伏 |
| `player_run_sheet.png` | 跑步 | 6 | 64x64 | 384x64 | 8 | 是 | 四肢交替摆动 |
| `player_hit_sheet.png` | 受击 | 2 | 64x64 | 128x64 | 8 | 否 | 白闪+后仰，0.25s 后切回 idle |
| `player_death_sheet.png` | 死亡 | 5 | 64x64 | 320x64 | 6 | 否 | 倒地+变灰，最后一帧停留 |

**俯视角绘制要点**：能看到头顶和肩膀，4 方向对称（或 8 方向，Godot 中可用 `flip_h` 处理左右），统一左上方光源。

### 2. 基础敌人

替换目标：`scenes/enemy/enemy.tscn` 中 `Visual (Sprite2D)` 的 texture。

| 资源名 | 用途 | 帧数 | 单帧尺寸 | 总尺寸 | FPS | 循环 | 备注 |
|--------|------|------|----------|--------|-----|------|------|
| `enemy_walk_sheet.png` | 行走 | 4 | 64x64 | 256x64 | 6 | 是 | 红色系，向玩家移动时播放 |
| `enemy_hit_sheet.png` | 受击 | 2 | 64x64 | 128x64 | 8 | 否 | 白闪，代码已控制 0.08s |
| `enemy_death_sheet.png` | 死亡 | 6 | 64x64 | 384x64 | 8 | 否 | 消散/碎裂，末帧透明 |

---

## 二、武器图标（Weapons — HUD / 升级UI）

20 种武器各需一张图标，显示在升级选择卡片和暂停菜单武器栏中；生命源泉和局内被动使用 `assets/art/upgrades/icons/` 下的强化图标。当前 20 种武器均已补独立图标，详见 [`skill_visual_redesign.md`](./skill_visual_redesign.md)。

| 资源名 | 用途 | 尺寸 | 格式 | 备注 |
|--------|------|------|------|------|
| `icon_melee.png` | 利刃 | 32x32 | PNG | 剑/刀 |
| `icon_projectile.png` | 弓箭 | 32x32 | PNG | 弓/箭矢 |
| `icon_thunder.png` | 天雷引 | 32x32 | PNG | 闪电符号 |
| `icon_orbit.png` | 护盾球 | 32x32 | PNG | 环绕的球体 |
| `icon_thorns.png` | 荆棘护甲 | 32x32 | PNG | 带刺的盾 |
| `icon_regen.png` | 生命源泉强化 | 32x32 | PNG | 绿色十字/水滴 |
| `icon_shotgun.png` | 散弹枪 | 32x32 | PNG | 双管枪 |
| `icon_fire_bottle.png` | 火焰瓶 | 32x32 | PNG | 燃烧瓶 |
| `icon_frost_ring.png` | 冰霜环 | 32x32 | PNG | 雪花/冰环 |
| `icon_holy_prism.png` | 圣光棱镜 | 32x32 | PNG | 棱镜/光柱 |
| `icon_poison_vial.png` | 毒液罐 | 32x32 | PNG | 绿色药瓶 |
| `icon_mine.png` | 地雷 | 32x32 | PNG | 圆形地雷 |
| `icon_laser_pen.png` | 激光笔 | 32x32 | PNG | 激光发射器 |
| `icon_boomerang.png` | 回旋镖 | 32x32 | PNG | 弧形回旋镖 |
| `icon_chain.png` | 电磁链 | 32x32 | PNG | 闪电链 |
| `icon_saw_blade.png` | 锯片陷阱 | 32x32 | PNG | 旋转锯齿 |
| `icon_rocket_pack.png` | 火箭背包 | 32x32 | PNG | 火焰喷射器 |

**代码关联**：`WeaponData.icon: Texture2D` — 升级卡片和暂停菜单显示。

---

## 三、武器攻击特效（帧动画 Sprite Sheet）

当前多数武器特效已接入 `Sprite2D` / `AnimatedSprite2D` 或动态分段贴图；短时范围爆发优先使用帧动画，动态长度或动态范围特效应使用下方“动态缩放特效规范”。

| 资源名 | 对应武器 | 帧数 | 单帧尺寸 | 总尺寸 | FPS | 循环 | 持续 | 备注 |
|--------|----------|------|----------|--------|-----|------|------|------|
| `fx_slash_sheet.png` | 利刃 | 5 | 128x128 | 640x128 | 12 | 否 | ~0.4s | 以玩家为圆心的扇形外缘斩击，运行时按攻击半径缩放 |
| `fx_thunder_sheet.png` | 天雷引 | 6 | 64x64 | 384x64 | 10 | 否 | ~0.6s | 黄色落雷+地面扩散 |
| `fx_holy_sheet.png` | 圣光棱镜 | 6 | 64x64 | 384x64 | 10 | 否 | ~0.6s | 金色光柱+治疗粒子 |
| `fx_ice_ring_sheet.png` | 冰霜环 | 4 | 128x128 | 512x128 | 10 | 否 | ~0.45s | 冰环从中心扩散后消散 |
| `fx_shockwave_sheet.png` | 冲击波 | 4 | 128x128 | 512x128 | 12 | 否 | ~0.38s | 地裂冲击环从中心扩张，运行时按半径缩放 |
| `fx_fire_field_sheet.png` | 火焰瓶 | 4 | 64x64 | 256x64 | 6 | 是 | 循环 | 地面火焰持续燃烧 |
| `fx_poison_field_sheet.png` | 毒液罐 | 4 | 64x64 | 256x64 | 6 | 是 | 循环 | 绿色毒雾翻滚 |
| `fx_mine_blink_sheet.png` | 地雷（待机） | 4 | 16x16 | 64x16 | 4 | 是 | 循环 | 金属地雷本体，红灯闪烁 |
| `fx_explosion_sheet.png` | 地雷/通用爆炸 | 8 | 64x64 | 512x64 | 12 | 否 | ~0.7s | 橙红色爆炸 |
| `fx_laser_sheet.png` | 激光笔 | 4 | 256x16 | 1024x16 | 8 | 否 | ~0.5s | 光束闪烁+末端消散 |
| `fx_regen_sheet.png` | 生命源泉强化 | 4 | 32x32 | 128x32 | 4 | 是 | 循环 | 绿色十字浮动光点 |
| `fx_thorns_sheet.png` | 荆棘护甲 | 4 | 48x48 | 192x48 | 4 | 是 | 循环 | 尖刺脉冲红光 |
| `fx_chain_sheet.png` | 电磁链 | 3 | 32x32 | 96x32 | 12 | 否 | ~0.25s | 闪电弧跳跃 |
| `fx_whirlwind_arc_sheet.png` | 旋风斩 | 4 | 128x128 | 512x128 | 16 | 是 | ~0.32s | 弧形刀光围绕玩家旋转，运行时多段错帧 |
| `fx_rocket_fire_sheet.png` | 火箭背包 | start / mid / end 各 4 | 32x32 | 各 128x32 | 14 | 是 | 循环 | 身后火焰三段式闪烁，mid 按距离重复 |

**播放方式**：在武器 `_activate()` 中实例化 `AnimatedSprite2D` 场景，设置 `animation = "default"`，`play()`，`animation_finished` 信号后 `queue_free()`。

### 动态缩放特效规范

部分攻击效果会根据目标距离、武器范围或持续区域动态变化，不适合只用固定尺寸 sprite sheet。

| 类型 | 适用武器/效果 | 推荐素材 | 运行时处理 |
|------|---------------|----------|------------|
| 三段式射线 | 激光笔 | `fx_laser_start.png` / `fx_laser_mid.png` / `fx_laser_end.png` | `start` 和 `end` 保持原尺寸，`mid` 按目标长度横向拉伸或平铺，整体旋转到攻击方向 |
| 三段式圣光 | 圣光棱镜射线 | `fx_holy_ray_start.png` / `fx_holy_ray_mid.png` / `fx_holy_ray_end.png` | 与激光同样三段拼接，但使用金白色棱镜光，避免红色激光视觉误读 |
| 程序化折线 | 电磁链、闪电链 | `fx_chain_core.png` / `fx_chain_node.png` | 用 `Line2D` 生成起点到终点的随机折线，小电弧贴图作为沿线装饰，命中点用 node 闪光 |
| 半径缩放范围 | 斩击、爆炸、冰环、圣光、落雷地面圈 | 原有 `fx_*_sheet.png` | 按标准半径绘制，运行时按 `target_radius / base_radius` 等比缩放，优先使用 1x / 1.5x / 2x / 3x 档位 |
| 地面 tile 平铺 | 火场、毒雾、持续陷阱 | `fx_fire_tile_sheet.png` / `fx_poison_tile_sheet.png` | 多个 tile 随机铺满区域，不拉伸单张图，避免像素糊和边缘变形 |
| 尾焰/喷射 | 火箭背包、火焰尾迹 | `flame_start_01..04.png` / `flame_mid_01..04.png` / `flame_end_01..04.png` | 根据移动速度或持续时间改变 mid 数量，起止端保持清晰，每段内部循环闪烁 |
| 弹体方向 | 箭、火瓶、毒瓶、回旋镖 | 原有 `proj_*_sheet.png` | 素材统一朝上或朝右绘制，运行时只旋转，不缩放 |

**需要更新或补充的动态素材**：

| 新资源名 | 替代/补充 | 用途 |
|----------|-----------|------|
| `fx_laser_start.png` | 补充 `fx_laser_sheet.png` | 激光起点/发射口 |
| `fx_laser_mid.png` | 补充 `fx_laser_sheet.png` | 激光可平铺中段 |
| `fx_laser_end.png` | 补充 `fx_laser_sheet.png` | 激光末端命中闪光 |
| `fx_holy_ray_start.png` | 补充圣光棱镜动态素材 | 圣光起点棱镜爆光 |
| `fx_holy_ray_mid.png` | 补充圣光棱镜动态素材 | 圣光可拉伸中段 |
| `fx_holy_ray_end.png` | 补充圣光棱镜动态素材 | 圣光末端命中闪光 |
| `fx_chain_core.png` | 补充 `fx_chain_sheet.png` | 闪电链沿线小电弧 |
| `fx_chain_node.png` | 补充 `fx_chain_sheet.png` | 闪电链命中节点 |
| `fx_fire_tile_sheet.png` | 补充 `fx_fire_field_sheet.png` | 火场区域 tile 平铺 |
| `fx_poison_tile_sheet.png` | 补充 `fx_poison_field_sheet.png` | 毒雾区域 tile 平铺 |
| `flame_start_01..04.png` | 补充 `fx_rocket_fire_sheet.png` | 火箭/喷火起点循环帧 |
| `flame_mid_01..04.png` | 补充 `fx_rocket_fire_sheet.png` | 火焰可平铺中段循环帧 |
| `flame_end_01..04.png` | 补充 `fx_rocket_fire_sheet.png` | 火焰末端消散循环帧 |

---

## 四、弹体（Projectiles）

| 资源名 | 对应武器 | 帧数 | 单帧尺寸 | 总尺寸 | FPS | 循环 | 备注 |
|--------|----------|------|----------|--------|-----|------|------|
| `proj_arrow_sheet.png` | 弓箭 | 1 | 16x16 | 16x16 | — | — | 静态，代码旋转朝向 |
| `proj_arrow_sheet.png` | 散弹枪 | 1 | 12x12 | 12x12 | — | — | 同上，略小 |
| `proj_boomerang_sheet.png` | 回旋镖 | 4 | 24x24 | 96x24 | 12 | 是 | 旋转飞行 |
| `proj_fire_trail_sheet.png` | 火焰瓶投掷 | 4 | 32x8 | 128x8 | 10 | 是 | 火瓶主体 + 火星尾迹 |
| `proj_poison_trail_sheet.png` | 毒液罐投掷 | 4 | 32x8 | 128x8 | 10 | 是 | 绿色毒瓶/毒滴轨迹 |
| `spark_bomb_01..04.png` | 火花弹 | 4 | 64x64 | 独立帧 | 12 | 是 | 电弧脉冲弹体，运行时自转 |

**代码关联**：`scenes/weapons/projectile.tscn` 中 `Sprite2D` 替换为 `AnimatedSprite2D`。

---

## 五、持续物体武器视觉（Orbit / Saw Blade）

这些武器不触发一次性特效，而是持续存在的可视物体。护盾球跟随玩家环绕，锯片陷阱会投放到敌群位置并在短时轨道上往返切割。

| 资源名 | 对应武器 | 帧数 | 单帧尺寸 | 总尺寸 | FPS | 循环 | 备注 |
|--------|----------|------|----------|--------|-----|------|------|
| `orb_sheet.png` | 护盾球 | 4 | 20x20 | 80x20 | 6 | 是 | 蓝色光球轻微脉动 |
| `saw_blade_sheet.png` | 锯片陷阱 | 4 | 24x24 | 96x24 | 10 | 是 | 锯齿旋转 |

**代码关联**：`weapon_orbit.gd` / `weapon_saw_blade.gd` 中的持续视觉物体使用 `AnimatedSprite2D`。

---

## 六、掉落物（Drops）

替换目标：`scenes/drops/exp_orb.tscn` / `gold_pickup.tscn` 中的 `Sprite2D`。

| 资源名 | 用途 | 帧数 | 单帧尺寸 | 总尺寸 | FPS | 循环 | 备注 |
|--------|------|------|----------|--------|-----|------|------|
| `exp_orb_sheet.png` | 经验球 | 5 | 32x32 | 160x32 | 4 | 是 | 蓝色晶体球呼吸脉动 |
| `gold_coin_sheet.png` | 金币 | 5 | 32x32 | 160x32 | 6 | 是 | 旋转闪烁（正面→侧面） |

---

## 七、UI（User Interface）

| 资源名 | 用途 | 帧数 | 单帧尺寸 | 总尺寸 | FPS | 循环 | 备注 |
|--------|------|------|----------|--------|-----|------|------|
| `panel_bg.png` | 面板背景 | 1 | 400x200 | 400x200 | — | — | 深色半透明圆角 |
| `button_normal.png` | 按钮常态 | 1 | 220x48 | 220x48 | — | — | — |
| `button_hover.png` | 按钮悬停 | 1 | 220x48 | 220x48 | — | — | 比常态亮 |
| `button_pressed.png` | 按钮按下 | 1 | 220x48 | 220x48 | — | — | 比常态暗 |
| `hp_bar_fill.png` | HP条填充 | 1 | 256x24 | 256x24 | — | — | 红色渐变，NinePatch |
| `exp_bar_fill.png` | 经验条填充 | 1 | 256x20 | 256x20 | — | — | 蓝色渐变，NinePatch |
| `icon_heart.png` | HP图标 | 1 | 16x16 | 16x16 | — | — | 红心 |
| `icon_gold.png` | 金币图标 | 1 | 16x16 | 16x16 | — | — | 金色硬币 |
| `joystick_base.png` | 摇杆底座 | 1 | 120x120 | 120x120 | — | — | 灰色半透明圆环 |
| `joystick_knob.png` | 摇杆头 | 1 | 50x50 | 50x50 | — | — | 白色圆点 |
| `level_up_glow_sheet.png` | 升级光环 | 6 | 64x64 | 384x64 | 8 | 否 | 玩家脚下金色光环，升级时播放 |

---

## 八、环境（Environment）

| 资源名 | 用途 | 尺寸 | 格式 | 备注 |
|--------|------|------|------|------|
| `ground_tile.png` | 地面平铺纹理 | 256x256 或 512x512 | PNG | 暗色北境废墟氛围的枯草 / 苔石 / 破碎石路，无缝平铺 |
| `ground_detail_sheet.png` | 地面装饰（草/石子） | 4x32x32 | 128x32 | 随机点缀，静态或 1FPS 微动 |

---

## 九、通用特效（Effects）

| 资源名 | 用途 | 帧数 | 单帧尺寸 | 总尺寸 | FPS | 循环 | 持续 | 备注 |
|--------|------|------|----------|--------|-----|------|------|------|
| `fx_hit_flash.png` | 受击白闪 | 1 | 64x64 | 64x64 | — | — | 0.08s | 纯白填充，代码调透明度 |
| `fx_enemy_death.png` | 敌人死亡残留 | 1 | 64x64 | 64x64 | — | — | — | 尸体/灰尘，可选 |
| `fx_level_up.png` | 升级粒子爆发 | 8 | 64x64 | 512x64 | 10 | 否 | ~0.8s | 金色星芒向四周飞散 |
| `fx_pickup_glow.png` | 拾取光环 | 4 | 48x48 | 192x48 | 8 | 否 | ~0.5s | 经验/金币被吸时发光 |

---

## 总计

| 分类 | 静态图 | 帧动画 | 合计 | 优先级 |
|------|--------|--------|------|--------|
| 角色 | — | 4+3 = 7 张 sheet | **7** | **高** — 最直观 |
| 武器图标 | 21 | — | **21** | **高** — UI  everywhere |
| 武器特效 | — | 13 张 sheet | **13** | **高** — 战斗反馈核心 |
| 弹体 | 2 | 3 张 sheet | **5** | 中 |
| 持续物体武器 | — | 2 张 sheet | **2** | 中 |
| 掉落物 | — | 2 张 sheet | **2** | **高** — 战斗中 constantly 可见 |
| UI | 10 | 1 张 sheet | **11** | 中 — 优先按钮和面板 |
| 环境 | 2 | — | **2** | 低 — 可后期 |
| 通用特效 | 1 | 3 张 sheet | **4** | 中 |
| **总计** | **32** | **31** | **63** | |

**最小可行美术集（MVP）**：
- 角色：`player_idle_sheet.png` (4帧) + `enemy_walk_sheet.png` (4帧)
- 武器图标：21 张静态 icon（20 武器 + 生命源泉）
- 特效：`fx_slash_sheet.png` + `fx_thunder_sheet.png` + `fx_explosion_sheet.png`
- 掉落物：`exp_orb_sheet.png` + `gold_coin_sheet.png`
- 弹体：`proj_arrow_sheet.png`
- UI：`panel_bg.png` + `button_*.png` + `hp_bar_fill.png` + `exp_bar_fill.png`

---

## 像素画规格建议

- **画布尺寸**：角色 64x64（最终显示尺寸，不依赖 `scale`），弹体/掉落物 16x16，特效 64x64，UI 图标 16x16 或 32x32
- **Scale 策略**：所有角色/敌人素材按游戏内最终显示像素绘制，Godot 中 `scale = 1.0`，避免运行时放大导致模糊
- **色深**：限制调色板（如 8-16 色）统一风格
- **线条**：1 像素描边，颜色比填充色深 2-3 个色阶
- **俯视角角度**：约 45 度，能看到头顶和两侧肩膀
- **光源**：统一左上方打光，右侧和底部偏暗
- **Sprite Sheet 排列**：横向从左到右排列帧，间距为 0（紧密排列），Godot 中通过 `hframes` 分割

## 帧动画在 Godot 中的使用方式

### 方式 1：AnimatedSprite2D（推荐）

```gdscript
var sprite := AnimatedSprite2D.new()
var frames := SpriteFrames.new()
# 从 sprite sheet 创建动画
var atlas := AtlasTexture.new()
atlas.atlas = load("res://assets/art/effects/fx_slash_sheet.png")
atlas.region = Rect2(0, 0, 64, 64)  # 第1帧
frames.add_animation("default")
frames.add_frame("default", atlas, 0)
# ... 添加其余帧
sprite.sprite_frames = frames
sprite.play("default")
sprite.animation_finished.connect(sprite.queue_free)
```

### 方式 2：Sprite2D + AtlasTexture（代码控制）

```gdscript
@export var sprite_sheet: Texture2D
@export var frame_count: int = 4
@export var frame_width: int = 32

var _frame := 0
var _timer := 0.0
var _fps := 6.0

func _process(delta: float) -> void:
    _timer += delta
    if _timer >= 1.0 / _fps:
        _timer = 0.0
        _frame = (_frame + 1) % frame_count
        var atlas := AtlasTexture.new()
        atlas.atlas = sprite_sheet
        atlas.region = Rect2(_frame * frame_width, 0, frame_width, sprite_sheet.get_height())
        $Sprite2D.texture = atlas
```
