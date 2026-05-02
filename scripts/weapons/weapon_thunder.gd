extends WeaponBase

func _activate() -> void:
	var player := get_parent().get_parent() as Node2D
	if not player:
		return

	var enemies := get_tree().get_nodes_in_group("enemies")
	if enemies.is_empty():
		return

	_play_sfx()
	var strikes := _get_strike_count()
	for i in range(strikes):
		var target: Node2D = enemies.pick_random()
		_strike_at(target.global_position)
		_show_visual(target.global_position, player)
		if has_special_tag(&"chain_zap"):
			_chain_zap(target.global_position, player)

func _strike_at(pos: Vector2) -> void:
	var dmg := get_damage()
	var strike_radius := get_range()
	for enemy in get_tree().get_nodes_in_group("enemies"):
			if enemy.global_position.distance_to(pos) <= strike_radius:
				_deal_damage_to(enemy, dmg, DamageEvent.DAMAGE_TYPE_LIGHTNING, DamageEvent.DELIVERY_AREA)
				if has_special_tag(&"thunder_slow"):
					_apply_status_to(enemy, &"slow", 1.0, 0.5)
				if has_special_tag(&"thunder_paralyze"):
					_apply_status_to(enemy, &"stun", 0.3, 0.0)

func _chain_zap(origin_pos: Vector2, player: Node2D) -> void:
	var chain_radius := get_range() * 2.0
	var closest: Node2D = null
	var best := INF
	for enemy in get_tree().get_nodes_in_group("enemies"):
		var d: float = enemy.global_position.distance_squared_to(origin_pos)
		if d < best and d > 1.0:
			best = d
			closest = enemy
	if closest and closest.global_position.distance_to(origin_pos) <= chain_radius:
		_show_visual(closest.global_position, player)
		_strike_at(closest.global_position)

func _get_strike_count() -> int:
	if has_special_tag(&"triple_strike"):
		return 3
	if has_special_tag(&"double_strike"):
		return 2
	return 1

func _show_visual(pos: Vector2, player: Node2D) -> void:
	VFXHelper.spawn_animated_one_shot(
		player.get_tree().current_scene,
		"res://assets/art/effects/by_type/fx_thunder",
		"thunder",
		6,
		pos,
		12.0
	)
