# 美术素材补齐记录

> 基于 [`art_requirements.md`](./art_requirements.md) 规格整理。原先缺失的角色、武器、特效、掉落物和 UI 素材已基本生成并接入；本文保留生成位置、规格和后续优化建议，避免重复返工。

## 当前接入状态

| 类型 | 位置 | 状态 |
|------|------|------|
| 角色动画 | `assets/art/characters/` | 已接入玩家 idle / run / hit / death，敌人 walk / hit / death |
| 武器图标 | `assets/art/weapons/icons/` | 20 种武器图标已接入；新增低复杂度武器暂复用现有图标，生命源泉作为强化图标复用 |
| 弹体素材 | `assets/art/weapons/projectiles/` | 箭矢、冰片、回旋镖等已接入 |
| 攻击特效 | `assets/art/effects/by_type/fx_*/*.png` | 已按类型拆分为逐帧目录，供 `AnimatedSprite2D` 使用 |
| 动态缩放特效 | `assets/art/effects/generated_missing/dynamic/` | 激光三段、闪电链节点、火/毒 tile、火箭火焰段已生成 |
| 掉落物 | `assets/art/drops/` 和 `assets/art/effects/by_type/drop_*` | 经验球、金币和拾取光效已接入 |
| UI 元素 | `assets/art/ui/` | 面板、按钮、HP/EXP 条、心、金币、属性升级图标、摇杆已接入 |
| 生成源图 | `assets/art/sheets/` | 保留 atlas 源图和预览图，便于重切或迭代 |

## 已补齐素材

| 素材 | 规格 | 用途 |
|------|------|------|
| `proj_boomerang_sheet.png` | 4 帧，24x24，总 96x24 | 回旋镖旋转弹体 |
| `fx_slash` | 5 帧，64x64 | 基础利刃斩击 |
| `fx_thunder` | 6 帧，64x64 | 天雷引落雷 |
| `fx_holy` | 6 帧，64x64 | 圣光棱镜 |
| `fx_fire_field` | 4 帧，64x64 / tile 32x32 | 火焰瓶火场 |
| `fx_poison_field` | 4 帧，64x64 / tile 32x32 | 毒液罐毒雾 |
| `fx_explosion` | 8 帧，64x64 | 地雷 / 通用爆炸 |
| `fx_laser` | 4 帧 + start/mid/end | 激光笔光束 |
| `fx_regen` | 4 帧，32x32 | 生命源泉恢复 |
| `fx_thorns` | 4 帧，48x48 | 荆棘护甲反伤 |
| `fx_rocket_fire` | 4 帧 + flame start/mid/end | 火箭背包喷火 |
| `saw_blade` | 4 帧，24x24 | 锯片陷阱旋转 |
| `fx_level_up` | 8 帧，64x64 | 玩家升级光效 |
| `fx_pickup_glow` | 4 帧，48x48 | 拾取吸附光效 |
| `panel_bg.png` | 400x200 | UI 面板背景 |
| `button_normal/hover/pressed.png` | 220x48 | 按钮三态 |
| `hp_bar_fill.png` / `exp_bar_fill.png` | 256x24 / 256x20 | HUD 进度条填充 |
| `icon_heart.png` / `icon_gold.png` | 16x16 | HUD 图标 |
| `icon_stat_upgrade.png` | 32x32 | 角色强化升级卡图标 |

## 当前格式说明

攻击特效主要采用“按类型分目录 + 单帧命名”的形式，例如：

```text
assets/art/effects/by_type/fx_slash/slash_01.png
assets/art/effects/by_type/fx_slash/slash_02.png
...
```

这种格式已能被现有代码正确加载为 `AnimatedSprite2D`。`assets/art/sheets/` 下仍保留横向 atlas 源图，后续如果要降低文件数量或优化包体，可以重新整理为 sprite sheet。

## 后续建议

- 统一清理 `generated_missing/` 与最终 `by_type/` 目录之间的重复资源，避免包体膨胀
- 为新增敌人、Boss、地图机制预留独立素材目录
- 发布前检查 Web 包体大小，必要时压缩或合并小图
- 若引入 Spine / Aseprite / TexturePacker 等流程，再更新 `art_requirements.md` 和本文件
