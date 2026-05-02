class_name DamageCalculator
extends RefCounted
## Shared entry point for combat damage. Targets still own HP and mitigation rules.

const CombatEffectRules := preload("res://scripts/combat/combat_effect_rules.gd")

const BARRAGE_TAG := &"弹幕"
const BARRAGE_FIXED_DAMAGE_BONUS := 0.08
const BARRAGE_DISTANCE_MIN := 180.0
const BARRAGE_DISTANCE_MAX := 420.0
const BARRAGE_DISTANCE_DAMAGE_BONUS_MAX := 0.18
const BARRAGE_KNOCKBACK_FORCE := 180.0
const BARRAGE_KNOCKBACK_DURATION := 0.12
const BARRAGE_ELITE_BOSS_KNOCKBACK_MULTIPLIER := 0.3
const MELEE_TAG := &"近身"
const MELEE_FIXED_DAMAGE_BONUS := 0.08
const MELEE_DISTANCE_MIN := 60.0
const MELEE_DISTANCE_MAX := 160.0
const MELEE_DISTANCE_DAMAGE_BONUS_MAX := 0.18
const FIELD_TAG := &"场地"
const FIELD_FIXED_DAMAGE_BONUS := 0.08
const FIELD_SUPPRESSION_DURATION := 2.0
const FIELD_SUPPRESSION_DAMAGE_BONUS_PER_STACK := 0.06
const FIELD_SUPPRESSION_MAX_STACKS := 3
const FIELD_LOCKDOWN_DURATION := 1.2
const FIELD_LOCKDOWN_SLOW_VALUE := 0.65
const FIELD_LOCKDOWN_ELITE_BOSS_SLOW_VALUE := 0.85
const FIELD_LOCKDOWN_COOLDOWN := 2.0
const CONTROL_TAG := &"控制"
const CONTROL_FIXED_DAMAGE_BONUS := 0.08
const CONTROL_THREAT_REDUCTION_DURATION := 2.0
const CONTROL_THREAT_DAMAGE_MULTIPLIER := 0.8
const CONTROL_CHARGE_MAX := 100.0
const CONTROL_CHARGE_PER_TARGET_COOLDOWN := 0.5
const CONTROL_CHARGE_SLOW := 3.0
const CONTROL_CHARGE_KNOCKBACK := 5.0
const CONTROL_CHARGE_STUN := 8.0
const CONTROL_CHARGE_ELITE_MULTIPLIER := 1.5
const CONTROL_CHARGE_BOSS_MULTIPLIER := 2.0
const CONTROL_STASIS_STUN_DURATION := 0.8
const CONTROL_STASIS_ELITE_BOSS_STUN_DURATION := 0.3
const BURST_TAG := &"爆发"
const BURST_FIXED_DAMAGE_BONUS := 0.08
const BURST_OVERFLOW_RATIO_TIER_2 := 0.8
const BURST_OVERFLOW_RATIO_TIER_3 := 1.0
const BURST_OVERFLOW_RADIUS_TIER_2 := 180.0
const BURST_OVERFLOW_RADIUS_TIER_3 := 220.0
const BURST_OVERFLOW_TARGETS_TIER_2 := 1
const BURST_OVERFLOW_TARGETS_TIER_3 := 3

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
			_apply_after_damage_effects(target, event, applied_result)
			GameState.record_damage_result(applied_result)
			return applied_result
		return calculate(event)
	return DamageResult.blocked(event)

static func _apply_status_if_needed(target: Node, event: DamageEvent, result: DamageResult) -> void:
	if event.status_id.is_empty() or not target.has_method("apply_status"):
		return
	target.call("apply_status", event.status_id, event.status_duration, event.status_value)
	result.applied_status = event.status_id

static func _apply_build_resonance_modifiers(event: DamageEvent, amount: float) -> float:
	if CombatEffectRules.skips_build_resonance(event):
		return amount

	var barrage_tier := GameState.get_build_resonance_reward_tier(str(BARRAGE_TAG))
	if barrage_tier >= 1 and _is_weapon_event_with_build_tag(event, BARRAGE_TAG):
		amount *= 1.0 + BARRAGE_FIXED_DAMAGE_BONUS
		if barrage_tier >= 2:
			amount *= 1.0 + _get_barrage_distance_damage_bonus(event)

	var melee_tier := GameState.get_build_resonance_reward_tier(str(MELEE_TAG))
	if melee_tier >= 1 and _is_weapon_event_with_build_tag(event, MELEE_TAG):
		amount *= 1.0 + MELEE_FIXED_DAMAGE_BONUS
		if melee_tier >= 2:
			amount *= 1.0 + _get_melee_distance_damage_bonus(event)

	var field_tier := GameState.get_build_resonance_reward_tier(str(FIELD_TAG))
	if field_tier >= 1 and _is_weapon_event_with_build_tag(event, FIELD_TAG):
		amount *= 1.0 + FIELD_FIXED_DAMAGE_BONUS
		if field_tier >= 2:
			amount *= 1.0 + _get_field_suppression_damage_bonus(event)

	var control_tier := GameState.get_build_resonance_reward_tier(str(CONTROL_TAG))
	if control_tier >= 1 and _is_weapon_event_with_build_tag(event, CONTROL_TAG):
		amount *= 1.0 + CONTROL_FIXED_DAMAGE_BONUS

	var burst_tier := GameState.get_build_resonance_reward_tier(str(BURST_TAG))
	if burst_tier >= 1 and _is_weapon_event_with_build_tag(event, BURST_TAG):
		amount *= 1.0 + BURST_FIXED_DAMAGE_BONUS
	return amount

static func notify_control_effect_applied(target: Node, event: DamageEvent, effect_id: StringName) -> void:
	if effect_id.is_empty():
		return
	if not _is_control_effect(effect_id):
		return
	if not _is_weapon_event_with_build_tag(event, CONTROL_TAG):
		return
	if not target or not target.is_in_group("enemies"):
		return

	var control_tier := GameState.get_build_resonance_reward_tier(str(CONTROL_TAG))
	if control_tier >= 2 and target.has_method("apply_control_threat_reduction"):
		target.call("apply_control_threat_reduction", CONTROL_THREAT_REDUCTION_DURATION, CONTROL_THREAT_DAMAGE_MULTIPLIER)
	if control_tier >= 3:
		_charge_control_stasis_if_needed(target, effect_id)

static func _apply_after_damage_effects(target: Node, event: DamageEvent, result: DamageResult) -> void:
	var skips_post_hit := CombatEffectRules.skips_post_hit_effects(event)
	if not skips_post_hit:
		_apply_control_resonance_from_result(target, event, result)
	_apply_post_kill_effects(target, event, result)
	if not skips_post_hit:
		_apply_field_suppression_if_needed(target, event, result)
		_record_melee_replay_candidate_if_needed(event, result)
		_apply_barrage_knockback_if_needed(target, event, result)

static func _apply_post_kill_effects(target: Node, event: DamageEvent, result: DamageResult) -> void:
	if CombatEffectRules.skips_post_kill_effects(event):
		return
	_apply_burst_overflow_if_needed(target, event, result)

static func _get_barrage_distance_damage_bonus(event: DamageEvent) -> float:
	var distance := _get_event_hit_position(event).distance_to(_get_event_origin_position(event))
	if distance <= BARRAGE_DISTANCE_MIN:
		return 0.0
	var span := maxf(BARRAGE_DISTANCE_MAX - BARRAGE_DISTANCE_MIN, 1.0)
	var progress := clampf((distance - BARRAGE_DISTANCE_MIN) / span, 0.0, 1.0)
	return progress * BARRAGE_DISTANCE_DAMAGE_BONUS_MAX

static func _get_melee_distance_damage_bonus(event: DamageEvent) -> float:
	var distance := _get_event_hit_position(event).distance_to(_get_event_origin_position(event))
	if distance >= MELEE_DISTANCE_MAX:
		return 0.0
	var span := maxf(MELEE_DISTANCE_MAX - MELEE_DISTANCE_MIN, 1.0)
	var progress := clampf((MELEE_DISTANCE_MAX - distance) / span, 0.0, 1.0)
	return progress * MELEE_DISTANCE_DAMAGE_BONUS_MAX

static func _get_field_suppression_damage_bonus(event: DamageEvent) -> float:
	if not event or not event.target or not event.target.has_method("get_field_suppression_stack_count"):
		return 0.0
	var stacks := clampi(int(event.target.call("get_field_suppression_stack_count")), 0, FIELD_SUPPRESSION_MAX_STACKS)
	return float(stacks) * FIELD_SUPPRESSION_DAMAGE_BONUS_PER_STACK

static func _apply_field_suppression_if_needed(target: Node, event: DamageEvent, result: DamageResult) -> void:
	if not result or result.final_amount <= 0 or result.killed:
		return
	if CombatEffectRules.skips_post_hit_effects(event):
		return
	var field_tier := GameState.get_build_resonance_reward_tier(str(FIELD_TAG))
	if field_tier < 2:
		return
	if not _is_weapon_event_with_build_tag(event, FIELD_TAG):
		return
	if not target or not target.is_in_group("enemies") or not target.has_method("apply_field_suppression"):
		return
	var stacks := int(target.call("apply_field_suppression", FIELD_SUPPRESSION_DURATION))
	if field_tier < 3 or stacks < FIELD_SUPPRESSION_MAX_STACKS or not target.has_method("trigger_field_lockdown"):
		return
	var slow_value := FIELD_LOCKDOWN_ELITE_BOSS_SLOW_VALUE if _is_elite_or_boss(target) else FIELD_LOCKDOWN_SLOW_VALUE
	var triggered := bool(target.call("trigger_field_lockdown", slow_value, FIELD_LOCKDOWN_DURATION, FIELD_LOCKDOWN_COOLDOWN))
	if triggered and target is Node2D:
		_spawn_resonance_effect(VFXHelper.EFFECT_FIELD_LOCKDOWN, (target as Node2D).global_position)

static func _apply_control_resonance_from_result(target: Node, event: DamageEvent, result: DamageResult) -> void:
	if not result or result.final_amount <= 0 or result.killed:
		return
	if CombatEffectRules.skips_post_hit_effects(event):
		return
	if result.applied_status.is_empty():
		return
	notify_control_effect_applied(target, event, result.applied_status)

static func _apply_burst_overflow_if_needed(target: Node, event: DamageEvent, result: DamageResult) -> void:
	if not result or not event or not result.killed or result.overkill_amount <= 0:
		return
	if CombatEffectRules.skips_post_kill_effects(event):
		return
	var burst_tier := GameState.get_build_resonance_reward_tier(str(BURST_TAG))
	if burst_tier < 2:
		return
	if not _is_weapon_event_with_build_tag(event, BURST_TAG):
		return
	if not target or not target.is_in_group("enemies") or not (target is Node2D):
		return

	var ratio := BURST_OVERFLOW_RATIO_TIER_3 if burst_tier >= 3 else BURST_OVERFLOW_RATIO_TIER_2
	var radius := BURST_OVERFLOW_RADIUS_TIER_3 if burst_tier >= 3 else BURST_OVERFLOW_RADIUS_TIER_2
	var target_count := BURST_OVERFLOW_TARGETS_TIER_3 if burst_tier >= 3 else BURST_OVERFLOW_TARGETS_TIER_2
	var overflow_damage := maxi(1, int(round(float(result.overkill_amount) * ratio)))
	var center := (target as Node2D).global_position
	_spawn_resonance_effect(VFXHelper.EFFECT_BURST_OVERFLOW, center, 0.0, 1.15)
	for enemy in _get_nearest_enemies_in_radius(center, radius, target, target_count):
		if enemy is Node2D:
			_spawn_resonance_effect(VFXHelper.EFFECT_BURST_OVERFLOW, (enemy as Node2D).global_position)
		var overflow_event := DamageEvent.from_amount(overflow_damage, event.source if event.source else event.owner, event.damage_type, DamageEvent.DELIVERY_AREA)
		overflow_event.owner = event.owner
		overflow_event.weapon_id = event.weapon_id
		overflow_event.position = center
		overflow_event.tags = event.tags.duplicate()
		CombatEffectRules.add_tag_once(overflow_event, CombatEffectRules.BURST_OVERFLOW_TAG)
		DamageCalculator.deal_damage(enemy, overflow_event)

static func _charge_control_stasis_if_needed(target: Node, effect_id: StringName) -> void:
	if not GameState.claim_control_resonance_charge_source(target, CONTROL_CHARGE_PER_TARGET_COOLDOWN):
		return
	var amount := _get_control_charge_amount(target, effect_id)
	if amount <= 0.0:
		return
	if GameState.add_control_resonance_energy(amount, CONTROL_CHARGE_MAX):
		_trigger_control_stasis_pulse()

static func _get_control_charge_amount(target: Node, effect_id: StringName) -> float:
	var amount := 0.0
	match effect_id:
		&"slow":
			amount = CONTROL_CHARGE_SLOW
		&"knockback":
			amount = CONTROL_CHARGE_KNOCKBACK
		&"stun":
			amount = CONTROL_CHARGE_STUN
		_:
			return 0.0
	if _is_boss(target):
		amount *= CONTROL_CHARGE_BOSS_MULTIPLIER
	elif _is_elite_or_boss(target):
		amount *= CONTROL_CHARGE_ELITE_MULTIPLIER
	return amount

static func _trigger_control_stasis_pulse() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if not tree:
		return
	var player := tree.get_first_node_in_group("player") as Node2D
	if player:
		_spawn_resonance_effect(VFXHelper.EFFECT_CONTROL_STASIS, player.global_position, 0.0, 1.35)
	for enemy in tree.get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or not enemy.has_method("apply_status"):
			continue
		var duration := CONTROL_STASIS_ELITE_BOSS_STUN_DURATION if _is_elite_or_boss(enemy) else CONTROL_STASIS_STUN_DURATION
		enemy.call("apply_status", &"stun", duration, 0.0)
		if enemy is Node2D:
			_spawn_resonance_effect(VFXHelper.EFFECT_CONTROL_STASIS, (enemy as Node2D).global_position, 0.0, 0.75)

static func _is_control_effect(effect_id: StringName) -> bool:
	return effect_id == &"slow" or effect_id == &"stun" or effect_id == &"knockback"

static func _record_melee_replay_candidate_if_needed(event: DamageEvent, result: DamageResult) -> void:
	if not result or result.final_amount <= 0:
		return
	if CombatEffectRules.skips_post_hit_effects(event) or CombatEffectRules.skips_melee_replay_record(event):
		return
	if GameState.get_build_resonance_reward_tier(str(MELEE_TAG)) < 3:
		return
	if not _is_weapon_event_with_build_tag(event, MELEE_TAG):
		return
	if not event.target or not event.target.is_in_group("enemies"):
		return
	GameState.record_melee_replay_damage(result.final_amount, event.damage_type)

static func _apply_barrage_knockback_if_needed(target: Node, event: DamageEvent, result: DamageResult) -> void:
	if not result or result.final_amount <= 0 or result.killed:
		return
	if CombatEffectRules.skips_post_hit_effects(event):
		return
	if GameState.get_build_resonance_reward_tier(str(BARRAGE_TAG)) < 3:
		return
	if not _is_weapon_event_with_build_tag(event, BARRAGE_TAG):
		return
	if not (target is Node2D):
		return
	var force := BARRAGE_KNOCKBACK_FORCE
	if _is_elite_or_boss(target):
		force *= BARRAGE_ELITE_BOSS_KNOCKBACK_MULTIPLIER
	var target_pos := (target as Node2D).global_position
	var dir := (target_pos - _get_event_origin_position(event)).normalized()
	if dir != Vector2.ZERO:
		_spawn_resonance_effect(VFXHelper.EFFECT_BARRAGE_KNOCKBACK, target_pos, dir.angle())
	if target.has_method("apply_knockback"):
		target.call("apply_knockback", _get_event_origin_position(event), force, BARRAGE_KNOCKBACK_DURATION)
	elif target is CharacterBody2D:
		var body := target as CharacterBody2D
		dir = (body.global_position - _get_event_origin_position(event)).normalized()
		if dir == Vector2.ZERO:
			return
		body.velocity = dir * force
		body.move_and_slide()

static func _get_nearest_enemies_in_radius(center: Vector2, radius: float, excluded: Node, limit: int) -> Array[Node]:
	var candidates: Array[Node] = []
	var tree := Engine.get_main_loop() as SceneTree
	if not tree or radius <= 0.0 or limit <= 0:
		return candidates
	var radius_sq := radius * radius
	for enemy in tree.get_nodes_in_group("enemies"):
		if enemy == excluded or not is_instance_valid(enemy) or not (enemy is Node2D):
			continue
		if enemy.is_queued_for_deletion():
			continue
		if "_dead" in enemy and bool(enemy._dead):
			continue
		if center.distance_squared_to((enemy as Node2D).global_position) > radius_sq:
			continue
		candidates.append(enemy)
	candidates.sort_custom(func(a: Node, b: Node) -> bool:
		return center.distance_squared_to((a as Node2D).global_position) < center.distance_squared_to((b as Node2D).global_position)
	)
	return candidates.slice(0, mini(limit, candidates.size()))

static func _is_weapon_event_with_build_tag(event: DamageEvent, tag: StringName) -> bool:
	if not event:
		return false
	if event.has_tag(tag):
		return true
	if event.weapon_id.is_empty():
		return false
	var weapon_data = DataManager.get_weapon(str(event.weapon_id))
	return weapon_data is WeaponData and (weapon_data as WeaponData).tags.has(tag)

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

static func _is_boss(target: Node) -> bool:
	if not target:
		return false
	if target.is_in_group("bosses"):
		return true
	var enemy_data = target.get("enemy_data") if "enemy_data" in target else null
	if enemy_data is EnemyData:
		return (enemy_data as EnemyData).tags.has(&"boss")
	return false

static func _spawn_resonance_effect(effect_id: StringName, pos: Vector2, rotation: float = 0.0, scale_multiplier: float = 1.0) -> void:
	VFXHelper.spawn_resonance_effect(null, effect_id, pos, rotation, scale_multiplier)
