extends WeaponBase

const FLAME_START_FX_PATH := "res://assets/art/effects/by_type/fx_rocket_flame_start"
const FLAME_MID_FX_PATH := "res://assets/art/effects/by_type/fx_rocket_flame_mid"
const FLAME_END_FX_PATH := "res://assets/art/effects/by_type/fx_rocket_flame_end"
const FLAME_START_FX_PREFIX := "flame_start"
const FLAME_MID_FX_PREFIX := "flame_mid"
const FLAME_END_FX_PREFIX := "flame_end"
const FLAME_FRAME_COUNT := 4
const FLAME_FPS := 14.0
const FLAME_VISUAL_START_DISTANCE := 18.0
const FLAME_VISUAL_END_DISTANCE := 62.0
const FLAME_SEGMENT_SPACING := 18.0
const FLAME_VISUAL_DURATION := 0.22

var _last_player_pos: Vector2 = Vector2.ZERO

func _ready() -> void:
	super._ready()
	var player := get_tree().get_first_node_in_group("player")
	if player:
		_last_player_pos = player.global_position

func _process(delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player")
	if not player:
		return

	var is_moving: bool = player.global_position != _last_player_pos
	_last_player_pos = player.global_position

	if is_moving:
		_cooldown_timer -= delta
		if _cooldown_timer <= 0:
			_spawn_fire_behind(player)
			_cooldown_timer = get_cooldown()

func _spawn_fire_behind(player: Node2D) -> void:
	# 在玩家身后创建小型火焰区域
	var field := preload("res://scenes/weapons/fire_field.tscn").instantiate()
	var back_dir: Vector2 = -player.velocity.normalized()
	if back_dir.length() < 0.1:
		back_dir = Vector2.LEFT
	field.global_position = player.global_position + back_dir * 20.0
	field.damage = _get_rocket_damage()
	field.lifetime = _get_trail_lifetime()
	field.radius = _get_fire_radius()

	_show_flame_segments(
		player.global_position + back_dir * FLAME_VISUAL_START_DISTANCE,
		player.global_position + back_dir * FLAME_VISUAL_END_DISTANCE
	)

	var __proj := get_tree().current_scene.get_node_or_null("Projectiles")
	if __proj == null:
		__proj = get_tree().current_scene.find_child("Projectiles", true, false)
	if __proj:
		__proj.add_child(field)

func _show_flame_segments(from_pos: Vector2, to_pos: Vector2) -> void:
	var scene := get_tree().current_scene
	if not scene:
		return

	var dir := (to_pos - from_pos).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.LEFT

	var container := Node2D.new()
	container.name = "RocketFlameSegments"
	container.z_index = 14
	scene.add_child(container)

	var angle := dir.angle()
	_add_flame_sprite(container, FLAME_START_FX_PATH, FLAME_START_FX_PREFIX, from_pos, angle, "RocketFlameStart")

	var dist: float = from_pos.distance_to(to_pos)
	var mid_count: int = maxi(1, int(floor(dist / FLAME_SEGMENT_SPACING)))
	for i in range(mid_count):
		var t: float = float(i + 1) / float(mid_count + 1)
		_add_flame_sprite(container, FLAME_MID_FX_PATH, FLAME_MID_FX_PREFIX, from_pos.lerp(to_pos, t), angle, "RocketFlameMid")

	_add_flame_sprite(container, FLAME_END_FX_PATH, FLAME_END_FX_PREFIX, to_pos, angle, "RocketFlameEnd")

	var tween := container.create_tween()
	tween.tween_property(container, "modulate", Color(1, 1, 1, 0), FLAME_VISUAL_DURATION)
	tween.tween_callback(container.queue_free)

func _add_flame_sprite(parent: Node, base_path: String, prefix: String, pos: Vector2, angle: float, sprite_name: String) -> void:
	var sprite := AnimatedSprite2D.new()
	sprite.name = sprite_name
	sprite.sprite_frames = VFXHelper.build_sprite_frames(base_path, prefix, FLAME_FRAME_COUNT, FLAME_FPS, true)
	if not sprite.sprite_frames or sprite.sprite_frames.get_frame_count("default") <= 0:
		sprite.queue_free()
		return
	sprite.play("default")
	sprite.global_position = pos
	sprite.rotation = angle
	sprite.modulate = Color(1.0, 0.92, 0.72, 0.95)
	parent.add_child(sprite)

func _get_rocket_damage() -> int:
	var dmg := get_damage()
	if has_special_tag(&"stronger_rocket"):
		dmg += 1
	if has_special_tag(&"inferno_rocket"):
		dmg += 2
	return dmg

func _get_trail_lifetime() -> float:
	if has_special_tag(&"eternal_rocket"):
		return 2.5
	if has_special_tag(&"longer_trail"):
		return 2.0
	return 1.5

func _get_fire_radius() -> float:
	var r := get_range()
	if has_special_tag(&"wider_rocket"):
		r += 10.0
	return r
