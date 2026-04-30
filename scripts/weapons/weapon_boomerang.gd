extends WeaponBase

func _activate() -> void:
	var player := get_parent().get_parent() as Node2D
	if not player:
		return

	var target := _find_nearest_enemy(player.global_position)
	if not target:
		return

	var count := _get_boomerang_count()
	var base_dir := (target.global_position - player.global_position).normalized()
	var spread := deg_to_rad(10.0)
	for i in range(count):
		var projectile := preload("res://scenes/weapons/projectile.tscn").instantiate()
		projectile.global_position = player.global_position
		var dir := base_dir
		if count > 1:
			var offset := spread * (i - (count - 1) / 2.0)
			dir = base_dir.rotated(offset)
		projectile.direction = dir
		projectile.speed = _get_boomerang_speed()
		projectile.damage = get_damage()
		projectile.max_range = get_range()
		projectile.pierce = _get_pierce_count()
		projectile.is_boomerang = true
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

func _get_boomerang_count() -> int:
	var count := 1
	if has_special_tag(&"dual_boomerang"):
		count += 1
	if has_special_tag(&"triple_boomerang"):
		count += 2
	if has_special_tag(&"quad_boomerang"):
		count += 3
	return count

func _get_pierce_count() -> int:
	var p := weapon_data.pierce if weapon_data else 0
	if has_special_tag(&"pierce_1"):
		p += 1
	if has_special_tag(&"pierce_2"):
		p += 2
	if has_special_tag(&"pierce_max"):
		p += 3
	return p

func _get_boomerang_speed() -> float:
	var speed := weapon_data.projectile_speed if weapon_data else 280.0
	if has_special_tag(&"faster_boomerang"):
		speed += 50.0
	return speed

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
