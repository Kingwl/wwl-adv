extends Node2D

func _ready() -> void:
	GameState.run_ended.connect(_on_run_ended)
	$GameOver.restart_pressed.connect(_on_restart)
	$GameOver.quit_to_menu_pressed.connect(_on_quit_to_menu)
	$PauseMenu.get_node("Panel/VBoxContainer/QuitButton").pressed.connect(_on_quit_to_menu)
	GameState.start_new_run()

func _process(delta: float) -> void:
	GameState.add_run_time(delta)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_stats"):
		if $GameOver.visible or $PauseMenu.visible:
			return
		$StatsPanel.toggle()

func _on_run_ended(_victory: bool) -> void:
	get_tree().paused = true
	$GameOver.show_stats()

func _on_restart() -> void:
	get_tree().reload_current_scene()

func _on_quit_to_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
