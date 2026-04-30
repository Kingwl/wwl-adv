extends WeaponBase

var _last_hp: int = 0

func _ready() -> void:
	super._ready()
	GameState.hp_changed.connect(_on_hp_changed)
	_last_hp = GameState.run.hp

func _process(_delta: float) -> void:
	pass

func _on_hp_changed(current: int, _max_hp: int) -> void:
	if _last_hp == 0:
		_last_hp = current
		return
	if current < _last_hp:
		var damage_taken := _last_hp - current
		var reflect_percent := _get_reflect_percent()
		var reflect_damage := int(damage_taken * reflect_percent) + _get_thorns_damage_bonus()
		_reflect_damage(reflect_damage)
		_show_thorns_visual()
		if has_special_tag(&"thorns_heal") or has_special_tag(&"thorns_vengeance"):
			var heal_amount := 1
			if has_special_tag(&"thorns_vengeance"):
				heal_amount = 2
			GameState.heal(heal_amount)
	_last_hp = current

func _get_reflect_percent() -> float:
	var p := weapon_data.reflect_percent if weapon_data else 0.5
	if has_special_tag(&"reflect_plus_10"):
		p += 0.1
	return min(p, 1.0)

func _get_thorns_damage_bonus() -> int:
	var bonus := 0
	if has_special_tag(&"thorns_damage"):
		bonus += 2
	return bonus

func _reflect_damage(dmg: int) -> void:
	var player := get_tree().get_first_node_in_group("player")
	if not player:
		return
	var radius := _get_thorns_range()
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.global_position.distance_to(player.global_position) <= radius:
			_deal_damage_to(enemy, dmg, DamageEvent.DAMAGE_TYPE_PHYSICAL, DamageEvent.DELIVERY_REFLECT)
			VFXHelper.spawn_animated_one_shot(
				player.get_tree().current_scene,
				"res://assets/art/effects/by_type/fx_thorns",
				"thorns",
				4,
				enemy.global_position,
				6.0
			)

func _get_thorns_range() -> float:
	var r := get_range()
	if has_special_tag(&"wider_thorns"):
		r += 15.0
	return r

func get_cooldown_progress() -> float:
	return 0.0

func _show_thorns_visual() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if not player:
		return
	VFXHelper.spawn_animated_one_shot(
		player.get_tree().current_scene,
		"res://assets/art/effects/by_type/fx_thorns",
		"thorns",
		4,
		player.global_position,
		12.0
	)
