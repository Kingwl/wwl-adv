extends WeaponBase

const HOLY_RAY_START_TEXTURE := preload("res://assets/art/effects/dynamic/fx_holy_ray_start.png")
const HOLY_RAY_MID_TEXTURE := preload("res://assets/art/effects/dynamic/fx_holy_ray_mid.png")
const HOLY_RAY_END_TEXTURE := preload("res://assets/art/effects/dynamic/fx_holy_ray_end.png")
const HOLY_RAY_DURATION := 0.2
const HOLY_RAY_COLOR := Color(1.0, 0.88, 0.34, 0.72)

func _activate() -> void:
	var player := get_parent().get_parent() as Node2D
	if not player:
		return

	var enemies := get_tree().get_nodes_in_group("enemies")
	if enemies.is_empty():
		return

	var target: Node2D = enemies.pick_random()
	_strike_at(target.global_position)
	_show_visual(target.global_position, player)

func _strike_at(pos: Vector2) -> void:
	var dmg := get_damage()
	var strike_radius := _get_holy_range()
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.global_position.distance_to(pos) <= strike_radius:
			_deal_damage_to(enemy, dmg, DamageEvent.DAMAGE_TYPE_HOLY, DamageEvent.DELIVERY_AREA)
	GameState.heal(_get_heal_amount())

func _get_heal_amount() -> int:
	var heal := weapon_data.heal_amount if weapon_data else 3
	if has_special_tag(&"heal_plus_2"):
		heal += 2
	if has_special_tag(&"heal_plus_3"):
		heal += 3
	if has_special_tag(&"heal_plus_4"):
		heal += 4
	if has_special_tag(&"heal_plus_5"):
		heal += 5
	return heal

func _get_holy_range() -> float:
	var r := get_range()
	if has_special_tag(&"wider_holy"):
		r += 15.0
	return r

func _show_visual(pos: Vector2, player: Node2D) -> void:
	_show_holy_ray(player.global_position, pos)
	VFXHelper.spawn_animated_one_shot(
		player.get_tree().current_scene,
		"res://assets/art/effects/by_type/fx_holy",
		"holy",
		6,
		pos,
		12.0
	)
	# Heal visual on player
	VFXHelper.spawn_animated_one_shot(
		player.get_tree().current_scene,
		"res://assets/art/effects/by_type/fx_regen",
		"regen",
		4,
		player.global_position,
		4.0
	)

func _show_holy_ray(from_pos: Vector2, to_pos: Vector2) -> void:
	var scene := get_tree().current_scene
	if not scene:
		return
	var dir := (to_pos - from_pos).normalized()
	if dir == Vector2.ZERO:
		return

	var dist := from_pos.distance_to(to_pos)
	var ray := Node2D.new()
	ray.name = "HolyPrismRay"
	ray.global_position = from_pos
	ray.rotation = dir.angle()
	ray.z_index = 14
	scene.add_child(ray)

	var start := Sprite2D.new()
	start.name = "HolyRayStart"
	start.texture = HOLY_RAY_START_TEXTURE
	start.position = Vector2(16, 0)
	start.modulate = HOLY_RAY_COLOR
	ray.add_child(start)

	var mid := Sprite2D.new()
	mid.name = "HolyRayMid"
	mid.texture = HOLY_RAY_MID_TEXTURE
	mid.position = Vector2(dist / 2.0, 0)
	mid.scale = Vector2(maxf(dist - 32.0, 1.0) / maxf(float(HOLY_RAY_MID_TEXTURE.get_width()), 1.0), 0.65)
	mid.modulate = HOLY_RAY_COLOR
	ray.add_child(mid)

	var end := Sprite2D.new()
	end.name = "HolyRayEnd"
	end.texture = HOLY_RAY_END_TEXTURE
	end.position = Vector2(maxf(dist - 16.0, 16.0), 0)
	end.modulate = HOLY_RAY_COLOR
	ray.add_child(end)

	var tween := ray.create_tween()
	tween.tween_property(ray, "modulate", Color(1, 1, 1, 0), HOLY_RAY_DURATION)
	tween.tween_callback(ray.queue_free)
