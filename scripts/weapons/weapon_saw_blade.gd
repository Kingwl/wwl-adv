extends WeaponBase

var _saws: Array[Area2D] = []
var _angle: float = 0.0
var _base_sweep_speed: float = 4.0

func _ready() -> void:
	super._ready()
	_rebuild_saws()

func _process(delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player")
	if not player:
		return
	_angle += _get_sweep_speed() * delta
	var radius := get_range()
	var count := _saws.size()
	for i in range(count):
		var saw := _saws[i]
		if not saw:
			continue
		var angle_offset := _angle + (TAU / count) * i
		var offset := Vector2(cos(angle_offset), sin(angle_offset)) * radius
		saw.global_position = player.global_position + offset

func _rebuild_saws() -> void:
	# Remove old saws
	for saw in _saws:
		if saw:
			saw.queue_free()
	_saws.clear()

	var count := _get_saw_count()
	for i in range(count):
		_spawn_saw(i)
	if count > 0:
		_play_sfx(-3.0, 1.0)

func _spawn_saw(index: int) -> void:
	var saw := Area2D.new()
	saw.collision_layer = 4
	saw.collision_mask = 2

	var shape := CircleShape2D.new()
	shape.radius = _get_saw_shape_radius()
	var cs := CollisionShape2D.new()
	cs.shape = shape
	saw.add_child(cs)

	saw.body_entered.connect(_on_saw_hit.bind(saw))

	VFXHelper.spawn_animated_loop(
		saw,
		"res://assets/art/effects/by_type/fx_saw_blade",
		"saw",
		4,
		10.0
	)

	var player := get_tree().get_first_node_in_group("player")
	if player:
		var __proj := player.get_tree().current_scene.get_node_or_null("Projectiles")
		if __proj == null:
			__proj = player.get_tree().current_scene.find_child("Projectiles", true, false)
		if __proj:
			__proj.add_child(saw)

	_saws.append(saw)

func _on_saw_hit(body: Node2D, saw: Area2D) -> void:
	if body.is_in_group("enemies"):
		_deal_damage_to(body, get_damage(), DamageEvent.DAMAGE_TYPE_PHYSICAL, DamageEvent.DELIVERY_AREA)

func _get_saw_count() -> int:
	var count := 1
	if has_special_tag(&"dual_saw"):
		count += 1
	if has_special_tag(&"triple_saw"):
		count += 2
	if has_special_tag(&"saw_swarm"):
		count += 3
	return count

func _get_sweep_speed() -> float:
	var speed := _base_sweep_speed
	if has_special_tag(&"faster_spin"):
		speed += 1.0
	if has_special_tag(&"blade_storm"):
		speed += 2.0
	return speed

func _get_saw_shape_radius() -> float:
	var r := 12.0
	if has_special_tag(&"larger_saw"):
		r *= 1.2
	if has_special_tag(&"massive_saw"):
		r *= 1.3
	return r

func get_cooldown_progress() -> float:
	return 0.0

func _on_level_up() -> void:
	_rebuild_saws()
