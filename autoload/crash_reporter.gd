extends Node
## Thin runtime wrapper around the optional Sentry Godot addon.
##
## The project can run without addons/sentry installed. When the addon is
## present and a DSN is configured, this autoload initializes Sentry and adds
## stable game/build tags.

const SENTRY_SINGLETON := "SentrySDK"
const LEVEL_INFO := 1
const LEVEL_WARNING := 2
const LEVEL_ERROR := 3

var _initialized := false
var _enabled := false
var _last_scene_path := ""
var _scene_tag_timer := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_initialize")


func _process(delta: float) -> void:
	if not _enabled:
		return
	_scene_tag_timer -= delta
	if _scene_tag_timer <= 0.0:
		_scene_tag_timer = 1.0
		_update_scene_tag()


func is_available() -> bool:
	return Engine.has_singleton(SENTRY_SINGLETON)


func is_enabled() -> bool:
	return _enabled


func capture_message(message: String, level: int = LEVEL_INFO) -> void:
	if not _enabled:
		return
	_sentry_call("capture_message", [message, level])


func capture_warning(message: String) -> void:
	capture_message(message, LEVEL_WARNING)


func capture_error(message: String) -> void:
	capture_message(message, LEVEL_ERROR)


func add_breadcrumb(message: String, category: String = "game", data: Dictionary = {}) -> void:
	if not _enabled:
		return
	var breadcrumb = ClassDB.class_call_static("SentryBreadcrumb", "create", str(message))
	if breadcrumb == null:
		return
	breadcrumb.category = category
	breadcrumb.call("set_data", data)
	_sentry_call("add_breadcrumb", [breadcrumb])


func set_tag(key: String, value: String) -> void:
	if not _enabled:
		return
	_sentry_call("set_tag", [key, value])


func set_context(key: String, value: Dictionary) -> void:
	if not _enabled:
		return
	_sentry_call("set_context", [key, value])


func _initialize() -> void:
	if _initialized:
		return
	_initialized = true

	if _get_configured_dsn().is_empty():
		return
	if not is_available():
		push_warning("CrashReporter: Sentry DSN is configured but addons/sentry is not installed.")
		return

	var sdk := Engine.get_singleton(SENTRY_SINGLETON)
	if sdk == null:
		return
	if bool(sdk.call("is_enabled")):
		_enabled = true
	else:
		sdk.call("init", Callable(self, "_configure_sentry_options"))
		_enabled = bool(sdk.call("is_enabled"))

	if _enabled:
		_apply_runtime_tags()
		_update_scene_tag()


func _configure_sentry_options(options: Object) -> void:
	options.dsn = _get_configured_dsn()
	options.release = _get_release()
	options.environment = _get_environment_name()
	options.send_default_pii = false
	options.attach_log = not OS.has_feature("web")
	options.attach_scene_tree = false
	options.attach_screenshot = false
	options.enable_logs = true
	options.logger_enabled = true
	options.logger_include_source = false
	options.logger_include_variables = false
	options.logger_messages_as_breadcrumbs = true
	options.before_send = Callable(self, "_before_send")


func _before_send(event: Object) -> Object:
	var current_scene := _get_current_scene_path()
	if not current_scene.is_empty() and event:
		event.call("set_tag", "scene", current_scene)
	return event


func _apply_runtime_tags() -> void:
	set_tag("game", ProjectSettings.get_setting("application/config/name", "WWL Adventure"))
	set_tag("game_version", ProjectSettings.get_setting("application/config/version", "0.0.0"))
	set_tag("platform", OS.get_name())
	set_tag("build_target", _get_build_target())
	set_tag("renderer", ProjectSettings.get_setting("rendering/renderer/rendering_method", "unknown"))
	set_context("runtime", {
		"godot_version": Engine.get_version_info().get("string", "unknown"),
		"debug_build": OS.has_feature("debug"),
	})


func _update_scene_tag() -> void:
	var scene_path := _get_current_scene_path()
	if scene_path.is_empty() or scene_path == _last_scene_path:
		return
	_last_scene_path = scene_path
	set_tag("scene", scene_path)


func _get_current_scene_path() -> String:
	var scene := get_tree().current_scene
	if scene == null:
		return ""
	return scene.scene_file_path


func _get_configured_dsn() -> String:
	var from_project := str(ProjectSettings.get_setting("sentry/options/dsn", "")).strip_edges()
	if not from_project.is_empty():
		return from_project
	return OS.get_environment("SENTRY_DSN").strip_edges()


func _get_release() -> String:
	var from_project := str(ProjectSettings.get_setting("sentry/options/release", "")).strip_edges()
	if not from_project.is_empty():
		return from_project
	var from_env := OS.get_environment("SENTRY_RELEASE").strip_edges()
	if not from_env.is_empty():
		return from_env
	var app_name := str(ProjectSettings.get_setting("application/config/name", "wwl-adventure")).to_snake_case()
	var app_version := str(ProjectSettings.get_setting("application/config/version", "0.0.0"))
	return "%s@%s" % [app_name, app_version]


func _get_environment_name() -> String:
	var from_project := str(ProjectSettings.get_setting("sentry/options/environment", "")).strip_edges()
	if not from_project.is_empty():
		return from_project
	var from_env := OS.get_environment("SENTRY_ENVIRONMENT").strip_edges()
	if not from_env.is_empty():
		return from_env
	if OS.has_feature("debug") or OS.has_feature("editor"):
		return "development"
	return "production"


func _get_build_target() -> String:
	if OS.has_feature("web"):
		return "web"
	if OS.has_feature("android"):
		return "android"
	if OS.has_feature("ios"):
		return "ios"
	if OS.has_feature("macos"):
		return "macos"
	if OS.has_feature("windows"):
		return "windows"
	if OS.has_feature("linux"):
		return "linux"
	return OS.get_name().to_lower()


func _sentry_call(method: StringName, args: Array = []) -> Variant:
	var sdk := Engine.get_singleton(SENTRY_SINGLETON) if Engine.has_singleton(SENTRY_SINGLETON) else null
	if sdk == null:
		return null
	return sdk.callv(method, args)
