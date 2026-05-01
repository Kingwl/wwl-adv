class_name UpgradeData
extends Resource
## 升级数据。定义升级选项的属性。

enum UpgradeType { WEAPON_UNLOCK, WEAPON_LEVEL, WEAPON_PATH, PLAYER_STAT }

@export var id: StringName
@export var display_name: String
@export_multiline var description: String
@export var upgrade_type: UpgradeType = UpgradeType.WEAPON_LEVEL
@export var icon: Texture2D
## 路线方向标签。主要用于武器流派卡，例如：强击、扩散、疾速、控制。
@export var build_tags: Array[String] = []

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
