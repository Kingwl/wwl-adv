extends Area2D

const FIELD_Z_INDEX := 4
const TILE_FRAME_WIDTH := 32
const TILE_SPACING := 24.0
const TILE_JITTER := 9.0
const EDGE_FADE_START := 0.54
const CENTER_ALPHA := 0.72
const EDGE_ALPHA := 0.22
const CENTER_SCALE := 1.12
const EDGE_SCALE := 0.76
const POISON_TILE_SHEET := preload("res://assets/art/effects/generated_missing/dynamic/fx_poison_tile_sheet.png")

var damage: int = 2
var lifetime: float = 4.0
var radius: float = 40.0
var _tick_interval: float = 0.5
var _tick_timer: float = 0.0

func _ready() -> void:
	z_index = FIELD_Z_INDEX
	var shape := CircleShape2D.new()
	shape.radius = radius
	var cs := CollisionShape2D.new()
	cs.shape = shape
	add_child(cs)

	_build_tiled_visual(POISON_TILE_SHEET)

	var tween := create_tween()
	tween.tween_property(self, "modulate", Color(1, 1, 1, 0), lifetime)
	tween.tween_callback(queue_free)

func _build_tiled_visual(sheet: Texture2D) -> void:
	if not sheet:
		push_warning("PoisonField: missing poison tile sheet")
		return
	var frame_width := TILE_FRAME_WIDTH
	var frame_height: int = sheet.get_height()
	var frame_count := int(sheet.get_width() / frame_width)
	if frame_count <= 0:
		push_warning("PoisonField: poison tile sheet has no frames")
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
			if normalized_distance > 0.76 and rng.randf() < 0.45:
				continue
			var tile := AnimatedSprite2D.new()
			tile.name = "PoisonTile"
			tile.sprite_frames = frames
			tile.position = pos
			tile.frame = rng.randi_range(0, frame_count - 1)
			tile.speed_scale = rng.randf_range(0.75, 1.1)
			tile.flip_h = rng.randf() < 0.5
			tile.flip_v = rng.randf() < 0.35
			var edge_t: float = clampf((normalized_distance - EDGE_FADE_START) / (1.0 - EDGE_FADE_START), 0.0, 1.0)
			var tile_alpha: float = lerpf(CENTER_ALPHA, EDGE_ALPHA, edge_t)
			var tile_scale: float = lerpf(CENTER_SCALE, EDGE_SCALE, edge_t) * rng.randf_range(0.9, 1.18)
			tile.modulate = Color(1.0, 1.0, 1.0, tile_alpha)
			tile.scale = Vector2(tile_scale, tile_scale)
			tile.play("default")
			add_child(tile)

func _make_visual_rng() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(abs(global_position.x * 92821.0 + global_position.y * 68917.0 + radius * 193.0)) + 43
	return rng

func _process(delta: float) -> void:
	lifetime -= delta
	if lifetime <= 0:
		queue_free()
		return

	_tick_timer -= delta
	if _tick_timer <= 0:
		_tick_timer = _tick_interval
		for body in get_overlapping_bodies():
			if body.is_in_group("enemies"):
				body.take_damage(damage)
