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
	_play_sfx()
	for i in range(count):
		var dir := base_dir
		if count > 1:
			var offset := spread * (i - (count - 1) / 2.0)
			dir = base_dir.rotated(offset)
		var beam := preload("res://scenes/weapons/laser_beam.tscn").instantiate()
		beam.global_position = player.global_position
		beam.direction = dir
		beam.damage = _get_beam_damage()
		beam.max_range = _get_beam_range()
		beam.beam_width = _get_beam_width()
		beam.lifetime = 0.5
		beam.source = self
		beam.damage_owner = player
		beam.weapon_id = weapon_data.id if weapon_data else &""
		beam.damage_type = DamageEvent.DAMAGE_TYPE_LIGHTNING
		beam.delivery_type = DamageEvent.DELIVERY_BEAM
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

func _get_beam_damage() -> int:
	var dmg := get_damage()
	if has_special_tag(&"intense_beam"):
		dmg = int(round(float(dmg) * 1.25))
	return dmg

func _get_beam_range() -> float:
	var r := get_range()
	if has_special_tag(&"extended_range"):
		r += 80.0
	if has_special_tag(&"pierce_beam"):
		r += 20.0
	return r

func _get_beam_width() -> float:
	if has_special_tag(&"intense_beam"):
		return 16.0
	if has_special_tag(&"wider_beam"):
		return 12.0
	if has_special_tag(&"pierce_beam"):
		return 10.0
	return 8.0

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
