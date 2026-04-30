class_name StatusEffect
extends RefCounted
## Runtime state for one status effect instance on a combat target.

const REFRESH_REPLACE := &"replace"
const REFRESH_EXTEND := &"extend"
const REFRESH_MAX := &"max"
const REFRESH_STACK_REFRESH := &"stack_refresh"

var id: StringName = &""
var duration: float = 0.0
var remaining: float = 0.0
var value: float = 0.0
var stack_count: int = 1
var max_stacks: int = 1
var refresh_policy: StringName = REFRESH_REPLACE
var tick_interval: float = 0.0
var tick_timer: float = 0.0
var tick_damage_event: DamageEvent = null

# Compatibility alias for older tests/debug code that read status.timer.
var timer: float:
	get:
		return remaining
	set(value):
		remaining = maxf(value, 0.0)

static func from_values(status_id: StringName, status_duration: float, status_value: float = 0.0) -> StatusEffect:
	var effect := StatusEffect.new()
	effect.id = status_id
	effect.duration = maxf(status_duration, 0.0)
	effect.remaining = effect.duration
	effect.value = status_value
	return effect

func refresh_from(other: StatusEffect) -> void:
	if not other:
		return

	var next_duration := maxf(other.duration, 0.0)
	match other.refresh_policy:
		REFRESH_EXTEND:
			duration = maxf(duration, next_duration)
			remaining += next_duration
			value = other.value
		REFRESH_MAX:
			duration = maxf(duration, next_duration)
			remaining = maxf(remaining, next_duration)
			value = other.value
		REFRESH_STACK_REFRESH:
			max_stacks = maxi(1, other.max_stacks)
			stack_count = mini(max_stacks, stack_count + maxi(1, other.stack_count))
			duration = maxf(duration, next_duration)
			remaining = maxf(remaining, next_duration)
			value = other.value
		_:
			duration = next_duration
			remaining = next_duration
			value = other.value
			stack_count = maxi(1, other.stack_count)
			max_stacks = maxi(1, other.max_stacks)

	refresh_policy = other.refresh_policy
	tick_interval = other.tick_interval
	tick_timer = other.tick_timer if other.tick_timer > 0.0 else other.tick_interval
	tick_damage_event = other.tick_damage_event

func tick(delta: float, target: Node) -> bool:
	var step := maxf(delta, 0.0)
	if step <= 0.0:
		return remaining <= 0.0

	remaining = maxf(remaining - step, 0.0)
	_tick_damage(step, target)
	return remaining <= 0.0

func effective_value() -> float:
	return value

func _tick_damage(delta: float, target: Node) -> void:
	if tick_interval <= 0.0 or not tick_damage_event or not is_instance_valid(target):
		return

	tick_timer -= delta
	var applied_ticks := 0
	while tick_timer <= 0.0 and remaining > 0.0 and applied_ticks < 16:
		var event := tick_damage_event.duplicate_for_target(target)
		DamageCalculator.deal_damage(target, event)
		tick_timer += tick_interval
		applied_ticks += 1
