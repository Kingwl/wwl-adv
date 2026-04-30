extends WeaponBase

func _get_mine_count() -> int:
	var count := 1
	if has_special_tag(&"extra_mine"):
		count += 1
	if has_special_tag(&"triple_mine"):
		count += 2
	if has_special_tag(&"mine_deluge"):
		count += 3
	return count

func _get_blast_radius() -> float:
	var r := 60.0
	if has_special_tag(&"larger_blast"):
		r += 20.0
	if has_special_tag(&"massive_blast"):
		r += 30.0
	return r

func _get_cluster_count() -> int:
	if has_special_tag(&"cluster_mine"):
		return 2
	return 0

func _activate() -> void:
	var player := get_parent().get_parent() as Node2D
	if not player:
		return

	var count := _get_mine_count()
	for i in range(count):
		var place_radius := get_range()
		var angle := randf() * TAU + (i * PI / 3.0)
		var dist := randf_range(20.0, place_radius)
		var place_pos := player.global_position + Vector2(cos(angle), sin(angle)) * dist

		var mine := preload("res://scenes/weapons/mine_trap.tscn").instantiate()
		mine.global_position = place_pos
		mine.damage = get_damage()
		mine.explosion_radius = _get_blast_radius()
		mine.cluster_count = _get_cluster_count()
		var __proj := get_tree().current_scene.get_node_or_null("Projectiles")
		if __proj == null:
			__proj = get_tree().current_scene.find_child("Projectiles", true, false)
		if __proj:
			__proj.add_child(mine)
