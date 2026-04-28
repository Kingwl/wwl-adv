extends CanvasLayer

@onready var _panel: PanelContainer = $Panel
@onready var _basic_grid: GridContainer = $Panel/ScrollContainer/VBoxContainer/BasicSection/GridContainer
@onready var _weapons_list: VBoxContainer = $Panel/ScrollContainer/VBoxContainer/WeaponsSection/WeaponsList

func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	visible = false
	_setup_panel_style()
	_setup_button_style()

func _setup_panel_style() -> void:
	var style := StyleBoxTexture.new()
	style.texture = preload("res://assets/art/ui/panel_bg.png")
	style.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	style.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	_panel.add_theme_stylebox_override("panel", style)

func _setup_button_style() -> void:
	var btn: Button = $Panel/ScrollContainer/VBoxContainer/CloseButton
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

func toggle() -> void:
	visible = not visible
	if visible:
		get_tree().paused = true
		_refresh()
	else:
		get_tree().paused = false

func _refresh() -> void:
	_refresh_basic_stats()
	_refresh_weapons()

func _refresh_basic_stats() -> void:
	var player := get_tree().get_first_node_in_group("player")
	var move_speed: float = player.move_speed if player else 0.0
	var pickup_radius: float = 50.0 + GameState.run.get("pickup_radius_bonus", 0.0)

	var rows := [
		["生命值", "%d / %d" % [GameState.run.hp, GameState.run.max_hp]],
		["移速", "%.0f" % move_speed],
		["吸附范围", "%.0f" % pickup_radius],
		["等级", "Lv.%d" % GameState.run.level],
		["经验值", "%d / %d" % [GameState.run.exp, GameState.run.exp_to_next_level]],
		["金币", "%d" % GameState.run.gold],
		["击杀", "%d" % GameState.run.kills],
		["存活时间", GameState.get_time_string()],
	]

	for child in _basic_grid.get_children():
		child.queue_free()

	for row in rows:
		var name_label := Label.new()
		name_label.text = row[0]
		name_label.add_theme_font_size_override("font_size", 16)
		name_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75, 1))
		_basic_grid.add_child(name_label)

		var value_label := Label.new()
		value_label.text = row[1]
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		value_label.add_theme_font_size_override("font_size", 16)
		value_label.add_theme_color_override("font_color", Color(0.95, 0.95, 1, 1))
		_basic_grid.add_child(value_label)

func _refresh_weapons() -> void:
	for child in _weapons_list.get_children():
		child.queue_free()

	var weapons := _get_player_weapons()
	if weapons.is_empty():
		var empty := Label.new()
		empty.text = "暂无武器"
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.add_theme_font_size_override("font_size", 14)
		empty.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55, 1))
		_weapons_list.add_child(empty)
		return

	for w in weapons:
		var row := HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_theme_constant_override("separation", 8)

		var name_label := Label.new()
		var name_text: String = w.weapon_data.display_name if w.weapon_data else "?"
		name_label.text = "%s  Lv.%d" % [name_text, w.level]
		name_label.add_theme_font_size_override("font_size", 15)
		name_label.add_theme_color_override("font_color", Color(0.95, 0.95, 1, 1))
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_label)

		if w.weapon_data:
			var cat_label := Label.new()
			cat_label.text = _category_name(w.weapon_data.category)
			cat_label.add_theme_font_size_override("font_size", 12)
			cat_label.add_theme_color_override("font_color", _category_color(w.weapon_data.category))
			row.add_child(cat_label)

		var stats_label := Label.new()
		stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		stats_label.add_theme_font_size_override("font_size", 13)
		stats_label.add_theme_color_override("font_color", Color(0.75, 0.75, 0.8, 1))
		var dmg := w.get_damage() if w.has_method("get_damage") else w.weapon_data.damage if w.weapon_data else 0
		var cd := w.get_cooldown() if w.has_method("get_cooldown") else w.weapon_data.cooldown if w.weapon_data else 0.0
		var rng := w.get_range() if w.has_method("get_range") else w.weapon_data.range if w.weapon_data else 0.0
		stats_label.text = "伤害 %d  冷却 %.1f  范围 %.0f" % [dmg, cd, rng]
		row.add_child(stats_label)

		_weapons_list.add_child(row)

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

func _on_close_pressed() -> void:
	visible = false
