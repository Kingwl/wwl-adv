extends CharacterBody2D

@export var enemy_data: EnemyData

const CONTACT_DAMAGE_PADDING := 2.0
const DEFAULT_CONTACT_RADIUS := 16.0

var _hp: int = 12
var _base_speed: float = 60.0
var _damage: int = 5
var _exp_reward: int = 2
var _gold_reward: int = 1
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
	_setup_animations()
	_setup_health_bar()

func _setup_animations() -> void:
	var frames := SpriteFrames.new()

	# Walk: 4 frames
	frames.add_animation("walk")
	var walk_sheet := load("res://assets/art/characters/enemy_walk_sheet.png")
	for i in range(4):
		var atlas := AtlasTexture.new()
		atlas.atlas = walk_sheet
		atlas.region = Rect2(i * 64, 0, 64, 64)
		frames.add_frame("walk", atlas)
	frames.set_animation_loop("walk", true)
	frames.set_animation_speed("walk", 6.0)

	# Hit: 2 frames
	frames.add_animation("hit")
	var hit_sheet := load("res://assets/art/characters/enemy_hit_sheet.png")
	for i in range(2):
		var atlas := AtlasTexture.new()
		atlas.atlas = hit_sheet
		atlas.region = Rect2(i * 64, 0, 64, 64)
		frames.add_frame("hit", atlas)
	frames.set_animation_loop("hit", false)
	frames.set_animation_speed("hit", 8.0)

	# Death: 6 frames
	frames.add_animation("death")
	var death_sheet := load("res://assets/art/characters/enemy_death_sheet.png")
	for i in range(6):
		var atlas := AtlasTexture.new()
		atlas.atlas = death_sheet
		atlas.region = Rect2(i * 64, 0, 64, 64)
		frames.add_frame("death", atlas)
	frames.set_animation_loop("death", false)
	frames.set_animation_speed("death", 8.0)

	_sprite.sprite_frames = frames
	_sprite.play("walk")

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

func _physics_process(_delta: float) -> void:
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
		velocity = dir * current_speed
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
		_sprite.modulate = Color.WHITE

func _setup_health_bar() -> void:
	if _health_bar:
		_health_bar.max_value = _hp
		_health_bar.value = _hp

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
