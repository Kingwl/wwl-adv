extends Area2D

const VACUUM_SPEED := 1400.0
const MAX_DROPS_STARTED_PER_FRAME := 48

@export var magnet_speed: float = 280.0
@export var magnet_distance: float = 150.0

var _player: Node2D
var _magnetized: bool = false
var _activated: bool = false
var _pending_drops: Array[Node] = []
@onready var _anim: AnimatedSprite2D = $Visual

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_player = get_tree().get_first_node_in_group("player")
	_anim.sprite_frames = VFXHelper.build_sprite_frames(
		"res://assets/art/effects/by_type/fx_pickup_glow",
		"pickup_glow",
		4,
		8.0,
		true
	)
	_anim.modulate = Color(0.5, 0.9, 1.0, 1.0)
	if _anim.sprite_frames.get_frame_count("default") > 0:
		_anim.play("default")

func _process(delta: float) -> void:
	if _activated:
		_process_pending_drops()
		return
	if not _player:
		return
	var dist := global_position.distance_to(_player.global_position)
	if dist < magnet_distance:
		_magnetized = true
	if not _magnetized:
		return
	var offset := _player.global_position - global_position
	if offset.length() <= 6.0:
		_activate()
		return
	global_position += offset.normalized() * magnet_speed * delta

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player = body
		_activate()

func _activate() -> void:
	if _activated:
		return
	_activated = true
	if is_inside_tree():
		VFXHelper.spawn_animated_one_shot(
			get_tree().current_scene,
			"res://assets/art/effects/by_type/fx_pickup_glow",
			"pickup_glow",
			4,
			global_position,
			10.0,
			Vector2(1.5, 1.5)
		)
	_collect_ground_drop_snapshot()
	_hide_after_activation()
	_process_pending_drops()

func _collect_ground_drop_snapshot() -> void:
	if not _player:
		return
	for drop in get_tree().get_nodes_in_group("drops"):
		if drop == self or not is_instance_valid(drop) or drop.is_queued_for_deletion():
			continue
		if drop.has_method("force_magnetize_to_player"):
			_pending_drops.append(drop)

func _hide_after_activation() -> void:
	hide()
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	var collision := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision:
		collision.set_deferred("disabled", true)

func _process_pending_drops() -> void:
	if not _player:
		_pending_drops.clear()
		queue_free()
		return
	var attempts := 0
	while attempts < MAX_DROPS_STARTED_PER_FRAME and not _pending_drops.is_empty():
		attempts += 1
		var drop: Node = _pending_drops.pop_back()
		if not is_instance_valid(drop) or drop.is_queued_for_deletion():
			continue
		if drop.has_method("force_magnetize_to_player"):
			drop.call("force_magnetize_to_player", _player, VACUUM_SPEED, true)
	if _pending_drops.is_empty():
		queue_free()
