extends WeaponBase

func _activate() -> void:
	var player := get_parent().get_parent() as Node2D
	if not player:
		return

	var enemies := get_tree().get_nodes_in_group("enemies")
	if enemies.is_empty():
		return

	var first := _find_nearest_enemy(player.global_position, enemies)
	if not first:
		return

	var chain_count := _get_chain_count()
	var hit_targets: Array[Node2D] = [first]
	var current := first
	var dmg := get_damage()
	var jump_range := get_range()

	# 伤害第一个目标
	current.take_damage(dmg)
	_show_chain(player.global_position, current.global_position)

	for i in range(chain_count - 1):
		var next := _find_nearest_enemy_in_list(current.global_position, enemies, hit_targets)
		if not next:
			break
		if current.global_position.distance_to(next.global_position) > jump_range:
			break
		next.take_damage(dmg)
		_show_chain(current.global_position, next.global_position)
		hit_targets.append(next)
		current = next

func _find_nearest_enemy(from_pos: Vector2, enemies: Array[Node]) -> Node2D:
	var nearest: Node2D = null
	var min_dist := INF
	for enemy in enemies:
		var dist := from_pos.distance_to(enemy.global_position)
		if dist < min_dist:
			min_dist = dist
			nearest = enemy
	return nearest

func _find_nearest_enemy_in_list(from_pos: Vector2, enemies: Array[Node], exclude: Array[Node2D]) -> Node2D:
	var nearest: Node2D = null
	var min_dist := INF
	for enemy in enemies:
		if enemy in exclude:
			continue
		var dist := from_pos.distance_to(enemy.global_position)
		if dist < min_dist:
			min_dist = dist
			nearest = enemy
	return nearest

func _show_chain(from_pos: Vector2, to_pos: Vector2) -> void:
	var dist := from_pos.distance_to(to_pos)
	var dir := (to_pos - from_pos).normalized()
	var segments: int = max(3, int(dist / 20.0))

	var container := Node2D.new()
	container.z_index = 15
	get_tree().current_scene.add_child(container)

	var line := Line2D.new()
	line.width = 4.0
	line.texture = preload("res://assets/art/effects/generated_missing/dynamic/fx_chain_core.png")
	line.texture_mode = Line2D.LINE_TEXTURE_TILE
	var points: PackedVector2Array = PackedVector2Array()
	points.append(from_pos)
	for i in range(1, segments):
		var t: float = float(i) / float(segments)
		var base := from_pos.lerp(to_pos, t)
		var offset := dir.rotated(PI / 2.0) * randf_range(-8.0, 8.0)
		points.append(base + offset)
	points.append(to_pos)
	line.points = points
	container.add_child(line)

	# Add node decorations at endpoints and turns
	var node_tex := preload("res://assets/art/effects/generated_missing/dynamic/fx_chain_node.png")
	for i in range(points.size()):
		var node := Sprite2D.new()
		node.texture = node_tex
		node.position = points[i]
		node.scale = Vector2(0.6, 0.6) if i > 0 and i < points.size() - 1 else Vector2(1.0, 1.0)
		container.add_child(node)

	# Fade out and free
	var tween := create_tween()
	tween.tween_property(container, "modulate", Color(1, 1, 1, 0), 0.25)
	tween.tween_callback(container.queue_free)

func _get_chain_count() -> int:
	var base := 3 + (level - 1)
	if has_special_tag(&"chain_3"):
		return base + 3
	if has_special_tag(&"chain_2"):
		return base + 2
	if has_special_tag(&"chain_1"):
		return base + 1
	return base
