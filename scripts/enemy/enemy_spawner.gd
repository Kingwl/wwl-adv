extends Node

@export var spawn_view_margin_min: float = 80.0
@export var spawn_view_margin_max: float = 300.0
@export var base_spawn_interval: float = 2.4
@export var min_spawn_interval: float = 0.55
@export var spawn_acceleration_per_minute: float = 0.32
@export var stat_scale_period: float = 210.0
@export var speed_scale_period: float = 360.0
@export var max_speed_scale: float = 1.55
@export var max_alive_enemies: int = 150
@export var pack_spawn_min_spacing: float = 72.0
@export var pack_spawn_spread: float = 160.0
@export var exp_reward_scale_strength: float = 0.5
@export var max_exp_reward_scale: float = 3.0
@export var gold_reward_scale_strength: float = 0.25
@export var max_gold_reward_scale: float = 2.0
@export var late_weight_start_time: float = 510.0
@export var late_imp_weight_multiplier: float = 0.35
@export var late_dash_weight_multiplier: float = 2.0
@export var late_ranged_weight_multiplier: float = 1.8
@export var late_elite_weight_multiplier: float = 2.4
@export var boss_spawn_events: Array[Dictionary] = [
	{"time": 300.0, "enemy_id": &"boss_warlord"},
	{"time": 510.0, "enemy_ids": [&"boss_frost_guardian", &"boss_rune_seer"]},
	{"time": 720.0, "enemy_id": &"boss_icecrown_overlord"},
]

var _player: Node2D
var _elapsed_time: float = 0.0
var _spawn_timer: float = 0.0
var _spawned_boss_events: Array[int] = []

func _ready() -> void:
	_player = get_tree().get_first_node_in_group("player")

func _process(delta: float) -> void:
	_elapsed_time += delta
	if not _try_spawn_boss_event().is_empty():
		_spawn_timer = maxf(_spawn_timer, base_spawn_interval)
		return
	_spawn_timer -= delta
	if _spawn_timer <= 0:
		_spawn_enemy()
		_spawn_timer = _get_spawn_interval()

func _spawn_enemy() -> void:
	if not _player:
		return
	if _get_alive_enemy_count() >= max_alive_enemies:
		return

	var data := _pick_enemy_data()
	_spawn_enemy_pack(data)

func _try_spawn_boss_event() -> Array[CharacterBody2D]:
	var spawned: Array[CharacterBody2D] = []
	if not _player:
		return spawned
	for event_index in range(boss_spawn_events.size()):
		if _spawned_boss_events.has(event_index):
			continue
		var event: Dictionary = boss_spawn_events[event_index]
		var spawn_time := float(event.get("time", -1.0))
		if spawn_time < 0.0 or _elapsed_time < spawn_time:
			continue
		spawned = _spawn_bosses(_get_boss_event_enemy_ids(event), event_index)
		if not spawned.is_empty():
			_spawned_boss_events.append(event_index)
		return spawned
	return spawned

func _try_spawn_boss() -> CharacterBody2D:
	var spawned := _try_spawn_boss_event()
	if spawned.is_empty():
		return null
	return spawned[0]

func _spawn_bosses(enemy_ids: Array[StringName], event_index: int = -1) -> Array[CharacterBody2D]:
	var spawned: Array[CharacterBody2D] = []
	for enemy_id in enemy_ids:
		var boss := _spawn_boss(enemy_id)
		if boss:
			if event_index >= 0 and "boss_drop_key" in boss:
				boss.boss_drop_key = StringName("boss_event_%d" % event_index)
			spawned.append(boss)
	return spawned

func _spawn_boss(enemy_id: StringName) -> CharacterBody2D:
	if enemy_id.is_empty():
		return null
	var boss_data := DataManager.get_enemy(str(enemy_id)) as EnemyData
	if not boss_data:
		push_warning("EnemySpawner: boss enemy data not found: %s" % enemy_id)
		return null
	var boss := _spawn_single_enemy(boss_data, _get_spawn_position())
	return boss

func _get_boss_event_enemy_ids(event: Dictionary) -> Array[StringName]:
	var result: Array[StringName] = []
	var values = event.get("enemy_ids", [])
	if values is Array:
		for value in values:
			var enemy_id := _normalize_boss_enemy_id(value)
			if not enemy_id.is_empty():
				result.append(enemy_id)
	var single_id := _normalize_boss_enemy_id(event.get("enemy_id", &""))
	if not single_id.is_empty() and not result.has(single_id):
		result.append(single_id)
	return result

func _get_boss_event_enemy_id(event: Dictionary) -> StringName:
	var ids := _get_boss_event_enemy_ids(event)
	if ids.is_empty():
		return &""
	return ids[0]

func _normalize_boss_enemy_id(value) -> StringName:
	if value is StringName:
		return value
	return StringName(str(value))

func _spawn_enemy_pack(data: EnemyData = null) -> Array[CharacterBody2D]:
	var spawned: Array[CharacterBody2D] = []
	if not _player:
		return spawned

	var pack_size := _get_pack_size(data)
	var base_pos := _get_spawn_position()
	var base_angle := randf() * TAU
	for i in range(pack_size):
		if _get_alive_enemy_count() >= max_alive_enemies:
			break
		var offset := _get_pack_member_offset(i, pack_size, base_angle)
		var enemy := _spawn_single_enemy(data, base_pos + offset)
		if enemy:
			spawned.append(enemy)
	return spawned

func _spawn_single_enemy(data: EnemyData, spawn_pos: Vector2) -> CharacterBody2D:
	var enemy_scene := preload("res://scenes/enemy/enemy.tscn")
	var enemy := enemy_scene.instantiate() as CharacterBody2D
	enemy.global_position = spawn_pos
	if data:
		enemy.enemy_data = data

	var enemies_parent := _get_enemies_parent()
	if enemies_parent:
		enemies_parent.add_child(enemy)
		# Apply time-based difficulty scaling
		var stat_factor := _get_stat_scale()
		var speed_factor := _get_speed_scale()
		enemy._hp = int(enemy._hp * stat_factor)
		enemy._base_speed *= speed_factor
		enemy._damage = int(enemy._damage * stat_factor)
		_scale_enemy_rewards(enemy, stat_factor)
		enemy._setup_health_bar()
		return enemy
	enemy.queue_free()
	return null

func _get_spawn_position() -> Vector2:
	var angle := randf() * TAU
	var radius_bounds := _get_spawn_radius_bounds()
	var radius := randf_range(radius_bounds.x, radius_bounds.y)
	return _player.global_position + Vector2(cos(angle), sin(angle)) * radius

func _pick_enemy_data() -> EnemyData:
	var valid_enemies := _get_valid_enemy_data()
	if valid_enemies.is_empty():
		return null
	return _weighted_pick(valid_enemies)

func _get_valid_enemy_data() -> Array:
	var enemy_data_list := DataManager.all_enemies()
	return enemy_data_list.filter(func(d: EnemyData) -> bool:
		if _get_enemy_spawn_weight(d) <= 0.0:
			return false
		if _elapsed_time < d.min_spawn_time:
			return false
		return d.max_spawn_time < 0.0 or _elapsed_time <= d.max_spawn_time
	)

func _get_pack_size(data: EnemyData) -> int:
	if not data:
		return 1
	return maxi(data.pack_size, 1)

func _get_pack_member_offset(index: int, pack_size: int, base_angle: float = 0.0) -> Vector2:
	if index <= 0 or pack_size <= 1:
		return Vector2.ZERO
	var max_radius := maxf(pack_spawn_spread, pack_spawn_min_spacing)
	var min_radius := minf(pack_spawn_min_spacing, max_radius)
	var angle_step := TAU / float(maxi(pack_size, 2))
	var jitter := randf_range(-angle_step * 0.2, angle_step * 0.2)
	var radius := randf_range(min_radius, max_radius)
	return Vector2.RIGHT.rotated(base_angle + angle_step * float(index) + jitter) * radius

func _get_alive_enemy_count() -> int:
	var enemies_parent := _get_enemies_parent()
	if not enemies_parent:
		return 0
	var count := 0
	for child in enemies_parent.get_children():
		if is_instance_valid(child) and not child.is_queued_for_deletion():
			count += 1
	return count

func _get_enemies_parent() -> Node:
	var parent := get_parent()
	if parent:
		var sibling := parent.get_node_or_null("Enemies")
		if sibling:
			return sibling
	var current := get_tree().current_scene
	if current:
		return current.find_child("Enemies", true, false)
	return null

func _get_spawn_interval() -> float:
	var difficulty_multiplier := 1.0 + (_elapsed_time / 60.0) * spawn_acceleration_per_minute
	return max(min_spawn_interval, base_spawn_interval / difficulty_multiplier)

func _get_stat_scale() -> float:
	return 1.0 + _elapsed_time / maxf(stat_scale_period, 1.0)

func _get_speed_scale() -> float:
	var uncapped_scale := 1.0 + _elapsed_time / maxf(speed_scale_period, 1.0)
	return minf(uncapped_scale, max_speed_scale)

func _scale_enemy_rewards(enemy: CharacterBody2D, stat_factor: float) -> void:
	if not enemy:
		return
	enemy._exp_reward = maxi(1, int(round(float(enemy._exp_reward) * _get_reward_scale(stat_factor, exp_reward_scale_strength, max_exp_reward_scale))))
	if enemy._gold_reward > 0:
		enemy._gold_reward = maxi(1, int(round(float(enemy._gold_reward) * _get_reward_scale(stat_factor, gold_reward_scale_strength, max_gold_reward_scale))))

func _get_reward_scale(stat_factor: float, strength: float, max_scale: float) -> float:
	return clampf(1.0 + maxf(0.0, stat_factor - 1.0) * strength, 1.0, max_scale)

func _get_enemy_spawn_weight(data: EnemyData) -> float:
	if not data or data.spawn_weight <= 0.0:
		return 0.0
	var multiplier := 1.0
	if _elapsed_time >= late_weight_start_time:
		multiplier *= _get_late_spawn_weight_multiplier(data)
	return maxf(0.0, data.spawn_weight * multiplier)

func _get_late_spawn_weight_multiplier(data: EnemyData) -> float:
	var multiplier := 1.0
	if data.id == &"imp":
		multiplier *= late_imp_weight_multiplier
	if data.tags.has(&"dash") or data.behavior_id == EnemyData.BEHAVIOR_DASH:
		multiplier *= late_dash_weight_multiplier
	if data.tags.has(&"ranged") or data.behavior_id == EnemyData.BEHAVIOR_RANGED:
		multiplier *= late_ranged_weight_multiplier
	if data.tags.has(&"elite"):
		multiplier *= late_elite_weight_multiplier
	return multiplier

func _get_spawn_radius_bounds() -> Vector2:
	var view_radius := _get_view_radius()
	var min_radius := view_radius + spawn_view_margin_min
	var max_margin: float = max(spawn_view_margin_max, spawn_view_margin_min + 1.0)
	return Vector2(min_radius, view_radius + max_margin)

func _get_view_radius() -> float:
	var viewport_size := Vector2(720.0, 1280.0)
	var viewport := get_viewport()
	if viewport:
		var visible_size := viewport.get_visible_rect().size
		if visible_size.x > 0.0 and visible_size.y > 0.0:
			viewport_size = visible_size
	return (viewport_size * 0.5).length()

func _weighted_pick(enemies: Array) -> EnemyData:
	var total_weight := 0.0
	for e in enemies:
		total_weight += _get_enemy_spawn_weight(e)
	if total_weight <= 0.0:
		return null

	var pick := randf() * total_weight
	var current := 0.0
	for e in enemies:
		current += _get_enemy_spawn_weight(e)
		if pick <= current:
			return e
	return enemies[0]
