extends Control

@onready var _continue_button: Button = $CenterContainer/VBoxContainer/ContinueButton

var _character_buttons: Dictionary = {}
var _character_info_label: Label
var _gold_summary_label: Label

func _ready() -> void:
	GameState.reset_game_speed()
	get_tree().paused = false
	_setup_background()
	_style_button($CenterContainer/VBoxContainer/StartButton)
	_style_button(_continue_button)
	_style_button($CenterContainer/VBoxContainer/QuitButton)
	_continue_button.visible = false
	_setup_profile_summary()
	_setup_character_select()

func _setup_background() -> void:
	var bg: ColorRect = $Background
	bg.color = Color.TRANSPARENT
	var tex_rect := TextureRect.new()
	tex_rect.name = "GroundTileBackground"
	tex_rect.anchor_left = 0.0
	tex_rect.anchor_top = 0.0
	tex_rect.anchor_right = 1.0
	tex_rect.anchor_bottom = 1.0
	tex_rect.offset_left = 0.0
	tex_rect.offset_top = 0.0
	tex_rect.offset_right = 0.0
	tex_rect.offset_bottom = 0.0
	tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tex_rect.texture = preload("res://assets/art/ui/ground_tile.png")
	tex_rect.stretch_mode = TextureRect.STRETCH_TILE
	bg.add_child(tex_rect)

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

func _setup_profile_summary() -> void:
	var vbox: VBoxContainer = $CenterContainer/VBoxContainer
	var spacer := vbox.get_node_or_null("Spacer")
	var insert_index := spacer.get_index() if spacer else 2

	var row := HBoxContainer.new()
	row.name = "GoldSummary"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	var icon := TextureRect.new()
	icon.name = "GoldIcon"
	icon.custom_minimum_size = Vector2(24, 24)
	icon.texture = preload("res://assets/art/ui/icon_gold.png")
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	row.add_child(icon)

	_gold_summary_label = Label.new()
	_gold_summary_label.name = "GoldSummaryLabel"
	_gold_summary_label.text = "全局金币: %d" % GameState.get_total_gold()
	_gold_summary_label.add_theme_font_size_override("font_size", 18)
	_gold_summary_label.add_theme_color_override("font_color", Color(0.95, 0.82, 0.28, 1))
	row.add_child(_gold_summary_label)

	vbox.add_child(row)
	vbox.move_child(row, insert_index)

func _setup_character_select() -> void:
	var characters := DataManager.all_characters()
	if characters.is_empty():
		return

	var vbox: VBoxContainer = $CenterContainer/VBoxContainer
	var spacer := vbox.get_node_or_null("Spacer")
	var insert_index := spacer.get_index() if spacer else 2

	var panel := PanelContainer.new()
	panel.name = "CharacterPanel"
	panel.custom_minimum_size = Vector2(560, 0)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var panel_style := StyleBoxTexture.new()
	panel_style.texture = preload("res://assets/art/ui/panel_bg.png")
	panel_style.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	panel_style.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	panel.add_theme_stylebox_override("panel", panel_style)

	var content := VBoxContainer.new()
	content.name = "CharacterContent"
	content.add_theme_constant_override("separation", 8)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(content)

	var title := Label.new()
	title.text = "选择角色"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	content.add_child(title)

	var grid := GridContainer.new()
	grid.name = "CharacterCards"
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 8)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	content.add_child(grid)

	for character in characters:
		var character_id: StringName = character.id
		var button := Button.new()
		button.name = "Character_%s" % character_id
		button.custom_minimum_size = Vector2(250, 68)
		button.toggle_mode = true
		button.icon = character.icon
		button.expand_icon = true
		button.text = "%s\nHP %d  速 %.0f" % [character.display_name, character.max_hp, character.move_speed]
		button.pressed.connect(func(): _select_character(character_id))
		_style_button(button)
		grid.add_child(button)
		_character_buttons[str(character_id)] = button

	_character_info_label = Label.new()
	_character_info_label.name = "CharacterInfo"
	_character_info_label.custom_minimum_size = Vector2(520, 44)
	_character_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_character_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_character_info_label.add_theme_font_size_override("font_size", 14)
	_character_info_label.add_theme_color_override("font_color", Color(0.78, 0.78, 0.9, 1))
	content.add_child(_character_info_label)

	vbox.add_child(panel)
	vbox.move_child(panel, insert_index)
	_refresh_character_select()

func _select_character(character_id: StringName) -> void:
	SaveManager.set_selected_character_id(character_id)
	_refresh_character_select()

func _refresh_character_select() -> void:
	var selected_id := str(SaveManager.get_selected_character_id())
	for key in _character_buttons.keys():
		var button: Button = _character_buttons[key]
		button.button_pressed = key == selected_id

	var character := DataManager.get_character(selected_id)
	if not character:
		character = DataManager.get_default_character()
	if character and _character_info_label:
		_character_info_label.text = "%s  ·  初始武器：%s\n%s" % [
			character.passive_description,
			_get_starting_weapon_names(character),
			character.description,
		]

func _get_starting_weapon_names(character: Resource) -> String:
	var names: Array[String] = []
	for weapon_id in character.starting_weapon_ids:
		var weapon := DataManager.get_weapon(str(weapon_id))
		if weapon is WeaponData:
			names.append(weapon.display_name)
		else:
			names.append(str(weapon_id))
	return "、".join(names)

func _on_start_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/game/game.tscn")

func _on_quit_pressed() -> void:
	get_tree().quit()
