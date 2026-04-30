extends WeaponBase

func _activate() -> void:
	var player := get_parent().get_parent() as Node2D
	if not player:
		return

	var target := _find_nearest_enemy(player.global_position)
	if not target:
		return

	var count := _get_projectile_count()
	var base_dir := (target.global_position - player.global_position).normalized()
	var spread := _get_spread_angle()
	var dmg := _get_final_damage()
	var pierce := _get_pierce_count()
	_play_sfx()

	for i in range(count):
		var projectile := preload("res://scenes/weapons/projectile.tscn").instantiate()
		projectile.global_position = player.global_position
		var offset := spread * (i - (count - 1) / 2.0)
		projectile.direction = base_dir.rotated(offset)
		projectile.speed = weapon_data.projectile_speed if weapon_data else 250.0
		projectile.damage = dmg
		projectile.max_range = get_range()
		projectile.pierce = pierce
		projectile.source = self
		projectile.damage_owner = player
		projectile.weapon_id = weapon_data.id if weapon_data else &""
		projectile.damage_type = DamageEvent.DAMAGE_TYPE_PHYSICAL
		projectile.delivery_type = DamageEvent.DELIVERY_PROJECTILE
		var __proj := get_tree().current_scene.get_node_or_null("Projectiles")
		if __proj == null:
			__proj = get_tree().current_scene.find_child("Projectiles", true, false)
		if __proj:
			__proj.add_child(projectile)

func _get_projectile_count() -> int:
	var count := weapon_data.projectile_count if weapon_data else 5
	if has_special_tag(&"extra_pellet"):
		count += 1
	if has_special_tag(&"more_pellets"):
		count += 2
	if has_special_tag(&"shotgun_deluge"):
		count += 3
	return count

func _get_pierce_count() -> int:
	var p := weapon_data.pierce if weapon_data else 0
	if has_special_tag(&"shotgun_pierce"):
		p += 1
	if has_special_tag(&"shotgun_pierce_2"):
		p += 2
	return p

func _get_spread_angle() -> float:
	if has_special_tag(&"wider_spread"):
		return deg_to_rad(60.0)
	if has_special_tag(&"tighter_spread"):
		return deg_to_rad(30.0)
	return deg_to_rad(45.0)

func _get_final_damage() -> int:
	var dmg := get_damage()
	if has_special_tag(&"slug_shot"):
		dmg = int(dmg * 1.5)
	return dmg

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
