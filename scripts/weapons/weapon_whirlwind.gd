extends WeaponBase

const SLASH_FX_PATH := "res://assets/art/effects/by_type/fx_whirlwind"
const SLASH_FX_PREFIX := "whirlwind_arc"
const SLASH_FRAME_COUNT := 4
const ARC_COUNT := 4
const EFFECT_DURATION := 0.32

func _activate() -> void:
	var player := get_parent().get_parent() as Node2D
	if not player:
		return

	var radius := _get_whirlwind_radius()
	_show_whirlwind(player.global_position, radius)
	_play_sfx()

	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.global_position.distance_to(player.global_position) <= radius:
			for i in range(_get_hit_count()):
				_deal_damage_to(enemy, _get_final_damage(), DamageEvent.DAMAGE_TYPE_PHYSICAL, DamageEvent.DELIVERY_AREA)
			if _should_slow():
				enemy.apply_status(&"slow", 1.0, 0.65)
			if _should_knockback():
				_knockback(enemy, player.global_position)

func _show_whirlwind(pos: Vector2, radius: float) -> void:
	var current := get_tree().current_scene
	if not current:
		return

	var root := Node2D.new()
	root.name = "WhirlwindEffect"
	root.global_position = pos
	root.z_index = 14
	current.add_child(root)

	var slash_frames := VFXHelper.build_sprite_frames(SLASH_FX_PATH, SLASH_FX_PREFIX, SLASH_FRAME_COUNT, 16.0, true)
	if not slash_frames or slash_frames.get_frame_count("default") <= 0:
		root.queue_free()
		return
	var frame_count := slash_frames.get_frame_count("default")
	var first_frame := slash_frames.get_frame_texture("default", 0)
	var tex_width := maxf(float(first_frame.get_width()), 1.0)
	var sprite_scale := maxf(radius / tex_width, 0.55)
	for i in range(_get_arc_count()):
		var slash := AnimatedSprite2D.new()
		slash.sprite_frames = slash_frames
		slash.play("default")
		slash.frame = i % frame_count
		slash.rotation = i * TAU / _get_arc_count()
		slash.position = Vector2.RIGHT.rotated(slash.rotation) * radius * 0.34
		slash.scale = Vector2.ONE * sprite_scale
		slash.modulate = Color(1.0, 1.0, 1.0, 0.9)
		root.add_child(slash)

	var tween := root.create_tween()
	tween.tween_property(root, "rotation", TAU, EFFECT_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(root, "modulate", Color(1, 1, 1, 0), EFFECT_DURATION)
	tween.tween_callback(root.queue_free)

func _get_final_damage() -> int:
	var dmg := get_damage()
	if has_special_tag(&"whirlwind_rend"):
		dmg += 3
	if has_special_tag(&"whirlwind_bladestorm"):
		dmg += 5
	return dmg

func _get_hit_count() -> int:
	if has_special_tag(&"whirlwind_double_hit"):
		return 2
	return 1

func _get_arc_count() -> int:
	if has_special_tag(&"whirlwind_bladestorm"):
		return ARC_COUNT + 3
	if has_special_tag(&"whirlwind_extra_arcs"):
		return ARC_COUNT + 2
	return ARC_COUNT

func _get_whirlwind_radius() -> float:
	var r := get_range()
	if has_special_tag(&"whirlwind_wide"):
		r += 20.0
	if has_special_tag(&"whirlwind_wall"):
		r += 30.0
	return r

func _should_slow() -> bool:
	return has_special_tag(&"whirlwind_slow") or has_special_tag(&"whirlwind_wall")

func _should_knockback() -> bool:
	return has_special_tag(&"whirlwind_knockback") or has_special_tag(&"whirlwind_wall")

func _knockback(enemy: Node2D, from_pos: Vector2) -> void:
	if enemy is CharacterBody2D:
		var push_dir := (enemy.global_position - from_pos).normalized()
		enemy.velocity = push_dir * 180.0
		enemy.move_and_slide()
