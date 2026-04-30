extends CanvasLayer

signal restart_pressed
signal quit_to_menu_pressed

@onready var _time_label: Label = $Panel/VBoxContainer/Stats/TimeRow/TimeValue
@onready var _title_label: Label = $Panel/VBoxContainer/Title
@onready var _kills_label: Label = $Panel/VBoxContainer/Stats/KillsRow/KillsValue
@onready var _level_label: Label = $Panel/VBoxContainer/Stats/LevelRow/LevelValue
@onready var _gold_label: Label = $Panel/VBoxContainer/Stats/GoldRow/GoldValue
@onready var _weapons_container: HBoxContainer = $Panel/VBoxContainer/WeaponsSection/WeaponsContainer
@onready var _enhancements_container: HBoxContainer = $Panel/VBoxContainer/EnhancementsSection/EnhancementsContainer

func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	visible = false
	_setup_panel_style()
	_setup_button_styles()

func _setup_panel_style() -> void:
	var panel: PanelContainer = $Panel
	var style := StyleBoxTexture.new()
	style.texture = preload("res://assets/art/ui/panel_bg.png")
	style.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	style.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	panel.add_theme_stylebox_override("panel", style)

func _setup_button_styles() -> void:
	_style_button($Panel/VBoxContainer/RestartButton)
	_style_button($Panel/VBoxContainer/QuitButton)

func _style_button(btn: Button) -> void:
	var normal := StyleBoxTexture.new()
	normal.texture = preload("res://assets/art/ui/button_normal.png")
	normal.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	normal.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	btn.add_theme_stylebox_override("normal", normal)

	var hover := StyleBoxTexture.new()
	hover.texture = preload("res://assets/art/ui/button_hover.png")
	hover.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	hover.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	btn.add_theme_stylebox_override("hover", hover)

	var pressed := StyleBoxTexture.new()
	pressed.texture = preload("res://assets/art/ui/button_pressed.png")
	pressed.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	pressed.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	btn.add_theme_stylebox_override("pressed", pressed)

func show_stats() -> void:
	visible = true
	_title_label.text = "胜利" if bool(GameState.run.get("victory", false)) else "游戏结束"
	_time_label.text = GameState.get_time_string()
	_kills_label.text = str(GameState.run.kills)
	_level_label.text = "Lv." + str(GameState.run.level)
	_gold_label.text = "%d（累计 %d）" % [GameState.run.gold, GameState.get_total_gold()]
	_populate_weapons()
	_populate_enhancements()

func _populate_weapons() -> void:
	for child in _weapons_container.get_children():
		child.queue_free()

	var weapons := _get_player_weapons()
	for i in range(GameState.MAX_WEAPON_SLOTS):
		var slot := VBoxContainer.new()
		slot.alignment = BoxContainer.ALIGNMENT_CENTER
		slot.custom_minimum_size = Vector2(64, 80)

		if i < weapons.size():
			var w := weapons[i]
			if w.weapon_data and w.weapon_data.icon:
				var icon := TextureRect.new()
				icon.texture = w.weapon_data.icon
				icon.custom_minimum_size = Vector2(32, 32)
				icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
				icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
				slot.add_child(icon)

			var label := Label.new()
			var name_text: String = w.weapon_data.display_name if w.weapon_data else "?"
			label.text = "%s\nLv.%d" % [name_text, w.level]
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			label.add_theme_font_size_override("font_size", 12)
			label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9, 1))
			slot.add_child(label)

			if w.weapon_data:
				var cat_label := Label.new()
				cat_label.text = _category_name(w.weapon_data.category)
				cat_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				cat_label.add_theme_font_size_override("font_size", 10)
				cat_label.add_theme_color_override("font_color", _category_color(w.weapon_data.category))
				slot.add_child(cat_label)
		else:
			var empty_label := Label.new()
			empty_label.text = "[空]"
			empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			empty_label.add_theme_font_size_override("font_size", 11)
			empty_label.add_theme_color_override("font_color", Color(0.35, 0.35, 0.4, 1))
			slot.add_child(empty_label)

		_weapons_container.add_child(slot)

func _populate_enhancements() -> void:
	for child in _enhancements_container.get_children():
		child.queue_free()

	var enhancements := GameState.get_enhancements()
	for i in range(GameState.MAX_ENHANCEMENT_SLOTS):
		var slot := VBoxContainer.new()
		slot.alignment = BoxContainer.ALIGNMENT_CENTER
		slot.custom_minimum_size = Vector2(54, 62)

		if i < enhancements.size():
			var enhancement: Dictionary = enhancements[i]
			var icon := TextureRect.new()
			icon.texture = enhancement.get("icon", GameState.STAT_UPGRADE_ICON)
			icon.custom_minimum_size = Vector2(28, 28)
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
			icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			slot.add_child(icon)

			var label := Label.new()
			label.text = "%s\nLv.%d" % [enhancement.get("display_name", "?"), int(enhancement.get("level", 1))]
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			label.add_theme_font_size_override("font_size", 10)
			label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9, 1))
			slot.add_child(label)
		else:
			var empty_label := Label.new()
			empty_label.text = "[空]"
			empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			empty_label.add_theme_font_size_override("font_size", 10)
			empty_label.add_theme_color_override("font_color", Color(0.35, 0.35, 0.4, 1))
			slot.add_child(empty_label)

		_enhancements_container.add_child(slot)

func _category_name(cat: WeaponData.Category) -> String:
	match cat:
		WeaponData.Category.DAMAGE:
			return "攻击"
		WeaponData.Category.DEFENSE:
			return "防御"
		WeaponData.Category.BUFF:
			return "增益"
	return ""

func _category_color(cat: WeaponData.Category) -> Color:
	match cat:
		WeaponData.Category.DAMAGE:
			return Color(0.95, 0.5, 0.4, 1)
		WeaponData.Category.DEFENSE:
			return Color(0.4, 0.65, 0.95, 1)
		WeaponData.Category.BUFF:
			return Color(0.5, 0.9, 0.5, 1)
	return Color(0.7, 0.7, 0.7, 1)

func _get_player_weapons() -> Array[WeaponBase]:
	var result: Array[WeaponBase] = []
	var player := get_tree().get_first_node_in_group("player")
	if not player:
		return result
	var weapons := player.get_node_or_null("Weapons")
	if not weapons:
		return result
	for w in weapons.get_children():
		if w is WeaponBase and w.weapon_data:
			result.append(w)
	return result

func _on_restart_pressed() -> void:
	restart_pressed.emit()

func _on_quit_pressed() -> void:
	quit_to_menu_pressed.emit()
