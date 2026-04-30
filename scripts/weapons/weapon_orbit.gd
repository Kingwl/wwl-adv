extends WeaponBase

var _orbs: Array[Area2D] = []
var _angle: float = 0.0
var _player: Node2D
var _orbit_count: int = 2
var _orbit_speed: float = 3.0

func _ready() -> void:
	super._ready()
	_player = get_tree().get_first_node_in_group("player")
	_orbit_count = _get_orbit_count()
	_orbit_speed = _get_orbit_speed()
	_spawn_orbs()

func _process(delta: float) -> void:
	if not _player:
		return
	_angle += _orbit_speed * delta
	var radius := _get_orbit_radius()
	var valid_orbs: Array[Area2D] = []
	for i in range(_orbs.size()):
		var orb := _orbs[i]
		if not is_instance_valid(orb):
			continue
		valid_orbs.append(orb)
		var idx := valid_orbs.size() - 1
		var orb_angle: float = _angle + float(idx) / max(1, valid_orbs.size()) * TAU
		orb.global_position = _player.global_position + Vector2(cos(orb_angle), sin(orb_angle)) * radius
	_orbs = valid_orbs

func _spawn_orbs() -> void:
	for i in range(_orbit_count):
		var orb := Area2D.new()
		orb.collision_layer = 4
		orb.collision_mask = 2

		var shape := CircleShape2D.new()
		shape.radius = 10.0
		var cs := CollisionShape2D.new()
		cs.shape = shape
		orb.add_child(cs)

		orb.body_entered.connect(_on_orb_hit)

		VFXHelper.spawn_animated_loop(
			orb,
			"res://assets/art/effects/by_type/fx_orb",
			"orb",
			4,
			10.0
		)

		var __proj := _player.get_tree().current_scene.get_node_or_null("Projectiles")
		if __proj == null:
			__proj = _player.get_tree().current_scene.find_child("Projectiles", true, false)
		if __proj:
			__proj.add_child(orb)
		_orbs.append(orb)

func _on_orb_hit(body: Node2D) -> void:
	if body.is_in_group("enemies"):
		body.take_damage(get_damage())

func get_cooldown_progress() -> float:
	return 0.0

func _on_level_up() -> void:
	var target := _get_orbit_count()
	if _orbs.size() < target:
		_rebuild_orbs()

func _rebuild_orbs() -> void:
	for orb in _orbs:
		orb.queue_free()
	_orbs.clear()
	_orbit_count = _get_orbit_count()
	_orbit_speed = _get_orbit_speed()
	_spawn_orbs()

func _get_orbit_count() -> int:
	var base := weapon_data.orbit_count if weapon_data else 2
	var bonus := 0
	if has_special_tag(&"orb_constellation"):
		bonus = 4
	elif has_special_tag(&"orb_swarm"):
		bonus = 3
	elif has_special_tag(&"more_orbs"):
		bonus = 2
	elif has_special_tag(&"extra_orb"):
		bonus = 1
	return base + bonus

func _get_orbit_speed() -> float:
	var base := 3.0
	if has_special_tag(&"blade_storm"):
		return base * 2.0
	if has_special_tag(&"rapid_spin"):
		return base * 1.6
	if has_special_tag(&"faster_spin"):
		return base * 1.3
	return base

func _get_orbit_radius() -> float:
	var r := get_range()
	if has_special_tag(&"wider_orbit"):
		r += 15.0
	return r
