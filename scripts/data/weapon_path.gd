class_name WeaponPath
extends Resource

@export var path_id: StringName
@export var display_name: String
@export_multiline var description: String
@export var icon: Texture2D
@export var levels: Array[WeaponPathLevel] = []

func get_level_effect(target_level: int) -> WeaponPathLevel:
	for lvl in levels:
		if lvl.level == target_level:
			return lvl
	return null
