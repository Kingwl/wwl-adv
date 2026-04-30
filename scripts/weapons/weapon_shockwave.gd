extends WeaponBase

const WAVE_FX_PATH := "res://assets/art/effects/by_type/fx_shockwave"
const WAVE_FX_PREFIX := "shockwave"
const WAVE_FRAME_COUNT := 4
const WAVE_DURATION := 0.38
const BASE_STUN_DURATION := 0.35

func _activate() -> void:
	var player := get_parent().get_parent() as Node2D
	if not player:
		return

	var radius := _get_wave_radius()
	_show_shockwave(player.global_position, radius)

	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.global_position.distance_to(player.global_position) <= radius:
			for i in range(_get_pulse_count()):
				_deal_damage_to(enemy, _get_final_damage(), DamageEvent.DAMAGE_TYPE_PHYSICAL, DamageEvent.DELIVERY_AREA)
			if enemy.has_method("apply_status"):
				enemy.apply_status(&"stun", _get_stun_duration(), 0.0)
				if _should_slow():
					enemy.apply_status(&"slow", 1.5, 0.55)

func _show_shockwave(pos: Vector2, radius: float) -> void:
	var current := get_tree().current_scene
	if not current:
		return

	var wave := AnimatedSprite2D.new()
	wave.name = "ShockwaveEffect"
	wave.sprite_frames = VFXHelper.build_sprite_frames(WAVE_FX_PATH, WAVE_FX_PREFIX, WAVE_FRAME_COUNT, 12.0, false)
	if not wave.sprite_frames or wave.sprite_frames.get_frame_count("default") <= 0:
		wave.queue_free()
		return
	wave.play("default")
	wave.global_position = pos
	wave.z_index = 13
	wave.modulate = Color(1.0, 1.0, 1.0, 0.86)
	current.add_child(wave)

	var first_frame := wave.sprite_frames.get_frame_texture("default", 0)
	var tex_size := maxf(float(first_frame.get_width()), 1.0)
	var final_scale := Vector2.ONE * (radius * 2.0 / tex_size)
	wave.scale = final_scale * 0.25
	var tween := wave.create_tween()
	tween.tween_property(wave, "scale", final_scale, WAVE_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(wave, "modulate", Color(1.0, 1.0, 1.0, 0.0), WAVE_DURATION)
	tween.tween_callback(wave.queue_free)

func _get_final_damage() -> int:
	var dmg := get_damage()
	if has_special_tag(&"shock_fracture"):
		dmg += 3
	if has_special_tag(&"shock_earthsplit"):
		dmg += 5
	return dmg

func _get_pulse_count() -> int:
	if has_special_tag(&"triple_pulse"):
		return 3
	if has_special_tag(&"double_pulse"):
		return 2
	return 1

func _get_wave_radius() -> float:
	var r := get_range()
	if has_special_tag(&"wide_shockwave"):
		r += 25.0
	if has_special_tag(&"shock_earthsplit"):
		r += 35.0
	return r

func _get_stun_duration() -> float:
	if has_special_tag(&"shock_lockdown"):
		return 0.75
	if has_special_tag(&"long_stun"):
		return 0.55
	return BASE_STUN_DURATION

func _should_slow() -> bool:
	return has_special_tag(&"shock_slow") or has_special_tag(&"shock_lockdown")
