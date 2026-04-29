extends Node
class_name WeaponBase

@export var weapon_data: WeaponData

var level: int = 1
var current_path_id: StringName = &""

# 运行时属性（应用升级后）
var _current_damage: int = 0
var _current_cooldown: float = 1.0
var _current_range: float = 50.0
var _cooldown_timer: float = 0.0

func _ready() -> void:
	_recalc_stats()
	_cooldown_timer = _current_cooldown

func _process(delta: float) -> void:
	_cooldown_timer -= delta
	if _cooldown_timer <= 0:
		_activate()
		_cooldown_timer = _current_cooldown

func _activate() -> void:
	push_warning("WeaponBase._activate() should be overridden")

func _recalc_stats() -> void:
	if not weapon_data:
		return
	_current_damage = int(round(weapon_data.damage * (1.0 + (level - 1) * 0.10) * GameState.get_character_damage_multiplier()))
	_current_cooldown = max(0.1, weapon_data.cooldown * pow(0.92, level - 1) * GameState.get_character_cooldown_multiplier(weapon_data))
	_current_range = (weapon_data.range + (level - 1) * 10.0) * GameState.get_character_area_multiplier()

func set_path(path_id: StringName) -> void:
	if not current_path_id.is_empty():
		push_warning("Weapon %s already has path %s, cannot switch to %s" % [weapon_data.id if weapon_data else "?", current_path_id, path_id])
		return
	current_path_id = path_id

func level_up() -> void:
	if weapon_data and level >= weapon_data.max_level:
		return
	level += 1
	_recalc_stats()
	_apply_path_effects()
	_on_level_up()
	GameState.notify_weapons_changed()

func _apply_path_effects() -> void:
	if not weapon_data or current_path_id.is_empty():
		return
	for path in weapon_data.paths:
		if path.path_id == current_path_id:
			var effect := path.get_level_effect(level)
			if effect:
				if effect.damage_bonus != 0:
					_current_damage += effect.damage_bonus
				if effect.cooldown_bonus != 0:
					_current_cooldown = max(0.1, _current_cooldown + effect.cooldown_bonus)
				if effect.range_bonus != 0:
					_current_range += effect.range_bonus
			break

func _on_level_up() -> void:
	pass

func has_special_tag(tag: StringName) -> bool:
	if not weapon_data or current_path_id.is_empty():
		return false
	for path in weapon_data.paths:
		if path.path_id == current_path_id:
			var effect := path.get_level_effect(level)
			if effect and effect.special_tag == tag:
				return true
	return false

func get_path_effect(level_target: int = level) -> WeaponPathLevel:
	if not weapon_data or current_path_id.is_empty():
		return null
	for path in weapon_data.paths:
		if path.path_id == current_path_id:
			return path.get_level_effect(level_target)
	return null

func get_damage() -> int:
	return _current_damage

func get_cooldown() -> float:
	return _current_cooldown

func get_range() -> float:
	return _current_range

func get_cooldown_progress() -> float:
	if _current_cooldown <= 0.001:
		return 0.0
	return clampf(_cooldown_timer / _current_cooldown, 0.0, 1.0)
