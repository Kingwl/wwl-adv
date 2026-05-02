class_name CombatEffectRules
extends RefCounted
## Central rules for derived damage tags and combat side-effect permissions.

const BURST_OVERFLOW_TAG := &"burst_overflow"
const MELEE_REPLAY_TAG := &"melee_replay"
const GUARDIAN_REFRACTION_TAG := &"guardian_refraction"
const SURVIVAL_ECHO_TAG := &"survival_echo"

static func add_tag_once(event: DamageEvent, tag: StringName) -> void:
	if not event or tag.is_empty():
		return
	if not event.tags.has(tag):
		event.tags.append(tag)

static func has_derived_tag(event: DamageEvent, tag: StringName) -> bool:
	return event != null and event.has_tag(tag)

static func skips_build_resonance(event: DamageEvent) -> bool:
	return has_derived_tag(event, BURST_OVERFLOW_TAG) or has_derived_tag(event, MELEE_REPLAY_TAG)

static func skips_post_hit_effects(event: DamageEvent) -> bool:
	return has_derived_tag(event, BURST_OVERFLOW_TAG)

static func skips_post_kill_effects(event: DamageEvent) -> bool:
	return has_derived_tag(event, BURST_OVERFLOW_TAG)

static func skips_combat_stats(event: DamageEvent) -> bool:
	return (
		has_derived_tag(event, MELEE_REPLAY_TAG)
		or has_derived_tag(event, GUARDIAN_REFRACTION_TAG)
		or has_derived_tag(event, SURVIVAL_ECHO_TAG)
	)

static func skips_melee_replay_record(event: DamageEvent) -> bool:
	return has_derived_tag(event, MELEE_REPLAY_TAG)
