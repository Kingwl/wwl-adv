extends WeaponBase

func _activate() -> void:
	var player := get_parent().get_parent() as Node2D
	if not player:
		return

	var target := _find_nearest_enemy(player.global_position)
	if not target:
		return

	var base_dir := (target.global_position - player.global_position).normalized()
	var count := _get_beam_count()
	var spread := deg_to_rad(8.0)
	for i in range(count):
		var dir := base_dir
		if count > 1:
			var offset := spread * (i - (count - 1) / 2.0)
			dir = base_dir.rotated(offset)
		var beam := preload("res://scenes/weapons/laser_beam.tscn").instantiate()
		beam.global_position = player.global_position
		beam.direction = dir
		beam.damage = get_damage()
		beam.max_range = get_range()
		beam.lifetime = 0.5
		var __proj := get_tree().current_scene.get_node_or_null("Projectiles")
		if __proj == null:
			__proj = get_tree().current_scene.find_child("Projectiles", true, false)
		if __proj:
			__proj.add_child(beam)

func _get_beam_count() -> int:
	if has_special_tag(&"triple_beam"):
		return 3
	if has_special_tag(&"dual_beam"):
		return 2
	return 1

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
