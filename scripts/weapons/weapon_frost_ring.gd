extends WeaponBase

const FROST_RING_TEXTURE := preload("res://assets/art/effects/by_type/fx_frost_ring/frost_01.png")
const FROST_RING_Z_INDEX := 6
const FROST_RING_FADE_TIME := 0.45
const FROST_RING_START_SCALE := 0.55

func _activate() -> void:
	var player := get_parent().get_parent() as Node2D
	if not player:
		return

	var radius := get_range()
	_show_ice_ring(player.global_position, radius)

	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.global_position.distance_to(player.global_position) <= radius:
			enemy.apply_status(&"slow", _get_slow_duration(), _get_slow_value())
			enemy.take_damage(get_damage())

func _show_ice_ring(pos: Vector2, radius: float) -> void:
	var ring := Sprite2D.new()
	ring.name = "FrostRingEffect"
	ring.texture = FROST_RING_TEXTURE
	ring.global_position = pos
	ring.z_index = FROST_RING_Z_INDEX
	ring.modulate = Color(0.78, 0.94, 1.0, 0.9)

	var tex_size: float = maxf(float(ring.texture.get_width()), 1.0)
	var final_scale := Vector2(radius * 2.0 / tex_size, radius * 2.0 / tex_size)
	ring.scale = final_scale * FROST_RING_START_SCALE
	get_tree().current_scene.add_child(ring)

	var tween := ring.create_tween()
	tween.tween_property(ring, "scale", final_scale, FROST_RING_FADE_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(ring, "modulate", Color(0.78, 0.94, 1.0, 0), FROST_RING_FADE_TIME)
	tween.tween_callback(ring.queue_free)

func _get_slow_duration() -> float:
	if has_special_tag(&"deep_freeze"):
		return 4.0
	if has_special_tag(&"longer_slow"):
		return 3.0
	return 2.0

func _get_slow_value() -> float:
	if has_special_tag(&"frozen_solid"):
		return 0.1
	if has_special_tag(&"stronger_slow"):
		return 0.3
	return 0.5
