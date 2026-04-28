extends WeaponBase

const SECTOR_ANGLE := deg_to_rad(90.0)
const SLASH_EFFECT_ROTATION_OFFSET := 0.0
const SLASH_EFFECT_BASE_RADIUS := 60.0

func _activate() -> void:
	var player := get_parent().get_parent() as Node2D
	if not player:
		return

	var target := _find_closest_enemy(player)
	var attack_dir := Vector2.RIGHT
	if target:
		attack_dir = (target.global_position - player.global_position).normalized()

	_show_slash_effect(player, attack_dir)
	_deal_sector_damage(player, attack_dir)

func _deal_sector_damage(player: Node2D, attack_dir: Vector2) -> void:
	var sector := _get_sector_angle()
	var half_sector := sector / 2.0
	var range_sq := get_range() * get_range()
	var dmg := _get_final_damage()
	var strikes := _get_strike_count()

	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy is CharacterBody2D:
			var e := enemy as Node2D
			var to_enemy: Vector2 = e.global_position - player.global_position
			var dist_sq: float = to_enemy.length_squared()
			if dist_sq > range_sq:
				continue
			var angle_diff: float = abs(to_enemy.angle_to(attack_dir))
			if angle_diff <= half_sector:
				for i in range(strikes):
					e.take_damage(dmg)
				if has_special_tag(&"heal_on_hit_boost"):
					GameState.heal(5)
				elif has_special_tag(&"heal_on_hit"):
					GameState.heal(2)
				if has_special_tag(&"knockback"):
					_knockback(e, player.global_position)

func _get_sector_angle() -> float:
	var base := SECTOR_ANGLE
	if has_special_tag(&"widest_arc"):
		return deg_to_rad(180.0)
	if has_special_tag(&"wider_arc"):
		return deg_to_rad(135.0)
	return base

func _get_final_damage() -> int:
	var dmg := get_damage()
	if has_special_tag(&"full_hp_bonus"):
		var player := get_tree().get_first_node_in_group("player")
		if player and GameState.run.hp >= GameState.run.max_hp:
			dmg *= 2
	return dmg

func _get_strike_count() -> int:
	if has_special_tag(&"triple_strike"):
		return 3
	if has_special_tag(&"double_strike"):
		return 2
	return 1

func _knockback(enemy: Node2D, from_pos: Vector2) -> void:
	if enemy is CharacterBody2D:
		var push_dir := (enemy.global_position - from_pos).normalized()
		enemy.velocity = push_dir * 200.0
		enemy.move_and_slide()

func _show_slash_effect(player: Node2D, attack_dir: Vector2) -> void:
	var anim := VFXHelper.spawn_animated_one_shot(
		player.get_tree().current_scene,
		"res://assets/art/effects/by_type/fx_slash",
			"slash",
			5,
			_get_slash_effect_position(player.global_position, attack_dir),
			12.0,
			_get_slash_effect_scale()
	)
	anim.name = "MeleeSlashEffect"
	anim.rotation = _get_slash_effect_rotation(attack_dir)

func _get_slash_effect_position(player_position: Vector2, _attack_dir: Vector2) -> Vector2:
	return player_position

func _get_slash_effect_scale() -> Vector2:
	var scale_factor: float = maxf(1.0, get_range() / SLASH_EFFECT_BASE_RADIUS)
	return Vector2(scale_factor, scale_factor)

func _get_slash_effect_rotation(attack_dir: Vector2) -> float:
	var dir := attack_dir.normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT
	return dir.angle() + SLASH_EFFECT_ROTATION_OFFSET

func _find_closest_enemy(player: Node2D) -> Node2D:
	var closest: Node2D = null
	var best := INF
	for enemy in get_tree().get_nodes_in_group("enemies"):
		var d := player.global_position.distance_squared_to(enemy.global_position)
		if d < best:
			best = d
			closest = enemy
	return closest
