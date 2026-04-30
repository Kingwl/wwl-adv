extends Area2D

var direction: Vector2 = Vector2.RIGHT
var speed: float = 300.0
var damage: int = 10
var max_range: float = 200.0
var pierce: int = 0
var is_boomerang: bool = false
var visual_texture: Texture2D = null
var visual_sprite_frames: SpriteFrames = null
var visual_modulate: Color = Color.WHITE
var visual_rotation_offset: float = PI
var visual_spin_speed: float = 0.0
var explosion_radius: float = 0.0
var explosion_damage: int = -1
var explosion_status: StringName = &""
var explosion_status_duration: float = 0.0
var explosion_status_value: float = 0.0
var source: Node = null
var damage_owner: Node = null
var weapon_id: StringName = &""
var damage_type: StringName = DamageEvent.DAMAGE_TYPE_PHYSICAL
var delivery_type: StringName = DamageEvent.DELIVERY_PROJECTILE

var _start_pos: Vector2
var _pierced: int = 0
var _returning: bool = false
var _player: Node2D
var _visual_node: Node2D
var _exploded: bool = false

func _ready() -> void:
	_start_pos = global_position
	_player = get_tree().get_first_node_in_group("player")
	body_entered.connect(_on_body_entered)

	# Remove scene's default visual to avoid duplicates
	var old_visual := get_node_or_null("Visual")
	if old_visual:
		old_visual.queue_free()

	if _has_default_visual_frames(visual_sprite_frames):
		var anim := AnimatedSprite2D.new()
		anim.sprite_frames = visual_sprite_frames
		anim.play("default")
		anim.modulate = visual_modulate
		anim.rotation = direction.angle() + visual_rotation_offset
		add_child(anim)
		_visual_node = anim
	elif is_boomerang and visual_texture == null:
		var anim := AnimatedSprite2D.new()
		var frames := SpriteFrames.new()
		var sheet := preload("res://assets/art/weapons/projectiles/proj_boomerang_sheet.png")
		for i in range(4):
			var atlas := AtlasTexture.new()
			atlas.atlas = sheet
			atlas.region = Rect2(i * 24, 0, 24, 24)
			frames.add_frame("default", atlas)
		frames.set_animation_loop("default", true)
		frames.set_animation_speed("default", 12.0)
		anim.sprite_frames = frames
		anim.play("default")
		anim.modulate = visual_modulate
		add_child(anim)
		_visual_node = anim
	else:
		var visual := Sprite2D.new()
		visual.texture = visual_texture if visual_texture else preload("res://assets/art/weapons/projectiles/arrow.png")
		visual.modulate = visual_modulate
		visual.rotation = direction.angle() + visual_rotation_offset
		add_child(visual)
		_visual_node = visual

func _has_default_visual_frames(frames: SpriteFrames) -> bool:
	return frames != null and frames.has_animation("default") and frames.get_frame_count("default") > 0

func _process(delta: float) -> void:
	if _visual_node and visual_spin_speed != 0.0:
		_visual_node.rotation += visual_spin_speed * delta
	if is_boomerang and _returning:
		if _player:
			var dir := (_player.global_position - global_position).normalized()
			global_position += dir * speed * delta
			if global_position.distance_to(_player.global_position) < 20.0:
				queue_free()
		return

	global_position += direction * speed * delta
	if not _returning and global_position.distance_to(_start_pos) > max_range:
		if is_boomerang:
			_returning = true
		else:
			queue_free()

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("enemies"):
		if explosion_radius > 0.0:
			_explode()
			if not is_boomerang:
				queue_free()
			return
		DamageCalculator.deal_damage(body, _make_damage_event(body, damage, global_position, delivery_type))
		_pierced += 1
		if _pierced > pierce and not is_boomerang:
			queue_free()

func _explode() -> void:
	if _exploded:
		return
	_exploded = true
	var dmg := explosion_damage if explosion_damage >= 0 else damage
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.global_position.distance_to(global_position) <= explosion_radius:
			var event := _make_damage_event(enemy, dmg, global_position, DamageEvent.DELIVERY_AREA)
			event.status_id = explosion_status
			event.status_duration = explosion_status_duration
			event.status_value = explosion_status_value
			DamageCalculator.deal_damage(enemy, event)
	var current := get_tree().current_scene
	if current:
		var scale_factor := maxf(explosion_radius * 2.0 / 64.0, 0.5)
		VFXHelper.spawn_animated_one_shot(
			current,
			"res://assets/art/effects/by_type/fx_explosion",
			"explosion",
			8,
			global_position,
			16.0,
			Vector2.ONE * scale_factor
		)

func _make_damage_event(target: Node, amount: int, hit_position: Vector2, delivery: StringName) -> DamageEvent:
	var event := DamageEvent.from_amount(amount, source if source else self, damage_type, delivery)
	event.owner = damage_owner
	event.target = target
	event.weapon_id = weapon_id
	event.position = hit_position
	return event
