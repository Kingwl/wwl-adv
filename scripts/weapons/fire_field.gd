extends Area2D

const FIELD_Z_INDEX := 4
const TILE_FRAME_WIDTH := 32
const TILE_SPACING := 24.0
const TILE_JITTER := 8.0
const EDGE_FADE_START := 0.58
const CENTER_ALPHA := 0.82
const EDGE_ALPHA := 0.28
const CENTER_SCALE := 1.05
const EDGE_SCALE := 0.72
const FIRE_TILE_SHEET := preload("res://assets/art/effects/generated_missing/dynamic/fx_fire_tile_sheet.png")

var damage: int = 3
var lifetime: float = 3.0
var radius: float = 40.0
var source: Node = null
var damage_owner: Node = null
var weapon_id: StringName = &""
var damage_type: StringName = DamageEvent.DAMAGE_TYPE_FIRE
var delivery_type: StringName = DamageEvent.DELIVERY_DOT
var _tick_interval: float = 0.5
var _tick_timer: float = 0.0

func _ready() -> void:
	z_index = FIELD_Z_INDEX
	_tick_timer = _tick_interval
	var shape := CircleShape2D.new()
	shape.radius = radius
	var cs := CollisionShape2D.new()
	cs.shape = shape
	add_child(cs)

	_build_tiled_visual(FIRE_TILE_SHEET)

	var tween := create_tween()
	tween.tween_property(self, "modulate", Color(1, 1, 1, 0), lifetime)
	tween.tween_callback(queue_free)
	call_deferred("_apply_tick")

func _build_tiled_visual(sheet: Texture2D) -> void:
	if not sheet:
		push_warning("FireField: missing fire tile sheet")
		return
	var frame_width := TILE_FRAME_WIDTH
	var frame_height: int = sheet.get_height()
	var frame_count := int(sheet.get_width() / frame_width)
	if frame_count <= 0:
		push_warning("FireField: fire tile sheet has no frames")
		return

	var frames := SpriteFrames.new()
	for i in range(frame_count):
		var atlas := AtlasTexture.new()
		atlas.atlas = sheet
		atlas.region = Rect2(i * frame_width, 0, frame_width, frame_height)
		frames.add_frame("default", atlas)
	frames.set_animation_loop("default", true)
	frames.set_animation_speed("default", 6.0)

	var rng := _make_visual_rng()
	var grid_radius := int(ceil(radius / TILE_SPACING)) + 1

	for y in range(-grid_radius, grid_radius + 1):
		for x in range(-grid_radius, grid_radius + 1):
			var row_offset := TILE_SPACING * 0.5 if abs(y) % 2 == 1 else 0.0
			var base_pos := Vector2(x * TILE_SPACING + row_offset, y * TILE_SPACING)
			var jitter := Vector2(
				rng.randf_range(-TILE_JITTER, TILE_JITTER),
				rng.randf_range(-TILE_JITTER, TILE_JITTER)
			)
			var pos := base_pos + jitter
			var normalized_distance := pos.length() / radius
			if normalized_distance > 1.0:
				continue
			if normalized_distance > 0.78 and rng.randf() < 0.38:
				continue
			var tile := AnimatedSprite2D.new()
			tile.name = "FireTile"
			tile.sprite_frames = frames
			tile.position = pos
			tile.frame = rng.randi_range(0, frame_count - 1)
			tile.speed_scale = rng.randf_range(0.82, 1.18)
			tile.flip_h = rng.randf() < 0.5
			var edge_t: float = clampf((normalized_distance - EDGE_FADE_START) / (1.0 - EDGE_FADE_START), 0.0, 1.0)
			var tile_alpha: float = lerpf(CENTER_ALPHA, EDGE_ALPHA, edge_t)
			var tile_scale: float = lerpf(CENTER_SCALE, EDGE_SCALE, edge_t) * rng.randf_range(0.88, 1.12)
			tile.modulate = Color(1.0, 1.0, 1.0, tile_alpha)
			tile.scale = Vector2(tile_scale, tile_scale)
			tile.play("default")
			add_child(tile)

func _make_visual_rng() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(abs(global_position.x * 92821.0 + global_position.y * 68917.0 + radius * 193.0)) + 17
	return rng

func _process(delta: float) -> void:
	lifetime -= delta
	if lifetime <= 0:
		queue_free()
		return

	_tick_timer -= delta
	if _tick_timer <= 0:
		_tick_timer = _tick_interval
		_apply_tick()

func _apply_tick() -> void:
	if not is_inside_tree():
		return
	var damaged: Dictionary = {}
	for body in get_overlapping_bodies():
		_damage_enemy_once(body, damaged)
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if _is_enemy_in_radius(enemy):
			_damage_enemy_once(enemy, damaged)

func _damage_enemy_once(enemy: Node, damaged: Dictionary) -> void:
	if not is_instance_valid(enemy) or not enemy.is_in_group("enemies"):
		return
	var enemy_id := enemy.get_instance_id()
	if damaged.has(enemy_id):
		return
	damaged[enemy_id] = true
	DamageCalculator.deal_damage(enemy, _make_damage_event(enemy))

func _is_enemy_in_radius(enemy: Node) -> bool:
	if not is_instance_valid(enemy) or enemy.is_queued_for_deletion() or not (enemy is Node2D):
		return false
	if "_dead" in enemy and bool(enemy._dead):
		return false
	return global_position.distance_squared_to((enemy as Node2D).global_position) <= radius * radius

func _make_damage_event(target: Node) -> DamageEvent:
	var event := DamageEvent.from_amount(damage, source if source else self, damage_type, delivery_type)
	event.owner = damage_owner
	event.target = target
	event.weapon_id = weapon_id
	event.position = global_position
	return event
