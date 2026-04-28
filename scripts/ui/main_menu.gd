extends Control

func _ready() -> void:
	get_tree().paused = false
	_setup_background()
	_style_button($CenterContainer/VBoxContainer/StartButton)
	_style_button($CenterContainer/VBoxContainer/ContinueButton)
	_style_button($CenterContainer/VBoxContainer/QuitButton)

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

func _on_start_pressed() -> void:
	GameState.start_new_run()
	get_tree().change_scene_to_file("res://scenes/game/game.tscn")

func _on_quit_pressed() -> void:
	get_tree().quit()
