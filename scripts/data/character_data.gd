class_name CharacterData
extends Resource
## 可选角色数据。第一版所有角色默认可选，不包含解锁逻辑。

@export var id: StringName
@export var display_name: String
@export_multiline var description: String
@export var icon: Texture2D
@export var portrait: Texture2D
@export var walk_sheet: Texture2D

@export_group("基础属性")
@export var max_hp: int = 100
@export var move_speed: float = 170.0
@export var pickup_radius_bonus: float = 0.0

@export_group("战斗修正")
@export var exp_gain_multiplier: float = 1.0
@export var incoming_damage_multiplier: float = 1.0
@export var damage_multiplier: float = 1.0
@export var cooldown_multiplier: float = 1.0
@export var area_multiplier: float = 1.0
@export var projectile_cooldown_multiplier: float = 1.0
@export var field_lifetime_multiplier: float = 1.0

@export_group("开局构筑")
@export var starting_weapon_ids: Array[StringName] = [&"melee_basic"]

@export_group("被动")
@export var passive_id: StringName
@export_multiline var passive_description: String
