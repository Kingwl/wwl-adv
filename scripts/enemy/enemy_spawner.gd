extends Node

@export var spawn_radius_min: float = 450.0
@export var spawn_radius_max: float = 700.0
@export var base_spawn_interval: float = 2.0

var _player: Node2D
var _elapsed_time: float = 0.0
var _spawn_timer: float = 0.0

func _ready() -> void:
	_player = get_tree().get_first_node_in_group("player")

func _process(delta: float) -> void:
	_elapsed_time += delta
	_spawn_timer -= delta
	if _spawn_timer <= 0:
		_spawn_enemy()
		_spawn_timer = _get_spawn_interval()

func _spawn_enemy() -> void:
	if not _player:
		return

	var enemy_scene := preload("res://scenes/enemy/enemy.tscn")
	var enemy := enemy_scene.instantiate() as CharacterBody2D

	var angle := randf() * TAU
	var radius := randf_range(spawn_radius_min, spawn_radius_max)
	var spawn_pos := _player.global_position + Vector2(cos(angle), sin(angle)) * radius
	enemy.global_position = spawn_pos

	var enemy_data_list := DataManager.all_enemies()
	if not enemy_data_list.is_empty():
		var valid_enemies := enemy_data_list.filter(func(d: EnemyData) -> bool:
			return _elapsed_time >= d.min_spawn_time
		)
		if not valid_enemies.is_empty():
			var data: EnemyData = _weighted_pick(valid_enemies)
			enemy.enemy_data = data

	var enemies_parent := get_tree().current_scene.get_node_or_null("Enemies")
	if enemies_parent:
		enemies_parent.add_child(enemy)
		# Apply time-based difficulty scaling
		var time_factor := 1.0 + _elapsed_time / 120.0
		enemy._hp = int(enemy._hp * time_factor)
		enemy._base_speed *= time_factor
		enemy._damage = int(enemy._damage * time_factor)

func _get_spawn_interval() -> float:
	var difficulty_multiplier := 1.0 + (_elapsed_time / 60.0) * 0.5
	return max(0.3, base_spawn_interval / difficulty_multiplier)

func _weighted_pick(enemies: Array) -> EnemyData:
	var total_weight := 0.0
	for e in enemies:
		total_weight += e.spawn_weight

	var pick := randf() * total_weight
	var current := 0.0
	for e in enemies:
		current += e.spawn_weight
		if pick <= current:
			return e
	return enemies[0]
