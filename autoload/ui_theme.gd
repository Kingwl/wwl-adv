extends Node

const UI_FONT: FontFile = preload("res://assets/fonts/NotoSansCJKsc-Regular.otf")
const UI_FONT_SIZE := 18

const FONT_THEME_TYPES := [
	"Button",
	"CheckBox",
	"CheckButton",
	"ItemList",
	"Label",
	"LineEdit",
	"LinkButton",
	"MenuBar",
	"MenuButton",
	"OptionButton",
	"PopupMenu",
	"RichTextLabel",
	"TabBar",
	"TextEdit",
	"TooltipLabel",
	"Tree",
]

func _ready() -> void:
	_install_ui_font()
	get_tree().node_added.connect(_on_node_added)
	_apply_font_overrides(get_tree().root)

func _install_ui_font() -> void:
	ThemeDB.set_fallback_font(UI_FONT)
	ThemeDB.set_fallback_font_size(UI_FONT_SIZE)

	var theme := Theme.new()
	theme.set_default_font(UI_FONT)
	theme.set_default_font_size(UI_FONT_SIZE)
	for theme_type: String in FONT_THEME_TYPES:
		theme.set_font("font", theme_type, UI_FONT)

	get_tree().root.theme = theme

func _on_node_added(node: Node) -> void:
	if node is Control:
		_apply_control_font(node)

func _apply_font_overrides(node: Node) -> void:
	if node is Control:
		_apply_control_font(node)
	for child in node.get_children():
		_apply_font_overrides(child)

func _apply_control_font(control: Control) -> void:
	control.add_theme_font_override("font", UI_FONT)
