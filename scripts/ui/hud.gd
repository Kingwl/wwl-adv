extends CanvasLayer

signal pause_requested

@onready var _time_label: Label = $TopBar/TimeLabel
@onready var _kill_label: Label = $TopBar/KillLabel
@onready var _gold_label: Label = $TopBar/GoldLabel
@onready var _hp_bar: ProgressBar = $HPPanel/HPBar
@onready var _hp_label: Label = $HPPanel/HPBar/HPLabel
@onready var _exp_bar: ProgressBar = $EXPPanel/ExpBar
@onready var _level_label: Label = $EXPPanel/LevelLabel
@onready var _weapon_bar: HBoxContainer = $WeaponBar
@onready var _enhancement_bar: HBoxContainer = $EnhancementBar
@onready var _speed_button: Button = $TopBar/SpeedButton
@onready var _stats_button: Button = $TopBar/StatsButton
@onready var _menu_button: Button = $TopBar/MenuButton

var _slot_style_normal: StyleBoxFlat
var _slot_style_max: StyleBoxFlat
const COOLDOWN_VISIBLE_THRESHOLD := 0.01
const LOCAL_DEBUG_KEY_SEQUENCE: Array[int] = [KEY_I, KEY_D, KEY_D, KEY_Q, KEY_D]
const LOCAL_DEBUG_TAP_REQUIRED := 7
const LOCAL_DEBUG_TAP_WINDOW_MSEC := 2000
const LOCAL_DEBUG_TOAST_DURATION_MSEC := 1600

var _local_debug_key_index := 0
var _local_debug_tap_count := 0
var _local_debug_first_tap_msec := 0
var _local_debug_toast: Label
var _local_debug_toast_until_msec := 0

func _ready() -> void:
	_setup_bar_styles()
	_add_gold_icon()
	_add_heart_icon()
	_setup_local_debug_toast()
	_init_weapon_slots()
	_init_enhancement_slots()
	_speed_button.pressed.connect(_on_speed_pressed)
	_stats_button.pressed.connect(_on_stats_pressed)
	_menu_button.pressed.connect(_on_menu_pressed)
	GameState.hp_changed.connect(_on_hp_changed)
	GameState.exp_changed.connect(_on_exp_changed)
	GameState.gold_changed.connect(_on_gold_changed)
	GameState.game_speed_changed.connect(_on_game_speed_changed)
	GameState.weapons_changed.connect(_on_weapons_changed)
	GameState.run_started.connect(_on_run_started)
	GameState.local_debug_mode_changed.connect(_on_local_debug_mode_changed)
	_on_run_started()
	_on_game_speed_changed(GameState.game_speed_multiplier)

func _process(_delta: float) -> void:
	_time_label.text = GameState.get_time_string()
	_kill_label.text = "击杀: %d" % GameState.run.kills
	_update_weapon_bar()
	_update_enhancement_bar()
	_update_local_debug_toast()

func _input(event: InputEvent) -> void:
	if not GameState.is_local_debug_available():
		return
	_handle_local_debug_key(event)
	_handle_local_debug_tap(event)

func _init_weapon_slots() -> void:
	_slot_style_normal = StyleBoxFlat.new()
	_slot_style_normal.bg_color = Color(0.06, 0.07, 0.1, 0.9)
	_slot_style_normal.border_color = Color(0.25, 0.3, 0.45, 1.0)
	_slot_style_normal.border_width_left = 2
	_slot_style_normal.border_width_top = 2
	_slot_style_normal.border_width_right = 2
	_slot_style_normal.border_width_bottom = 2

	_slot_style_max = StyleBoxFlat.new()
	_slot_style_max.bg_color = Color(0.1, 0.08, 0.02, 0.95)
	_slot_style_max.border_color = Color(0.95, 0.78, 0.25, 1.0)
	_slot_style_max.border_width_left = 2
	_slot_style_max.border_width_top = 2
	_slot_style_max.border_width_right = 2
	_slot_style_max.border_width_bottom = 2

	for i in range(GameState.MAX_WEAPON_SLOTS):
		_weapon_bar.add_child(_create_slot("Slot%d" % i, Vector2(56, 56), Vector2(28, 28), true))

func _init_enhancement_slots() -> void:
	for i in range(GameState.MAX_ENHANCEMENT_SLOTS):
		_enhancement_bar.add_child(_create_slot("EnhancementSlot%d" % i, Vector2(46, 46), Vector2(24, 24), false))

func _create_slot(slot_name: String, slot_size: Vector2, icon_size: Vector2, with_cooldown: bool) -> PanelContainer:
	var slot := PanelContainer.new()
	slot.custom_minimum_size = slot_size
	slot.name = slot_name
	slot.add_theme_stylebox_override("panel", _slot_style_normal)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER

	var icon_container := Control.new()
	icon_container.name = "IconContainer"
	icon_container.custom_minimum_size = icon_size
	icon_container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	var icon_rect := TextureRect.new()
	icon_rect.name = "IconRect"
	icon_rect.anchor_right = 1.0
	icon_rect.anchor_bottom = 1.0
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL

	icon_container.add_child(icon_rect)

	if with_cooldown:
		var cooldown_overlay := Control.new()
		cooldown_overlay.name = "CooldownOverlay"
		cooldown_overlay.anchor_right = 1.0
		cooldown_overlay.anchor_bottom = 1.0
		cooldown_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cooldown_overlay.visible = false

		var cooldown_fill := ColorRect.new()
		cooldown_fill.name = "CooldownFill"
		cooldown_fill.anchor_right = 1.0
		cooldown_fill.anchor_bottom = 1.0
		cooldown_fill.color = Color(0.0, 0.0, 0.0, 0.62)
		cooldown_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cooldown_overlay.add_child(cooldown_fill)
		icon_container.add_child(cooldown_overlay)

	var level_label := Label.new()
	level_label.name = "LevelLabel"
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_label.add_theme_font_size_override("font_size", 10)
	level_label.text = ""

	vbox.add_child(icon_container)
	vbox.add_child(level_label)
	slot.add_child(vbox)
	return slot

func _update_weapon_bar() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if not player:
		return
	var weapons := player.get_node_or_null("Weapons")
	if not weapons:
		return

	var slots := _weapon_bar.get_children()
	var weapon_idx := 0
	for w in weapons.get_children():
		if w is WeaponBase and w.weapon_data:
			if weapon_idx < slots.size():
				var slot: PanelContainer = slots[weapon_idx]
				var vbox := slot.get_child(0)
				var icon_container: Control = vbox.get_node("IconContainer")
				var icon_rect: TextureRect = icon_container.get_node("IconRect")
				var cooldown_overlay: Control = icon_container.get_node("CooldownOverlay")
				var level_label: Label = vbox.get_node("LevelLabel")
				slot.set_meta("weapon_id", w.weapon_data.id)
				slot.tooltip_text = w.weapon_data.display_name
				icon_rect.texture = w.weapon_data.icon
				_set_cooldown_overlay(cooldown_overlay, w.get_cooldown_progress())
				level_label.text = "Lv.%d" % w.level
				if w.level >= w.weapon_data.max_level:
					slot.add_theme_stylebox_override("panel", _slot_style_max)
				else:
					slot.add_theme_stylebox_override("panel", _slot_style_normal)
				weapon_idx += 1

	for i in range(weapon_idx, slots.size()):
		var slot: PanelContainer = slots[i]
		var vbox := slot.get_child(0)
		var icon_container: Control = vbox.get_node("IconContainer")
		var icon_rect: TextureRect = icon_container.get_node("IconRect")
		var cooldown_overlay: Control = icon_container.get_node("CooldownOverlay")
		var level_label: Label = vbox.get_node("LevelLabel")
		if slot.has_meta("weapon_id"):
			slot.remove_meta("weapon_id")
		slot.tooltip_text = ""
		icon_rect.texture = null
		_set_cooldown_overlay(cooldown_overlay, 0.0)
		level_label.text = ""
		slot.add_theme_stylebox_override("panel", _slot_style_normal)

func _set_cooldown_overlay(cooldown_overlay: Control, progress: float) -> void:
	var amount := clampf(progress, 0.0, 1.0)
	cooldown_overlay.visible = amount > COOLDOWN_VISIBLE_THRESHOLD
	var cooldown_fill: ColorRect = cooldown_overlay.get_node("CooldownFill")
	cooldown_fill.anchor_top = 1.0 - amount
	cooldown_fill.offset_left = 0.0
	cooldown_fill.offset_top = 0.0
	cooldown_fill.offset_right = 0.0
	cooldown_fill.offset_bottom = 0.0

func _update_enhancement_bar() -> void:
	var slots := _enhancement_bar.get_children()
	var enhancements := GameState.get_enhancements()
	for i in range(slots.size()):
		var slot: PanelContainer = slots[i]
		var vbox := slot.get_child(0)
		var icon_container: Control = vbox.get_node("IconContainer")
		var icon_rect: TextureRect = icon_container.get_node("IconRect")
		var level_label: Label = vbox.get_node("LevelLabel")
		if i < enhancements.size():
			var enhancement: Dictionary = enhancements[i]
			icon_rect.texture = enhancement.get("icon", GameState.STAT_UPGRADE_ICON)
			level_label.text = "Lv.%d" % int(enhancement.get("level", 1))
			slot.add_theme_stylebox_override("panel", _slot_style_normal)
		else:
			icon_rect.texture = null
			level_label.text = ""
			slot.add_theme_stylebox_override("panel", _slot_style_normal)

func _setup_bar_styles() -> void:
	var hp_fill := StyleBoxTexture.new()
	hp_fill.texture = preload("res://assets/art/ui/hp_bar_fill.png")
	hp_fill.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	hp_fill.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	_hp_bar.add_theme_stylebox_override("fill", hp_fill)

	var exp_fill := StyleBoxTexture.new()
	exp_fill.texture = preload("res://assets/art/ui/exp_bar_fill.png")
	exp_fill.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	exp_fill.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	_exp_bar.add_theme_stylebox_override("fill", exp_fill)

func _add_gold_icon() -> void:
	var icon := TextureRect.new()
	icon.texture = preload("res://assets/art/ui/icon_gold.png")
	icon.custom_minimum_size = Vector2(20, 20)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_gold_label.get_parent().add_child(icon)
	_gold_label.get_parent().move_child(icon, _gold_label.get_index())

func _add_heart_icon() -> void:
	var icon := TextureRect.new()
	icon.texture = preload("res://assets/art/ui/icon_heart.png")
	icon.custom_minimum_size = Vector2(24, 24)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon.position = Vector2(-28, 2)
	_hp_bar.add_sibling(icon)

func _setup_local_debug_toast() -> void:
	_local_debug_toast = Label.new()
	_local_debug_toast.name = "LocalDebugToast"
	_local_debug_toast.visible = false
	_local_debug_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_local_debug_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_local_debug_toast.add_theme_font_size_override("font_size", 16)
	_local_debug_toast.add_theme_color_override("font_color", Color(0.55, 0.92, 1.0, 0.95))
	_local_debug_toast.anchor_left = 0.5
	_local_debug_toast.anchor_right = 0.5
	_local_debug_toast.anchor_top = 0.0
	_local_debug_toast.anchor_bottom = 0.0
	_local_debug_toast.offset_left = -160.0
	_local_debug_toast.offset_right = 160.0
	_local_debug_toast.offset_top = 64.0
	_local_debug_toast.offset_bottom = 88.0
	add_child(_local_debug_toast)

func _handle_local_debug_key(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	var keycode := key_event.keycode
	if keycode == 0:
		keycode = key_event.physical_keycode
	if keycode == LOCAL_DEBUG_KEY_SEQUENCE[_local_debug_key_index]:
		_local_debug_key_index += 1
		if _local_debug_key_index >= LOCAL_DEBUG_KEY_SEQUENCE.size():
			_local_debug_key_index = 0
			_toggle_local_debug_mode()
		return
	_local_debug_key_index = 1 if keycode == LOCAL_DEBUG_KEY_SEQUENCE[0] else 0

func _handle_local_debug_tap(event: InputEvent) -> void:
	var position := Vector2.INF
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if not touch.pressed:
			return
		position = touch.position
	elif event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if not mouse_button.pressed or mouse_button.button_index != MOUSE_BUTTON_LEFT:
			return
		position = mouse_button.position
	else:
		return
	if not _is_local_debug_tap_position(position):
		return
	var now := Time.get_ticks_msec()
	if _local_debug_first_tap_msec == 0 or now - _local_debug_first_tap_msec > LOCAL_DEBUG_TAP_WINDOW_MSEC:
		_local_debug_first_tap_msec = now
		_local_debug_tap_count = 0
	_local_debug_tap_count += 1
	if _local_debug_tap_count >= LOCAL_DEBUG_TAP_REQUIRED:
		_local_debug_tap_count = 0
		_local_debug_first_tap_msec = 0
		_toggle_local_debug_mode()

func _is_local_debug_tap_position(position: Vector2) -> bool:
	return _hp_bar.get_global_rect().grow(12.0).has_point(position)

func _toggle_local_debug_mode() -> void:
	if not GameState.is_local_debug_available():
		return
	GameState.toggle_local_debug_mode()

func _on_local_debug_mode_changed(enabled: bool) -> void:
	_show_local_debug_toast("本地调试护身：%s" % ("开" if enabled else "关"))

func _show_local_debug_toast(message: String) -> void:
	if not _local_debug_toast:
		return
	_local_debug_toast.text = message
	_local_debug_toast.visible = true
	_local_debug_toast_until_msec = Time.get_ticks_msec() + LOCAL_DEBUG_TOAST_DURATION_MSEC

func _update_local_debug_toast() -> void:
	if not _local_debug_toast or not _local_debug_toast.visible:
		return
	if Time.get_ticks_msec() >= _local_debug_toast_until_msec:
		_local_debug_toast.visible = false

func _on_run_started() -> void:
	_on_hp_changed(GameState.run.hp, GameState.run.max_hp)
	_on_exp_changed(GameState.run.exp, GameState.run.exp_to_next_level)
	_on_gold_changed(GameState.run.gold)
	_update_weapon_bar()

func _on_weapons_changed() -> void:
	_update_weapon_bar()

func _on_hp_changed(current: int, max_hp: int) -> void:
	_hp_bar.max_value = max_hp
	_hp_bar.value = current
	_hp_label.text = "%d / %d" % [current, max_hp]

func _on_exp_changed(current: int, required: int) -> void:
	_exp_bar.max_value = required
	_exp_bar.value = current
	_level_label.text = "Lv.%d" % GameState.run.level

func _on_gold_changed(amount: int) -> void:
	_gold_label.text = "金币: %d" % amount

func _on_game_speed_changed(multiplier: float) -> void:
	_speed_button.text = "%dx" % int(round(multiplier))

func _on_speed_pressed() -> void:
	GameState.toggle_game_speed()

func _on_stats_pressed() -> void:
	var stats_panel := get_tree().current_scene.get_node_or_null("StatsPanel")
	if stats_panel:
		stats_panel.toggle()

func _on_menu_pressed() -> void:
	pause_requested.emit()
