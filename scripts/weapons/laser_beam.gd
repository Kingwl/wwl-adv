extends Area2D

const LASER_FLICKER_PATH := "res://assets/art/effects/by_type/fx_laser"
const LASER_FLICKER_PREFIX := "laser"
const LASER_FLICKER_FRAME_COUNT := 4
const LASER_FLICKER_FPS := 18.0

var direction: Vector2 = Vector2.RIGHT
var damage: int = 5
var max_range: float = 250.0
var lifetime: float = 0.5
var beam_width: float = 8.0
var source: Node = null
var damage_owner: Node = null
var weapon_id: StringName = &""
var damage_type: StringName = DamageEvent.DAMAGE_TYPE_LIGHTNING
var delivery_type: StringName = DamageEvent.DELIVERY_BEAM

func _ready() -> void:
	z_index = 15
	var shape := RectangleShape2D.new()
	shape.size = Vector2(max_range, beam_width)
	var cs := CollisionShape2D.new()
	cs.shape = shape
	cs.position = Vector2(max_range / 2.0, 0)
	add_child(cs)

	rotation = direction.angle()

	_build_beam_visual()

	body_entered.connect(_on_body_entered)
	_deal_damage()

	var tween := create_tween()
	tween.tween_property(self, "modulate", Color(1, 1, 1, 0), lifetime)
	tween.tween_callback(queue_free)

func _build_beam_visual() -> void:
	var start_tex := preload("res://assets/art/effects/generated_missing/dynamic/fx_laser_start.png")
	var mid_tex := preload("res://assets/art/effects/generated_missing/dynamic/fx_laser_mid.png")
	var end_tex := preload("res://assets/art/effects/generated_missing/dynamic/fx_laser_end.png")

	var start := Sprite2D.new()
	start.name = "LaserStart"
	start.texture = start_tex
	start.z_index = 2
	start.position = Vector2(16, 0)
	start.scale.y = maxf(beam_width / 8.0, 1.0)
	add_child(start)

	var end := Sprite2D.new()
	end.name = "LaserEnd"
	end.texture = end_tex
	end.z_index = 2
	end.position = Vector2(max_range - 16, 0)
	end.scale.y = maxf(beam_width / 8.0, 1.0)
	add_child(end)

	var mid := Sprite2D.new()
	mid.name = "LaserMid"
	mid.texture = mid_tex
	mid.position = Vector2(max_range / 2.0, 0)
	mid.scale = Vector2(maxf(max_range - 32.0, 1.0) / maxf(float(mid_tex.get_width()), 1.0), maxf(beam_width / 8.0, 1.0))
	add_child(mid)

	var flicker := AnimatedSprite2D.new()
	flicker.name = "LaserFlicker"
	flicker.sprite_frames = VFXHelper.build_sprite_frames(
		LASER_FLICKER_PATH,
		LASER_FLICKER_PREFIX,
		LASER_FLICKER_FRAME_COUNT,
		LASER_FLICKER_FPS,
		true
	)
	flicker.position = Vector2(max_range / 2.0, 0)
	flicker.modulate = Color(1.0, 1.0, 1.0, 0.62)
	flicker.z_index = 1
	var frame_count := flicker.sprite_frames.get_frame_count("default")
	if frame_count > 0:
		var tex := flicker.sprite_frames.get_frame_texture("default", 0)
		if tex:
			flicker.scale = Vector2(maxf(max_range, 1.0) / maxf(float(tex.get_width()), 1.0), maxf(beam_width / 8.0, 1.0))
	add_child(flicker)
	flicker.play("default")

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("enemies"):
		DamageCalculator.deal_damage(body, _make_damage_event(body))

func _deal_damage() -> void:
	for body in get_overlapping_bodies():
		if body.is_in_group("enemies"):
			DamageCalculator.deal_damage(body, _make_damage_event(body))

func _make_damage_event(target: Node) -> DamageEvent:
	var event := DamageEvent.from_amount(damage, source if source else self, damage_type, delivery_type)
	event.owner = damage_owner
	event.target = target
	event.weapon_id = weapon_id
	event.position = global_position
	return event
