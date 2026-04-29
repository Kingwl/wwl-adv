# WWL Adventure — 项目里程碑

> 每次有重要进展（新增系统、完成阶段性目标、通过关键测试）时更新此文件。
> 规则见 `agents.md`。

---

## 已完成

### 核心玩法
- [x] 玩家移动（WASD / 方向键 / 虚拟摇杆）
- [x] 玩家受击、闪白反馈、死亡结算
- [x] 敌人基础追踪 AI
- [x] 敌人波次生成器
- [x] 经验 / 金币掉落与拾取
- [x] 升级三选一（角色强化 + 武器解锁 + 武器强化 + 流派）
- [x] 游戏时间 / 击杀数统计
- [x] 暂停菜单 + 武器 / 强化槽位展示
- [x] 游戏结束画面（时间、击杀）
- [x] 主菜单 → 游戏流程
- [x] 本地数值存档（累计金币、累计击杀、最佳成绩）
- [x] 多角色系统（4 个默认可选角色，不含解锁）

### 武器系统（16 种）
- [x] 近战武器（weapon_melee）
- [x] 远程弹体（weapon_projectile）
- [x] 落雷（weapon_thunder）
- [x] 环绕球（weapon_orbit）
- [x] 荆棘反伤（weapon_thorns）
- [x] 火焰瓶（weapon_fire_bottle）
- [x] 冰冻环（weapon_frost_ring）
- [x] 圣棱镜（weapon_holy_prism）
- [x] 毒药瓶（weapon_poison_vial）
- [x] 地雷陷阱（weapon_mine）
- [x] 激光笔（weapon_laser_pen）
- [x] 霰弹枪（weapon_shotgun）
- [x] 回旋镖（weapon_boomerang）
- [x] 电磁链（weapon_electromagnetic_chain）
- [x] 锯刃（weapon_saw_blade）
- [x] 火箭背包（weapon_rocket_pack）
- [x] 所有武器统一继承 WeaponBase
- [x] 每种武器均有独立 `.tscn` 场景
- [x] 升级解锁 / 强化 / 流派机制（UpgradeSystem）
- [x] 生命源泉改为角色被动恢复强化，不占武器槽

### 美术资源集成
- [x] 玩家角色帧动画（idle / run，64×64）
- [x] 敌人帧动画（walk / hit / death）
- [x] 全部武器特效替换为 Sprite2D / AnimatedSprite2D（取代 Polygon2D / Line2D / ColorRect）
- [x] 多帧攻击特效使用 AnimatedSprite2D 播放帧动画（slash / thunder / holy / chain / thorns / saw / orb / fire_field / mine_blink / trail）
- [x] 全部子弹 / 投射物替换为 Sprite2D
- [x] 经验球、金币替换为 Sprite2D
- [x] 武器图标替换为 sliced icons（16 种武器 + 角色强化图标）
- [x] 虚拟摇杆替换为 TextureRect（joystick_base / joystick_knob）
- [x] 背景替换为 TextureRect（ground_tile）
- [x] 所有资源按最终显示尺寸绘制，无运行时 scale
- [x] 缺失素材生成并落盘（回旋镖、补帧特效、动态缩放特效、UI 元素、属性升级图标）
- [x] HUD 血条 / 经验条使用 StyleBoxTexture（hp_bar_fill / exp_bar_fill）
- [x] HUD 金币、心形图标（icon_gold / icon_heart）
- [x] HUD 武器栏显示图标（取代文字）
- [x] 升级卡片属性选项显示图标（icon_stat_upgrade.png）
- [x] 游戏结束画面武器栏显示图标
- [x] 激光笔射线三段式动态拼接（start / mid / end）
- [x] 电磁链程序化折线 + 节点装饰（Line2D + chain_core / chain_node）
- [x] 火场 / 毒雾区域 tile 平铺（fx_fire_tile_sheet / fx_poison_tile_sheet）
- [x] 近战斩击方向 / 位置修正，并改为 fx_slash 5 帧动画
- [x] 地雷爆炸、冰冻环、激光、火箭背包、圣棱镜特效对齐现有帧动画 / 分段素材
- [x] UI 面板背景贴图化（panel_bg.png）
- [x] UI 按钮贴图化（button_normal / hover / pressed）
- [x] 主菜单背景替换为 ground_tile.png 平铺
- [x] 主菜单角色选择面板
- [x] 4 个默认职业专属头像与四向行走动画 sheet
- [x] 主菜单全局金币展示
- [x] HUD 1x / 2x 倍速切换
- [x] 武器分类标签在 UI 中显示（攻击 / 防御 / 增益）
- [x] 升级选择支持刷新全部卡片和跳过本次选择
- [x] 武器槽与角色强化槽拆分为 6 + 6
- [x] Web UI 中文字体打包、CI 自动子集化与运行时 fallback 主题注入
- [x] GitHub Actions Web 导出与 GitHub Pages 自动部署 workflow

### 测试与质量
- [x] 自动化集成测试框架（headless Godot）
- [x] 场景加载验证（Player / HUD / UI）
- [x] 升级系统测试（选项生成、点击、效果生效）
- [x] 每种武器增加 + 使用测试（16 种全覆盖），生命源泉覆盖为被动强化测试
- [x] 暂停菜单测试（显示 / 恢复 / 武器和强化槽位）
- [x] 游戏结束测试（结算数据）
- [x] 相机跟随验证
- [x] 武器动效视觉结构测试（斩击、场地 tile、爆炸帧、冰环、激光、火箭背包、圣棱镜、弹体朝向）
- [x] 武器栏回归测试（电磁链、火箭背包解锁后进入 HUD 装备栏）
- [x] 玩家受伤回归测试（无敌帧结束后恢复受伤，敌人重叠接触会持续扣血）

---

## 待完成

### 核心体验
- [ ] 音效系统（攻击、受击、升级、背景音乐）
- [ ] 设置页与设置持久化
- [ ] 移动端适配（触屏攻击按钮、UI 安全区）

### 内容扩展
- [ ] 敌人数据资源文件化（.tres）
- [ ] 更多敌人类型（不同速度 / 血量 / 行为）
- [ ] Boss 战设计
- [ ] 更多关卡 / 地图机制

### 美术素材
- [x] 详见 [`docs/missing_assets.md`](./missing_assets.md) — 已补齐素材记录与后续优化建议

### 系统打磨
- [x] 升级选项去重（同一轮不重复出现同武器）
- [x] 升级 bonus（damage_bonus / cooldown_bonus / range_bonus）真正生效
- [x] 武器等级上限 max_level 真正生效
- [x] 武器分类标签（攻击 / 防御 / 增益）在升级 / 暂停 / 结算 / 属性 UI 中体现
- [ ] 武器组合 / 联动系统（暂不实现，预留扩展）

### 性能与发布
- [x] Web 导出优化（字体子集化、排除测试 / 预览资源，当前 Web 包体约 41M）
- [ ] Android / iOS 导出配置
- [ ] 发热与帧率测试

---

## 统计

| 指标 | 数值 |
|------|------|
| 武器种类 | 16 |
| 角色数量 | 4（全部默认可选） |
| 敌人类型 | 1（基础追踪型，未资源化） |
| UI 场景 | 8 |
| 自动化测试 | 529 passed, 0 failed |
| HUD 冷却遮罩 | 高度连续变化 |
| 引擎版本 | Godot 4.x（最近测试 4.6.2，GL Compatibility） |
| 目标平台 | Web / Android / iOS |
| Web 导出体积 | 约 41M（index.wasm 36M，index.pck 5.1M） |
