extends WeaponBase

const SPARK_FX_PATH := "res://assets/art/weapons/projectiles"
const SPARK_FX_PREFIX := "spark_bomb"
const SPARK_FRAME_COUNT := 4
const SPARK_SPIN_SPEED := TAU * 2.0

func _activate() -> void:
	var player := get_parent().get_parent() as Node2D
	if not player:
		return

	var target := _find_nearest_enemy(player.global_position)
	if not target:
		return

	var projectiles := _get_projectiles_parent()
	if not projectiles:
		return

	var count := _get_projectile_count()
	var base_dir := (target.global_position - player.global_position).normalized()
	var spread := deg_to_rad(14.0)
	for i in range(count):
		var projectile := preload("res://scenes/weapons/projectile.tscn").instantiate()
		projectile.global_position = player.global_position
		var dir := base_dir
		if count > 1:
			dir = base_dir.rotated(spread * (i - (count - 1) / 2.0))
		projectile.direction = dir
		projectile.speed = _get_spark_speed()
		projectile.damage = _get_final_damage()
		projectile.max_range = get_range()
		projectile.pierce = 0
		projectile.visual_sprite_frames = VFXHelper.build_sprite_frames(SPARK_FX_PATH, SPARK_FX_PREFIX, SPARK_FRAME_COUNT, 12.0, true)
		projectile.visual_rotation_offset = 0.0
		projectile.visual_spin_speed = SPARK_SPIN_SPEED
		projectile.visual_modulate = Color.WHITE
		projectile.explosion_radius = _get_explosion_radius()
		projectile.explosion_damage = _get_final_damage()
		projectile.explosion_status = _get_explosion_status()
		projectile.explosion_status_duration = _get_explosion_status_duration()
		projectile.explosion_status_value = _get_explosion_status_value()
		projectiles.add_child(projectile)

func _get_final_damage() -> int:
	var dmg := get_damage()
	if has_special_tag(&"spark_overload"):
		dmg += 4
	if has_special_tag(&"spark_supernova"):
		dmg += 6
	return dmg

func _get_projectile_count() -> int:
	var count := 1
	if has_special_tag(&"spark_split"):
		count += 1
	if has_special_tag(&"spark_triple"):
		count += 2
	return count

func _get_explosion_radius() -> float:
	var base_radius := weapon_data.field_radius if weapon_data and weapon_data.field_radius > 0.0 else 70.0
	var radius := base_radius * GameState.get_character_area_multiplier() + float(level - 1) * 4.0
	if has_special_tag(&"spark_wide"):
		radius += 20.0
	if has_special_tag(&"spark_supernova"):
		radius += 30.0
	return radius

func _get_spark_speed() -> float:
	var speed := weapon_data.projectile_speed if weapon_data else 240.0
	if has_special_tag(&"spark_fast"):
		speed += 50.0
	return speed

func _get_explosion_status() -> StringName:
	if has_special_tag(&"spark_stun"):
		return &"stun"
	if has_special_tag(&"spark_slow"):
		return &"slow"
	return &""

func _get_explosion_status_duration() -> float:
	if has_special_tag(&"spark_stun"):
		return 0.35
	if has_special_tag(&"spark_slow"):
		return 1.2
	return 0.0

func _get_explosion_status_value() -> float:
	if has_special_tag(&"spark_slow"):
		return 0.55
	return 0.0

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
