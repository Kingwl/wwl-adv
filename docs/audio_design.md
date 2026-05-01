# 音效设计

## 当前策略

- 第一阶段只接武器 SFX，不接 BGM、UI、受击、拾取和升级。
- 武器音效按“实际出手 / 产生有效特效”触发，不在冷却 tick 统一播放，避免没目标也响。
- 常驻型武器的 loop 素材先作为低音量生成 / 刷新提示使用，不做持续循环，避免吸血鬼 like 多武器场景下声场过满。
- 音效由 `AudioManager` 统一管理，使用 12 路 `AudioStreamPlayer` 池、武器级最小播放间隔和轻微 pitch 浮动。
- 武器 SFX 以 PCM WAV 入库，`AudioManager` 优先通过 `ResourceLoader` 读取 Godot 导入后的 `AudioStream`，并缓存播放；仅在本地原始文件场景下 fallback 解析 WAV。Web 导出不能依赖 `FileAccess` 读取原始音频文件。

## 武器映射

| 武器 | 触发点 | 音效文件 |
|---|---|---|
| 基础利刃 | 近战挥砍窗口开始 | `assets/audio/sfx/weapons/melee_basic.wav` |
| 弓箭精通 | 找到目标并发射箭矢 | `assets/audio/sfx/weapons/projectile_basic.wav` |
| 天雷引 | 生成雷击前 | `assets/audio/sfx/weapons/thunder.wav` |
| 护盾球 | 生成 / 重建护盾球 | `assets/audio/sfx/weapons/orbit.wav` |
| 荆棘护甲 | 玩家受伤并触发反击 | `assets/audio/sfx/weapons/thorns.wav` |
| 散弹枪 | 找到目标并发射弹幕 | `assets/audio/sfx/weapons/shotgun.wav` |
| 火焰瓶 | 火焰区域落地生成 | `assets/audio/sfx/weapons/fire_bottle.wav` |
| 冰霜环 | 冰环扩散生成 | `assets/audio/sfx/weapons/frost_ring.wav` |
| 圣光棱镜 | 圣光光束发射 | `assets/audio/sfx/weapons/holy_prism.wav` |
| 毒液罐 | 毒雾区域落地生成 | `assets/audio/sfx/weapons/poison_vial.wav` |
| 地雷 | 地雷被敌人触发爆炸 | `assets/audio/sfx/weapons/mine.wav` |
| 激光笔 | 光束发射 | `assets/audio/sfx/weapons/laser_pen.wav` |
| 回旋镖 | 找到目标并掷出 | `assets/audio/sfx/weapons/boomerang.wav` |
| 电磁链 | 首次命中并开始连锁 | `assets/audio/sfx/weapons/electromagnetic_chain.wav` |
| 锯片陷阱 | 部署 / 重建锯片 | `assets/audio/sfx/weapons/saw_blade.wav` |
| 火箭背包 | 移动中喷焰生成火场 | `assets/audio/sfx/weapons/rocket_pack.wav` |
| 旋风斩 | 旋风斩特效展开 | `assets/audio/sfx/weapons/whirlwind.wav` |
| 投掷斧 | 找到目标并掷出 | `assets/audio/sfx/weapons/throwing_axe.wav` |
| 冲击波 | 冲击波扩散生成 | `assets/audio/sfx/weapons/shockwave.wav` |
| 火花弹 | 电火花弹发射 | `assets/audio/sfx/weapons/spark_bomb.wav` |

## 后续

- UI：按钮、升级、选择卡片、结算。
- 反馈：玩家受击、死亡、回血、拾取金币 / 经验。
- 混音：独立 SFX / UI / BGM bus，增加音量设置和静音开关。
- 真机：移动端同时播放数、延迟和 Web autoplay 限制验证。
