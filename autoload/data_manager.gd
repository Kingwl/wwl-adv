extends Node
## 数据管理器 autoload。负责扫描各类资源目录并提供查询接口。

const WEAPONS_DIR := "res://resources/weapons"
const ENEMIES_DIR := "res://resources/enemies"
const UPGRADES_DIR := "res://resources/upgrades"
const CHARACTERS_DIR := "res://resources/characters"
const DEFAULT_CHARACTER_ID := &"adventurer"
const CHARACTER_RESOURCES := [
	preload("res://resources/characters/adventurer.tres"),
	preload("res://resources/characters/alchemist.tres"),
	preload("res://resources/characters/guardian.tres"),
	preload("res://resources/characters/ranger.tres"),
]

var _weapons_by_id: Dictionary = {}
var _enemies_by_id: Dictionary = {}
var _upgrades_by_id: Dictionary = {}
var _characters_by_id: Dictionary = {}

func _ready() -> void:
	_load_all_characters()
	_load_all_weapons()
	_load_all_enemies()
	_load_all_upgrades()

func _load_resources(dir_path: String, target_dict: Dictionary, warn_if_missing: bool = true) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		if warn_if_missing:
			push_warning("DataManager: 资源目录尚未创建：%s" % dir_path)
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if not dir.current_is_dir():
			var path := _resource_path_from_dir_entry(dir_path, entry)
			if not path.is_empty():
				_register_resource(load(path), target_dict)
		entry = dir.get_next()
	dir.list_dir_end()

func _resource_path_from_dir_entry(dir_path: String, entry: String) -> String:
	if entry.ends_with(".remap"):
		entry = entry.trim_suffix(".remap")
	if not entry.ends_with(".tres"):
		return ""
	return "%s/%s" % [dir_path, entry]

func _register_resource(res: Resource, target_dict: Dictionary) -> void:
	if res and "id" in res:
		target_dict[res.id] = res

func _load_all_weapons() -> void:
	_load_resources(WEAPONS_DIR, _weapons_by_id)

func _load_all_enemies() -> void:
	_load_resources(ENEMIES_DIR, _enemies_by_id)

func _load_all_upgrades() -> void:
	_load_resources(UPGRADES_DIR, _upgrades_by_id, false)

func _load_all_characters() -> void:
	_load_resources(CHARACTERS_DIR, _characters_by_id)
	for character in CHARACTER_RESOURCES:
		_register_resource(character, _characters_by_id)

func get_weapon(id: String) -> Resource:
	return _weapons_by_id.get(id)

func all_weapons() -> Array:
	return _weapons_by_id.values()

func get_enemy(id: String) -> Resource:
	return _enemies_by_id.get(id)

func all_enemies() -> Array:
	return _enemies_by_id.values()

func get_upgrade(id: String) -> Resource:
	return _upgrades_by_id.get(id)

func all_upgrades() -> Array:
	return _upgrades_by_id.values()

func get_character(id: String) -> Resource:
	return _characters_by_id.get(id)

func get_default_character() -> Resource:
	var data := get_character(str(DEFAULT_CHARACTER_ID))
	if data:
		return data
	var values := all_characters()
	if values.is_empty():
		return null
	return values[0]

func all_characters() -> Array:
	var result := _characters_by_id.values()
	result.sort_custom(func(a, b): return str(a.id) < str(b.id))
	return result

func get_random_upgrades(count: int, filter: Callable = Callable()) -> Array:
	var pool := all_upgrades()
	if filter.is_valid():
		pool = pool.filter(filter)
	pool.shuffle()
	return pool.slice(0, count)
