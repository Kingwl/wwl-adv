class_name WeaponPath
extends Resource

@export var path_id: StringName
@export var display_name: String
@export_multiline var description: String
## 路线主轴，用于升级卡标签和后续构筑奖励。
## 统一取值：强击 / 扩散 / 疾速 / 穿透 / 控制 / 守护 / 持续。
@export var primary_build_tag: StringName
@export var build_tags: Array[StringName] = []
@export var icon: Texture2D
@export var levels: Array[WeaponPathLevel] = []

func get_level_effect(target_level: int) -> WeaponPathLevel:
	for lvl in levels:
		if lvl.level == target_level:
			return lvl
	return null

func get_level_effects_up_to(target_level: int) -> Array[WeaponPathLevel]:
	var result: Array[WeaponPathLevel] = []
	for lvl in levels:
		if lvl and lvl.level <= target_level:
			result.append(lvl)
	return result
