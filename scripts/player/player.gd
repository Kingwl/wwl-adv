extends CharacterBody2D

@export var move_speed: float = 170.0

const INVINCIBILITY_DURATION := 0.25
const FRAME_SIZE := 64
const CLASS_WALK_FRAME_COUNT := 4
const CLASS_DIRECTIONS := ["down", "left", "right", "up"]

const STARTING_WEAPON_SCENES: Dictionary = {
	&"melee_basic": "res://scenes/weapons/weapon_melee.tscn",
	&"projectile_basic": "res://scenes/weapons/weapon_projectile.tscn",
	&"thorns": "res://scenes/weapons/weapon_thorns.tscn",
	&"fire_bottle": "res://scenes/weapons/weapon_fire_bottle.tscn",
	&"poison_vial": "res://scenes/weapons/weapon_poison_vial.tscn",
}

var _invincible: bool = false
var _invincibility_timer: float = 0.0
var _invincible_until_msec: int = 0
var _dying: bool = false
var _uses_directional_class_animations: bool = false
var _last_facing: String = "down"
@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _health_bar: ProgressBar = $HealthBar

func _ready() -> void:
	move_speed = float(GameState.run.get("move_speed", move_speed))
	_setup_animations()
	GameState.level_up.connect(_on_level_up)
	GameState.hp_changed.connect(_on_hp_changed)
	_setup_health_bar()

	# Initialize weapons container and starting weapon
	var weapons := Node.new()
	weapons.name = "Weapons"
	add_child(weapons)

	for weapon_id in GameState.run.get("starting_weapon_ids", [&"melee_basic"]):
		_add_starting_weapon(weapons, StringName(weapon_id))

func _process(_delta: float) -> void:
	if not _invincible:
		return
	_invincibility_timer = maxf(0.0, float(_invincible_until_msec - Time.get_ticks_msec()) / 1000.0)
	if not _is_invincibility_active():
		_end_invincibility()

func _setup_animations() -> void:
	var frames := SpriteFrames.new()
	var class_walk_sheet := _get_character_walk_sheet()
	_uses_directional_class_animations = class_walk_sheet != null

	if _uses_directional_class_animations:
		_add_class_walk_animations(frames, class_walk_sheet)
	else:
		_add_default_idle_animation(frames)
		_add_default_run_animation(frames)

	_add_hit_animation(frames)
	_add_death_animation(frames)

	_sprite.sprite_frames = frames
	_sprite.play(_idle_animation_name())

func _get_character_walk_sheet() -> Texture2D:
	var character := DataManager.get_character(str(GameState.run.get("character_id", GameState.DEFAULT_CHARACTER_ID)))
	if character and "walk_sheet" in character and character.walk_sheet:
		return character.walk_sheet
	return null

func _add_class_walk_animations(frames: SpriteFrames, sheet: Texture2D) -> void:
	for row in range(CLASS_DIRECTIONS.size()):
		var direction: String = CLASS_DIRECTIONS[row]
		var idle_name := "idle_%s" % direction
		frames.add_animation(idle_name)
		frames.add_frame(idle_name, _make_atlas_texture(sheet, 0, row))
		frames.set_animation_loop(idle_name, true)
		frames.set_animation_speed(idle_name, 1.0)

		var walk_name := "walk_%s" % direction
		frames.add_animation(walk_name)
		for col in range(CLASS_WALK_FRAME_COUNT):
			frames.add_frame(walk_name, _make_atlas_texture(sheet, col, row))
		frames.set_animation_loop(walk_name, true)
		frames.set_animation_speed(walk_name, 8.0)

func _add_default_idle_animation(frames: SpriteFrames) -> void:
	frames.add_animation("idle")
	var idle_sheet := load("res://assets/art/characters/player_idle_sheet.png")
	for i in range(4):
		frames.add_frame("idle", _make_atlas_texture(idle_sheet, i, 0))
	frames.set_animation_loop("idle", true)
	frames.set_animation_speed("idle", 4.0)

func _add_default_run_animation(frames: SpriteFrames) -> void:
	frames.add_animation("run")
	var run_sheet := load("res://assets/art/characters/player_run_sheet.png")
	for i in range(6):
		frames.add_frame("run", _make_atlas_texture(run_sheet, i, 0))
	frames.set_animation_loop("run", true)
	frames.set_animation_speed("run", 8.0)

func _add_hit_animation(frames: SpriteFrames) -> void:
	frames.add_animation("hit")
	var hit_sheet := load("res://assets/art/characters/player_hit_sheet.png")
	for i in range(2):
		frames.add_frame("hit", _make_atlas_texture(hit_sheet, i, 0))
	frames.set_animation_loop("hit", false)
	frames.set_animation_speed("hit", 8.0)

func _add_death_animation(frames: SpriteFrames) -> void:
	frames.add_animation("death")
	var death_sheet := load("res://assets/art/characters/player_death_sheet.png")
	for i in range(5):
		frames.add_frame("death", _make_atlas_texture(death_sheet, i, 0))
	frames.set_animation_loop("death", false)
	frames.set_animation_speed("death", 6.0)

func _make_atlas_texture(sheet: Texture2D, col: int, row: int) -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = sheet
	atlas.region = Rect2(col * FRAME_SIZE, row * FRAME_SIZE, FRAME_SIZE, FRAME_SIZE)
	return atlas

func _add_starting_weapon(weapons: Node, weapon_id: StringName) -> void:
	var scene_path: String = STARTING_WEAPON_SCENES.get(weapon_id, "")
	if scene_path.is_empty():
		scene_path = STARTING_WEAPON_SCENES[&"melee_basic"]
	var weapon_scene := ResourceLoader.load(scene_path) as PackedScene
	if not weapon_scene:
		push_warning("Player: failed to load starting weapon scene %s" % scene_path)
		return
	var weapon: Node = weapon_scene.instantiate()
	weapons.add_child(weapon)
	GameState.notify_weapons_changed()

func _physics_process(_delta: float) -> void:
	var input_dir := _get_move_input()
	velocity = input_dir * move_speed
	move_and_slide()
	_update_movement_animation(input_dir)

func _update_movement_animation(input_dir: Vector2) -> void:
	if _dying or _sprite.animation == "hit" or _sprite.animation == "death":
		return
	if _uses_directional_class_animations:
		_sprite.flip_h = false
		if input_dir.length() > 0.1:
			_last_facing = _facing_from_direction(input_dir)
			_play_animation_if_needed(_walk_animation_name())
		else:
			_play_animation_if_needed(_idle_animation_name())
		return

	if velocity.length() > 10.0:
		_play_animation_if_needed("run")
		if velocity.x < 0:
			_sprite.flip_h = true
		elif velocity.x > 0:
			_sprite.flip_h = false
	else:
		_play_animation_if_needed("idle")

func _facing_from_direction(direction: Vector2) -> String:
	if absf(direction.x) > absf(direction.y):
		if direction.x < 0.0:
			return "left"
		return "right"
	if direction.y < 0.0:
		return "up"
	return "down"

func _idle_animation_name() -> String:
	if _uses_directional_class_animations:
		return "idle_%s" % _last_facing
	return "idle"

func _walk_animation_name() -> String:
	if _uses_directional_class_animations:
		return "walk_%s" % _last_facing
	return "run"

func _play_animation_if_needed(animation_name: String) -> void:
	if _sprite.animation != animation_name:
		_sprite.play(animation_name)

func _get_move_input() -> Vector2:
	var keyboard_dir := Vector2.ZERO
	keyboard_dir.x = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	keyboard_dir.y = Input.get_action_strength("move_down") - Input.get_action_strength("move_up")

	var joystick_dir := Vector2.ZERO
	var joystick := get_tree().get_first_node_in_group("virtual_joystick")
	if joystick:
		joystick_dir = joystick.get_direction()

	return _compose_move_input(keyboard_dir, joystick_dir)

func _compose_move_input(keyboard_dir: Vector2, joystick_dir: Vector2) -> Vector2:
	if joystick_dir.length_squared() > 0.0001:
		return joystick_dir.limit_length(1.0)
	if keyboard_dir.length_squared() > 0.0001:
		return keyboard_dir.normalized()
	return Vector2.ZERO

func take_damage(amount: int) -> void:
	if _invincible:
		if _is_invincibility_active():
			return
		_end_invincibility()
	if _dying:
		return
	# Intercept fatal damage to play death animation first
	if GameState.run.hp <= amount:
		_dying = true
		set_physics_process(false)
		if _sprite:
			_sprite.process_mode = PROCESS_MODE_ALWAYS
			_sprite.play("death")
			await _sprite.animation_finished
		GameState.take_damage(amount)
		return
	GameState.take_damage(amount)
	_flash()

func _flash() -> void:
	_invincible = true
	_invincibility_timer = INVINCIBILITY_DURATION
	_invincible_until_msec = Time.get_ticks_msec() + int(INVINCIBILITY_DURATION * 1000.0)
	_sprite.play("hit")
	modulate = Color(1, 0.5, 0.5, 0.6)

func _end_invincibility() -> void:
	_invincibility_timer = 0.0
	_invincible_until_msec = 0
	modulate = Color.WHITE
	_invincible = false
	if _sprite.animation == "hit":
		_sprite.play(_idle_animation_name())

func _is_invincibility_active() -> bool:
	return Time.get_ticks_msec() < _invincible_until_msec

func _on_level_up(_new_level: int) -> void:
	_show_level_up_visual()

func _show_level_up_visual() -> void:
	VFXHelper.spawn_animated_one_shot(
		get_tree().current_scene,
		"res://assets/art/effects/by_type/fx_level_up",
		"levelup",
		8,
		global_position,
		10.0
	)

func _setup_health_bar() -> void:
	if _health_bar:
		_health_bar.max_value = GameState.run.max_hp
		_health_bar.value = GameState.run.hp

func _on_hp_changed(current: int, max_hp: int) -> void:
	if _health_bar:
		_health_bar.max_value = max_hp
		_health_bar.value = current
