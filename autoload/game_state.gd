extends Node
## 全局游戏状态。autoload 单例，跨场景持有当前一局的进度。

signal run_started
signal run_ended(victory: bool)
signal hp_changed(current: int, max_hp: int)
signal gold_changed(amount: int)
signal exp_changed(current: int, required: int)
signal level_up(new_level: int)

const STARTING_HP := 100
const STARTING_GOLD := 0
const STARTING_EXP_TO_LEVEL := 15
const MAX_WEAPON_SLOTS := 6
const MAX_ENHANCEMENT_SLOTS := 6
const STAT_UPGRADE_ICON := preload("res://assets/art/ui/icon_stat_upgrade.png")
const REGEN_ENHANCEMENT_ID := &"regen"
const REGEN_BASE_HEAL := 5
const REGEN_HEAL_PER_LEVEL := 2
const REGEN_INTERVAL := 5.0

var run := {
	"hp": STARTING_HP,
	"max_hp": STARTING_HP,
	"gold": STARTING_GOLD,
	"level": 1,
	"exp": 0,
	"exp_to_next_level": STARTING_EXP_TO_LEVEL,
	"run_time": 0.0,
	"kills": 0,
	"seed": 0,
	"pickup_radius_bonus": 0.0,
	"enhancements": {},
	"enhancement_order": [],
}

func start_new_run(rng_seed: int = 0) -> void:
	if rng_seed == 0:
		rng_seed = int(Time.get_unix_time_from_system())
	run = {
		"hp": STARTING_HP,
		"max_hp": STARTING_HP,
		"gold": STARTING_GOLD,
		"level": 1,
		"exp": 0,
		"exp_to_next_level": STARTING_EXP_TO_LEVEL,
		"run_time": 0.0,
		"kills": 0,
		"seed": rng_seed,
		"pickup_radius_bonus": 0.0,
		"enhancements": {},
		"enhancement_order": [],
	}
	run_started.emit()

func take_damage(amount: int) -> void:
	run.hp = max(0, run.hp - amount)
	hp_changed.emit(run.hp, run.max_hp)
	if run.hp <= 0:
		run_ended.emit(false)

func heal(amount: int) -> void:
	run.hp = min(run.max_hp, run.hp + amount)
	hp_changed.emit(run.hp, run.max_hp)

func add_gold(amount: int) -> void:
	run.gold += amount
	gold_changed.emit(run.gold)

func add_exp(amount: int) -> void:
	run.exp += amount
	while run.exp >= run.exp_to_next_level:
		run.exp -= run.exp_to_next_level
		run.level += 1
		run.exp_to_next_level = _calc_exp_required(run.level)
		level_up.emit(run.level)
	exp_changed.emit(run.exp, run.exp_to_next_level)

func add_kill() -> void:
	run.kills += 1

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

func _calc_exp_required(level: int) -> int:
	return int(STARTING_EXP_TO_LEVEL * pow(1.2, level - 1))
