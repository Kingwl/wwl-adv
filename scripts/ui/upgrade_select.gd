extends CanvasLayer

signal option_selected(upgrade: UpgradeData)
signal reroll_requested
signal skip_requested

@onready var _panel: PanelContainer = $PanelContainer
@onready var _options_container: HBoxContainer = $PanelContainer/VBoxContainer/OptionsContainer
@onready var _reroll_button: Button = $PanelContainer/VBoxContainer/ActionsContainer/RerollButton
@onready var _skip_button: Button = $PanelContainer/VBoxContainer/ActionsContainer/SkipButton

var _card_style_base: StyleBoxFlat

func _ready() -> void:
	add_to_group("upgrade_select")
	visible = false
	_card_style_base = StyleBoxFlat.new()
	_card_style_base.bg_color = Color(0.06, 0.07, 0.1, 0.95)
	_card_style_base.corner_radius_top_left = 6
	_card_style_base.corner_radius_top_right = 6
	_card_style_base.corner_radius_bottom_left = 6
	_card_style_base.corner_radius_bottom_right = 6
	_setup_panel_style()
	_setup_button_styles()

func _setup_panel_style() -> void:
	var style := StyleBoxTexture.new()
	style.texture = preload("res://assets/art/ui/panel_bg.png")
	style.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	style.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	_panel.add_theme_stylebox_override("panel", style)

func _setup_button_styles() -> void:
	_style_button(_reroll_button)
	_style_button(_skip_button)

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

func show_options(options: Array) -> void:
	visible = true
	for child in _options_container.get_children():
		child.queue_free()

	for option in options:
		var card := _create_option_card(option)
		_options_container.add_child(card)

func _create_option_card(option: UpgradeData) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(220, 200)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_on_option_pressed(option)
	)

	var border_color := _get_type_color(option.upgrade_type)
	var style := _card_style_base.duplicate()
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.border_color = border_color
	card.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_BEGIN
	vbox.add_theme_constant_override("separation", 6)
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL

	# Icon
	var icon_tex := _get_option_icon(option)
	if icon_tex:
		var icon_rect := TextureRect.new()
		icon_rect.texture = icon_tex
		icon_rect.custom_minimum_size = Vector2(48, 48)
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		icon_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		vbox.add_child(icon_rect)

	# Type tag
	var tag_label := Label.new()
	tag_label.text = _get_type_name(option.upgrade_type)
	tag_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag_label.add_theme_font_size_override("font_size", 12)
	tag_label.add_theme_color_override("font_color", border_color)

	# Category tag (only for weapon upgrades)
	if option.weapon_id:
		var cat_name := _get_weapon_category_name(option.weapon_id)
		if not cat_name.is_empty():
			var cat_label := Label.new()
			cat_label.text = cat_name
			cat_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			cat_label.add_theme_font_size_override("font_size", 11)
			cat_label.add_theme_color_override("font_color", _get_weapon_category_color(option.weapon_id))
			vbox.add_child(cat_label)

	# Name
	var name_label := Label.new()
	name_label.text = option.display_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 22)
	name_label.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95, 1))

	# Description
	var desc_label := Label.new()
	desc_label.text = option.description
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.add_theme_font_size_override("font_size", 13)
	desc_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75, 1))
	desc_label.size_flags_vertical = Control.SIZE_EXPAND_FILL

	# Effect detail
	var detail := _format_detail(option)
	var detail_label := Label.new()
	if not detail.is_empty():
		detail_label.text = detail
		detail_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		detail_label.add_theme_font_size_override("font_size", 12)
		detail_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85, 1))

	vbox.add_child(tag_label)
	vbox.add_child(name_label)
	vbox.add_child(desc_label)
	if not detail.is_empty():
		vbox.add_child(detail_label)

	card.add_child(vbox)
	return card

func _get_type_color(t: UpgradeData.UpgradeType) -> Color:
	match t:
		UpgradeData.UpgradeType.WEAPON_UNLOCK:
			return Color(0.23, 0.65, 1.0, 1.0)
		UpgradeData.UpgradeType.WEAPON_LEVEL:
			return Color(0.95, 0.78, 0.3, 1.0)
		UpgradeData.UpgradeType.WEAPON_PATH:
			return Color(0.95, 0.4, 0.6, 1.0)
		UpgradeData.UpgradeType.PLAYER_STAT:
			return Color(0.4, 0.9, 0.5, 1.0)
	return Color(0.7, 0.7, 0.7, 1.0)

func _get_type_name(t: UpgradeData.UpgradeType) -> String:
	match t:
		UpgradeData.UpgradeType.WEAPON_UNLOCK:
			return "新武器"
		UpgradeData.UpgradeType.WEAPON_LEVEL:
			return "武器强化"
		UpgradeData.UpgradeType.WEAPON_PATH:
			return "流派选择"
		UpgradeData.UpgradeType.PLAYER_STAT:
			return "角色属性"
	return "未知"

func _get_weapon_category_name(weapon_id: StringName) -> String:
	var weapon_data_path := "res://resources/weapons/%s.tres" % weapon_id
	if ResourceLoader.exists(weapon_data_path):
		var wdata := load(weapon_data_path)
		if wdata is WeaponData:
			match wdata.category:
				WeaponData.Category.DAMAGE:
					return "攻击"
				WeaponData.Category.DEFENSE:
					return "防御"
				WeaponData.Category.BUFF:
					return "增益"
	return ""

func _get_weapon_category_color(weapon_id: StringName) -> Color:
	var weapon_data_path := "res://resources/weapons/%s.tres" % weapon_id
	if ResourceLoader.exists(weapon_data_path):
		var wdata := load(weapon_data_path)
		if wdata is WeaponData:
			match wdata.category:
				WeaponData.Category.DAMAGE:
					return Color(0.95, 0.5, 0.4, 1)
				WeaponData.Category.DEFENSE:
					return Color(0.4, 0.65, 0.95, 1)
				WeaponData.Category.BUFF:
					return Color(0.5, 0.9, 0.5, 1)
	return Color(0.7, 0.7, 0.7, 1)

func _format_detail(option: UpgradeData) -> String:
	var parts: Array[String] = []
	if option.damage_bonus != 0:
		parts.append("伤害 %+d" % option.damage_bonus)
	if option.cooldown_bonus != 0:
		parts.append("冷却 %+.2f" % option.cooldown_bonus)
	if option.range_bonus != 0:
		parts.append("范围 %+d" % int(option.range_bonus))
	if option.speed_bonus != 0:
		parts.append("移速 %+d" % int(option.speed_bonus))
	if option.max_hp_bonus != 0:
		parts.append("最大生命 %+d" % option.max_hp_bonus)
	if option.hp_bonus != 0 and option.hp_bonus != option.max_hp_bonus:
		parts.append("生命 %+d" % option.hp_bonus)
	if option.pickup_radius_bonus != 0:
		parts.append("拾取 %+d" % int(option.pickup_radius_bonus))
	return "  |  ".join(parts)

func _get_option_icon(option: UpgradeData) -> Texture2D:
	if option.icon != null:
		return option.icon
	if option.upgrade_type == UpgradeData.UpgradeType.PLAYER_STAT:
		return preload("res://assets/art/ui/icon_stat_upgrade.png")
	if option.weapon_id:
		var weapon_data_path := "res://resources/weapons/%s.tres" % option.weapon_id
		if ResourceLoader.exists(weapon_data_path):
			var wdata := load(weapon_data_path)
			if wdata is WeaponData:
				return wdata.icon
	return null

func _on_option_pressed(option: UpgradeData) -> void:
	option_selected.emit(option)
	visible = false

func _on_reroll_pressed() -> void:
	reroll_requested.emit()

func _on_skip_pressed() -> void:
	skip_requested.emit()
	visible = false
