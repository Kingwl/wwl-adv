extends Node
## 全局游戏状态。autoload 单例，跨场景持有当前一局的进度。

signal run_started
signal run_ended(victory: bool)
signal hp_changed(current: int, max_hp: int)
signal gold_changed(amount: int)
signal exp_changed(current: int, required: int)
signal level_up(new_level: int)
signal game_speed_changed(multiplier: float)
signal weapons_changed

const STARTING_HP := 100
const STARTING_GOLD := 0
const STARTING_EXP_TO_LEVEL := 15
const MAX_WEAPON_SLOTS := 6
const MAX_ENHANCEMENT_SLOTS := 6
const GAME_SPEED_OPTIONS := [1.0, 2.0]
const STAT_UPGRADE_ICON := preload("res://assets/art/ui/icon_stat_upgrade.png")
const REGEN_ENHANCEMENT_ID := &"regen"
const REGEN_BASE_HEAL := 5
const REGEN_HEAL_PER_LEVEL := 2
const REGEN_INTERVAL := 5.0
const DEFAULT_CHARACTER_ID := &"adventurer"
const GUARD_REFRACTION_PASSIVE_ID := &"refraction_armor"
const GUARD_REFRACTION_DAMAGE_REDUCTION := 0.12
const GUARD_REFRACTION_RADIUS := 180.0
const GUARD_REFRACTION_NEAR_MULTIPLIER := 1.8
const GUARD_REFRACTION_FAR_MULTIPLIER := 0.6

var run := {
	"hp": STARTING_HP,
	"max_hp": STARTING_HP,
	"character_id": DEFAULT_CHARACTER_ID,
	"character_name": "冒险者",
	"passive_id": &"balanced",
	"gold": STARTING_GOLD,
	"level": 1,
	"exp": 0,
	"exp_to_next_level": STARTING_EXP_TO_LEVEL,
	"run_time": 0.0,
	"kills": 0,
	"seed": 0,
	"pickup_radius_bonus": 0.0,
	"exp_gain_multiplier": 1.0,
	"incoming_damage_multiplier": 1.0,
	"damage_multiplier": 1.0,
	"cooldown_multiplier": 1.0,
	"area_multiplier": 1.0,
	"projectile_cooldown_multiplier": 1.0,
	"field_lifetime_multiplier": 1.0,
	"starting_weapon_ids": [&"melee_basic"],
	"enhancements": {},
	"enhancement_order": [],
}
var game_speed_multiplier := 1.0

func start_new_run(rng_seed: int = 0, character_id: StringName = &"") -> void:
	reset_game_speed()
	if rng_seed == 0:
		rng_seed = int(Time.get_unix_time_from_system())
	var character := _resolve_character(character_id)
	var max_hp := STARTING_HP
	var move_speed := 170.0
	var display_name := "冒险者"
	var selected_id := DEFAULT_CHARACTER_ID
	var passive_id := &"balanced"
	var pickup_bonus := 0.0
	var exp_gain := 1.0
	var incoming_damage := 1.0
	var damage_mult := 1.0
	var cooldown_mult := 1.0
	var area_mult := 1.0
	var projectile_cooldown_mult := 1.0
	var field_lifetime_mult := 1.0
	var starting_weapons: Array[StringName] = [&"melee_basic"]
	if character:
		selected_id = character.id
		display_name = character.display_name
		passive_id = character.passive_id
		max_hp = character.max_hp
		move_speed = character.move_speed
		pickup_bonus = character.pickup_radius_bonus
		exp_gain = character.exp_gain_multiplier
		incoming_damage = character.incoming_damage_multiplier
		damage_mult = character.damage_multiplier
		cooldown_mult = character.cooldown_multiplier
		area_mult = character.area_multiplier
		projectile_cooldown_mult = character.projectile_cooldown_multiplier
		field_lifetime_mult = character.field_lifetime_multiplier
		starting_weapons = character.starting_weapon_ids.duplicate()
		if starting_weapons.is_empty():
			starting_weapons = [&"melee_basic"]
	run = {
		"hp": max_hp,
		"max_hp": max_hp,
		"character_id": selected_id,
		"character_name": display_name,
		"passive_id": passive_id,
		"gold": STARTING_GOLD,
		"level": 1,
		"exp": 0,
		"exp_to_next_level": STARTING_EXP_TO_LEVEL,
		"run_time": 0.0,
		"kills": 0,
		"seed": rng_seed,
		"move_speed": move_speed,
		"pickup_radius_bonus": pickup_bonus,
		"exp_gain_multiplier": exp_gain,
		"incoming_damage_multiplier": incoming_damage,
		"damage_multiplier": damage_mult,
		"cooldown_multiplier": cooldown_mult,
		"area_multiplier": area_mult,
		"projectile_cooldown_multiplier": projectile_cooldown_mult,
		"field_lifetime_multiplier": field_lifetime_mult,
		"starting_weapon_ids": starting_weapons,
		"enhancements": {},
		"enhancement_order": [],
	}
	run_started.emit()

func take_damage(amount: int) -> DamageResult:
	var event := DamageEvent.from_amount(amount, self, DamageEvent.DAMAGE_TYPE_PHYSICAL, DamageEvent.DELIVERY_DIRECT)
	return apply_damage(event)

func apply_damage(event: DamageEvent) -> DamageResult:
	if not event or event.amount <= 0:
		return DamageResult.blocked(event)
	var base_result := DamageCalculator.calculate(event)
	if base_result.final_amount <= 0:
		return base_result
	var damage_info := _calculate_incoming_damage(base_result.final_amount, event)
	var final_amount := int(damage_info["final_amount"])
	var guard_prevented := int(damage_info["guard_refraction_prevented"])
	base_result.prevented_amount += maxi(0, base_result.final_amount - final_amount)
	base_result.final_amount = final_amount
	base_result.was_blocked = final_amount <= 0
	run.hp = max(0, run.hp - final_amount)
	if guard_prevented > 0:
		_reflect_guard_refraction_damage(guard_prevented)
	hp_changed.emit(run.hp, run.max_hp)
	if run.hp <= 0:
		base_result.killed = true
		run_ended.emit(false)
	return base_result

func preview_take_damage(amount: int) -> int:
	if amount <= 0:
		return 0
	return preview_apply_damage(DamageEvent.from_amount(amount, self, DamageEvent.DAMAGE_TYPE_PHYSICAL, DamageEvent.DELIVERY_DIRECT)).final_amount

func preview_apply_damage(event: DamageEvent) -> DamageResult:
	if not event or event.amount <= 0:
		return DamageResult.blocked(event)
	var base_result := DamageCalculator.calculate(event)
	var damage_info := _calculate_incoming_damage(base_result.final_amount, event)
	var final_amount := int(damage_info["final_amount"])
	base_result.prevented_amount += maxi(0, base_result.final_amount - final_amount)
	base_result.final_amount = final_amount
	base_result.was_blocked = final_amount <= 0
	base_result.killed = run.hp <= final_amount
	return base_result

func heal(amount: int) -> void:
	run.hp = min(run.max_hp, run.hp + amount)
	hp_changed.emit(run.hp, run.max_hp)

func add_gold(amount: int) -> void:
	run.gold += amount
	SaveManager.add_total_gold(amount)
	gold_changed.emit(run.gold)

func add_exp(amount: int) -> void:
	if amount <= 0:
		return
	var gained := maxi(1, int(round(amount * float(run.get("exp_gain_multiplier", 1.0)))))
	run.exp += gained
	while run.exp >= run.exp_to_next_level:
		run.exp -= run.exp_to_next_level
		run.level += 1
		run.exp_to_next_level = _calc_exp_required(run.level)
		level_up.emit(run.level)
	exp_changed.emit(run.exp, run.exp_to_next_level)

func add_kill() -> void:
	run.kills += 1
	SaveManager.add_lifetime_kills(1)

func add_run_time(delta: float) -> void:
	run.run_time += delta

func get_time_string() -> String:
	var total_seconds := int(run.run_time)
	var minutes := total_seconds / 60
	var seconds := total_seconds % 60
	return "%02d:%02d" % [minutes, seconds]

func get_enhancement_count() -> int:
	return (run.get("enhancement_order", []) as Array).size()

func get_enhancement_level(enhancement_id: StringName) -> int:
	var enhancements: Dictionary = run.get("enhancements", {})
	var key := str(enhancement_id)
	if not enhancements.has(key):
		return 0
	return int(enhancements[key].get("level", 0))

func can_add_enhancement(enhancement_id: StringName) -> bool:
	if get_enhancement_level(enhancement_id) > 0:
		return true
	return get_enhancement_count() < MAX_ENHANCEMENT_SLOTS

func add_enhancement(upgrade: UpgradeData) -> bool:
	if not upgrade or upgrade.id.is_empty():
		return false
	var key := str(upgrade.id)
	var enhancements: Dictionary = run.get("enhancements", {})
	var order: Array = run.get("enhancement_order", [])
	if not enhancements.has(key):
		if order.size() >= MAX_ENHANCEMENT_SLOTS:
			return false
		enhancements[key] = {
			"id": key,
			"display_name": upgrade.display_name,
			"description": upgrade.description,
			"level": 1,
			"icon": upgrade.icon if upgrade.icon else STAT_UPGRADE_ICON,
		}
		order.append(key)
	else:
		var data: Dictionary = enhancements[key]
		data["level"] = int(data.get("level", 1)) + 1
		data["display_name"] = upgrade.display_name
		data["description"] = upgrade.description
		if upgrade.icon:
			data["icon"] = upgrade.icon
		elif not data.has("icon"):
			data["icon"] = STAT_UPGRADE_ICON
		enhancements[key] = data
	run["enhancements"] = enhancements
	run["enhancement_order"] = order
	return true

func get_enhancements() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var enhancements: Dictionary = run.get("enhancements", {})
	var order: Array = run.get("enhancement_order", [])
	for key in order:
		if enhancements.has(str(key)):
			result.append(enhancements[str(key)])
	return result

func get_regen_heal_amount() -> int:
	var level := get_enhancement_level(REGEN_ENHANCEMENT_ID)
	if level <= 0:
		return 0
	return REGEN_BASE_HEAL + (level - 1) * REGEN_HEAL_PER_LEVEL

func get_character_damage_multiplier() -> float:
	return maxf(0.05, float(run.get("damage_multiplier", 1.0)))

func get_character_cooldown_multiplier(weapon_data: WeaponData = null) -> float:
	var multiplier := maxf(0.05, float(run.get("cooldown_multiplier", 1.0)))
	if weapon_data and weapon_data.weapon_type == WeaponData.WeaponType.PROJECTILE:
		multiplier *= maxf(0.05, float(run.get("projectile_cooldown_multiplier", 1.0)))
	return multiplier

func get_character_area_multiplier() -> float:
	return maxf(0.05, float(run.get("area_multiplier", 1.0)))

func get_character_field_lifetime_multiplier() -> float:
	return maxf(0.05, float(run.get("field_lifetime_multiplier", 1.0)))

func get_total_gold() -> int:
	return int(SaveManager.get_profile_value("total_gold", 0))

func notify_weapons_changed() -> void:
	weapons_changed.emit()

func set_game_speed(multiplier: float) -> bool:
	var normalized := _normalize_game_speed(multiplier)
	if normalized <= 0.0:
		return false
	game_speed_multiplier = normalized
	Engine.time_scale = normalized
	game_speed_changed.emit(game_speed_multiplier)
	return true

func toggle_game_speed() -> float:
	var current_index := _get_game_speed_index(game_speed_multiplier)
	var next_index := (current_index + 1) % GAME_SPEED_OPTIONS.size()
	set_game_speed(float(GAME_SPEED_OPTIONS[next_index]))
	return game_speed_multiplier

func reset_game_speed() -> void:
	set_game_speed(float(GAME_SPEED_OPTIONS[0]))

func _calc_exp_required(level: int) -> int:
	return int(STARTING_EXP_TO_LEVEL * pow(1.2, level - 1))

func _normalize_game_speed(multiplier: float) -> float:
	for option in GAME_SPEED_OPTIONS:
		if is_equal_approx(multiplier, float(option)):
			return float(option)
	return -1.0

func _get_game_speed_index(multiplier: float) -> int:
	for i in range(GAME_SPEED_OPTIONS.size()):
		if is_equal_approx(multiplier, float(GAME_SPEED_OPTIONS[i])):
			return i
	return 0

func _resolve_character(character_id: StringName) -> Resource:
	var id := character_id
	if id.is_empty():
		id = SaveManager.get_selected_character_id()
	var character := DataManager.get_character(str(id))
	if character:
		return character
	return DataManager.get_default_character()

func _apply_incoming_damage_multiplier(amount: int) -> int:
	if amount <= 0:
		return amount
	var multiplier := maxf(0.0, float(run.get("incoming_damage_multiplier", 1.0)))
	return maxi(1, int(ceil(amount * multiplier)))

func _calculate_incoming_damage(amount: int, event: DamageEvent = null) -> Dictionary:
	var scaled_amount := amount if event and event.damage_type == DamageEvent.DAMAGE_TYPE_PURE else _apply_incoming_damage_multiplier(amount)
	var guard_prevented := _get_guard_refraction_prevented_damage(scaled_amount)
	return {
		"final_amount": maxi(0, scaled_amount - guard_prevented),
		"guard_refraction_prevented": guard_prevented,
	}

func _get_guard_refraction_prevented_damage(amount: int) -> int:
	if amount <= 1:
		return 0
	if StringName(run.get("passive_id", &"")) != GUARD_REFRACTION_PASSIVE_ID:
		return 0
	var max_prevented := amount - 1
	var prevented := int(round(float(amount) * GUARD_REFRACTION_DAMAGE_REDUCTION))
	return clampi(prevented, 1, max_prevented)

func _reflect_guard_refraction_damage(prevented_damage: int) -> void:
	if prevented_damage <= 0:
		return
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if not player:
		return
	var parent := get_tree().current_scene
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not (enemy is Node2D) or not enemy.has_method("take_damage"):
			continue
		var distance := player.global_position.distance_to(enemy.global_position)
		if distance > GUARD_REFRACTION_RADIUS:
			continue
		var t := clampf(distance / GUARD_REFRACTION_RADIUS, 0.0, 1.0)
		var multiplier := GUARD_REFRACTION_NEAR_MULTIPLIER + (GUARD_REFRACTION_FAR_MULTIPLIER - GUARD_REFRACTION_NEAR_MULTIPLIER) * t
		var reflected_damage := maxi(1, int(round(float(prevented_damage) * multiplier)))
		var event := DamageEvent.from_amount(reflected_damage, self, DamageEvent.DAMAGE_TYPE_PURE, DamageEvent.DELIVERY_REFLECT)
		event.tags.append(&"guardian_refraction")
		DamageCalculator.deal_damage(enemy, event)
		if parent:
			VFXHelper.spawn_animated_one_shot(
				parent,
				"res://assets/art/effects/by_type/fx_thorns",
				"thorns",
				4,
				enemy.global_position,
				8.0,
				Vector2(0.75, 0.75)
			)
