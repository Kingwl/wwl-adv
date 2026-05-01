extends CharacterBody2D

@export var enemy_data: EnemyData

const CONTACT_DAMAGE_PADDING := 2.0
const DEFAULT_CONTACT_RADIUS := 16.0
const DEFAULT_FRAME_SIZE := Vector2i(64, 64)
const DEFAULT_ANIMATION_COLUMNS := 6
const DASH_STATE_COOLDOWN := &"cooldown"
const DASH_STATE_WINDUP := &"windup"
const DASH_STATE_DASHING := &"dashing"
const DASH_STATE_RECOVER := &"recover"

var _hp: int = 12
var _base_speed: float = 60.0
var _damage: int = 5
var _exp_reward: int = 2
var _gold_reward: int = 1
var _configured_collision_radius: float = DEFAULT_CONTACT_RADIUS
var _base_modulate: Color = Color.WHITE
var _behavior_id: StringName = EnemyData.BEHAVIOR_CHASE
var _dash_speed_multiplier: float = 2.6
var _dash_windup: float = 0.22
var _dash_duration: float = 0.32
var _dash_recover_duration: float = 0.42
var _dash_cooldown: float = 2.4
var _preferred_range: float = 260.0
var _retreat_range: float = 150.0
var _attack_range: float = 360.0
var _ranged_attack_cooldown: float = 2.0
var _projectile_damage: int = 0
var _projectile_speed: float = 280.0
var _projectile_range: float = 420.0
var _projectile_radius: float = 5.0
var _projectile_modulate: Color = Color.WHITE
var _projectile_animation_sheet: Texture2D = null
var _projectile_animation_frame_size: Vector2i = Vector2i(32, 32)
var _projectile_animation_columns: int = 4
var _projectile_animation_frame_count: int = 0
var _projectile_animation_speed: float = 10.0
var _projectile_visual_rotation_offset: float = PI
var _projectile_sprite_frames: SpriteFrames = null
var _boss_projectile_count: int = 8
var _dash_state: StringName = DASH_STATE_COOLDOWN
var _dash_timer: float = 0.0
var _dash_direction: Vector2 = Vector2.RIGHT
var _ranged_attack_timer: float = 0.0
var _strafe_sign: float = 1.0
var _boss_volley_index: int = 0
var _can_damage: bool = true
var _damage_cooldown: float = 1.0
var _dead: bool = false

# 状态系统: status_name -> StatusEffect
var _statuses: Dictionary = {}

@onready var _player: Node2D
@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _health_bar: ProgressBar = $HealthBar

func _ready() -> void:
	_player = get_tree().get_first_node_in_group("player")
	if enemy_data:
		_hp = enemy_data.max_hp
		_base_speed = enemy_data.speed
		_damage = enemy_data.damage
		_exp_reward = enemy_data.exp_reward
		_gold_reward = enemy_data.gold_reward
		_damage_cooldown = enemy_data.contact_damage_cooldown
		_configured_collision_radius = enemy_data.collision_radius
		_base_modulate = enemy_data.visual_modulate
		_behavior_id = enemy_data.behavior_id
		_dash_speed_multiplier = enemy_data.dash_speed_multiplier
		_dash_windup = enemy_data.dash_windup
		_dash_duration = enemy_data.dash_duration
		_dash_recover_duration = enemy_data.dash_recover_duration
		_dash_cooldown = enemy_data.dash_cooldown
		_preferred_range = enemy_data.preferred_range
		_retreat_range = enemy_data.retreat_range
		_attack_range = enemy_data.attack_range
		_ranged_attack_cooldown = enemy_data.attack_cooldown
		_projectile_damage = enemy_data.projectile_damage
		_projectile_speed = enemy_data.projectile_speed
		_projectile_range = enemy_data.projectile_range
		_projectile_radius = enemy_data.projectile_radius
		_projectile_modulate = enemy_data.projectile_modulate
		_projectile_animation_sheet = enemy_data.projectile_animation_sheet
		_projectile_animation_frame_size = enemy_data.projectile_animation_frame_size
		_projectile_animation_columns = enemy_data.projectile_animation_columns
		_projectile_animation_frame_count = enemy_data.projectile_animation_frame_count
		_projectile_animation_speed = enemy_data.projectile_animation_speed
		_projectile_visual_rotation_offset = enemy_data.projectile_visual_rotation_offset
		_boss_projectile_count = enemy_data.boss_projectile_count
		if _sprite:
			_sprite.scale = Vector2.ONE * enemy_data.visual_scale
		if _is_boss():
			add_to_group("bosses")
	_projectile_sprite_frames = _build_projectile_sprite_frames()
	_setup_collision_shape()
	_setup_animations()
	_setup_health_bar()
	_reset_behavior_state()
	_refresh_status_visual()

func _setup_collision_shape() -> void:
	var shape_node := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if not shape_node:
		return
	var circle := shape_node.shape as CircleShape2D
	if not circle:
		circle = CircleShape2D.new()
		shape_node.shape = circle
	circle.radius = maxf(_configured_collision_radius, 1.0)

func _setup_animations() -> void:
	var frames := SpriteFrames.new()
	var animation_sheet: Texture2D = null
	var frame_size := DEFAULT_FRAME_SIZE
	var columns := DEFAULT_ANIMATION_COLUMNS
	if enemy_data:
		animation_sheet = enemy_data.animation_sheet
		if enemy_data.animation_frame_size.x > 0 and enemy_data.animation_frame_size.y > 0:
			frame_size = enemy_data.animation_frame_size
		columns = maxi(enemy_data.animation_columns, DEFAULT_ANIMATION_COLUMNS)

	if animation_sheet:
		_setup_sheet_animations(frames, animation_sheet, frame_size, columns)
	else:
		_setup_default_animations(frames)

	_sprite.sprite_frames = frames
	_sprite.play("walk")

func _setup_sheet_animations(frames: SpriteFrames, sheet: Texture2D, frame_size: Vector2i, columns: int) -> void:
	_add_sheet_animation(frames, &"walk", sheet, [0, 1, 2, 3], frame_size, columns, true, 6.0)
	_add_sheet_animation(frames, &"hit", sheet, [4, 0], frame_size, columns, false, 8.0)
	_add_sheet_animation(frames, &"death", sheet, [4, 5, 5, 5, 5, 5], frame_size, columns, false, 8.0)

func _setup_default_animations(frames: SpriteFrames) -> void:
	_add_sheet_animation(frames, &"walk", load("res://assets/art/characters/enemy_walk_sheet.png"), [0, 1, 2, 3], DEFAULT_FRAME_SIZE, 4, true, 6.0)
	_add_sheet_animation(frames, &"hit", load("res://assets/art/characters/enemy_hit_sheet.png"), [0, 1], DEFAULT_FRAME_SIZE, 2, false, 8.0)
	_add_sheet_animation(frames, &"death", load("res://assets/art/characters/enemy_death_sheet.png"), [0, 1, 2, 3, 4, 5], DEFAULT_FRAME_SIZE, 6, false, 8.0)

func _add_sheet_animation(
	frames: SpriteFrames,
	animation: StringName,
	sheet: Texture2D,
	frame_indices: Array[int],
	frame_size: Vector2i,
	columns: int,
	loop: bool,
	speed: float
) -> void:
	frames.add_animation(animation)
	for frame_index in frame_indices:
		var atlas := AtlasTexture.new()
		atlas.atlas = sheet
		var column := frame_index % columns
		var row := frame_index / columns
		atlas.region = Rect2(column * frame_size.x, row * frame_size.y, frame_size.x, frame_size.y)
		frames.add_frame(animation, atlas)
	frames.set_animation_loop(animation, loop)
	frames.set_animation_speed(animation, speed)

func _process(delta: float) -> void:
	var expired: Array[String] = []
	for status_key in _statuses.keys():
		var effect := _statuses[status_key] as StatusEffect
		if not effect or effect.tick(delta, self):
			expired.append(str(status_key))
	for status_key in expired:
		var effect := _statuses.get(status_key) as StatusEffect
		_statuses.erase(status_key)
		_on_status_removed(effect.id if effect else StringName(status_key))

func _physics_process(delta: float) -> void:
	if _player:
		if _has_status(&"stun"):
			velocity = Vector2.ZERO
			move_and_slide()
			return

		var current_speed := _base_speed
		var slow_effect := _get_status(&"slow")
		if slow_effect:
			current_speed *= slow_effect.effective_value()

		var dir := (_player.global_position - global_position).normalized()
		var distance := global_position.distance_to(_player.global_position)
		_try_ranged_attack(delta, dir, distance)
		_try_boss_attack(delta, dir, distance)
		velocity = _get_behavior_velocity(delta, dir, current_speed)
		move_and_slide()
		_try_damage_player()

		# Flip sprite based on movement direction
		if velocity.x < 0:
			_sprite.flip_h = true
		elif velocity.x > 0:
			_sprite.flip_h = false

func apply_status(status: StringName, duration: float, value: float = 0.0) -> StatusEffect:
	return apply_status_effect(StatusEffect.from_values(status, duration, value))

func apply_status_effect(effect: StatusEffect) -> StatusEffect:
	if not effect or effect.id.is_empty():
		return null

	var status_key := str(effect.id)
	var applied := _statuses.get(status_key) as StatusEffect
	if applied:
		applied.refresh_from(effect)
	else:
		if effect.tick_interval > 0.0 and effect.tick_timer <= 0.0:
			effect.tick_timer = effect.tick_interval
		applied = effect
		_statuses[status_key] = applied

	_on_status_applied(applied.id, applied.value)
	return applied

func clear_status(status: StringName) -> void:
	var status_key := str(status)
	if _statuses.erase(status_key):
		_on_status_removed(status)

func _get_status(status: StringName) -> StatusEffect:
	return _statuses.get(str(status)) as StatusEffect

func _has_status(status: StringName) -> bool:
	return _get_status(status) != null

func _get_behavior_velocity(delta: float, dir: Vector2, current_speed: float) -> Vector2:
	match _behavior_id:
		EnemyData.BEHAVIOR_DASH:
			return _get_dash_velocity(delta, dir, current_speed)
		EnemyData.BEHAVIOR_RANGED:
			return _get_ranged_velocity(dir, current_speed)
		EnemyData.BEHAVIOR_BOSS:
			return _get_boss_velocity(dir, current_speed)
		_:
			return dir * current_speed

func _get_dash_velocity(delta: float, dir: Vector2, current_speed: float) -> Vector2:
	match _dash_state:
		DASH_STATE_WINDUP:
			_dash_timer -= delta
			if _dash_timer <= 0.0:
				_dash_direction = dir if dir != Vector2.ZERO else _dash_direction
				_dash_state = DASH_STATE_DASHING
				_dash_timer = _dash_duration
				return _dash_direction * current_speed * _dash_speed_multiplier
			return dir * current_speed * 0.25
		DASH_STATE_DASHING:
			_dash_timer -= delta
			if _dash_timer <= 0.0:
				_dash_state = DASH_STATE_RECOVER
				_dash_timer = _dash_recover_duration
				return Vector2.ZERO
			return _dash_direction * current_speed * _dash_speed_multiplier
		DASH_STATE_RECOVER:
			_dash_timer -= delta
			if _dash_timer <= 0.0:
				_dash_state = DASH_STATE_COOLDOWN
				_dash_timer = _dash_cooldown
			return dir * current_speed * 0.35
		_:
			_dash_timer -= delta
			if _dash_timer <= 0.0:
				_dash_state = DASH_STATE_WINDUP
				_dash_timer = _dash_windup
				_dash_direction = dir if dir != Vector2.ZERO else _dash_direction
			return dir * current_speed

func _reset_behavior_state() -> void:
	if _behavior_id == EnemyData.BEHAVIOR_DASH:
		_dash_state = DASH_STATE_COOLDOWN
		_dash_timer = randf_range(_dash_cooldown * 0.35, _dash_cooldown)
		_dash_direction = Vector2.RIGHT
	elif _behavior_id == EnemyData.BEHAVIOR_RANGED or _behavior_id == EnemyData.BEHAVIOR_BOSS:
		_dash_state = DASH_STATE_COOLDOWN
		_dash_timer = 0.0
		_ranged_attack_timer = randf_range(_ranged_attack_cooldown * 0.35, _ranged_attack_cooldown)
		_strafe_sign = -1.0 if randf() < 0.5 else 1.0
	else:
		_dash_state = DASH_STATE_COOLDOWN
		_dash_timer = 0.0

func _get_ranged_velocity(dir: Vector2, current_speed: float) -> Vector2:
	if not is_instance_valid(_player):
		return Vector2.ZERO
	var distance := global_position.distance_to(_player.global_position)
	if distance < _retreat_range:
		return -dir * current_speed * 0.85
	if distance > _preferred_range:
		return dir * current_speed
	var strafe := dir.orthogonal() * _strafe_sign
	return strafe * current_speed * 0.25

func _get_boss_velocity(dir: Vector2, current_speed: float) -> Vector2:
	if not is_instance_valid(_player):
		return Vector2.ZERO
	var distance := global_position.distance_to(_player.global_position)
	if distance < _retreat_range:
		return -dir * current_speed * 0.45
	if distance > _preferred_range:
		return dir * current_speed
	return dir.orthogonal() * _strafe_sign * current_speed * 0.35

func _try_ranged_attack(delta: float, dir: Vector2, distance: float) -> void:
	if _behavior_id != EnemyData.BEHAVIOR_RANGED:
		return
	_ranged_attack_timer -= delta
	if _ranged_attack_timer > 0.0:
		return
	if distance > _attack_range or dir == Vector2.ZERO:
		return
	_fire_ranged_projectile(dir)
	_ranged_attack_timer = _ranged_attack_cooldown

func _try_boss_attack(delta: float, dir: Vector2, distance: float) -> void:
	if _behavior_id != EnemyData.BEHAVIOR_BOSS:
		return
	_ranged_attack_timer -= delta
	if _ranged_attack_timer > 0.0:
		return
	if distance > _attack_range or dir == Vector2.ZERO:
		return
	_fire_boss_volley(dir)
	_ranged_attack_timer = _ranged_attack_cooldown

func _fire_boss_volley(dir: Vector2) -> Array[Node]:
	var spawned: Array[Node] = []
	var count := maxi(_boss_projectile_count, 1)
	var step := TAU / float(count)
	var base_angle := dir.angle() + (_boss_volley_index % 2) * step * 0.5
	for i in range(count):
		var shot_dir := Vector2.RIGHT.rotated(base_angle + step * i)
		var projectile := _spawn_enemy_projectile(shot_dir)
		if projectile:
			spawned.append(projectile)
	_boss_volley_index += 1
	return spawned

func _fire_ranged_projectile(dir: Vector2) -> Node:
	return _spawn_enemy_projectile(dir)

func _spawn_enemy_projectile(dir: Vector2) -> Node:
	var projectiles_parent := _get_projectiles_parent()
	if not projectiles_parent:
		return null
	var projectile := preload("res://scenes/weapons/projectile.tscn").instantiate()
	projectile.global_position = global_position + dir * (_configured_collision_radius + _projectile_radius + 2.0)
	projectile.direction = dir
	projectile.speed = _projectile_speed
	projectile.max_range = _projectile_range
	projectile.damage = _projectile_damage if _projectile_damage > 0 else _damage
	projectile.pierce = 0
	projectile.source = self
	projectile.damage_owner = self
	projectile.weapon_id = &"enemy_projectile"
	projectile.damage_type = DamageEvent.DAMAGE_TYPE_PHYSICAL
	projectile.delivery_type = DamageEvent.DELIVERY_PROJECTILE
	projectile.target_group = &"player"
	projectile.collision_mask = 1
	projectile.visual_modulate = _projectile_modulate
	projectile.visual_sprite_frames = _projectile_sprite_frames
	projectile.visual_rotation_offset = _projectile_visual_rotation_offset
	var shape_node := projectile.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node and shape_node.shape is CircleShape2D:
		var circle := (shape_node.shape as CircleShape2D).duplicate() as CircleShape2D
		circle.radius = maxf(_projectile_radius, 1.0)
		shape_node.shape = circle
	projectiles_parent.add_child(projectile)
	return projectile

func _build_projectile_sprite_frames() -> SpriteFrames:
	if not _projectile_animation_sheet or _projectile_animation_frame_count <= 0:
		return null
	var frames := SpriteFrames.new()
	for i in range(_projectile_animation_frame_count):
		var atlas := AtlasTexture.new()
		atlas.atlas = _projectile_animation_sheet
		var column := i % maxi(_projectile_animation_columns, 1)
		var row := i / maxi(_projectile_animation_columns, 1)
		atlas.region = Rect2(
			column * _projectile_animation_frame_size.x,
			row * _projectile_animation_frame_size.y,
			_projectile_animation_frame_size.x,
			_projectile_animation_frame_size.y
		)
		frames.add_frame("default", atlas)
	frames.set_animation_loop("default", true)
	frames.set_animation_speed("default", _projectile_animation_speed)
	return frames

func _get_projectiles_parent() -> Node:
	var node := get_parent()
	while node:
		var projectiles := node.get_node_or_null("Projectiles")
		if projectiles:
			return projectiles
		node = node.get_parent()
	var current := get_tree().current_scene
	if current:
		return current.find_child("Projectiles", true, false)
	return null

func _try_damage_player() -> void:
	if not _can_damage or not is_instance_valid(_player):
		return
	if not _is_touching_player():
		return
	if _player.has_method("take_damage"):
		var event := DamageEvent.from_amount(_damage, self, DamageEvent.DAMAGE_TYPE_PHYSICAL, DamageEvent.DELIVERY_CONTACT)
		event.owner = self
		event.target = _player
		DamageCalculator.deal_damage(_player, event)
		_start_damage_cooldown()

func _is_touching_player() -> bool:
	if not is_instance_valid(_player):
		return false
	var contact_radius := _collision_radius(self) + _collision_radius(_player) + CONTACT_DAMAGE_PADDING
	return global_position.distance_squared_to(_player.global_position) <= contact_radius * contact_radius

func _collision_radius(body: Node2D) -> float:
	var shape_node := body.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if not shape_node or not shape_node.shape:
		return DEFAULT_CONTACT_RADIUS
	var scale_factor := maxf(absf(body.global_scale.x), absf(body.global_scale.y))
	if shape_node.shape is CircleShape2D:
		return (shape_node.shape as CircleShape2D).radius * scale_factor
	if shape_node.shape is RectangleShape2D:
		return (shape_node.shape as RectangleShape2D).size.length() * 0.5 * scale_factor
	if shape_node.shape is CapsuleShape2D:
		var capsule := shape_node.shape as CapsuleShape2D
		return maxf(capsule.radius, capsule.height * 0.5) * scale_factor
	return DEFAULT_CONTACT_RADIUS * scale_factor

func _on_status_applied(_status: StringName, _value: float) -> void:
	_refresh_status_visual()

func _on_status_removed(_status: StringName) -> void:
	_refresh_status_visual()

func _refresh_status_visual() -> void:
	if not _sprite:
		return
	if _has_status(&"stun"):
		_sprite.modulate = Color(1.0, 0.9, 0.3, 1.0)
	elif _has_status(&"slow"):
		_sprite.modulate = Color(0.6, 0.8, 1.0, 1.0)
	else:
		_sprite.modulate = _base_modulate

func _setup_health_bar() -> void:
	if _health_bar:
		_health_bar.max_value = _hp
		_health_bar.value = _hp
		if _is_boss():
			_health_bar.auto_hide = false
			_health_bar.visible = true

func take_damage(amount: int) -> DamageResult:
	var event := DamageEvent.from_amount(amount, null, DamageEvent.DAMAGE_TYPE_PHYSICAL, DamageEvent.DELIVERY_DIRECT)
	event.target = self
	return apply_damage(event)

func apply_damage(event: DamageEvent) -> DamageResult:
	if _dead:
		return DamageResult.blocked(event)
	var result := DamageCalculator.calculate(event)
	if result.final_amount <= 0:
		result.was_blocked = true
		return result
	_hp -= result.final_amount
	if _health_bar:
		_health_bar.update_health(_hp, _health_bar.max_value)
	if not event.status_id.is_empty() and _hp > 0:
		var applied_status := apply_status(event.status_id, event.status_duration, event.status_value)
		if applied_status:
			result.applied_status = applied_status.id
	_flash_white()
	if _hp <= 0:
		result.killed = true
		_die()
	return result

func _flash_white() -> void:
	_sprite.modulate = Color(2, 2, 2, 1)
	_sprite.play("hit")
	await get_tree().create_timer(0.08).timeout
	_refresh_status_visual()
	if _hp > 0 and _sprite.animation == "hit":
		_sprite.play("walk")

func _die() -> void:
	if _dead:
		return
	_dead = true
	GameState.add_kill()
	if _is_final_boss():
		GameState.run["victory"] = true
		GameState.run_ended.emit(true)
	call_deferred("_spawn_drop")
	_sprite.play("death")
	if _health_bar:
		_health_bar.visible = false
	# Disable collision and movement
	collision_layer = 0
	collision_mask = 0
	velocity = Vector2.ZERO
	set_physics_process(false)
	await get_tree().create_timer(0.8).timeout
	queue_free()

func _spawn_drop() -> void:
	var current := get_tree().current_scene
	var drops_parent := current.find_child("Drops", true, false) if current else null
	if not drops_parent:
		return

	var exp_orb := preload("res://scenes/drops/exp_orb.tscn").instantiate()
	exp_orb.global_position = global_position
	exp_orb.exp_value = _exp_reward
	drops_parent.add_child(exp_orb)

	if _gold_reward > 0:
		var gold := preload("res://scenes/drops/gold_pickup.tscn").instantiate()
		gold.global_position = global_position + Vector2(randf_range(-20, 20), randf_range(-20, 20))
		gold.gold_value = _gold_reward
		drops_parent.add_child(gold)

func _start_damage_cooldown() -> void:
	_can_damage = false
	await get_tree().create_timer(_damage_cooldown).timeout
	_can_damage = true

func _is_boss() -> bool:
	return enemy_data != null and enemy_data.tags.has(&"boss")

func _is_final_boss() -> bool:
	return _is_boss() and enemy_data.tags.has(&"final_boss")
