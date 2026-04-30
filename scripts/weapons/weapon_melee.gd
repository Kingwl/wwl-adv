extends WeaponBase

const SECTOR_ANGLE := deg_to_rad(90.0)
const SLASH_EFFECT_BASE_RADIUS := 80.0
const SLASH_EFFECT_OUTER_FRAME_RADIUS := 64.0
const SLASH_EFFECT_ARC_SEGMENTS := 18
const SLASH_EFFECT_DURATION := 5.0 / 12.0
const SLASH_EFFECT_FILL_COLOR := Color(1.0, 0.78, 0.12, 0.16)
const SLASH_EFFECT_EDGE_COLOR := Color(1.0, 0.96, 0.25, 0.72)

var _active_attack_windows: Array[Dictionary] = []

func _process(delta: float) -> void:
	super._process(delta)
	_update_attack_windows(delta)

func _activate() -> void:
	var player := get_parent().get_parent() as Node2D
	if not player:
		return

	var target := _find_closest_enemy(player)
	var attack_dir := Vector2.RIGHT
	if target:
		attack_dir = (target.global_position - player.global_position).normalized()

	_show_slash_effect(player, attack_dir)
	_start_attack_window(player, attack_dir)

func _start_attack_window(player: Node2D, attack_dir: Vector2) -> void:
	_active_attack_windows.append({
		"attack_shape": _get_attack_shape(player, attack_dir),
		"remaining": SLASH_EFFECT_DURATION,
		"damage": _get_final_damage(),
		"strikes": _get_strike_count(),
		"hit_ids": [],
	})
	_update_attack_windows(0.0)

func _update_attack_windows(delta: float) -> void:
	if _active_attack_windows.is_empty():
		return

	for i in range(_active_attack_windows.size() - 1, -1, -1):
		var window := _active_attack_windows[i]
		_apply_attack_window(window)
		window["remaining"] = float(window["remaining"]) - delta
		if float(window["remaining"]) <= 0.0:
			_active_attack_windows.remove_at(i)
		else:
			_active_attack_windows[i] = window

func _apply_attack_window(window: Dictionary) -> void:
	var attack_shape: Dictionary = window["attack_shape"]
	var hit_ids: Array = window["hit_ids"]
	var dmg := int(window["damage"])
	var strikes := int(window["strikes"])

	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy is CharacterBody2D:
			var e := enemy as Node2D
			var enemy_id := e.get_instance_id()
			if enemy_id in hit_ids:
				continue
			if _is_point_in_attack_shape(e.global_position, attack_shape):
				_apply_hit_to_enemy(e, dmg, strikes, attack_shape["origin"])
				hit_ids.append(enemy_id)
	window["hit_ids"] = hit_ids

func _deal_sector_damage(player: Node2D, attack_dir: Vector2) -> void:
	var attack_shape := _get_attack_shape(player, attack_dir)
	var dmg := _get_final_damage()
	var strikes := _get_strike_count()

	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy is CharacterBody2D:
			var e := enemy as Node2D
			if _is_point_in_attack_shape(e.global_position, attack_shape):
				_apply_hit_to_enemy(e, dmg, strikes, attack_shape["origin"])

func _apply_hit_to_enemy(enemy: Node2D, dmg: int, strikes: int, from_pos: Vector2) -> void:
	for i in range(strikes):
		enemy.take_damage(dmg)
	if has_special_tag(&"heal_on_hit_boost"):
		GameState.heal(5)
	elif has_special_tag(&"heal_on_hit"):
		GameState.heal(2)
	if has_special_tag(&"knockback"):
		_knockback(enemy, from_pos)

func _get_sector_angle() -> float:
	var base := SECTOR_ANGLE
	if has_special_tag(&"widest_arc"):
		return deg_to_rad(180.0)
	if has_special_tag(&"wider_arc"):
		return deg_to_rad(135.0)
	return base

func _get_attack_shape(player: Node2D, attack_dir: Vector2) -> Dictionary:
	return {
		"origin": player.global_position,
		"direction": _get_normalized_attack_dir(attack_dir),
		"radius": get_range(),
		"sector_angle": _get_sector_angle(),
	}

func _get_normalized_attack_dir(attack_dir: Vector2) -> Vector2:
	var dir := attack_dir.normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT
	return dir

func _is_point_in_attack_shape(point: Vector2, attack_shape: Dictionary) -> bool:
	var origin: Vector2 = attack_shape["origin"]
	var direction: Vector2 = attack_shape["direction"]
	var radius := float(attack_shape["radius"])
	var sector_angle := float(attack_shape["sector_angle"])
	var to_point := point - origin
	if to_point.length_squared() > radius * radius:
		return false
	if to_point == Vector2.ZERO:
		return true
	return abs(to_point.angle_to(direction)) <= sector_angle / 2.0

func _get_final_damage() -> int:
	var dmg := get_damage()
	if has_special_tag(&"full_hp_bonus"):
		var player := get_tree().get_first_node_in_group("player")
		if player and GameState.run.hp >= GameState.run.max_hp:
			dmg *= 2
	if has_special_tag(&"crit_bonus"):
		dmg = int(round(float(dmg) * 1.35))
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
	var parent: Node = player.get_tree().current_scene
	if not parent:
		parent = player.get_parent()
	if not parent:
		return

	var attack_shape := _get_attack_shape(player, attack_dir)
	var container := Node2D.new()
	container.name = "MeleeSlashEffect"
	container.global_position = attack_shape["origin"]
	var direction: Vector2 = attack_shape["direction"]
	container.rotation = direction.angle()
	container.z_index = 15
	parent.add_child(container)

	_add_slash_sector_visual(container, attack_shape)
	_add_slash_arc_animation(container, attack_shape)

	var tween := container.create_tween()
	tween.tween_property(container, "modulate", Color(1.0, 1.0, 1.0, 0.0), SLASH_EFFECT_DURATION)
	tween.tween_callback(container.queue_free)

func _add_slash_sector_visual(container: Node2D, attack_shape: Dictionary) -> void:
	var polygon := Polygon2D.new()
	polygon.name = "DamageSector"
	polygon.polygon = _build_slash_sector_points(float(attack_shape["radius"]), float(attack_shape["sector_angle"]))
	polygon.color = SLASH_EFFECT_FILL_COLOR
	container.add_child(polygon)

	var arc := Line2D.new()
	arc.name = "DamageSectorArc"
	arc.points = _build_slash_arc_points(float(attack_shape["radius"]), float(attack_shape["sector_angle"]))
	arc.width = maxf(4.0, float(attack_shape["radius"]) * 0.06)
	arc.default_color = SLASH_EFFECT_EDGE_COLOR
	arc.z_index = 1
	container.add_child(arc)

func _add_slash_arc_animation(container: Node2D, attack_shape: Dictionary) -> void:
	var anim := AnimatedSprite2D.new()
	anim.name = "SlashArc"
	anim.sprite_frames = VFXHelper.build_sprite_frames(
		"res://assets/art/effects/by_type/fx_slash",
		"slash",
		5,
		12.0,
		false
	)
	anim.position = _get_slash_arc_position(attack_shape)
	anim.scale = _get_slash_effect_scale()
	anim.z_index = 2
	container.add_child(anim)
	anim.play("default")

func _get_slash_effect_position(player_position: Vector2, attack_dir: Vector2) -> Vector2:
	return player_position

func _get_slash_effect_scale() -> Vector2:
	var scale_factor: float = maxf(1.0, get_range() / SLASH_EFFECT_BASE_RADIUS)
	return Vector2(scale_factor, scale_factor)

func _get_slash_effect_rotation(attack_dir: Vector2) -> float:
	return _get_normalized_attack_dir(attack_dir).angle()

func _get_slash_arc_position(attack_shape: Dictionary) -> Vector2:
	var radius := float(attack_shape["radius"])
	var scale_factor := _get_slash_effect_scale().x
	return Vector2(radius - SLASH_EFFECT_OUTER_FRAME_RADIUS * scale_factor, 0.0)

func _build_slash_sector_points(radius: float, sector_angle: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	points.append(Vector2.ZERO)
	for point in _build_slash_arc_points(radius, sector_angle):
		points.append(point)
	return points

func _build_slash_arc_points(radius: float, sector_angle: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	var half_sector := sector_angle / 2.0
	for i in range(SLASH_EFFECT_ARC_SEGMENTS + 1):
		var t := float(i) / float(SLASH_EFFECT_ARC_SEGMENTS)
		var angle := lerpf(-half_sector, half_sector, t)
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points

func _find_closest_enemy(player: Node2D) -> Node2D:
	var closest: Node2D = null
	var best := INF
	for enemy in get_tree().get_nodes_in_group("enemies"):
		var d := player.global_position.distance_squared_to(enemy.global_position)
		if d < best:
			best = d
			closest = enemy
	return closest
