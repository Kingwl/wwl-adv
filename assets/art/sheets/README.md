# Generated Art Atlases

These atlases were generated with the built-in `imagegen` workflow from `docs/art_requirements.md`.

Each atlas has two versions:

- `*_source.png`: original generated image with pure green chroma-key background.
- `*.png`: processed PNG with the chroma-key background removed to alpha.

## Atlas Files

| File | Covers |
|------|--------|
| `characters_animation_atlas.png` | Player idle/run/hit/death frames and basic enemy walk/hit/death frames |
| `weapon_icons_atlas.png` | Legacy weapon icon concept atlas |
| `../../../tmp/skill_pack_2026/icons/active_weapons/sheet-transparent.png` | Current 20 active weapon icon source sheet, excluded from export |
| `../../../tmp/skill_pack_2026/icons/passive_upgrades/sheet-transparent.png` | Current 10 passive upgrade icon source sheet, excluded from export |
| `combat_effects_projectiles_atlas.png` | Weapon VFX, projectiles, orbit objects, drops, hit flash, death dust, level-up, pickup glow |
| `dynamic_scalable_effects_atlas.png` | Scalable laser, lightning chain, tiled fire/poison fields, and stretchable flame parts |
| `missing_animation_effects_atlas.png` | Source atlas for missing/underfilled projectile, attack, and shared VFX frames |
| `missing_ui_assets_atlas.png` | Source atlas for missing panel, button, bar, HUD icon, stat icon, and level-up glow assets |
| `ui_environment_atlas.png` | Panel, buttons, HP/EXP bars, icons, joystick, weapon slot frames, level-up glow, ground tile/details |
| `generated_atlas_preview.png` | Checkerboard preview of the transparent atlases |
| `dynamic_scalable_effects_preview.png` | Checkerboard preview of the dynamic scalable effects atlas |
| `missing_assets_output_preview.png` | Preview of concrete files generated from `docs/missing_assets.md` |

## Weapon Icon Mapping

`weapon_icons_atlas.png` is the legacy concept atlas. Current runtime weapon and passive icons are documented in `docs/skill_visual_redesign.md`.

Legacy icon order:

| Order | Target file | Weapon |
|-------|-------------|--------|
| 1 | `icon_melee.png` | 利刃 |
| 2 | `icon_projectile.png` | 弓箭 |
| 3 | `icon_thunder.png` | 天雷引 |
| 4 | `icon_orbit.png` | 护盾球 |
| 5 | `icon_thorns.png` | 荆棘护甲 |
| 6 | `icon_regen.png` | 生命源泉强化 |
| 7 | `icon_shotgun.png` | 散弹枪 |
| 8 | `icon_fire_bottle.png` | 火焰瓶 |
| 9 | `icon_frost_ring.png` | 冰霜环 |
| 10 | `icon_holy_prism.png` | 圣光棱镜 |
| 11 | `icon_poison_vial.png` | 毒液罐 |
| 12 | `icon_mine.png` | 地雷 |
| 13 | `icon_laser_pen.png` | 激光笔 |
| 14 | `icon_boomerang.png` | 回旋镖 |
| 15 | `icon_chain.png` | 电磁链 |
| 16 | `icon_saw_blade.png` | 锯片陷阱 |
| 17 | `icon_rocket_pack.png` | 火箭背包 |

The current active weapon redesign adds `whirlwind`, `throwing_axe`, `shockwave`, and `spark_bomb` as independent icons instead of reusing old entries.

## Combat Effect Mapping

`combat_effects_projectiles_atlas.png` contains the attack effects from `docs/art_requirements.md` under "武器攻击特效", plus related projectiles, orbit objects, drops, and shared effects.

Expected attack-effect set:

| Target file | Weapon / Use |
|-------------|--------------|
| `fx_slash_sheet.png` | 利刃斩击 |
| `fx_thunder_sheet.png` | 天雷引落雷 |
| `fx_holy_sheet.png` | 圣光棱镜 |
| `fx_ice_ring_sheet.png` | 冰霜环 |
| `fx_fire_field_sheet.png` | 火焰瓶火场 |
| `fx_poison_field_sheet.png` | 毒液罐毒雾 |
| `fx_mine_blink_sheet.png` | 地雷待机闪烁 |
| `fx_explosion_sheet.png` | 地雷 / 通用爆炸 |
| `fx_laser_sheet.png` | 激光笔 |
| `fx_regen_sheet.png` | 生命源泉强化 |
| `fx_thorns_sheet.png` | 荆棘护甲 |
| `fx_chain_sheet.png` | 电磁链 |
| `fx_rocket_fire_sheet.png` | 火箭背包火焰 |

## Dynamic Scalable Effect Mapping

`dynamic_scalable_effects_atlas.png` supplements `combat_effects_projectiles_atlas.png` for effects that must change length, radius, or covered area at runtime.

Use these assets with runtime composition instead of a single fixed-size sprite:

| Target file | Use | Runtime rule |
|-------------|-----|--------------|
| `fx_laser_start.png` | 激光起点 / 发射口 | Keep original size, rotate with the whole beam |
| `fx_laser_mid.png` | 激光可平铺中段 | Tile or stretch horizontally to match target distance |
| `fx_laser_end.png` | 激光末端 / 命中闪光 | Keep original size at hit point |
| `fx_chain_core.png` | 闪电链沿线小电弧 | Place along a generated `Line2D` zigzag path |
| `fx_chain_node.png` | 闪电链命中节点 | Place at source, bounce targets, and final target |
| `fx_fire_tile_sheet.png` | 火场区域 tile | Tile multiple cells across the damage area; do not stretch one large sprite |
| `fx_poison_tile_sheet.png` | 毒雾区域 tile | Tile multiple cells across the damage area; randomize frame/offset |
| `fx_flame_start.png` | 火箭/喷火起点 | Keep near emitter |
| `fx_flame_mid.png` | 火焰可平铺中段 | Repeat to match flame length |
| `fx_flame_end.png` | 火焰末端消散 | Keep at flame tip |

Assets that need updated slicing from this atlas:

- `fx_laser_sheet.png` should be replaced in runtime use by `fx_laser_start.png`, `fx_laser_mid.png`, and `fx_laser_end.png`.
- `fx_chain_sheet.png` should be supplemented by `fx_chain_core.png` and `fx_chain_node.png`.
- `fx_fire_field_sheet.png` should be supplemented by `fx_fire_tile_sheet.png`.
- `fx_poison_field_sheet.png` should be supplemented by `fx_poison_tile_sheet.png`.
- `fx_rocket_fire_sheet.png` should be supplemented by `fx_flame_start.png`, `fx_flame_mid.png`, and `fx_flame_end.png`.

## Missing Assets Output

The assets requested by `docs/missing_assets.md` were generated from `missing_animation_effects_atlas.png`, `missing_ui_assets_atlas.png`, and `dynamic_scalable_effects_atlas.png`.

Concrete outputs:

| Category | Output location |
|----------|-----------------|
| Boomerang projectile sheet | `assets/art/weapons/projectiles/proj_boomerang_sheet.png` |
| Rebuilt effect sheets | `assets/art/effects/generated_missing/*.png` |
| Supplemental dynamic effect parts | `assets/art/effects/generated_missing/dynamic/*.png` |
| Added by-type effect frames | `assets/art/effects/by_type/fx_*/*.png` |
| UI assets for direct use | `assets/art/ui/*.png` |
| UI generated copies | `assets/art/ui/generated_missing/*.png` |

The by-type directories were only filled where frames were missing; existing frame files were left in place.

## Notes

- These are broad concept atlases, not final frame-perfect sheets.
- Before wiring into Godot scenes, slice the needed regions into exact-size assets from `docs/art_requirements.md`.
- For final `AnimatedSprite2D` usage, prefer tight horizontal sprite sheets with zero frame spacing and exact per-frame dimensions.
- Dynamic/scalable effects should be composed at runtime with `Line2D`, repeated sprites, or three-part sprite assembly instead of being uniformly scaled as one bitmap.
