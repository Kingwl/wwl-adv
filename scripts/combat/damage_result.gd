class_name DamageResult
extends RefCounted
## Result of applying a DamageEvent to a target.

var event: DamageEvent = null
var raw_amount: int = 0
var final_amount: int = 0
var prevented_amount: int = 0
var is_crit: bool = false
var was_blocked: bool = false
var killed: bool = false
var overkill_amount: int = 0
var applied_status: StringName = &""

static func blocked(source_event: DamageEvent = null) -> DamageResult:
	var result := DamageResult.new()
	result.event = source_event
	result.raw_amount = maxi(0, source_event.amount if source_event else 0)
	result.final_amount = 0
	result.prevented_amount = result.raw_amount
	result.was_blocked = true
	return result
