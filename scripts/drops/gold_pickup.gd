extends Area2D

@export var gold_value: int = 1
@export var magnet_speed: float = 250.0
@export var magnet_distance: float = 120.0

var _player: Node2D
var _magnetized: bool = false
var _collected: bool = false
var _suppress_collect_fx: bool = false
@onready var _anim: AnimatedSprite2D = $Visual

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_player = get_tree().get_first_node_in_group("player")

	var frames := SpriteFrames.new()
	for i in range(5):
		var texture_path := "res://assets/art/effects/by_type/drop_gold_coin/gold_%02d.png" % (i + 1)
		if not ResourceLoader.exists(texture_path):
			continue
		var texture := ResourceLoader.load(texture_path) as Texture2D
		if texture:
			frames.add_frame("default", texture)
		else:
			push_warning("GoldPickup: failed to load texture %s" % texture_path)
	frames.set_animation_loop("default", true)
	frames.set_animation_speed("default", 6.0)
	_anim.sprite_frames = frames
	if frames.get_frame_count("default") > 0:
		_anim.play("default")

func _process(delta: float) -> void:
	if not _player:
		return
	var dist := global_position.distance_to(_player.global_position)
	var effective_magnet: float = magnet_distance + GameState.run.get("pickup_radius_bonus", 0.0)
	if dist < effective_magnet:
		_magnetized = true

	if _magnetized:
		_move_to_player(delta)

func force_magnetize_to_player(player: Node2D, speed: float = 1200.0, suppress_collect_fx: bool = false) -> void:
	if _collected:
		return
	if player:
		_player = player
	magnet_speed = maxf(magnet_speed, speed)
	_magnetized = _player != null
	_suppress_collect_fx = _suppress_collect_fx or suppress_collect_fx

func _move_to_player(delta: float) -> void:
	var offset := _player.global_position - global_position
	var dist := offset.length()
	if dist <= 4.0:
		_collect()
		return
	var step := magnet_speed * delta
	if step >= dist:
		global_position = _player.global_position
		_collect()
		return
	global_position += offset / dist * step

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_collect()

func _collect() -> void:
	if _collected:
		return
	_collected = true
	if is_queued_for_deletion():
		return
	if is_inside_tree() and not _suppress_collect_fx:
		VFXHelper.spawn_animated_one_shot(
			get_tree().current_scene,
			"res://assets/art/effects/by_type/fx_pickup_glow",
			"pickup_glow",
			4,
			global_position,
			8.0
		)
	GameState.add_gold(gold_value)
	queue_free()
