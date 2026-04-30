class_name DamageCalculator
extends RefCounted
## Shared entry point for combat damage. Targets still own HP and mitigation rules.

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
			return applied as DamageResult
		return calculate(event)

	var result := calculate(event)
	if result.final_amount > 0 and target.has_method("take_damage"):
		target.call("take_damage", result.final_amount)
		_apply_status_if_needed(target, event, result)
	return result

static func _apply_status_if_needed(target: Node, event: DamageEvent, result: DamageResult) -> void:
	if event.status_id.is_empty() or not target.has_method("apply_status"):
		return
	target.call("apply_status", event.status_id, event.status_duration, event.status_value)
	result.applied_status = event.status_id
