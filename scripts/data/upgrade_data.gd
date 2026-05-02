class_name UpgradeData
extends Resource
## 升级数据。定义升级选项的属性。

enum UpgradeType { WEAPON_UNLOCK, WEAPON_LEVEL, WEAPON_PATH, PLAYER_STAT }

@export var id: StringName
@export var display_name: String
@export_multiline var description: String
@export var upgrade_type: UpgradeType = UpgradeType.WEAPON_LEVEL
@export var icon: Texture2D
## 卡片展示标签。武器解锁卡使用构筑标签，武器流派卡使用路线标签。
@export var build_tags: Array[String] = []
## 构筑共鸣变化预览；部分标签已接入战斗奖励，其余标签只展示贡献和进度。
@export_multiline var resonance_preview: String = ""
## 额外选择提示备用字段。当前卡片默认不展示，避免重复解释。
@export_multiline var choice_hint: String = ""

@export_group("效果")
## 关联的武器ID（武器解锁/升级时必填）
@export var weapon_id: StringName
## 流派ID（WEAPON_PATH 类型时必填）
@export var path_id: StringName
## 效果数值
@export var damage_bonus: int = 0
@export var cooldown_bonus: float = 0.0
@export var range_bonus: float = 0.0
@export var speed_bonus: float = 0.0
@export var hp_bonus: int = 0
@export var max_hp_bonus: int = 0
@export var pickup_radius_bonus: float = 0.0
@export var damage_multiplier_bonus: float = 0.0
@export var cooldown_multiplier_bonus: float = 0.0
@export var area_multiplier_bonus: float = 0.0
@export var field_lifetime_multiplier_bonus: float = 0.0
@export var incoming_damage_multiplier_bonus: float = 0.0
@export var exp_gain_multiplier_bonus: float = 0.0
