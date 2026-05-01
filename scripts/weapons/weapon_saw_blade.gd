extends WeaponBase

const DEPLOY_FORWARD_DISTANCE := 90.0
const DEFAULT_ACQUIRE_RANGE := 360.0
const SAW_LIFETIME := 3.2
const TRACK_SPACING := 28.0
const MAX_ACTIVE_GROUPS := 3

var _saws: Array[Area2D] = []
var _base_sweep_speed: float = 5.0
var _deploy_timer: float = 0.0

func _ready() -> void:
	super._ready()
	_deploy_saws()
	_deploy_timer = _get_deploy_interval()

func _process(delta: float) -> void:
	_deploy_timer -= delta
	if _deploy_timer <= 0.0:
		_deploy_saws()
		_deploy_timer = _get_deploy_interval()
	_update_saw_positions(delta)

func _deploy_saws() -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if not player:
		return

	var count := _get_saw_count()
	var anchor := _choose_deploy_anchor(player)
	var axis := _choose_deploy_axis(player, anchor)
	_trim_active_saws(count)
	for i in range(count):
		_spawn_saw(anchor, axis, i, count)
	_update_saw_positions(0.0)
	if not _saws.is_empty():
		_play_sfx(-3.0, 1.0)

func _update_saw_positions(delta: float) -> void:
	var radius := get_range()
	for i in range(_saws.size() - 1, -1, -1):
		var saw := _saws[i]
		if not is_instance_valid(saw):
			_saws.remove_at(i)
			continue
		var remaining := float(saw.get_meta("remaining", SAW_LIFETIME)) - delta
		if remaining <= 0.0:
			saw.queue_free()
			_saws.remove_at(i)
			continue
		var phase := float(saw.get_meta("phase", 0.0)) + _get_sweep_speed() * delta
		saw.set_meta("remaining", remaining)
		saw.set_meta("phase", phase)
		var anchor: Vector2 = saw.get_meta("anchor", Vector2.ZERO)
		var axis: Vector2 = saw.get_meta("axis", Vector2.RIGHT)
		saw.global_position = anchor + axis * sin(phase) * radius

func _clear_saws() -> void:
	for saw in _saws:
		if is_instance_valid(saw):
			saw.queue_free()
	_saws.clear()

func _spawn_saw(anchor: Vector2, axis: Vector2, index: int, count: int) -> void:
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

	var parent := _get_projectiles_parent()
	if parent:
		parent.add_child(saw)

	var side_axis := axis.rotated(PI / 2.0)
	var lane_offset := side_axis * (float(index) - float(count - 1) * 0.5) * TRACK_SPACING
	saw.set_meta("anchor", anchor + lane_offset)
	saw.set_meta("axis", axis)
	saw.set_meta("phase", float(index) * PI / maxf(1.0, float(count)))
	saw.set_meta("remaining", SAW_LIFETIME)
	_saws.append(saw)

func _on_saw_hit(body: Node2D, _saw: Area2D) -> void:
	if body.is_in_group("enemies"):
		_deal_damage_to(body, get_damage(), DamageEvent.DAMAGE_TYPE_PHYSICAL, DamageEvent.DELIVERY_AREA)

func _choose_deploy_anchor(player: Node2D) -> Vector2:
	var target := _find_nearest_enemy(player.global_position)
	if target:
		return target.global_position
	var dir := _get_player_facing_dir(player)
	return player.global_position + dir * minf(get_range(), DEPLOY_FORWARD_DISTANCE)

func _choose_deploy_axis(player: Node2D, anchor: Vector2) -> Vector2:
	var dir := anchor - player.global_position
	if dir.length_squared() <= 0.01:
		dir = _get_player_facing_dir(player)
	return dir.normalized()

func _get_player_facing_dir(player: Node2D) -> Vector2:
	if player is CharacterBody2D:
		var velocity := (player as CharacterBody2D).velocity
		if velocity.length_squared() > 0.01:
			return velocity.normalized()
	return Vector2.RIGHT

func _find_nearest_enemy(from_pos: Vector2) -> Node2D:
	var nearest: Node2D = null
	var min_dist := INF
	var acquire_range := _get_acquire_range()
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not _is_valid_enemy_target(enemy):
			continue
		var e := enemy as Node2D
		var dist := from_pos.distance_to(e.global_position)
		if dist > acquire_range:
			continue
		if dist < min_dist:
			min_dist = dist
			nearest = e
	return nearest

func _get_projectiles_parent() -> Node:
	var current := get_tree().current_scene
	if not current:
		return null
	var projectiles := current.get_node_or_null("Projectiles")
	if not projectiles:
		projectiles = current.find_child("Projectiles", true, false)
	return projectiles

func _trim_active_saws(incoming_count: int) -> void:
	var max_active := _get_saw_count() * MAX_ACTIVE_GROUPS
	while _saws.size() + incoming_count > max_active and not _saws.is_empty():
		var saw := _saws.pop_front() as Area2D
		if is_instance_valid(saw):
			saw.queue_free()

func _get_deploy_interval() -> float:
	return maxf(0.45, get_cooldown())

func _get_acquire_range() -> float:
	if weapon_data and weapon_data.acquire_range > 0.0:
		return weapon_data.acquire_range
	return DEFAULT_ACQUIRE_RANGE

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
	var interval := _get_deploy_interval()
	if interval <= 0.001:
		return 0.0
	return clampf(_deploy_timer / interval, 0.0, 1.0)

func _on_level_up() -> void:
	_deploy_saws()
