extends Node
## 全局游戏状态。autoload 单例，跨场景持有当前一局的进度。

const CombatEffectRules := preload("res://scripts/combat/combat_effect_rules.gd")

signal run_started
signal run_ended(victory: bool)
signal hp_changed(current: int, max_hp: int)
signal gold_changed(amount: int)
signal exp_changed(current: int, required: int)
signal level_up(new_level: int)
signal game_speed_changed(multiplier: float)
signal weapons_changed
signal build_resonance_changed
signal local_debug_mode_changed(enabled: bool)

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
const MELEE_RESONANCE_TAG := "近身"
const MELEE_REPLAY_WINDOW := 5.0
const MELEE_REPLAY_INTERVAL := 5.0
const MELEE_REPLAY_RADIUS := 160.0
const CONTROL_RESONANCE_TAG := "控制"
const SURVIVAL_RESONANCE_TAG := "生存"
const SURVIVAL_FIXED_DAMAGE_REDUCTION := 0.08
const SURVIVAL_LOW_HP_START_RATIO := 0.70
const SURVIVAL_LOW_HP_MAX_RATIO := 0.25
const SURVIVAL_LOW_HP_MAX_EXTRA_REDUCTION := 0.22
const SURVIVAL_ECHO_TRIGGER_RATIO := 0.20
const SURVIVAL_ECHO_DURATION := 3.0
const SURVIVAL_ECHO_COOLDOWN := 45.0
const SURVIVAL_ECHO_RADIUS := 220.0
const SURVIVAL_ECHO_DAMAGE_RATIO := 1.0

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
	"build_resonance_rewards": {},
	"melee_replay_history": [],
	"melee_replay_next_time": 0.0,
	"control_resonance_energy": 0.0,
	"control_charge_next_by_enemy": {},
	"survival_echo_until": 0.0,
	"survival_echo_next_trigger_time": 0.0,
	"survival_echo_absorbed_damage": 0,
}
var game_speed_multiplier := 1.0
var local_debug_mode_enabled := false

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
		"build_resonance_rewards": {},
		"melee_replay_history": [],
		"melee_replay_next_time": 0.0,
		"control_resonance_energy": 0.0,
		"control_charge_next_by_enemy": {},
		"survival_echo_until": 0.0,
		"survival_echo_next_trigger_time": 0.0,
		"survival_echo_absorbed_damage": 0,
	}
	run_started.emit()

func take_damage(amount: int) -> DamageResult:
	var event := DamageEvent.from_amount(amount, self, DamageEvent.DAMAGE_TYPE_PHYSICAL, DamageEvent.DELIVERY_DIRECT)
	return apply_damage(event)

func apply_damage(event: DamageEvent) -> DamageResult:
	if not event or event.amount <= 0:
		return DamageResult.blocked(event)
	if is_local_debug_mode_active():
		return DamageResult.blocked(event)
	var base_result := DamageCalculator.calculate(event)
	if base_result.final_amount <= 0:
		return base_result
	var damage_info := _calculate_incoming_damage(base_result.final_amount, event, true)
	var final_amount := int(damage_info["final_amount"])
	var guard_prevented := int(damage_info["guard_refraction_prevented"])
	base_result.prevented_amount += maxi(0, base_result.final_amount - final_amount)
	base_result.final_amount = final_amount
	base_result.was_blocked = final_amount <= 0
	var hp_before := int(run.hp)
	var survival_heal := int(damage_info["survival_echo_heal"])
	if survival_heal > 0:
		run.hp = mini(int(run.max_hp), int(run.hp) + survival_heal)
	else:
		run.hp = max(0, int(run.hp) - final_amount)
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
	if is_local_debug_mode_active():
		return DamageResult.blocked(event)
	var base_result := DamageCalculator.calculate(event)
	var damage_info := _calculate_incoming_damage(base_result.final_amount, event, false)
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
	if CombatEffectRules.skips_combat_stats(event):
		return
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
		"resonance_preview": upgrade.resonance_preview,
		"choice_hint": upgrade.choice_hint,
	})
	if history.size() > 80:
		history = history.slice(history.size() - 80)
	run["upgrade_history"] = history

func record_build_resonance_reward(tag: String, tier: int, reward_name: String) -> bool:
	if tag.is_empty() or tier <= 0:
		return false
	var rewards: Dictionary = run.get("build_resonance_rewards", {})
	var key := "%s_%d" % [tag, tier]
	if rewards.has(key):
		return false
	rewards[key] = {
		"tag": tag,
		"tier": tier,
		"reward_name": reward_name,
		"level": int(run.get("level", 1)),
		"time": float(run.get("run_time", 0.0)),
	}
	run["build_resonance_rewards"] = rewards
	if tag == MELEE_RESONANCE_TAG and tier >= 3:
		run["melee_replay_history"] = []
		run["melee_replay_next_time"] = float(run.get("run_time", 0.0)) + MELEE_REPLAY_INTERVAL
	build_resonance_changed.emit()
	return true

func get_build_resonance_reward_tier(tag: String) -> int:
	if tag.is_empty():
		return 0
	var rewards: Dictionary = run.get("build_resonance_rewards", {})
	var highest := 0
	for key in rewards.keys():
		var entry = rewards[key]
		if entry is Dictionary:
			var entry_data := entry as Dictionary
			if str(entry_data.get("tag", "")) == tag:
				highest = maxi(highest, int(entry_data.get("tier", 0)))
		elif str(key).begins_with("%s_" % tag):
			var parts := str(key).split("_")
			if parts.size() >= 2:
				highest = maxi(highest, int(parts[parts.size() - 1]))
	return highest

func record_melee_replay_damage(amount: int, damage_type: StringName) -> void:
	if amount <= 0 or get_build_resonance_reward_tier(MELEE_RESONANCE_TAG) < 3:
		return
	var now := float(run.get("run_time", 0.0))
	var history := _prune_melee_replay_history(now)
	history.append({
		"time": now,
		"amount": amount,
		"damage_type": damage_type,
	})
	run["melee_replay_history"] = history

func claim_control_resonance_charge_source(target: Node, cooldown: float) -> bool:
	if not is_instance_valid(target) or cooldown <= 0.0:
		return false
	var now := float(run.get("run_time", 0.0))
	var key := str(target.get_instance_id())
	var next_by_enemy: Dictionary = run.get("control_charge_next_by_enemy", {})
	if now < float(next_by_enemy.get(key, 0.0)):
		return false
	next_by_enemy[key] = now + cooldown
	run["control_charge_next_by_enemy"] = next_by_enemy
	return true

func add_control_resonance_energy(amount: float, max_energy: float) -> bool:
	if amount <= 0.0 or max_energy <= 0.0:
		return false
	var current := float(run.get("control_resonance_energy", 0.0))
	var next := current + amount
	if next >= max_energy:
		run["control_resonance_energy"] = 0.0
		return true
	run["control_resonance_energy"] = next
	return false

func is_survival_echo_active() -> bool:
	if get_build_resonance_reward_tier(SURVIVAL_RESONANCE_TAG) < 3:
		return false
	return float(run.get("survival_echo_until", 0.0)) > float(run.get("run_time", 0.0))

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
	_trigger_melee_replay_if_ready()
	_release_survival_echo_if_expired()

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
			"build_tags": upgrade.build_tags.duplicate(),
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
		data["build_tags"] = upgrade.build_tags.duplicate()
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

func is_local_debug_available() -> bool:
	return OS.has_feature("editor") or OS.has_feature("debug") or OS.is_debug_build()

func is_local_debug_mode_active() -> bool:
	return local_debug_mode_enabled and is_local_debug_available()

func set_local_debug_mode(enabled: bool) -> bool:
	if enabled and not is_local_debug_available():
		return false
	if local_debug_mode_enabled == enabled:
		return true
	local_debug_mode_enabled = enabled
	if local_debug_mode_enabled:
		heal(int(run.get("max_hp", STARTING_HP)))
	local_debug_mode_changed.emit(local_debug_mode_enabled)
	return true

func toggle_local_debug_mode() -> bool:
	set_local_debug_mode(not local_debug_mode_enabled)
	return local_debug_mode_enabled

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

func _calculate_incoming_damage(amount: int, event: DamageEvent = null, mutate: bool = false) -> Dictionary:
	var unmitigated_amount := maxi(0, amount)
	var scaled_amount := amount if event and event.damage_type == DamageEvent.DAMAGE_TYPE_PURE else _apply_incoming_damage_multiplier(amount)
	var survival_prevented := _get_survival_resonance_prevented_damage(scaled_amount, event)
	var survival_amount := maxi(0, scaled_amount - survival_prevented)
	var control_prevented := _get_control_threat_prevented_damage(survival_amount, event)
	var controlled_amount := maxi(0, survival_amount - control_prevented)
	var guard_prevented := 0
	var reflected_amount := controlled_amount
	var survival_echo_heal := 0
	var survival_echo_absorbed := _get_survival_echo_absorbed_damage(unmitigated_amount, event)
	if survival_echo_absorbed > 0:
		reflected_amount = 0
		survival_echo_heal = survival_echo_absorbed
		if mutate:
			_activate_survival_echo_if_needed()
			run["survival_echo_absorbed_damage"] = int(run.get("survival_echo_absorbed_damage", 0)) + survival_echo_absorbed
	else:
		guard_prevented = _get_guard_refraction_prevented_damage(controlled_amount, unmitigated_amount)
		reflected_amount = maxi(0, controlled_amount - guard_prevented)
	return {
		"final_amount": maxi(0, reflected_amount),
		"survival_prevented": survival_prevented,
		"control_threat_prevented": control_prevented,
		"guard_refraction_prevented": guard_prevented,
		"survival_echo_absorbed": survival_echo_absorbed,
		"survival_echo_heal": survival_echo_heal,
	}

func _get_survival_resonance_prevented_damage(amount: int, event: DamageEvent = null) -> int:
	if amount <= 1:
		return 0
	if not event or event.damage_type == DamageEvent.DAMAGE_TYPE_PURE:
		return 0
	var tier := get_build_resonance_reward_tier(SURVIVAL_RESONANCE_TAG)
	if tier <= 0:
		return 0
	var reduction := SURVIVAL_FIXED_DAMAGE_REDUCTION
	if tier >= 2:
		reduction += _get_survival_low_hp_extra_reduction()
	reduction = clampf(reduction, 0.0, 0.95)
	var reduced_amount := maxi(1, int(ceil(float(amount) * (1.0 - reduction))))
	return maxi(0, amount - reduced_amount)

func _get_survival_low_hp_extra_reduction() -> float:
	var max_hp := maxf(1.0, float(run.get("max_hp", STARTING_HP)))
	var hp_ratio := clampf(float(run.get("hp", 0)) / max_hp, 0.0, 1.0)
	if hp_ratio >= SURVIVAL_LOW_HP_START_RATIO:
		return 0.0
	if hp_ratio <= SURVIVAL_LOW_HP_MAX_RATIO:
		return SURVIVAL_LOW_HP_MAX_EXTRA_REDUCTION
	var span := maxf(SURVIVAL_LOW_HP_START_RATIO - SURVIVAL_LOW_HP_MAX_RATIO, 0.001)
	var progress := (SURVIVAL_LOW_HP_START_RATIO - hp_ratio) / span
	return progress * SURVIVAL_LOW_HP_MAX_EXTRA_REDUCTION

func _get_survival_echo_absorbed_damage(amount: int, event: DamageEvent = null) -> int:
	if amount <= 0:
		return 0
	if not _can_survival_echo_apply(event):
		return 0
	if is_survival_echo_active() or _would_trigger_survival_echo(amount):
		return amount
	return 0

func _can_survival_echo_apply(event: DamageEvent = null) -> bool:
	if get_build_resonance_reward_tier(SURVIVAL_RESONANCE_TAG) < 3:
		return false
	if not event or event.damage_type == DamageEvent.DAMAGE_TYPE_PURE:
		return false
	return true

func _would_trigger_survival_echo(amount: int) -> bool:
	if amount <= 0:
		return false
	var now := float(run.get("run_time", 0.0))
	if now < float(run.get("survival_echo_next_trigger_time", 0.0)):
		return false
	var max_hp := maxf(1.0, float(run.get("max_hp", STARTING_HP)))
	var trigger_hp := max_hp * SURVIVAL_ECHO_TRIGGER_RATIO
	var hp := float(run.get("hp", 0))
	return hp <= trigger_hp or hp - float(amount) <= trigger_hp

func _activate_survival_echo_if_needed() -> void:
	if is_survival_echo_active():
		return
	var now := float(run.get("run_time", 0.0))
	run["survival_echo_until"] = now + SURVIVAL_ECHO_DURATION
	run["survival_echo_next_trigger_time"] = now + SURVIVAL_ECHO_COOLDOWN
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player:
		_spawn_resonance_effect(VFXHelper.EFFECT_SURVIVAL_ECHO, player.global_position, 0.0, 1.2)

func _release_survival_echo_if_expired() -> void:
	var until := float(run.get("survival_echo_until", 0.0))
	if until <= 0.0 or float(run.get("run_time", 0.0)) < until:
		return
	var absorbed := int(run.get("survival_echo_absorbed_damage", 0))
	run["survival_echo_until"] = 0.0
	run["survival_echo_absorbed_damage"] = 0
	_reflect_survival_echo_damage(absorbed)

func _trigger_melee_replay_if_ready() -> void:
	var now := float(run.get("run_time", 0.0))
	if get_build_resonance_reward_tier(MELEE_RESONANCE_TAG) < 3:
		run["melee_replay_history"] = []
		run["melee_replay_next_time"] = 0.0
		return
	var next_time := float(run.get("melee_replay_next_time", 0.0))
	if next_time <= 0.0:
		run["melee_replay_next_time"] = now + MELEE_REPLAY_INTERVAL
		_prune_melee_replay_history(now)
		return
	if now < next_time:
		_prune_melee_replay_history(now)
		return
	var best_entry := _get_best_melee_replay_entry(now)
	while next_time <= now:
		next_time += MELEE_REPLAY_INTERVAL
	run["melee_replay_next_time"] = next_time
	if best_entry.is_empty():
		return
	_apply_melee_replay_damage(
		int(best_entry.get("amount", 0)),
		StringName(best_entry.get("damage_type", DamageEvent.DAMAGE_TYPE_PHYSICAL))
	)

func _prune_melee_replay_history(now: float) -> Array:
	var history: Array = run.get("melee_replay_history", [])
	var cutoff := now - MELEE_REPLAY_WINDOW
	var kept: Array = []
	for entry in history:
		if not (entry is Dictionary):
			continue
		var entry_data := entry as Dictionary
		if float(entry_data.get("time", -999999.0)) < cutoff:
			continue
		kept.append(entry_data)
	run["melee_replay_history"] = kept
	return kept

func _get_best_melee_replay_entry(now: float) -> Dictionary:
	var best_entry: Dictionary = {}
	var best_amount := 0
	for entry in _prune_melee_replay_history(now):
		if not (entry is Dictionary):
			continue
		var entry_data := entry as Dictionary
		var amount := int(entry_data.get("amount", 0))
		if amount > best_amount:
			best_amount = amount
			best_entry = entry_data
	return best_entry

func _apply_melee_replay_damage(amount: int, damage_type: StringName) -> void:
	if amount <= 0:
		return
	var target := _get_melee_replay_target()
	if not target:
		return
	if target is Node2D:
		_spawn_resonance_effect(VFXHelper.EFFECT_MELEE_REPLAY, (target as Node2D).global_position)
	var event := DamageEvent.from_amount(amount, self, damage_type, DamageEvent.DELIVERY_REFLECT)
	CombatEffectRules.add_tag_once(event, CombatEffectRules.MELEE_REPLAY_TAG)
	DamageCalculator.deal_damage(target, event)

func _get_melee_replay_target() -> Node:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if not player:
		return null
	var best_enemy: Node = null
	var best_distance_sq := MELEE_REPLAY_RADIUS * MELEE_REPLAY_RADIUS
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not (enemy is Node2D) or not enemy.has_method("apply_damage"):
			continue
		if enemy.is_queued_for_deletion():
			continue
		if "_dead" in enemy and bool(enemy._dead):
			continue
		var distance_sq := player.global_position.distance_squared_to((enemy as Node2D).global_position)
		if distance_sq > best_distance_sq:
			continue
		best_distance_sq = distance_sq
		best_enemy = enemy
	return best_enemy

func _get_control_threat_prevented_damage(amount: int, event: DamageEvent = null) -> int:
	if amount <= 1 or not event:
		return 0
	if event.damage_type == DamageEvent.DAMAGE_TYPE_PURE:
		return 0
	if event.delivery_type != DamageEvent.DELIVERY_CONTACT and event.delivery_type != DamageEvent.DELIVERY_PROJECTILE:
		return 0
	if not event.source or not event.source.has_method("get_control_threat_multiplier"):
		return 0
	var multiplier := clampf(float(event.source.call("get_control_threat_multiplier")), 0.0, 1.0)
	if multiplier >= 1.0:
		return 0
	var reduced_amount := maxi(1, int(ceil(float(amount) * multiplier)))
	return maxi(0, amount - reduced_amount)

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

func _get_guard_refraction_prevented_damage(amount: int, basis_amount: int = -1) -> int:
	if amount <= 1:
		return 0
	if StringName(run.get("passive_id", &"")) != GUARD_REFRACTION_PASSIVE_ID:
		return 0
	var max_prevented := amount - 1
	var calculation_amount := amount if basis_amount <= 0 else basis_amount
	var prevented := int(round(float(calculation_amount) * GUARD_REFRACTION_DAMAGE_REDUCTION))
	return clampi(prevented, 1, max_prevented)

func _reflect_guard_refraction_damage(prevented_damage: int) -> void:
	if prevented_damage <= 0:
		return
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if not player:
		return
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not (enemy is Node2D) or not enemy.has_method("apply_damage"):
			continue
		var distance := player.global_position.distance_to(enemy.global_position)
		if distance > GUARD_REFRACTION_RADIUS:
			continue
		var t := clampf(distance / GUARD_REFRACTION_RADIUS, 0.0, 1.0)
		var multiplier := GUARD_REFRACTION_NEAR_MULTIPLIER + (GUARD_REFRACTION_FAR_MULTIPLIER - GUARD_REFRACTION_NEAR_MULTIPLIER) * t
		var reflected_damage := maxi(1, int(round(float(prevented_damage) * multiplier)))
		var event := DamageEvent.from_amount(reflected_damage, self, DamageEvent.DAMAGE_TYPE_PURE, DamageEvent.DELIVERY_REFLECT)
		CombatEffectRules.add_tag_once(event, CombatEffectRules.GUARDIAN_REFRACTION_TAG)
		DamageCalculator.deal_damage(enemy, event)
		_spawn_resonance_effect(VFXHelper.EFFECT_GUARDIAN_REFRACTION, enemy.global_position)

func _reflect_survival_echo_damage(absorbed_damage: int) -> void:
	if absorbed_damage <= 0:
		return
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if not player:
		return
	var targets: Array[Node] = []
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not (enemy is Node2D) or not enemy.has_method("apply_damage"):
			continue
		if "_dead" in enemy and bool(enemy._dead):
			continue
		if player.global_position.distance_to((enemy as Node2D).global_position) > SURVIVAL_ECHO_RADIUS:
			continue
		targets.append(enemy)
	if targets.is_empty():
		return
	_spawn_resonance_effect(VFXHelper.EFFECT_SURVIVAL_ECHO, player.global_position, 0.0, 1.35)
	var damage_per_target := maxi(1, int(round(float(absorbed_damage) * SURVIVAL_ECHO_DAMAGE_RATIO / float(targets.size()))))
	for enemy in targets:
		var event := DamageEvent.from_amount(damage_per_target, self, DamageEvent.DAMAGE_TYPE_PURE, DamageEvent.DELIVERY_REFLECT)
		CombatEffectRules.add_tag_once(event, CombatEffectRules.SURVIVAL_ECHO_TAG)
		DamageCalculator.deal_damage(enemy, event)
		if enemy is Node2D:
			_spawn_resonance_effect(VFXHelper.EFFECT_SURVIVAL_ECHO, (enemy as Node2D).global_position, 0.0, 0.8)

func _spawn_resonance_effect(effect_id: StringName, pos: Vector2, rotation: float = 0.0, scale_multiplier: float = 1.0) -> void:
	VFXHelper.spawn_resonance_effect(get_tree().current_scene, effect_id, pos, rotation, scale_multiplier)
