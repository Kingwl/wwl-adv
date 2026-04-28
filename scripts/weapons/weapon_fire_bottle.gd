extends WeaponBase

func _activate() -> void:
	var player := get_parent().get_parent() as Node2D
	if not player:
		return

	var target := _find_nearest_enemy(player.global_position)
	if not target:
		return

	var field := preload("res://scenes/weapons/fire_field.tscn").instantiate()
	field.global_position = target.global_position
	field.damage = _get_burn_damage()
	field.lifetime = _get_lifetime()
	field.radius = _get_fire_radius()
	var __proj := get_tree().current_scene.get_node_or_null("Projectiles")
	if __proj == null:
		__proj = get_tree().current_scene.find_child("Projectiles", true, false)
	if __proj:
		__proj.add_child(field)

	_show_throw_visual(player.global_position, target.global_position)

func _get_burn_damage() -> int:
	var dmg := get_damage()
	if has_special_tag(&"stronger_burn"):
		dmg += 1
	if has_special_tag(&"inferno_burn"):
		dmg += 2
	return dmg

func _get_lifetime() -> float:
	if has_special_tag(&"eternal_flame"):
		return 5.0
	if has_special_tag(&"longer_burn"):
		return 4.0
	return 3.0

func _get_fire_radius() -> float:
	var r := get_range()
	if has_special_tag(&"wider_fire"):
		r += 20.0
	return r

func _find_nearest_enemy(from_pos: Vector2) -> Node2D:
	var enemies := get_tree().get_nodes_in_group("enemies")
	var nearest: Node2D = null
	var min_dist := INF
	for enemy in enemies:
		var dist := from_pos.distance_to(enemy.global_position)
		if dist < min_dist:
			min_dist = dist
			nearest = enemy
	return nearest

func _show_throw_visual(from_pos: Vector2, to_pos: Vector2) -> void:
	VFXHelper.spawn_animated_trail(
		get_tree().current_scene,
		"res://assets/art/effects/by_type/fx_fire_trail",
		"fire_trail",
		2,
		from_pos,
		to_pos,
		10.0,
		24.0,
		0.25
	)
