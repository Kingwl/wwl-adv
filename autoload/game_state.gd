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
const EXP_CURVE_SOFTEN_LEVEL := 20
const EXP_EARLY_GROWTH := 1.2
const EXP_LATE_GROWTH := 1.1
const MAX_WEAPON_SLOTS := 6
const MAX_ENHANCEMENT_SLOTS := 6
const MAX_ENHANCEMENT_LEVEL := 5
const MAX_PLAYER_MOVE_SPEED := 270.0
const MAX_PICKUP_RADIUS_BONUS := 180.0
const MAX_DAMAGE_MULTIPLIER := 1.6
const MIN_COOLDOWN_MULTIPLIER := 0.6
const MAX_AREA_MULTIPLIER := 1.6
const MAX_FIELD_LIFETIME_MULTIPLIER := 1.8
const MIN_INCOMING_DAMAGE_MULTIPLIER := 0.6
const MAX_EXP_GAIN_MULTIPLIER := 1.75
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
	"victory": false,
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
	"weapon_damage": {},
	"weapon_hits": {},
	"weapon_kills": {},
	"weapon_damage_stats": {},
	"damage_taken_by_source": {},
	"death_reason": {},
	"upgrade_history": [],
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
		"victory": false,
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
		"weapon_damage": {},
		"weapon_hits": {},
		"weapon_kills": {},
		"weapon_damage_stats": {},
		"damage_taken_by_source": {},
		"death_reason": {},
		"upgrade_history": [],
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
	var hp_before := int(run.hp)
	run.hp = max(0, run.hp - final_amount)
	if final_amount > 0:
		_record_damage_taken(event, final_amount, hp_before <= final_amount)
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

func record_damage_result(result: DamageResult) -> void:
	if not result or not result.event or result.final_amount <= 0:
		return
	var event := result.event
	if not event.target or not event.target.is_in_group("enemies"):
		return
	var weapon_id := _get_event_weapon_id(event)
	if weapon_id.is_empty():
		return
	record_weapon_damage(weapon_id, result.final_amount, result.killed)

func record_weapon_damage(weapon_id: StringName, amount: int, killed: bool = false) -> void:
	if weapon_id.is_empty() or amount <= 0:
		return
	var key := str(weapon_id)
	var weapon_damage: Dictionary = run.get("weapon_damage", {})
	var weapon_hits: Dictionary = run.get("weapon_hits", {})
	var weapon_kills: Dictionary = run.get("weapon_kills", {})
	var weapon_stats: Dictionary = run.get("weapon_damage_stats", {})
	weapon_damage[key] = int(weapon_damage.get(key, 0)) + amount
	weapon_hits[key] = int(weapon_hits.get(key, 0)) + 1
	if killed:
		weapon_kills[key] = int(weapon_kills.get(key, 0)) + 1

	var entry: Dictionary = weapon_stats.get(key, {})
	if entry.is_empty():
		entry = {
			"id": key,
			"display_name": _get_weapon_display_name(weapon_id),
			"damage": 0,
			"hits": 0,
			"kills": 0,
		}
	entry["damage"] = int(entry.get("damage", 0)) + amount
	entry["hits"] = int(entry.get("hits", 0)) + 1
	if killed:
		entry["kills"] = int(entry.get("kills", 0)) + 1
	weapon_stats[key] = entry

	run["weapon_damage"] = weapon_damage
	run["weapon_hits"] = weapon_hits
	run["weapon_kills"] = weapon_kills
	run["weapon_damage_stats"] = weapon_stats

func get_weapon_combat_summary(limit: int = 5) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var weapon_stats: Dictionary = run.get("weapon_damage_stats", {})
	for key in weapon_stats.keys():
		var entry: Dictionary = weapon_stats[key]
		result.append(entry.duplicate(true))
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var damage_a := int(a.get("damage", 0))
		var damage_b := int(b.get("damage", 0))
		if damage_a == damage_b:
			return int(a.get("kills", 0)) > int(b.get("kills", 0))
		return damage_a > damage_b
	)
	return result.slice(0, maxi(0, limit))

func record_upgrade_selected(upgrade: UpgradeData) -> void:
	if not upgrade:
		return
	var history: Array = run.get("upgrade_history", [])
	history.append({
		"id": str(upgrade.id),
		"display_name": upgrade.display_name,
		"type": int(upgrade.upgrade_type),
		"type_name": _upgrade_type_name(upgrade.upgrade_type),
		"weapon_id": str(upgrade.weapon_id),
		"path_id": str(upgrade.path_id),
		"level": int(run.get("level", 1)),
		"time": float(run.get("run_time", 0.0)),
		"build_tags": upgrade.build_tags.duplicate(),
	})
	if history.size() > 80:
		history = history.slice(history.size() - 80)
	run["upgrade_history"] = history

func get_upgrade_history(limit: int = 8) -> Array[Dictionary]:
	var history: Array = run.get("upgrade_history", [])
	var result: Array[Dictionary] = []
	var start_index := maxi(0, history.size() - limit)
	for i in range(start_index, history.size()):
		var entry: Dictionary = history[i]
		result.append(entry.duplicate(true))
	return result

func get_damage_taken_summary(limit: int = 3) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var sources: Dictionary = run.get("damage_taken_by_source", {})
	for key in sources.keys():
		var entry: Dictionary = sources[key]
		result.append(entry.duplicate(true))
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("amount", 0)) > int(b.get("amount", 0))
	)
	return result.slice(0, maxi(0, limit))

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
	var level := get_enhancement_level(enhancement_id)
	if level > 0:
		return level < get_max_enhancement_level(enhancement_id)
	return get_enhancement_count() < MAX_ENHANCEMENT_SLOTS

func get_max_enhancement_level(_enhancement_id: StringName) -> int:
	return MAX_ENHANCEMENT_LEVEL

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
		if int(data.get("level", 1)) >= get_max_enhancement_level(upgrade.id):
			return false
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

func get_regen_interval() -> float:
	return maxf(0.1, REGEN_INTERVAL * get_character_cooldown_multiplier())

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
	if level <= EXP_CURVE_SOFTEN_LEVEL:
		return int(STARTING_EXP_TO_LEVEL * pow(EXP_EARLY_GROWTH, level - 1))
	var pivot := STARTING_EXP_TO_LEVEL * pow(EXP_EARLY_GROWTH, EXP_CURVE_SOFTEN_LEVEL - 1)
	return int(pivot * pow(EXP_LATE_GROWTH, level - EXP_CURVE_SOFTEN_LEVEL))

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

func _record_damage_taken(event: DamageEvent, amount: int, fatal: bool) -> void:
	if amount <= 0:
		return
	var source_key := _get_damage_source_key(event)
	var source_name := _get_damage_source_display_name(event)
	var sources: Dictionary = run.get("damage_taken_by_source", {})
	var entry: Dictionary = sources.get(source_key, {})
	if entry.is_empty():
		entry = {
			"id": source_key,
			"display_name": source_name,
			"amount": 0,
			"hits": 0,
		}
	entry["display_name"] = source_name
	entry["amount"] = int(entry.get("amount", 0)) + amount
	entry["hits"] = int(entry.get("hits", 0)) + 1
	sources[source_key] = entry
	run["damage_taken_by_source"] = sources
	if fatal:
		run["death_reason"] = {
			"id": source_key,
			"display_name": source_name,
			"amount": amount,
			"damage_type": str(event.damage_type if event else DamageEvent.DAMAGE_TYPE_PHYSICAL),
			"delivery_type": str(event.delivery_type if event else DamageEvent.DELIVERY_DIRECT),
		}

func _get_event_weapon_id(event: DamageEvent) -> StringName:
	if not event:
		return &""
	if not event.weapon_id.is_empty():
		return event.weapon_id
	if event.source:
		var data = event.source.get("weapon_data")
		if data is WeaponData:
			return (data as WeaponData).id
	return &""

func _get_weapon_display_name(weapon_id: StringName) -> String:
	var weapon := DataManager.get_weapon(str(weapon_id))
	if weapon is WeaponData:
		return (weapon as WeaponData).display_name
	match weapon_id:
		&"enemy_projectile":
			return "敌方弹体"
	return str(weapon_id)

func _get_damage_source_key(event: DamageEvent) -> String:
	if not event:
		return "unknown"
	if not event.weapon_id.is_empty():
		if event.weapon_id == &"enemy_projectile" and event.source:
			var enemy_data = event.source.get("enemy_data")
			if enemy_data is EnemyData:
				return "enemy:%s:projectile" % str((enemy_data as EnemyData).id)
		return "weapon:%s" % str(event.weapon_id)
	if event.source:
		var enemy_data = event.source.get("enemy_data")
		if enemy_data is EnemyData:
			return "enemy:%s:%s" % [str((enemy_data as EnemyData).id), str(event.delivery_type)]
		if event.source == self:
			return "direct"
	return "unknown"

func _get_damage_source_display_name(event: DamageEvent) -> String:
	if not event:
		return "未知伤害"
	if event.source:
		var enemy_data = event.source.get("enemy_data")
		if enemy_data is EnemyData:
			var base_name := (enemy_data as EnemyData).display_name
			if event.weapon_id == &"enemy_projectile" or event.delivery_type == DamageEvent.DELIVERY_PROJECTILE:
				return "%s弹体" % base_name
			if event.delivery_type == DamageEvent.DELIVERY_CONTACT:
				return "%s接触" % base_name
			return base_name
	if not event.weapon_id.is_empty():
		return _get_weapon_display_name(event.weapon_id)
	if event.source == self:
		return "直接伤害"
	return "未知伤害"

func _upgrade_type_name(upgrade_type: int) -> String:
	match upgrade_type:
		UpgradeData.UpgradeType.WEAPON_UNLOCK:
			return "武器解锁"
		UpgradeData.UpgradeType.WEAPON_LEVEL:
			return "武器强化"
		UpgradeData.UpgradeType.WEAPON_PATH:
			return "流派选择"
		UpgradeData.UpgradeType.PLAYER_STAT:
			return "角色强化"
	return "升级"

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
