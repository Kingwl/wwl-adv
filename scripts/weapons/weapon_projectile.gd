extends WeaponBase

func _activate() -> void:
	var player := get_parent().get_parent() as Node2D
	if not player:
		return

	var target := _find_nearest_enemy(player.global_position)
	if not target:
		return

	_play_sfx()
	var count := _get_projectile_count()
	for i in range(count):
		var projectile := preload("res://scenes/weapons/projectile.tscn").instantiate()
		projectile.global_position = player.global_position
		var base_dir := (target.global_position - player.global_position).normalized()
		if count > 1:
			var spread := deg_to_rad(15.0)
			var offset := spread * (i - (count - 1) / 2.0)
			base_dir = base_dir.rotated(offset)
		projectile.direction = base_dir
		projectile.speed = weapon_data.projectile_speed if weapon_data else 300.0
		projectile.damage = get_damage()
		projectile.max_range = get_range()
		projectile.pierce = _get_pierce_count()
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
	var count := weapon_data.projectile_count if weapon_data else 1
	if has_special_tag(&"extra_arrow"):
		count += 1
	if has_special_tag(&"volley"):
		count += 2
	if has_special_tag(&"rain_of_arrows"):
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
