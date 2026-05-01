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
var source = null:
	set(value):
		source = node_or_null(value)
	get:
		return node_or_null(source)
var owner = null:
	set(value):
		owner = node_or_null(value)
	get:
		return node_or_null(owner)
var target = null:
	set(value):
		target = node_or_null(value)
	get:
		return node_or_null(target)
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
	source_node = null,
	type: StringName = DAMAGE_TYPE_PHYSICAL,
	delivery: StringName = DELIVERY_DIRECT
) -> DamageEvent:
	var event := DamageEvent.new()
	var valid_source := node_or_null(source_node)
	event.amount = base_amount
	event.source = valid_source
	event.owner = valid_source
	event.damage_type = type
	event.delivery_type = delivery
	if valid_source is Node2D:
		event.position = (valid_source as Node2D).global_position
	return event

static func weapon_hit(
	base_amount: int,
	source_weapon,
	type: StringName = DAMAGE_TYPE_PHYSICAL,
	delivery: StringName = DELIVERY_DIRECT,
	target_node = null
) -> DamageEvent:
	var valid_source := node_or_null(source_weapon)
	var event := from_amount(base_amount, valid_source, type, delivery)
	event.target = target_node
	if valid_source:
		var data = valid_source.get("weapon_data")
		if data is WeaponData:
			event.weapon_id = (data as WeaponData).id
		var parent := valid_source.get_parent()
		if parent:
			event.owner = parent.get_parent()
	return event

static func node_or_null(value) -> Node:
	if value == null:
		return null
	if not (value is Object):
		return null
	if not is_instance_valid(value):
		return null
	if not (value is Node):
		return null
	var node := value as Node
	if node.is_queued_for_deletion():
		return null
	return node

func duplicate_for_target(target_node) -> DamageEvent:
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
