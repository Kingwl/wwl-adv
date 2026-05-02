## VFX 辅助函数。用于在场景中创建一次性或循环的 AnimatedSprite2D 特效。

class_name VFXHelper

const EFFECT_MELEE_REPLAY := &"melee_replay"
const EFFECT_BURST_OVERFLOW := &"burst_overflow"
const EFFECT_CONTROL_STASIS := &"control_stasis"
const EFFECT_FIELD_LOCKDOWN := &"field_lockdown"
const EFFECT_BARRAGE_KNOCKBACK := &"barrage_knockback"
const EFFECT_SURVIVAL_ECHO := &"survival_echo"
const EFFECT_GUARDIAN_REFRACTION := &"guardian_refraction"

const RESONANCE_EFFECTS := {
	EFFECT_MELEE_REPLAY: {
		"base_path": "res://assets/art/effects/by_type/fx_melee_replay",
		"prefix": "replay",
		"frame_count": 6,
		"fps": 14.0,
		"scale": Vector2(1.0, 1.0),
		"z_index": 18,
	},
	EFFECT_BURST_OVERFLOW: {
		"base_path": "res://assets/art/effects/by_type/fx_burst_overflow",
		"prefix": "overflow",
		"frame_count": 6,
		"fps": 16.0,
		"scale": Vector2(1.25, 1.25),
		"z_index": 19,
	},
	EFFECT_CONTROL_STASIS: {
		"base_path": "res://assets/art/effects/by_type/fx_control_stasis",
		"prefix": "stasis",
		"frame_count": 6,
		"fps": 12.0,
		"scale": Vector2(1.05, 1.05),
		"z_index": 18,
	},
	EFFECT_FIELD_LOCKDOWN: {
		"base_path": "res://assets/art/effects/by_type/fx_field_lockdown",
		"prefix": "lockdown",
		"frame_count": 6,
		"fps": 12.0,
		"scale": Vector2(1.0, 1.0),
		"z_index": 17,
	},
	EFFECT_BARRAGE_KNOCKBACK: {
		"base_path": "res://assets/art/effects/by_type/fx_barrage_knockback",
		"prefix": "impact",
		"frame_count": 4,
		"fps": 16.0,
		"scale": Vector2(1.0, 1.0),
		"z_index": 18,
	},
	EFFECT_SURVIVAL_ECHO: {
		"base_path": "res://assets/art/effects/by_type/fx_survival_echo",
		"prefix": "echo",
		"frame_count": 6,
		"fps": 12.0,
		"scale": Vector2(1.0, 1.0),
		"z_index": 18,
	},
	EFFECT_GUARDIAN_REFRACTION: {
		"base_path": "res://assets/art/effects/by_type/fx_guardian_refraction",
		"prefix": "refraction",
		"frame_count": 4,
		"fps": 12.0,
		"scale": Vector2(0.85, 0.85),
		"z_index": 18,
	},
}

static func build_sprite_frames(base_path: String, prefix: String, frame_count: int, fps: float = 10.0, loop: bool = false) -> SpriteFrames:
	var frames := SpriteFrames.new()
	# SpriteFrames already has a "default" animation by default in Godot 4
	var loaded_count := 0
	for i in range(frame_count):
		var num := i + 1
		var texture_path := base_path + "/" + prefix + "_%02d.png" % num
		var texture := load_texture(texture_path)
		if texture:
			frames.add_frame("default", texture)
			loaded_count += 1
		else:
			push_warning("VFXHelper: failed to load texture %s" % texture_path)
	if loaded_count < frame_count:
		push_warning("VFXHelper: expected %d frames for %s/%s, loaded %d" % [frame_count, base_path, prefix, loaded_count])
	frames.set_animation_loop("default", loop)
	frames.set_animation_speed("default", fps)
	return frames

static func load_texture(texture_path: String) -> Texture2D:
	if texture_path.is_empty():
		return null
	if ResourceLoader.exists(texture_path):
		var imported_texture := ResourceLoader.load(texture_path) as Texture2D
		if imported_texture:
			return imported_texture
	if not FileAccess.file_exists(texture_path):
		return null
	var image := Image.load_from_file(texture_path)
	if not image:
		return null
	return ImageTexture.create_from_image(image)

static func spawn_animated_one_shot(parent: Node, base_path: String, prefix: String, frame_count: int, pos: Vector2, fps: float = 10.0, scale: Vector2 = Vector2.ONE) -> AnimatedSprite2D:
	var anim := AnimatedSprite2D.new()
	anim.sprite_frames = build_sprite_frames(base_path, prefix, frame_count, fps, false)
	anim.global_position = pos
	anim.scale = scale
	anim.z_index = 15
	parent.add_child(anim)
	if not _has_default_frames(anim.sprite_frames):
		anim.queue_free()
		return anim
	anim.play("default")
	anim.animation_finished.connect(anim.queue_free)
	return anim

static func spawn_animated_loop(parent: Node, base_path: String, prefix: String, frame_count: int, fps: float = 10.0, scale: Vector2 = Vector2.ONE) -> AnimatedSprite2D:
	var anim := AnimatedSprite2D.new()
	anim.sprite_frames = build_sprite_frames(base_path, prefix, frame_count, fps, true)
	anim.scale = scale
	anim.z_index = 15
	parent.add_child(anim)
	if not _has_default_frames(anim.sprite_frames):
		anim.queue_free()
		return anim
	anim.play("default")
	return anim

static func spawn_resonance_effect(
	parent: Node,
	effect_id: StringName,
	pos: Vector2,
	rotation: float = 0.0,
	scale_multiplier: float = 1.0
) -> AnimatedSprite2D:
	var config: Dictionary = RESONANCE_EFFECTS.get(effect_id, {})
	if config.is_empty():
		push_warning("VFXHelper: unknown resonance effect %s" % str(effect_id))
		return null
	var resolved_parent := parent if parent else get_default_vfx_parent()
	if not resolved_parent:
		return null
	var effect_scale: Vector2 = config.get("scale", Vector2.ONE)
	effect_scale *= maxf(0.01, scale_multiplier)
	var anim := spawn_animated_one_shot(
		resolved_parent,
		str(config.get("base_path", "")),
		str(config.get("prefix", "")),
		int(config.get("frame_count", 0)),
		pos,
		float(config.get("fps", 10.0)),
		effect_scale
	)
	if is_instance_valid(anim):
		anim.name = _get_resonance_effect_node_name(effect_id)
		anim.rotation = rotation
		anim.z_index = int(config.get("z_index", anim.z_index))
	return anim

static func get_default_vfx_parent() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if not tree:
		return null
	return tree.current_scene

static func _get_resonance_effect_node_name(effect_id: StringName) -> String:
	match effect_id:
		EFFECT_MELEE_REPLAY:
			return "MeleeReplayVFX"
		EFFECT_BURST_OVERFLOW:
			return "BurstOverflowVFX"
		EFFECT_CONTROL_STASIS:
			return "ControlStasisVFX"
		EFFECT_FIELD_LOCKDOWN:
			return "FieldLockdownVFX"
		EFFECT_BARRAGE_KNOCKBACK:
			return "BarrageKnockbackVFX"
		EFFECT_SURVIVAL_ECHO:
			return "SurvivalEchoVFX"
		EFFECT_GUARDIAN_REFRACTION:
			return "GuardianRefractionVFX"
	return "ResonanceVFX"

static func spawn_one_shot_sprite(parent: Node, texture: Texture2D, pos: Vector2, duration: float = 0.15, fade: bool = true, scale: Vector2 = Vector2.ONE) -> Sprite2D:
	if not texture:
		push_warning("VFXHelper: one-shot sprite skipped because texture is null")
		return null

	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.global_position = pos
	sprite.scale = scale
	sprite.z_index = 15
	parent.add_child(sprite)

	if fade:
		var tween := sprite.create_tween()
		tween.tween_property(sprite, "modulate", Color(1, 1, 1, 0), duration)
		tween.tween_callback(sprite.queue_free)
	else:
		sprite.get_tree().create_timer(duration).timeout.connect(sprite.queue_free)

	return sprite

static func spawn_tiled_sprite(parent: Node, texture: Texture2D, from_pos: Vector2, to_pos: Vector2, duration: float = 0.2) -> Sprite2D:
	## 创建一条从 from_pos 到 to_pos 的拉伸 sprite，用于尾迹/激光效果
	if not texture:
		push_warning("VFXHelper: tiled sprite skipped because texture is null")
		return null

	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.global_position = (from_pos + to_pos) / 2.0
	var dist := from_pos.distance_to(to_pos)
	var dir := (to_pos - from_pos).normalized()
	var angle := dir.angle()
	sprite.rotation = angle
	sprite.scale = Vector2(dist / max(texture.get_width(), 1), 1.0)
	sprite.z_index = 15
	parent.add_child(sprite)

	var tween := sprite.create_tween()
	tween.tween_property(sprite, "modulate", Color(1, 1, 1, 0), duration)
	tween.tween_callback(sprite.queue_free)

	return sprite

static func spawn_animated_trail(parent: Node, base_path: String, prefix: String, frame_count: int, from_pos: Vector2, to_pos: Vector2, fps: float = 10.0, spacing: float = 24.0, duration: float = 0.25) -> Node2D:
	var dir := (to_pos - from_pos).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT
	var dist: float = from_pos.distance_to(to_pos)
	var count: int = maxi(1, int(ceil(dist / spacing)))
	var frames: SpriteFrames = build_sprite_frames(base_path, prefix, frame_count, fps, true)

	var container := Node2D.new()
	container.z_index = 15
	parent.add_child(container)
	if not _has_default_frames(frames):
		container.queue_free()
		return container

	for i in range(count):
		var t: float = 0.0 if count == 1 else float(i) / float(count - 1)
		var anim := AnimatedSprite2D.new()
		anim.sprite_frames = frames
		anim.position = from_pos.lerp(to_pos, t)
		anim.rotation = dir.angle()
		anim.speed_scale = 0.85 + 0.1 * float(i % 3)
		var frame_total: int = frames.get_frame_count("default")
		if frame_total > 0:
			anim.frame = i % frame_total
		container.add_child(anim)
		anim.play("default")

	var tween := container.create_tween()
	tween.tween_property(container, "modulate", Color(1, 1, 1, 0), duration)
	tween.tween_callback(container.queue_free)
	return container

static func _has_default_frames(frames: SpriteFrames) -> bool:
	return frames != null and frames.has_animation("default") and frames.get_frame_count("default") > 0
