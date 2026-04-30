class_name DamageEvent
extends RefCounted
## Describes one damage attempt before target-specific mitigation is applied.

const DAMAGE_TYPE_PHYSICAL := &"physical"
const DAMAGE_TYPE_FIRE := &"fire"
const DAMAGE_TYPE_POISON := &"poison"
const DAMAGE_TYPE_FROST := &"frost"
const DAMAGE_TYPE_LIGHTNING := &"lightning"
const DAMAGE_TYPE_HOLY := &"holy"
const DAMAGE_TYPE_PURE := &"pure"

const DELIVERY_DIRECT := &"direct"
const DELIVERY_MELEE := &"melee"
const DELIVERY_PROJECTILE := &"projectile"
const DELIVERY_AREA := &"area"
const DELIVERY_DOT := &"dot"
const DELIVERY_BEAM := &"beam"
const DELIVERY_CONTACT := &"contact"
const DELIVERY_REFLECT := &"reflect"

var amount: int = 0
var source: Node = null
var owner: Node = null
var target: Node = null
var weapon_id: StringName = &""
var damage_type: StringName = DAMAGE_TYPE_PHYSICAL
var delivery_type: StringName = DELIVERY_DIRECT
var tags: Array[StringName] = []
var position: Vector2 = Vector2.ZERO
var can_crit: bool = false
var crit_chance: float = 0.0
var crit_multiplier: float = 2.0
var status_id: StringName = &""
var status_duration: float = 0.0
var status_value: float = 0.0

static func from_amount(
	base_amount: int,
	source_node: Node = null,
	type: StringName = DAMAGE_TYPE_PHYSICAL,
	delivery: StringName = DELIVERY_DIRECT
) -> DamageEvent:
	var event := DamageEvent.new()
	event.amount = base_amount
	event.source = source_node
	event.owner = source_node
	event.damage_type = type
	event.delivery_type = delivery
	if source_node is Node2D:
		event.position = (source_node as Node2D).global_position
	return event

static func weapon_hit(
	base_amount: int,
	source_weapon: Node,
	type: StringName = DAMAGE_TYPE_PHYSICAL,
	delivery: StringName = DELIVERY_DIRECT,
	target_node: Node = null
) -> DamageEvent:
	var event := from_amount(base_amount, source_weapon, type, delivery)
	event.target = target_node
	if source_weapon:
		var data = source_weapon.get("weapon_data")
		if data is WeaponData:
			event.weapon_id = (data as WeaponData).id
		var parent := source_weapon.get_parent()
		if parent:
			event.owner = parent.get_parent()
	return event

func duplicate_for_target(target_node: Node) -> DamageEvent:
	var event := DamageEvent.new()
	event.amount = amount
	event.source = source
	event.owner = owner
	event.target = target_node
	event.weapon_id = weapon_id
	event.damage_type = damage_type
	event.delivery_type = delivery_type
	event.tags = tags.duplicate()
	event.position = position
	event.can_crit = can_crit
	event.crit_chance = crit_chance
	event.crit_multiplier = crit_multiplier
	event.status_id = status_id
	event.status_duration = status_duration
	event.status_value = status_value
	return event

func has_tag(tag: StringName) -> bool:
	return tag in tags
