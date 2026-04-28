extends WeaponBase

var _heal_counter: int = 0

func _activate() -> void:
	var heal := _get_heal()
	if has_special_tag(&"burst_heal"):
		_heal_counter += 1
		if _heal_counter >= 3:
			heal += 5
			_heal_counter = 0
	GameState.heal(heal)
	_show_regen_visual()

func _get_heal() -> int:
	var heal := weapon_data.heal_amount if weapon_data else 5
	if has_special_tag(&"heal_plus_2"):
		heal += 2
	if has_special_tag(&"heal_plus_3"):
		heal += 3
	if has_special_tag(&"heal_plus_4"):
		heal += 4
	if has_special_tag(&"heal_plus_5"):
		heal += 5
	return heal

func _on_level_up() -> void:
	if has_special_tag(&"regen_max_hp"):
		GameState.run.max_hp += 10
		GameState.hp_changed.emit(GameState.run.hp, GameState.run.max_hp)

func _show_regen_visual() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if not player:
		return
	VFXHelper.spawn_animated_one_shot(
		player.get_tree().current_scene,
		"res://assets/art/effects/by_type/fx_regen",
		"regen",
		4,
		player.global_position,
		4.0
	)
