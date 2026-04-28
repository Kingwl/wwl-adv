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

func _calc_exp_required(level: int) -> int:
	return int(STARTING_EXP_TO_LEVEL * pow(1.2, level - 1))
