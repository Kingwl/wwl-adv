extends CharacterBody2D

@export var move_speed: float = 150.0

var _invincible: bool = false
var _dying: bool = false
@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _health_bar: ProgressBar = $HealthBar

func _ready() -> void:
	_setup_animations()
	GameState.level_up.connect(_on_level_up)
	GameState.hp_changed.connect(_on_hp_changed)
	_setup_health_bar()

	# Initialize weapons container and starting weapon
	var weapons := Node.new()
	weapons.name = "Weapons"
	add_child(weapons)

	var melee := preload("res://scenes/weapons/weapon_melee.tscn").instantiate()
	weapons.add_child(melee)

func _setup_animations() -> void:
	var frames := SpriteFrames.new()

	# Idle: 4 frames from player_idle_sheet.png
	frames.add_animation("idle")
	var idle_sheet := load("res://assets/art/characters/player_idle_sheet.png")
	for i in range(4):
		var atlas := AtlasTexture.new()
		atlas.atlas = idle_sheet
		atlas.region = Rect2(i * 64, 0, 64, 64)
		frames.add_frame("idle", atlas)
	frames.set_animation_loop("idle", true)
	frames.set_animation_speed("idle", 4.0)

	# Run: 6 frames from player_run_sheet.png
	frames.add_animation("run")
	var run_sheet := load("res://assets/art/characters/player_run_sheet.png")
	for i in range(6):
		var atlas := AtlasTexture.new()
		atlas.atlas = run_sheet
		atlas.region = Rect2(i * 64, 0, 64, 64)
		frames.add_frame("run", atlas)
	frames.set_animation_loop("run", true)
	frames.set_animation_speed("run", 8.0)

	# Hit: 2 frames from player_hit_sheet.png
	frames.add_animation("hit")
	var hit_sheet := load("res://assets/art/characters/player_hit_sheet.png")
	for i in range(2):
		var atlas := AtlasTexture.new()
		atlas.atlas = hit_sheet
		atlas.region = Rect2(i * 64, 0, 64, 64)
		frames.add_frame("hit", atlas)
	frames.set_animation_loop("hit", false)
	frames.set_animation_speed("hit", 8.0)

	# Death: 5 frames from player_death_sheet.png
	frames.add_animation("death")
	var death_sheet := load("res://assets/art/characters/player_death_sheet.png")
	for i in range(5):
		var atlas := AtlasTexture.new()
		atlas.atlas = death_sheet
		atlas.region = Rect2(i * 64, 0, 64, 64)
		frames.add_frame("death", atlas)
	frames.set_animation_loop("death", false)
	frames.set_animation_speed("death", 6.0)

	_sprite.sprite_frames = frames
	_sprite.play("idle")

func _physics_process(_delta: float) -> void:
	var input_dir := Vector2.ZERO
	input_dir.x = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	input_dir.y = Input.get_action_strength("move_down") - Input.get_action_strength("move_up")

	# Virtual joystick input
	var joystick := get_tree().get_first_node_in_group("virtual_joystick")
	if joystick:
		input_dir += joystick.get_direction()

	if input_dir.length() > 0:
		input_dir = input_dir.normalized()
	velocity = input_dir * move_speed
	move_and_slide()

	# Animation state
	if velocity.length() > 10.0:
		if _sprite.animation != "run":
			_sprite.play("run")
		# Flip based on horizontal direction
		if velocity.x < 0:
			_sprite.flip_h = true
		elif velocity.x > 0:
			_sprite.flip_h = false
	else:
		if _sprite.animation != "idle":
			_sprite.play("idle")

func take_damage(amount: int) -> void:
	if _invincible or _dying:
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
	_sprite.play("hit")
	modulate = Color(1, 0.5, 0.5, 0.6)
	await get_tree().create_timer(0.25).timeout
	modulate = Color.WHITE
	_invincible = false
	if _sprite.animation == "hit":
		_sprite.play("idle")

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
