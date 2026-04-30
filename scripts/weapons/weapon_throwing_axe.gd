extends WeaponBase

const AXE_TEXTURE := preload("res://assets/art/weapons/projectiles/throwing_axe.png")
const AXE_SPIN_SPEED := TAU * 3.5
const SPREAD_STEP := deg_to_rad(12.0)

func _activate() -> void:
	var player := get_parent().get_parent() as Node2D
	if not player:
		return

	var target := _find_nearest_enemy(player.global_position)
	if not target:
		return

	var count := _get_axe_count()
	var base_dir := (target.global_position - player.global_position).normalized()
	for i in range(count):
		var dir := base_dir
		if count > 1:
			dir = base_dir.rotated(SPREAD_STEP * (i - (count - 1) / 2.0))
		_spawn_axe(player.global_position, dir)

func _spawn_axe(pos: Vector2, dir: Vector2) -> void:
	var projectile := preload("res://scenes/weapons/projectile.tscn").instantiate()
	projectile.global_position = pos
	projectile.direction = dir
	projectile.speed = _get_axe_speed()
	projectile.damage = _get_final_damage()
	projectile.max_range = get_range()
	projectile.pierce = _get_pierce_count()
	projectile.is_boomerang = _should_return()
	projectile.visual_texture = AXE_TEXTURE
	projectile.visual_rotation_offset = 0.0
	projectile.visual_spin_speed = AXE_SPIN_SPEED
	projectile.visual_modulate = Color(1.0, 0.92, 0.78, 1.0)
	var projectiles := _get_projectiles_parent()
	if projectiles:
		projectiles.add_child(projectile)

func _get_final_damage() -> int:
	var dmg := get_damage()
	if has_special_tag(&"axe_heavy"):
		dmg = int(round(float(dmg) * 1.25))
	return dmg

func _get_axe_count() -> int:
	var count := maxi(1, weapon_data.projectile_count if weapon_data else 1)
	if has_special_tag(&"dual_axe"):
		count += 1
	if has_special_tag(&"triple_axe"):
		count += 2
	return count

func _get_pierce_count() -> int:
	var p := weapon_data.pierce if weapon_data else 1
	if has_special_tag(&"axe_pierce_1"):
		p += 1
	if has_special_tag(&"axe_pierce_2"):
		p += 2
	if has_special_tag(&"axe_cleaver"):
		p += 3
	return p

func _get_axe_speed() -> float:
	var speed := weapon_data.projectile_speed if weapon_data else 260.0
	if has_special_tag(&"axe_fast"):
		speed += 60.0
	if has_special_tag(&"storm_axe"):
		speed += 80.0
	return speed

func _should_return() -> bool:
	return has_special_tag(&"returning_axe") or has_special_tag(&"storm_axe")

func _get_projectiles_parent() -> Node:
	var current := get_tree().current_scene
	if not current:
		return null
	var projectiles := current.get_node_or_null("Projectiles")
	if not projectiles:
		projectiles = current.find_child("Projectiles", true, false)
	return projectiles

func _find_nearest_enemy(from_pos: Vector2) -> Node2D:
	var nearest: Node2D = null
	var min_dist := INF
	for enemy in get_tree().get_nodes_in_group("enemies"):
		var dist := from_pos.distance_to(enemy.global_position)
		if dist < min_dist:
			min_dist = dist
			nearest = enemy
	return nearest
