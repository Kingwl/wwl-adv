class_name DamageCalculator
extends RefCounted
## Shared entry point for combat damage. Targets still own HP and mitigation rules.

const BARRAGE_TAG := &"弹幕"
const BARRAGE_FIXED_DAMAGE_BONUS := 0.08
const BARRAGE_DISTANCE_MIN := 180.0
const BARRAGE_DISTANCE_MAX := 420.0
const BARRAGE_DISTANCE_DAMAGE_BONUS_MAX := 0.18
const BARRAGE_KNOCKBACK_FORCE := 180.0
const BARRAGE_KNOCKBACK_DURATION := 0.12
const BARRAGE_ELITE_BOSS_KNOCKBACK_MULTIPLIER := 0.3

static func calculate(event: DamageEvent) -> DamageResult:
	if not event:
		return DamageResult.blocked()

	var result := DamageResult.new()
	result.event = event
	result.raw_amount = maxi(0, event.amount)
	if result.raw_amount <= 0:
		result.was_blocked = true
		return result

	var amount := float(result.raw_amount)
	if event.can_crit and event.crit_chance > 0.0 and randf() < clampf(event.crit_chance, 0.0, 1.0):
		result.is_crit = true
		amount *= maxf(1.0, event.crit_multiplier)

	amount = _apply_build_resonance_modifiers(event, amount)

	result.final_amount = maxi(0, int(round(amount)))
	result.prevented_amount = maxi(0, result.raw_amount - result.final_amount)
	return result

static func deal_damage(target: Node, event: DamageEvent) -> DamageResult:
	if not is_instance_valid(target) or not event:
		return DamageResult.blocked(event)

	event.target = target
	if event.position == Vector2.ZERO and target is Node2D:
		event.position = (target as Node2D).global_position

	if target.has_method("apply_damage"):
		var applied = target.call("apply_damage", event)
		if applied is DamageResult:
			var applied_result := applied as DamageResult
			_apply_barrage_knockback_if_needed(target, event, applied_result)
			GameState.record_damage_result(applied_result)
			return applied_result
		return calculate(event)

	var result := calculate(event)
	if result.final_amount > 0 and target.has_method("take_damage"):
		target.call("take_damage", result.final_amount)
		_apply_status_if_needed(target, event, result)
		_apply_barrage_knockback_if_needed(target, event, result)
		GameState.record_damage_result(result)
	return result

static func _apply_status_if_needed(target: Node, event: DamageEvent, result: DamageResult) -> void:
	if event.status_id.is_empty() or not target.has_method("apply_status"):
		return
	target.call("apply_status", event.status_id, event.status_duration, event.status_value)
	result.applied_status = event.status_id

static func _apply_build_resonance_modifiers(event: DamageEvent, amount: float) -> float:
	if not _is_barrage_weapon_event(event):
		return amount
	var tier := GameState.get_build_resonance_reward_tier(str(BARRAGE_TAG))
	if tier <= 0:
		return amount
	if tier >= 1:
		amount *= 1.0 + BARRAGE_FIXED_DAMAGE_BONUS
	if tier >= 2:
		amount *= 1.0 + _get_barrage_distance_damage_bonus(event)
	return amount

static func _get_barrage_distance_damage_bonus(event: DamageEvent) -> float:
	var distance := _get_event_hit_position(event).distance_to(_get_event_origin_position(event))
	if distance <= BARRAGE_DISTANCE_MIN:
		return 0.0
	var span := maxf(BARRAGE_DISTANCE_MAX - BARRAGE_DISTANCE_MIN, 1.0)
	var progress := clampf((distance - BARRAGE_DISTANCE_MIN) / span, 0.0, 1.0)
	return progress * BARRAGE_DISTANCE_DAMAGE_BONUS_MAX

static func _apply_barrage_knockback_if_needed(target: Node, event: DamageEvent, result: DamageResult) -> void:
	if not result or result.final_amount <= 0 or result.killed:
		return
	if GameState.get_build_resonance_reward_tier(str(BARRAGE_TAG)) < 3:
		return
	if not _is_barrage_weapon_event(event):
		return
	if not (target is Node2D):
		return
	var force := BARRAGE_KNOCKBACK_FORCE
	if _is_elite_or_boss(target):
		force *= BARRAGE_ELITE_BOSS_KNOCKBACK_MULTIPLIER
	if target.has_method("apply_knockback"):
		target.call("apply_knockback", _get_event_origin_position(event), force, BARRAGE_KNOCKBACK_DURATION)
	elif target is CharacterBody2D:
		var body := target as CharacterBody2D
		var dir := (body.global_position - _get_event_origin_position(event)).normalized()
		if dir == Vector2.ZERO:
			return
		body.velocity = dir * force
		body.move_and_slide()

static func _is_barrage_weapon_event(event: DamageEvent) -> bool:
	if not event:
		return false
	if event.has_tag(BARRAGE_TAG):
		return true
	if event.weapon_id.is_empty():
		return false
	var weapon_data = DataManager.get_weapon(str(event.weapon_id))
	return weapon_data is WeaponData and (weapon_data as WeaponData).tags.has(BARRAGE_TAG)

static func _get_event_origin_position(event: DamageEvent) -> Vector2:
	if event.owner is Node2D:
		return (event.owner as Node2D).global_position
	if event.source is Node2D:
		return (event.source as Node2D).global_position
	return event.position

static func _get_event_hit_position(event: DamageEvent) -> Vector2:
	if event.target is Node2D:
		return (event.target as Node2D).global_position
	if event.position != Vector2.ZERO:
		return event.position
	if event.source is Node2D:
		return (event.source as Node2D).global_position
	return _get_event_origin_position(event)

static func _is_elite_or_boss(target: Node) -> bool:
	if not target:
		return false
	if target.is_in_group("bosses"):
		return true
	var enemy_data = target.get("enemy_data") if "enemy_data" in target else null
	if enemy_data is EnemyData:
		var data := enemy_data as EnemyData
		return data.tags.has(&"elite") or data.tags.has(&"boss")
	return false
