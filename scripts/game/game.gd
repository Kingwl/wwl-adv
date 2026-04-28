extends Node2D

var _regen_timer: float = 0.0
var _regen_last_level: int = 0
var _run_finished: bool = false

func _ready() -> void:
	GameState.run_ended.connect(_on_run_ended)
	$GameOver.restart_pressed.connect(_on_restart)
	$GameOver.quit_to_menu_pressed.connect(_on_quit_to_menu)
	$PauseMenu.quit_to_menu_pressed.connect(_on_quit_to_menu)
	GameState.start_new_run()

func _process(delta: float) -> void:
	if _run_finished:
		return
	GameState.add_run_time(delta)
	_process_passive_enhancements(delta)

func _process_passive_enhancements(delta: float) -> void:
	var regen_level := GameState.get_enhancement_level(GameState.REGEN_ENHANCEMENT_ID)
	if regen_level <= 0:
		_regen_timer = 0.0
		_regen_last_level = 0
		return
	if _regen_last_level == 0:
		_regen_last_level = regen_level
		_regen_timer = GameState.REGEN_INTERVAL
		return
	_regen_last_level = regen_level
	_regen_timer -= delta
	if _regen_timer > 0.0:
		return
	var heal_amount := GameState.get_regen_heal_amount()
	if heal_amount > 0:
		GameState.heal(heal_amount)
		_show_regen_visual()
	_regen_timer += GameState.REGEN_INTERVAL

func _show_regen_visual() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if not player:
		return
	VFXHelper.spawn_animated_one_shot(
		self,
		"res://assets/art/effects/by_type/fx_regen",
		"regen",
		4,
		player.global_position,
		4.0
	)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_stats"):
		if $GameOver.visible or $PauseMenu.visible:
			return
		$StatsPanel.toggle()

func _on_run_ended(_victory: bool) -> void:
	if _run_finished:
		return
	_run_finished = true
	SaveManager.record_run_finished()
	get_tree().paused = true
	$GameOver.show_stats()

func _on_restart() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

func _on_quit_to_menu() -> void:
	SaveManager.save_profile()
	get_tree().paused = false
	get_tree().call_deferred("change_scene_to_file", "res://scenes/ui/main_menu.tscn")
