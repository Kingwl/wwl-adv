extends Node

const SCHEMA_VERSION := 1
const SAVE_PATH := "user://save_v1.json"
const BACKUP_PATH := "user://save_v1.bak"
const TMP_PATH := "user://save_v1.tmp"
const PROFILE_SAVE_INTERVAL := 5.0

var _save_path := SAVE_PATH
var _backup_path := BACKUP_PATH
var _tmp_path := TMP_PATH
var _save_data: Dictionary = {}
var _loaded := false
var _dirty := false
var _flush_timer := 0.0

func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	load_or_create()

func _process(delta: float) -> void:
	if not _dirty:
		return
	_flush_timer += delta
	if _flush_timer >= PROFILE_SAVE_INTERVAL:
		save_profile()

func load_or_create() -> void:
	var loaded := _read_save_file(_save_path)
	if loaded.is_empty():
		loaded = _read_save_file(_backup_path)
	if loaded.is_empty():
		_save_data = _default_save_data()
		_write_save_file()
	else:
		_save_data = _normalize_save_data(loaded)
		_loaded = true
		save_profile()
		return
	_loaded = true

func save_profile() -> bool:
	_ensure_loaded()
	var previous := _save_data.duplicate(true)
	if not _write_save_file():
		_save_data = previous
		return false
	_dirty = false
	_flush_timer = 0.0
	return true

func add_total_gold(amount: int) -> bool:
	if amount <= 0:
		return true
	_ensure_loaded()
	var profile: Dictionary = _save_data.get("profile", {})
	profile["total_gold"] = int(profile.get("total_gold", 0)) + amount
	_save_data["profile"] = profile
	_mark_dirty()
	return true

func add_lifetime_kills(amount: int = 1) -> bool:
	if amount <= 0:
		return true
	_ensure_loaded()
	var profile: Dictionary = _save_data.get("profile", {})
	profile["lifetime_kills"] = int(profile.get("lifetime_kills", 0)) + amount
	_save_data["profile"] = profile
	_mark_dirty()
	return true

func record_run_finished() -> bool:
	_ensure_loaded()
	var previous := _save_data.duplicate(true)
	var profile: Dictionary = _save_data.get("profile", {})
	var now := Time.get_unix_time_from_system()
	profile["total_runs"] = int(profile.get("total_runs", 0)) + 1
	profile["best_time"] = maxf(float(profile.get("best_time", 0.0)), float(GameState.run.get("run_time", 0.0)))
	profile["best_level"] = maxi(int(profile.get("best_level", 1)), int(GameState.run.get("level", 1)))
	profile["best_kills"] = maxi(int(profile.get("best_kills", 0)), int(GameState.run.get("kills", 0)))
	profile["last_run"] = {
		"ended_at": now,
		"time": float(GameState.run.get("run_time", 0.0)),
		"level": int(GameState.run.get("level", 1)),
		"kills": int(GameState.run.get("kills", 0)),
		"gold": int(GameState.run.get("gold", 0)),
	}
	_save_data["profile"] = profile
	if not _write_save_file():
		_save_data = previous
		return false
	_dirty = false
	_flush_timer = 0.0
	return true

func get_profile_value(key: String, default_value = null):
	_ensure_loaded()
	var profile: Dictionary = _save_data.get("profile", {})
	return profile.get(key, default_value)

func set_profile_value(key: String, value) -> bool:
	_ensure_loaded()
	var previous := _save_data.duplicate(true)
	var profile: Dictionary = _save_data.get("profile", {})
	profile[key] = value
	_save_data["profile"] = profile
	if not _write_save_file():
		_save_data = previous
		return false
	return true

func get_profile() -> Dictionary:
	_ensure_loaded()
	return (_save_data.get("profile", {}) as Dictionary).duplicate(true)

func configure_paths_for_tests(save_path: String) -> void:
	_save_path = save_path
	_backup_path = "%s.bak" % save_path
	_tmp_path = "%s.tmp" % save_path
	_loaded = false
	load_or_create()

func delete_save_files_for_tests() -> void:
	for path in [_save_path, _backup_path, _tmp_path]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)

func _ensure_loaded() -> void:
	if not _loaded:
		load_or_create()

func _mark_dirty() -> void:
	_dirty = true

func _default_save_data() -> Dictionary:
	var now := Time.get_unix_time_from_system()
	return {
		"schema_version": SCHEMA_VERSION,
		"app_version": str(ProjectSettings.get_setting("application/config/version", "0.1.0")),
		"created_at": now,
		"updated_at": now,
		"profile": {
			"created_at": now,
			"total_runs": 0,
			"total_gold": 0,
			"lifetime_kills": 0,
			"best_time": 0.0,
			"best_level": 1,
			"best_kills": 0,
			"unlocked_weapon_ids": ["melee_basic"],
			"settings": {
				"music_volume": 1.0,
				"sfx_volume": 1.0,
				"language": "zh_CN",
				"joystick_mode": "auto",
			},
		},
	}

func _normalize_save_data(raw_data: Dictionary) -> Dictionary:
	var normalized := _default_save_data()
	if int(raw_data.get("schema_version", 0)) == SCHEMA_VERSION:
		normalized.merge(raw_data, true)
	if typeof(normalized.get("profile")) != TYPE_DICTIONARY:
		normalized["profile"] = _default_save_data()["profile"]
	normalized.erase("resume_run")
	return normalized

func _read_save_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var text := FileAccess.get_file_as_string(path)
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed

func _write_save_file() -> bool:
	_save_data["schema_version"] = SCHEMA_VERSION
	_save_data["app_version"] = str(ProjectSettings.get_setting("application/config/version", "0.1.0"))
	_save_data["updated_at"] = Time.get_unix_time_from_system()
	var file := FileAccess.open(_tmp_path, FileAccess.WRITE)
	if not file:
		push_warning("SaveManager: cannot open temp save file %s" % _tmp_path)
		return false
	file.store_string(JSON.stringify(_save_data, "\t"))
	file.close()

	var had_current := FileAccess.file_exists(_save_path)
	if FileAccess.file_exists(_backup_path):
		DirAccess.remove_absolute(_backup_path)
	if had_current:
		var backup_err := DirAccess.rename_absolute(_save_path, _backup_path)
		if backup_err != OK:
			push_warning("SaveManager: cannot create backup save, error %d" % backup_err)
			return false
	var save_err := DirAccess.rename_absolute(_tmp_path, _save_path)
	if save_err != OK:
		if had_current:
			DirAccess.rename_absolute(_backup_path, _save_path)
		push_warning("SaveManager: cannot commit save file, error %d" % save_err)
		return false
	return true
