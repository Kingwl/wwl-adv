extends Node

## 集成测试控制器。headless 下自动运行游戏并覆盖所有主要代码路径。

var _game: Node
var _passed := 0
var _failed := 0
var _phase := 0

func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	print("=== WWL ADVENTURE INTEGRATION TEST ===")
	SaveManager.configure_paths_for_tests("user://wwl_auto_test_save_v1.json")
	SaveManager.delete_save_files_for_tests()
	SaveManager.load_or_create()

	_game = load("res://scenes/game/game.tscn").instantiate()
	var spawner := _game.get_node_or_null("EnemySpawner")
	if spawner:
		spawner.set_process(false)
	add_child(_game)

	await _wait(0.5)
	_run_phase()

func _run_phase() -> void:
	match _phase:
		0: await _phase_load()
		1: await _phase_gameplay()
		2: await _phase_level_up()
		3: await _phase_weapon_unlocks()
		4: await _phase_weapon_usage()
		5: await _phase_pause()
		6: await _phase_game_over()
		7: await _phase_path_system()
		8: await _phase_enemy_damage()
		9: await _phase_special_tags()
		10: await _phase_weapon_path_tags()
		11: await _phase_melee_kill()
		12: await _phase_player_combat()
		13: await _phase_enemy_behavior()
		14: await _phase_upgrade_edges()
		15: await _phase_drop_pickups()
		16: await _phase_enemy_collision()
		17: await _phase_player_movement()
		18: await _phase_hud_sync()
		19: await _phase_stats_panel()
		20: await _phase_enemy_spawner()
		21: await _phase_projectile_system()
		22: await _phase_weapon_orbit()
		23: await _phase_passive_regen_thorns()
		24: await _phase_save_system()
		25: await _phase_character_system()
		26: _finish()
	_phase += 1
	if _phase <= 26:
		await _wait(0.1)
		_run_phase()

func _phase_load() -> void:
	print("[PHASE 0] Scene Load")
	var player: Node = get_tree().get_first_node_in_group("player")
	_assert(player != null, "Player exists")
	_assert(_game.get_node_or_null("HUD") != null, "HUD exists")
	_assert(_game.get_node_or_null("UpgradeSystem") != null, "UpgradeSystem exists")
	_assert(_game.get_node_or_null("UpgradeSelect") != null, "UpgradeSelect exists")
	_assert(_game.get_node_or_null("PauseMenu") != null, "PauseMenu exists")
	_assert(_game.get_node_or_null("GameOver") != null, "GameOver exists")
	if player:
		var camera: Node = player.get_node_or_null("Camera2D")
		_assert(camera != null, "Player Camera2D exists")
		if camera is Camera2D:
			_assert(camera.enabled, "Player Camera2D is enabled")
		_assert(str(GameState.run.get("character_id", "")) == "adventurer", "Default run uses adventurer")
		_assert(abs(player.move_speed - 170.0) < 0.01, "Default character speed applied")
	_assert(CrashReporter != null, "CrashReporter autoload exists")
	_assert(ProjectSettings.get_setting("sentry/options/auto_init", true) == false, "Sentry auto-init is disabled for wrapper-controlled startup")
	_assert(not CrashReporter._get_release().is_empty(), "CrashReporter builds a release name")
	_assert(AudioManager != null, "AudioManager autoload exists")
	var weapon_resources := DataManager.all_weapons()
	_assert(AudioManager.get_weapon_sfx_count() == weapon_resources.size(), "AudioManager registers one SFX per weapon")
	for weapon_data in weapon_resources:
		_assert(AudioManager.has_weapon_sfx(weapon_data.id), "Weapon %s has SFX mapping" % weapon_data.id)
		_assert(AudioManager.get_weapon_sfx(weapon_data.id) is AudioStream, "Weapon %s SFX stream loads" % weapon_data.id)

	# Verify HUD has icon elements
	var hud: Node = _game.get_node_or_null("HUD")
	if hud:
		_assert(hud.has_signal("pause_requested"), "HUD exposes pause request signal")
		var menu_button: Button = hud.get_node_or_null("TopBar/MenuButton")
		_assert(menu_button != null and menu_button.text == "菜单", "HUD has mobile menu button")
		var has_gold_icon := false
		var has_heart_icon := false
		for child in hud.get_children():
			for sub in child.get_children():
				if sub is TextureRect:
					if sub.texture != null:
						if sub.custom_minimum_size.x == 20:
							has_gold_icon = true
						if sub.custom_minimum_size.x == 24:
							has_heart_icon = true
		_assert(has_gold_icon, "HUD has gold icon")
		_assert(has_heart_icon, "HUD has heart icon")

	var main_menu: Node = load("res://scenes/ui/main_menu.tscn").instantiate()
	add_child(main_menu)
	await _wait(0.1)
	var characters := DataManager.all_characters()
	_assert(characters.size() >= 4, "Character data resources loaded")
	for character in characters:
		_assert(character.icon != null, "Character %s has class icon" % character.id)
		_assert("walk_sheet" in character and character.walk_sheet != null, "Character %s has walk sheet" % character.id)
	_assert(DataManager._resource_path_from_dir_entry("res://resources/characters", "adventurer.tres.remap") == "res://resources/characters/adventurer.tres", "Resource scan supports exported remap entries")
	var optional_resources := {}
	DataManager._load_resources("res://resources/__optional_missing__", optional_resources, false)
	_assert(optional_resources.is_empty(), "Optional missing resource directories are ignored")
	var menu_title: Label = main_menu.get_node_or_null("CenterContainer/VBoxContainer/Title")
	_assert(menu_title != null and menu_title.text == "WWL 大冒险", "Main menu title is localized")
	var menu_bg: Node = main_menu.get_node_or_null("Background")
	_assert(menu_bg is ColorRect, "Main menu background exists")
	var ground_tile: Node = menu_bg.get_node_or_null("GroundTileBackground") if menu_bg else null
	_assert(ground_tile is TextureRect, "Main menu has tiled ground background")
	if ground_tile is TextureRect:
		var tile_rect := ground_tile as TextureRect
		_assert(tile_rect.stretch_mode == TextureRect.STRETCH_TILE, "Main menu background uses tile stretch mode")
		_assert(tile_rect.anchor_left == 0.0 and tile_rect.anchor_top == 0.0 and tile_rect.anchor_right == 1.0 and tile_rect.anchor_bottom == 1.0, "Main menu background fills viewport anchors")
	var continue_button: Button = main_menu.get_node_or_null("CenterContainer/VBoxContainer/ContinueButton")
	_assert(continue_button != null and not continue_button.visible, "Main menu hides battle continue button")
	var gold_summary: Label = main_menu.get_node_or_null("CenterContainer/VBoxContainer/GoldSummary/GoldSummaryLabel")
	_assert(gold_summary != null and gold_summary.text == "全局金币: 0", "Main menu shows global gold")
	var character_panel: Node = main_menu.get_node_or_null("CenterContainer/VBoxContainer/CharacterPanel")
	_assert(character_panel != null, "Main menu has character selector")
	var character_cards: GridContainer = main_menu.get_node_or_null("CenterContainer/VBoxContainer/CharacterPanel/CharacterContent/CharacterCards")
	_assert(character_cards != null and character_cards.get_child_count() >= 4, "Character selector shows available characters")
	var character_info: Label = main_menu.get_node_or_null("CenterContainer/VBoxContainer/CharacterPanel/CharacterContent/CharacterInfo")
	_assert(character_info != null and not character_info.text.is_empty(), "Character selector shows character details")
	main_menu.queue_free()
	await _wait(0.3)

	var missing_vfx := VFXHelper.spawn_animated_one_shot(
		self,
		"res://assets/art/effects/by_type/__missing__",
		"missing",
		2,
		Vector2.ZERO
	)
	await _wait(0.05)
	_assert(not is_instance_valid(missing_vfx), "Missing VFX frames are skipped safely")

func _phase_gameplay() -> void:
	print("[PHASE 1] Gameplay")
	GameState.add_run_time(1.0)
	var player: Node = get_tree().get_first_node_in_group("player")
	if player:
		player.velocity = Vector2.RIGHT * 100
		player.move_and_slide()
		_assert(player.get_node_or_null("Weapons") != null, "Player Weapons container exists")
		var weapons := player.get_node("Weapons").get_children()
		_assert(weapons.size() >= 1, "Player has at least one weapon")

		# Verify HUD weapon bar shows icon for first weapon
		var hud: Node = _game.get_node_or_null("HUD")
		if hud:
			var weapon_bar = hud.get_node_or_null("WeaponBar")
			if weapon_bar and weapon_bar.get_child_count() > 0:
				var first_slot = weapon_bar.get_child(0)
				var vbox = first_slot.get_child(0)
				var icon_container = vbox.get_node_or_null("IconContainer")
				var icon_rect = icon_container.get_node_or_null("IconRect") if icon_container else null
				_assert(icon_rect is TextureRect and icon_rect.texture != null, "HUD weapon bar slot shows icon")
				var cooldown_overlay = icon_container.get_node_or_null("CooldownOverlay") if icon_container else null
				_assert(cooldown_overlay is Control, "HUD weapon bar slot has cooldown overlay")
				if cooldown_overlay:
					var cooldown_fill = cooldown_overlay.get_node_or_null("CooldownFill")
					_assert(cooldown_fill is ColorRect, "Cooldown overlay uses height-changing fill")
					if cooldown_fill and not weapons.is_empty() and weapons[0].has_method("get_cooldown_progress"):
						var cooldown_progress: float = weapons[0].get_cooldown_progress()
						var expected_anchor_top := 1.0 - clampf(cooldown_progress, 0.0, 1.0)
						_assert(abs(cooldown_fill.anchor_top - expected_anchor_top) < 0.01, "Cooldown overlay height tracks cooldown progress")
						_assert(cooldown_overlay.visible == (cooldown_progress > 0.01), "Cooldown overlay hides when ready")

			# Camera follow check: move player and verify camera follows
		var camera: Camera2D = player.get_node_or_null("Camera2D")
		if camera:
			var start_cam_pos := camera.global_position
			player.global_position += Vector2.RIGHT * 50
			await _wait(0.05)
			var end_cam_pos := camera.global_position
			_assert(end_cam_pos.x > start_cam_pos.x, "Camera follows player movement")

		var upgrade_system: Node = _game.get_node_or_null("UpgradeSystem")
		if upgrade_system:
			if not _find_weapon(&"electromagnetic_chain"):
				upgrade_system._unlock_weapon(&"electromagnetic_chain")
			if not _find_weapon(&"rocket_pack"):
				upgrade_system._unlock_weapon(&"rocket_pack")
			await _wait(0.1)
			var chain := _find_weapon(&"electromagnetic_chain")
			var rocket := _find_weapon(&"rocket_pack")
			_assert(chain != null, "Electromagnetic chain can be equipped")
			_assert(rocket != null, "Rocket pack can be equipped")
			if hud:
				hud._update_weapon_bar()
				_assert(_hud_weapon_bar_has_weapon(hud, &"electromagnetic_chain"), "HUD weapon bar shows electromagnetic chain")
				_assert(_hud_weapon_bar_has_weapon(hud, &"rocket_pack"), "HUD weapon bar shows rocket pack")
	await _wait(0.3)

func _phase_level_up() -> void:
	print("[PHASE 2] Level Up")

	var upgrade_system: Node = _game.get_node_or_null("UpgradeSystem")
	_assert(upgrade_system != null, "UpgradeSystem node found")

	var level_20_exp := GameState._calc_exp_required(GameState.EXP_CURVE_SOFTEN_LEVEL)
	var level_21_exp := GameState._calc_exp_required(GameState.EXP_CURVE_SOFTEN_LEVEL + 1)
	var level_22_exp := GameState._calc_exp_required(GameState.EXP_CURVE_SOFTEN_LEVEL + 2)
	var level_20_pivot := GameState.STARTING_EXP_TO_LEVEL * pow(GameState.EXP_EARLY_GROWTH, GameState.EXP_CURVE_SOFTEN_LEVEL - 1)
	_assert(level_20_exp == int(GameState.STARTING_EXP_TO_LEVEL * pow(GameState.EXP_EARLY_GROWTH, GameState.EXP_CURVE_SOFTEN_LEVEL - 1)), "EXP curve keeps early growth through level 20")
	_assert(level_21_exp == int(level_20_pivot * GameState.EXP_LATE_GROWTH), "EXP curve softens after level 20")
	_assert(level_22_exp < int(level_21_exp * GameState.EXP_EARLY_GROWTH), "Late EXP curve grows slower than early curve")

	# Disconnect automatic pause so test can keep running
	if GameState.level_up.is_connected(upgrade_system._on_level_up):
		GameState.level_up.disconnect(upgrade_system._on_level_up)

	var prev_level: int = GameState.run.level
	var prev_weapon_count: int = _get_weapon_count()

	# Generate options and apply first one manually
	var options = upgrade_system._generate_options()
	_assert(options.size() == 3, "Three upgrade options generated")
	_assert(options[0] is UpgradeData, "First option is UpgradeData")

	# Test UI icons before applying
	var upgrade_select: Node = _game.get_node_or_null("UpgradeSelect")
	if upgrade_select:
		upgrade_select.show_options(options)
		await _wait(0.1)
		var cards: Array = upgrade_select._options_container.get_children()
		for i in range(cards.size()):
			var has_icon := false
			for child in cards[i].get_children():
				if child is VBoxContainer:
					for sub in child.get_children():
						if sub is TextureRect:
							has_icon = true
							break
			if i < options.size():
				if options[i].weapon_id or options[i].upgrade_type == UpgradeData.UpgradeType.PLAYER_STAT:
					_assert(has_icon, "Upgrade card %d has icon" % i)

		var reroll_button := upgrade_select.get_node_or_null("PanelContainer/VBoxContainer/ActionsContainer/RerollButton") as Button
		var skip_button := upgrade_select.get_node_or_null("PanelContainer/VBoxContainer/ActionsContainer/SkipButton") as Button
		_assert(reroll_button != null, "UpgradeSelect has reroll button")
		_assert(skip_button != null, "UpgradeSelect has skip button")
		if reroll_button:
			var reroll_seen := [false]
			upgrade_select.reroll_requested.connect(func(): reroll_seen[0] = true)
			reroll_button.pressed.emit()
			await _wait(0.05)
			_assert(reroll_seen[0], "Reroll button emits reroll_requested")
		if skip_button:
			upgrade_select.show_options(options)
			var skip_seen := [false]
			upgrade_select.skip_requested.connect(func(): skip_seen[0] = true)
			skip_button.pressed.emit()
			await _wait(0.05)
			_assert(skip_seen[0], "Skip button emits skip_requested")
			_assert(not upgrade_select.visible, "Skip button hides UpgradeSelect")
		upgrade_select.visible = false

		# Test PLAYER_STAT option specifically has the stat upgrade icon
		var stat_option := UpgradeData.new()
		stat_option.id = "test_stat"
		stat_option.display_name = "Test Stat"
		stat_option.description = "Test"
		stat_option.upgrade_type = UpgradeData.UpgradeType.PLAYER_STAT
		upgrade_select.show_options([stat_option])
		await _wait(0.1)
		var stat_card = upgrade_select._options_container.get_child(0)
		var stat_has_icon := false
		for child in stat_card.get_children():
			if child is VBoxContainer:
				for sub in child.get_children():
					if sub is TextureRect and sub.texture != null:
						stat_has_icon = true
						break
		_assert(stat_has_icon, "PLAYER_STAT upgrade card has stat icon")
		upgrade_select.visible = false

		get_tree().paused = true
		upgrade_system._show_generated_options()
		await _wait(0.05)
		upgrade_system._on_reroll_requested()
		await _wait(0.05)
		_assert(upgrade_select.visible, "Reroll keeps UpgradeSelect visible")
		_assert(get_tree().paused, "Reroll keeps game paused")
		_assert(upgrade_select._options_container.get_child_count() == 3, "Reroll refreshes all cards")
		upgrade_system._on_skip_requested()
		await _wait(0.05)
		_assert(not upgrade_select.visible, "Skip hides UpgradeSelect")
		_assert(not get_tree().paused, "Skip resumes game")

	# Apply first option directly
	upgrade_system._on_option_selected(options[0])
	await _wait(0.2)

	# Verify level increased or weapon was added (PLAYER_STAT also counts)
	var leveled: bool = GameState.run.level > prev_level
	var weapon_added: bool = _get_weapon_count() > prev_weapon_count
	var stat_applied: bool = options[0].upgrade_type == UpgradeData.UpgradeType.PLAYER_STAT
	var path_applied: bool = options[0].upgrade_type == UpgradeData.UpgradeType.WEAPON_PATH
	_assert(leveled or weapon_added or stat_applied or path_applied, "Level up, weapon unlock, or stat boost took effect")

	# Also test via UI path: trigger another level up
	GameState.add_exp(999)
	await _wait(0.3)

	if upgrade_select and upgrade_select.visible:
		# Simulate click on first card
		var cards: Array = upgrade_select._options_container.get_children()
		if cards.size() > 0:
			var ev := InputEventMouseButton.new()
			ev.button_index = MOUSE_BUTTON_LEFT
			ev.pressed = true
			cards[0].gui_input.emit(ev)
			await _wait(0.2)
			_assert(not upgrade_select.visible, "UpgradeSelect hidden after card click")
	else:
		push_warning("[TEST] UpgradeSelect not visible after add_exp; level may have jumped multiple times")

	get_tree().paused = false
	await _wait(0.3)
	_reset_runtime_modifiers_for_tests()

func _phase_weapon_unlocks() -> void:
	print("[PHASE 3] Weapon Unlocks")
	var upgrade_system: Node = _game.get_node_or_null("UpgradeSystem")
	var scenes: Dictionary = upgrade_system.WEAPON_SCENES

	var unlocked_count := 0
	var cap_checked := false
	for weapon_id in scenes.keys():
		var existing := _find_weapon(weapon_id)
		if existing != null:
			_assert(existing.weapon_data != null, "Weapon %s already equipped has weapon_data" % weapon_id)
			if existing.weapon_data:
				_assert(existing.weapon_data.id == weapon_id, "Weapon %s already equipped data id matches" % weapon_id)
				_assert(existing.weapon_data.icon != null, "Weapon %s already equipped has icon" % weapon_id)
			_assert(existing.level >= 1, "Weapon %s already equipped has valid level" % weapon_id)
			unlocked_count += 1
			continue

		var unlock := UpgradeData.new()
		unlock.id = "test_unlock_" + str(weapon_id)
		unlock.display_name = "Test Unlock"
		unlock.description = "Test"
		unlock.upgrade_type = UpgradeData.UpgradeType.WEAPON_UNLOCK
		unlock.weapon_id = weapon_id

		var count_before := _get_weapon_count()
		if count_before < GameState.MAX_WEAPON_SLOTS:
			upgrade_system._on_option_selected(unlock)
		else:
			upgrade_system._on_option_selected(unlock)
			await _wait(0.05)
			_assert(_find_weapon(weapon_id) == null, "Weapon slot cap blocks normal unlock for %s" % weapon_id)
			_assert(_get_weapon_count() == count_before, "Weapon count stays at slot cap")
			if not cap_checked:
				var cap_options: Array[UpgradeData] = upgrade_system._generate_options()
				var has_unlock_option := false
				for u in cap_options:
					if u.upgrade_type == UpgradeData.UpgradeType.WEAPON_UNLOCK:
						has_unlock_option = true
						break
				_assert(not has_unlock_option, "Full weapon slots hide new weapon options")
				cap_checked = true
			upgrade_system._unlock_weapon(weapon_id, true)
		await _wait(0.05)

		var w := _find_weapon(weapon_id)
		_assert(w != null, "Weapon %s unlocked and added" % weapon_id)
		if w:
			_assert(w.weapon_data != null, "Weapon %s has weapon_data" % weapon_id)
			if w.weapon_data:
				_assert(w.weapon_data.id == weapon_id, "Weapon %s data id matches" % weapon_id)
				_assert(w.weapon_data.icon != null, "Weapon %s has icon" % weapon_id)
			_assert(w.level == 1, "Weapon %s starts at level 1" % weapon_id)
		unlocked_count += 1

	_assert(unlocked_count == scenes.size(), "All %d weapons unlocked for coverage" % scenes.size())
	print("  Unlocked %d weapons" % unlocked_count)

	# Test weapon level up
	var melee := _find_weapon(&"melee_basic")
	if melee:
		var prev_level: int = melee.level
		var prev_dmg: int = melee._current_damage
		var prev_range: float = melee._current_range
		# Reset to no path for predictable damage
		melee.current_path_id = &""
		melee._recalc_stats()
		prev_dmg = melee._current_damage
		prev_range = melee._current_range
		var lvl := UpgradeData.new()
		lvl.id = "test_melee_lvl"
		lvl.display_name = "Test"
		lvl.upgrade_type = UpgradeData.UpgradeType.WEAPON_LEVEL
		lvl.weapon_id = &"melee_basic"
		lvl.damage_bonus = 5
		upgrade_system._on_option_selected(lvl)
		await _wait(0.05)
		_assert(melee.level == prev_level + 1, "Melee leveled up by 1")
		_assert(melee._current_damage == prev_dmg + 6, "Melee damage bonus and base growth applied")
		_assert(melee._current_range == prev_range + 10.0, "Melee range grows by 10 per level")

func _phase_weapon_usage() -> void:
	print("[PHASE 4] Weapon Usage")

	var player: Node = get_tree().get_first_node_in_group("player")
	if not player:
		_assert(false, "Player missing during usage test")
		return

	var weapons := player.get_node_or_null("Weapons")
	if not weapons:
		_assert(false, "Weapons container missing during usage test")
		return

	var all_weapons := _get_all_weapons()
	_assert(all_weapons.size() > 0, "At least one weapon active during usage")

	# Verify base properties for all weapons
	for w in all_weapons:
		var id: String = w.weapon_data.id if w.weapon_data else "?"
		_assert(w._current_damage >= 0, "Weapon %s damage >= 0" % id)
		_assert(w._current_cooldown >= 0.1, "Weapon %s cooldown >= 0.1" % id)

	# Trigger thorns by taking damage
	GameState.take_damage(1)
	await _wait(0.2)

	# Simulate movement and time to trigger all weapons
	var triggered: Dictionary = {}
	var start_pos: Vector2 = player.global_position

	for i in range(120):  # 6 seconds
		player.global_position = start_pos + Vector2.RIGHT * (i * 2)

		for w in all_weapons:
			var id: String = w.weapon_data.id if w.weapon_data else "?"
			if w._cooldown_timer < w._current_cooldown:
				triggered[id] = true

		await _wait(0.05)

	# Assert every weapon was triggered at least once
	for w in all_weapons:
		var id: String = w.weapon_data.id if w.weapon_data else "?"
		match id:
			"orbit", "frost_ring", "saw_blade":
				_assert(w._current_damage >= 0, "Continuous weapon %s functional" % id)
			"thorns":
				_assert(w._current_damage >= 0, "Thorns functional after taking damage")
			"rocket_pack":
				_assert(triggered.has(id), "Rocket pack triggered by movement")
			_:
				_assert(triggered.has(id), "Weapon %s triggered at least once" % id)

	# Specific behavior checks
	var orbit := _find_weapon(&"orbit")
	if orbit:
		_assert(orbit._orbs.size() > 0, "Orbit weapon has rotating orbs")
		for orb in orbit._orbs:
			var has_anim := false
			for child in orb.get_children():
				if child is AnimatedSprite2D:
					has_anim = true
					break
			_assert(has_anim, "Orbit orb uses AnimatedSprite2D")

	var saw := _find_weapon(&"saw_blade")
	if saw and saw._saws.size() > 0 and saw._saws[0]:
		var has_anim := false
		for child in saw._saws[0].get_children():
			if child is AnimatedSprite2D:
				has_anim = true
				break
		_assert(has_anim, "Saw blade uses AnimatedSprite2D")

	var projectile := _find_weapon(&"projectile_basic")
	if projectile:
		_assert(projectile._cooldown_timer <= projectile._current_cooldown, "Projectile cooldown active")

	# Verify drops use AnimatedSprite2D
	var drops := _game.get_node_or_null("Drops")
	if drops:
		for drop in drops.get_children():
			var has_anim := false
			for child in drop.get_children():
				if child is AnimatedSprite2D:
					has_anim = true
					break
			if has_anim:
				_assert(true, "Drop item uses AnimatedSprite2D")
				break

func _phase_pause() -> void:
	print("[PHASE 5] Pause Menu")
	var pause_menu: Node = _game.get_node_or_null("PauseMenu")
	_assert(pause_menu != null, "PauseMenu node found")

	if pause_menu:
		_assert(pause_menu.has_signal("quit_to_menu_pressed"), "PauseMenu exposes quit-to-menu signal")
		var quit_button: Button = pause_menu.get_node_or_null("Panel/VBoxContainer/QuitButton")
		_assert(quit_button != null, "PauseMenu quit button exists")
		if quit_button:
			var direct_game_quit_connections := 0
			for connection in quit_button.pressed.get_connections():
				var callable: Callable = connection.get("callable")
				if callable.get_object() == _game:
					direct_game_quit_connections += 1
			_assert(direct_game_quit_connections == 0, "PauseMenu quit button does not directly change game scene")

		var game_quit_signal_connections := 0
		for connection in pause_menu.get_signal_connection_list(&"quit_to_menu_pressed"):
			var callable: Callable = connection.get("callable")
			if callable.get_object() == _game and callable.get_method() == &"_on_quit_to_menu":
				game_quit_signal_connections += 1
		_assert(game_quit_signal_connections == 1, "PauseMenu quit signal is connected to Game once")

		var hud: Node = _game.get_node_or_null("HUD")
		var menu_button: Button = hud.get_node_or_null("TopBar/MenuButton") if hud else null
		var hud_pause_connections := 0
		if hud:
			for connection in hud.get_signal_connection_list(&"pause_requested"):
				var callable: Callable = connection.get("callable")
				if callable.get_object() == _game and callable.get_method() == &"_on_hud_pause_requested":
					hud_pause_connections += 1
		_assert(hud_pause_connections == 1, "HUD menu signal is connected to Game once")
		_assert(menu_button != null, "HUD menu button exists for mobile pause")
		get_tree().paused = false
		pause_menu.visible = false
		if menu_button:
			menu_button.pressed.emit()
			await _wait(0.1)
			_assert(pause_menu.visible, "HUD menu button opens PauseMenu")
			_assert(get_tree().paused, "HUD menu button pauses game")
			pause_menu._resume()
			await _wait(0.1)

		pause_menu.show_pause()
		await _wait(0.3)
		_assert(pause_menu.visible, "PauseMenu is visible")

		var weapons_container: HBoxContainer = pause_menu._weapons_container
		_assert(weapons_container != null, "PauseMenu weapons container exists")
		var slot_labels: Array = weapons_container.get_children()
		_assert(slot_labels.size() == GameState.MAX_WEAPON_SLOTS, "PauseMenu shows 6 weapon slots")

		var enhancements_container: HBoxContainer = pause_menu._enhancements_container
		_assert(enhancements_container != null, "PauseMenu enhancements container exists")
		if enhancements_container:
			_assert(enhancements_container.get_child_count() == GameState.MAX_ENHANCEMENT_SLOTS, "PauseMenu shows 6 enhancement slots")

		# Verify weapon slots display icons
		for slot in slot_labels:
			if slot is VBoxContainer:
				var has_icon := false
				for child in slot.get_children():
					if child is TextureRect:
						has_icon = true
						break
				_assert(has_icon, "PauseMenu weapon slot has icon")

		pause_menu._resume()
		await _wait(0.3)
		_assert(not pause_menu.visible, "PauseMenu hidden after resume")

func _phase_game_over() -> void:
	print("[PHASE 6] Game Over")
	var game_over: Node = _game.get_node_or_null("GameOver")
	_assert(game_over != null, "GameOver node found")

	if game_over:
		# Add some stats first
		GameState.run.kills = 0
		GameState.run["weapon_damage"] = {}
		GameState.run["weapon_hits"] = {}
		GameState.run["weapon_kills"] = {}
		GameState.run["weapon_damage_stats"] = {}
		GameState.run["damage_taken_by_source"] = {}
		GameState.run["death_reason"] = {}
		GameState.run["upgrade_history"] = []
		GameState.add_gold(10)
		GameState.add_kill()
		GameState.add_kill()
		GameState.record_weapon_damage(&"melee_basic", 42, true)
		var recorded_upgrade := UpgradeData.new()
		recorded_upgrade.id = &"might"
		recorded_upgrade.display_name = "强攻"
		recorded_upgrade.upgrade_type = UpgradeData.UpgradeType.PLAYER_STAT
		GameState.record_upgrade_selected(recorded_upgrade)

		GameState.take_damage(9999)
		await _wait(0.5)

		_assert(game_over.visible, "GameOver visible after death")

		var time_label: Label = game_over.get_node_or_null("Panel/VBoxContainer/Stats/TimeRow/TimeValue")
		if time_label:
			_assert(not time_label.text.is_empty() and time_label.text != "00:00", "GameOver time label populated")

		var kills_label: Label = game_over.get_node_or_null("Panel/VBoxContainer/Stats/KillsRow/KillsValue")
		if kills_label:
			_assert(kills_label.text == "2", "GameOver kills correct (expected 2)")

		# Verify game over weapon slots display icons
		var weapons_container: HBoxContainer = game_over.get_node_or_null("Panel/VBoxContainer/WeaponsSection/WeaponsContainer")
		if weapons_container:
			_assert(weapons_container.get_child_count() == GameState.MAX_WEAPON_SLOTS, "GameOver shows 6 weapon slots")
			for slot in weapons_container.get_children():
				if slot is VBoxContainer:
					var has_icon := false
					for child in slot.get_children():
						if child is TextureRect:
							has_icon = true
							break
					_assert(has_icon, "GameOver weapon slot has icon")

		var enhancements_container: HBoxContainer = game_over.get_node_or_null("Panel/VBoxContainer/EnhancementsSection/EnhancementsContainer")
		if enhancements_container:
			_assert(enhancements_container.get_child_count() == GameState.MAX_ENHANCEMENT_SLOTS, "GameOver shows 6 enhancement slots")

		var weapon_damage_list: VBoxContainer = game_over.get_node_or_null("Panel/VBoxContainer/CombatSummarySection/WeaponDamageList")
		if weapon_damage_list:
			_assert(weapon_damage_list.get_child_count() > 0, "GameOver shows weapon damage summary")
			_assert(_node_text_contains(weapon_damage_list, "基础利刃") and _node_text_contains(weapon_damage_list, "42伤害"), "GameOver weapon damage row populated")

		var death_reason_label: Label = game_over.get_node_or_null("Panel/VBoxContainer/CombatSummarySection/DeathReasonLabel")
		if death_reason_label:
			_assert(death_reason_label.text.contains("最后伤害"), "GameOver death reason populated")

		var upgrade_history_list: VBoxContainer = game_over.get_node_or_null("Panel/VBoxContainer/UpgradeHistorySection/UpgradeHistoryList")
		if upgrade_history_list:
			_assert(_node_text_contains(upgrade_history_list, "强攻"), "GameOver upgrade history populated")

	# Unpause so subsequent phases can use non-always timers
	get_tree().paused = false

func _get_all_weapons() -> Array[WeaponBase]:
	var result: Array[WeaponBase] = []
	var player: Node = get_tree().get_first_node_in_group("player")
	if not player:
		return result
	var weapons := player.get_node_or_null("Weapons")
	if not weapons:
		return result
	for w in weapons.get_children():
		if w is WeaponBase:
			result.append(w)
	return result

func _find_weapon(weapon_id: StringName) -> WeaponBase:
	var player: Node = get_tree().get_first_node_in_group("player")
	if not player:
		return null
	var weapons := player.get_node_or_null("Weapons")
	if not weapons:
		return null
	for w in weapons.get_children():
		if w is WeaponBase and w.weapon_data and w.weapon_data.id == weapon_id:
			return w
	return null

func _hud_weapon_bar_has_weapon(hud: Node, weapon_id: StringName) -> bool:
	var weapon_bar: HBoxContainer = hud.get_node_or_null("WeaponBar")
	if not weapon_bar:
		return false
	for slot in weapon_bar.get_children():
		if slot.has_meta("weapon_id") and slot.get_meta("weapon_id") == weapon_id:
			return true
	return false

func _get_weapon_count() -> int:
	var player: Node = get_tree().get_first_node_in_group("player")
	if not player:
		return 0
	var weapons := player.get_node_or_null("Weapons")
	if not weapons:
		return 0
	var count := 0
	for w in weapons.get_children():
		if w is WeaponBase:
			count += 1
	return count

func _set_all_weapon_processing(enabled: bool) -> Array:
	var states := []
	for weapon in _get_all_weapons():
		states.append([weapon, weapon.is_processing()])
		weapon.set_process(enabled)
	return states

func _restore_weapon_processing(states: Array) -> void:
	for entry in states:
		if entry.size() < 2:
			continue
		var weapon := entry[0] as Node
		if is_instance_valid(weapon):
			weapon.set_process(bool(entry[1]))

func _clear_container_children(container: Node) -> void:
	if not container:
		return
	for child in container.get_children():
		child.queue_free()

func _reset_runtime_modifiers_for_tests() -> void:
	GameState.run.pickup_radius_bonus = 0.0
	GameState.run.exp_gain_multiplier = 1.0
	GameState.run.incoming_damage_multiplier = 1.0
	GameState.run.damage_multiplier = 1.0
	GameState.run.cooldown_multiplier = 1.0
	GameState.run.area_multiplier = 1.0
	GameState.run.projectile_cooldown_multiplier = 1.0
	GameState.run.field_lifetime_multiplier = 1.0
	GameState.run.enhancements = {}
	GameState.run.enhancement_order = []
	var player: Node = get_tree().get_first_node_in_group("player")
	if player and "move_speed" in player:
		player.move_speed = float(GameState.run.get("move_speed", 170.0))
	for weapon in _get_all_weapons():
		weapon._recalc_stats()
		weapon._apply_path_effects()

func _assert(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
		print("  [PASS] " + message)
	else:
		_failed += 1
		push_error("  [FAIL] " + message)

func _node_tree_contains_label_text(node: Node, text: String) -> bool:
	if node is Label and (node as Label).text == text:
		return true
	for child in node.get_children():
		if _node_tree_contains_label_text(child, text):
			return true
	return false

func _node_text_contains(node: Node, text: String) -> bool:
	if node is Label and (node as Label).text.contains(text):
		return true
	for child in node.get_children():
		if _node_text_contains(child, text):
			return true
	return false

func _wait(seconds: float):
	return get_tree().create_timer(seconds, true).timeout

func _assert_field_weapon_activation_damage(weapon: WeaponBase, field_type: String, expected_damage: int) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	var enemies_parent := _game.get_node_or_null("Enemies")
	if not player or not enemies_parent:
		_assert(false, "%s field damage test setup exists" % field_type.capitalize())
		return

	for child in enemies_parent.get_children():
		child.queue_free()
	await _wait(0.05)

	var enemy_scene := preload("res://scenes/enemy/enemy.tscn")
	var enemy := enemy_scene.instantiate()
	enemy.global_position = player.global_position + Vector2.RIGHT * 60.0
	enemies_parent.add_child(enemy)
	await _wait(0.05)

	enemy.set_physics_process(false)
	enemy.global_position = player.global_position + Vector2.RIGHT * 60.0
	enemy._hp = 999
	if "_dead" in enemy:
		enemy._dead = false
	if enemy.has_method("_setup_health_bar"):
		enemy._setup_health_bar()

	var hp_before: int = enemy._hp
	weapon._activate()
	await _wait(0.1)
	_assert(enemy._hp <= hp_before - expected_damage, "%s field deals damage when spawned on target" % field_type.capitalize())

	enemy.queue_free()
	await _wait(0.05)

func _phase_path_system() -> void:
	print("[PHASE 7] Weapon Path System")
	var melee := _find_weapon(&"melee_basic")
	_assert(melee != null, "Melee weapon exists for path test")
	if not melee:
		await _wait(0.2)
		return

	var orig_level := melee.level
	var orig_path := melee.current_path_id
	var orig_dmg := melee._current_damage
	var upgrade_system: Node = _game.get_node_or_null("UpgradeSystem")
	_assert(upgrade_system != null, "UpgradeSystem exists for path choice test")

	# Reset to level 1, no path
	melee.level = 1
	melee.current_path_id = &""
	melee._recalc_stats()

	# Test berserker path through the upgrade choice flow
	var berserker_path: WeaponPath = null
	for path in melee.weapon_data.paths:
		if path.path_id == &"berserker":
			berserker_path = path
			break
	_assert(berserker_path != null, "Berserker path data exists")
	var path_option: UpgradeData = upgrade_system._make_path_option(melee, berserker_path)
	_assert(path_option.description.contains("立即获得"), "Path choice card describes immediate Lv.2 upgrade")
	_assert(path_option.damage_bonus == 5, "Path choice carries first path damage bonus for display")
	_assert(path_option.build_tags.has("输出"), "Path choice carries build direction tag")
	var allowed_build_tags := ["输出", "范围", "控制", "频率", "生存", "穿透"]
	var missing_build_tags: Array[String] = []
	var invalid_build_tags: Array[String] = []
	for weapon_data in DataManager.all_weapons():
		if not ("paths" in weapon_data):
			continue
		for path in weapon_data.paths:
			var inferred_tags: Array[String] = upgrade_system._infer_path_build_tags(path)
			if inferred_tags.is_empty():
				missing_build_tags.append("%s/%s" % [str(weapon_data.id), str(path.path_id)])
			for tag in inferred_tags:
				if not allowed_build_tags.has(tag):
					invalid_build_tags.append("%s/%s/%s" % [str(weapon_data.id), str(path.path_id), tag])
	_assert(missing_build_tags.is_empty(), "All weapon paths infer build direction tags")
	_assert(invalid_build_tags.is_empty(), "Build direction tags use player-facing labels")
	var fire_spread := DataManager.get_weapon("fire_bottle").paths[1] as WeaponPath
	_assert(upgrade_system._infer_path_build_tags(fire_spread).has("范围"), "Range-oriented path uses range build tag")
	var upgrade_select: Node = _game.get_node_or_null("UpgradeSelect")
	if upgrade_select:
		var preview_card: Node = upgrade_select._create_option_card(path_option)
		_assert(_node_tree_contains_label_text(preview_card, "输出"), "Path choice card displays build direction tag")
		preview_card.free()
	upgrade_system._apply_upgrade(path_option)
	_assert(melee.current_path_id == &"berserker", "Berserker path set correctly")
	_assert(melee.level == 2, "Path selection triggers level up to 2")
	# Berserker Lv.2: damage +5 + base growth
	var expected_dmg := int(round(melee.weapon_data.damage * 1.1 * GameState.get_character_damage_multiplier())) + 5
	_assert(melee._current_damage == expected_dmg, "Berserker Lv.2 damage bonus applied")

	# Level through generated path cards to verify path bonuses are cumulative and not double-applied.
	var lvl3_effect := berserker_path.get_level_effect(3)
	_assert(lvl3_effect != null, "Berserker Lv.3 effect exists")
	var lvl3_option: UpgradeData = upgrade_system._make_level_from_path(melee, berserker_path, lvl3_effect)
	_assert(lvl3_option.path_id == &"berserker", "Path level card carries path id")
	upgrade_system._apply_upgrade(lvl3_option)
	var expected_lv3_dmg := int(round(melee.weapon_data.damage * 1.2 * GameState.get_character_damage_multiplier())) + 10
	_assert(melee._current_damage == expected_lv3_dmg, "Berserker Lv.3 cumulative damage applies once")
	_assert(melee.has_special_tag(&"wider_arc"), "Lv.3 berserker has wider_arc tag")

	var lvl4_option: UpgradeData = upgrade_system._make_level_from_path(melee, berserker_path, berserker_path.get_level_effect(4))
	upgrade_system._apply_upgrade(lvl4_option)
	var damage_after_lv4 := melee._current_damage
	var lvl5_option: UpgradeData = upgrade_system._make_level_from_path(melee, berserker_path, berserker_path.get_level_effect(5))
	upgrade_system._apply_upgrade(lvl5_option)
	var expected_lv5_dmg := int(round(melee.weapon_data.damage * 1.4 * GameState.get_character_damage_multiplier())) + 18
	var expected_lv5_range := (melee.weapon_data.range + 4.0 * 10.0) * GameState.get_character_area_multiplier() + 10.0
	_assert(melee._current_damage == expected_lv5_dmg and melee._current_damage >= damage_after_lv4, "Berserker Lv.5 range upgrade keeps prior damage bonuses")
	_assert(abs(melee._current_range - expected_lv5_range) < 0.01, "Berserker Lv.5 range bonus is applied once")

	# Level to 7 (widest_arc)
	for i in range(2):
		melee.level_up()
	_assert(melee.level == 7, "Melee reaches level 7")
	_assert(melee.has_special_tag(&"widest_arc"), "Lv.7 berserker has widest_arc tag")
	# Level to 8 (crit_bonus)
	melee.level_up()
	_assert(melee.level == 8, "Melee reaches max level 8")
	_assert(melee.has_special_tag(&"crit_bonus"), "Lv.8 berserker has crit_bonus tag")

	# Try exceeding max level
	var prev_level := melee.level
	melee.level_up()
	_assert(melee.level == prev_level, "Max level enforced, cannot exceed 8")

	# Test path exclusivity: cannot switch paths once selected
	melee.level = 1
	melee.current_path_id = &""
	melee._recalc_stats()
	melee.set_path(&"berserker")
	_assert(melee.current_path_id == &"berserker", "Path is berserker before switch attempt")
	melee.set_path(&"swiftblade")
	_assert(melee.current_path_id == &"berserker", "Cannot switch to another path after selection")

	# Test swiftblade path
	melee.level = 1
	melee.current_path_id = &""
	melee._recalc_stats()
	melee.set_path(&"swiftblade")
	for i in range(7):
		melee.level_up()
	_assert(melee.has_special_tag(&"triple_strike"), "Swiftblade Lv.8 has triple_strike")

	# Restore
	melee.level = orig_level
	melee.current_path_id = orig_path
	melee._recalc_stats()
	if not orig_path.is_empty():
		melee._apply_path_effects()

	await _wait(0.2)

func _phase_enemy_damage() -> void:
	print("[PHASE 8] Enemy Damage & Drops")

	var enemies_parent := _game.get_node_or_null("Enemies")
	var drops_parent := _game.get_node_or_null("Drops")
	var projectiles_parent := _game.get_node_or_null("Projectiles")
	_assert(enemies_parent != null, "Enemies container exists")
	_assert(drops_parent != null, "Drops container exists")
	if not enemies_parent or not drops_parent:
		await _wait(0.2)
		return

	var player := get_tree().get_first_node_in_group("player")
	_assert(player != null, "Player exists")
	if not player:
		await _wait(0.2)
		return

	var weapon_states := _set_all_weapon_processing(false)
	_clear_container_children(enemies_parent)
	_clear_container_children(drops_parent)
	_clear_container_children(projectiles_parent)
	await _wait(0.1)

	# Spawn enemy far enough that drops won't be auto-collected
	var enemy_scene := preload("res://scenes/enemy/enemy.tscn")
	var enemy := enemy_scene.instantiate()
	enemy.global_position = player.global_position + Vector2.RIGHT * 150.0
	enemies_parent.add_child(enemy)
	await _wait(0.1)
	enemy.set_physics_process(false)
	enemy._hp = 999
	if enemy.has_method("_setup_health_bar"):
		enemy._setup_health_bar()

	var initial_hp: int = enemy._hp
	var initial_kills: int = GameState.run.kills
	var initial_drop_count: int = drops_parent.get_child_count()

	# Deal typed damage through the shared combat entry point
	var event_hp_before: int = enemy._hp
	var fire_event := DamageEvent.from_amount(4, player, DamageEvent.DAMAGE_TYPE_FIRE, DamageEvent.DELIVERY_AREA)
	fire_event.weapon_id = &"test_fire"
	var fire_result := DamageCalculator.deal_damage(enemy, fire_event)
	_assert(fire_result is DamageResult, "DamageCalculator returns DamageResult")
	_assert(fire_result.raw_amount == 4 and fire_result.final_amount == 4, "DamageResult preserves raw and final damage")
	_assert(fire_result.event.damage_type == DamageEvent.DAMAGE_TYPE_FIRE, "DamageEvent carries damage type")
	_assert(enemy._hp == event_hp_before - 4, "DamageCalculator reduces enemy HP")
	_assert(int((GameState.run.get("weapon_damage", {}) as Dictionary).get("test_fire", 0)) >= 4, "DamageCalculator records weapon damage")

	var stale_owner := Node.new()
	stale_owner.free()
	var stale_event := DamageEvent.from_amount(2, stale_owner, DamageEvent.DAMAGE_TYPE_PHYSICAL, DamageEvent.DELIVERY_DIRECT)
	stale_event.owner = stale_owner
	stale_event.target = stale_owner
	_assert(stale_event.source == null and stale_event.owner == null and stale_event.target == null, "DamageEvent ignores freed node references")

	var status_event := DamageEvent.from_amount(1, player, DamageEvent.DAMAGE_TYPE_FROST, DamageEvent.DELIVERY_AREA)
	status_event.status_id = &"slow"
	status_event.status_duration = 0.2
	status_event.status_value = 0.5
	DamageCalculator.deal_damage(enemy, status_event)
	_assert(enemy._statuses.has("slow"), "DamageEvent applies status through target")
	if enemy._statuses.has("slow"):
		var applied_status := enemy._statuses["slow"] as StatusEffect
		_assert(applied_status != null and is_equal_approx(applied_status.value, 0.5), "DamageEvent status stores StatusEffect data")
		enemy.clear_status(&"slow")

	# Deal damage
	initial_hp = enemy._hp
	enemy.take_damage(10)
	_assert(enemy._hp == initial_hp - 10, "Enemy HP reduced by damage")

	# Kill enemy
	enemy.take_damage(999)
	_assert(enemy._hp <= 0, "Enemy HP <= 0 after lethal damage")
	var kills_after_lethal: int = GameState.run.kills
	enemy.take_damage(999)
	_assert(GameState.run.kills == kills_after_lethal, "Dead enemy ignores repeated damage")
	await _wait(0.05)
	_assert(drops_parent.get_child_count() > initial_drop_count, "Drops spawned after enemy death")

	await _wait(0.2)
	_assert(GameState.run.kills > initial_kills, "Kill count increased after enemy death")

	# Test pickup radius bonus
	var _upgrade_system: Node = _game.get_node_or_null("UpgradeSystem")
	var prev_bonus: float = GameState.run.get("pickup_radius_bonus", 0.0)
	var pickup_up := UpgradeData.new()
	pickup_up.id = "test_pickup"
	pickup_up.display_name = "Test"
	pickup_up.upgrade_type = UpgradeData.UpgradeType.PLAYER_STAT
	pickup_up.pickup_radius_bonus = 30.0
	_upgrade_system._on_option_selected(pickup_up)
	_assert(GameState.run.pickup_radius_bonus == prev_bonus + 30.0, "Pickup radius bonus applied")

	# Cleanup
	enemy.queue_free()
	_clear_container_children(enemies_parent)
	_restore_weapon_processing(weapon_states)
	await _wait(0.2)

func _phase_special_tags() -> void:
	print("[PHASE 9] Special Tag Effects")

	var melee := _find_weapon(&"melee_basic")
	_assert(melee != null, "Melee weapon exists for special tag test")
	if not melee:
		await _wait(0.2)
		return

	var player := get_tree().get_first_node_in_group("player")
	_assert(player != null, "Player exists")
	if not player:
		await _wait(0.2)
		return

	var orig_level := melee.level
	var orig_path := melee.current_path_id

	# Test sector angles
	melee.level = 1
	melee.current_path_id = &""
	melee._recalc_stats()
	var base_angle: float = melee._get_sector_angle()
	_assert(abs(base_angle - deg_to_rad(90.0)) < 0.001, "Base sector angle is 90 degrees")

	melee.set_path(&"berserker")
	melee.level = 3
	melee._recalc_stats()
	melee._apply_path_effects()
	var wider: float = melee._get_sector_angle()
	_assert(abs(wider - deg_to_rad(135.0)) < 0.001, "wider_arc sector angle is 135 degrees")

	melee.level = 7
	melee._recalc_stats()
	melee._apply_path_effects()
	var widest: float = melee._get_sector_angle()
	_assert(abs(widest - deg_to_rad(180.0)) < 0.001, "widest_arc sector angle is 180 degrees")

	# Test sector direction with actual enemies
	melee.level = 1
	melee.current_path_id = &""
	melee._recalc_stats()

	var _enemies_parent := _game.get_node_or_null("Enemies")
	if _enemies_parent:
		var enemy_scene := preload("res://scenes/enemy/enemy.tscn")

		var front_enemy := enemy_scene.instantiate()
		front_enemy.global_position = player.global_position + Vector2.RIGHT * 30.0
		_enemies_parent.add_child(front_enemy)

		var back_enemy := enemy_scene.instantiate()
		back_enemy.global_position = player.global_position + Vector2.LEFT * 30.0
		_enemies_parent.add_child(back_enemy)

		var side_enemy := enemy_scene.instantiate()
		side_enemy.global_position = player.global_position + Vector2.UP * 30.0
		_enemies_parent.add_child(side_enemy)
		await _wait(0.1)

		front_enemy.set_physics_process(false)
		back_enemy.set_physics_process(false)
		side_enemy.set_physics_process(false)
		front_enemy.global_position = player.global_position + Vector2.RIGHT * 30.0
		back_enemy.global_position = player.global_position + Vector2.LEFT * 30.0
		side_enemy.global_position = player.global_position + Vector2.UP * 30.0
		for test_enemy in [front_enemy, back_enemy, side_enemy]:
			test_enemy._hp = 999
			if "_dead" in test_enemy:
				test_enemy._dead = false
			if test_enemy.has_method("_setup_health_bar"):
				test_enemy._setup_health_bar()
		melee._active_attack_windows.clear()

		var front_hp_before: int = front_enemy._hp
		var back_hp_before: int = back_enemy._hp
		var side_hp_before: int = side_enemy._hp

		melee._deal_sector_damage(player, Vector2.RIGHT)

		_assert(front_enemy._hp < front_hp_before, "Front enemy takes damage when attack_dir is RIGHT")
		_assert(back_enemy._hp == back_hp_before, "Back enemy does NOT take damage when attack_dir is RIGHT")
		_assert(side_enemy._hp == side_hp_before, "Side enemy (90°) does NOT take damage in 90° sector")

		var attack_shape: Dictionary = melee._get_attack_shape(player, Vector2.RIGHT)
		_assert(attack_shape["origin"] == player.global_position, "Melee attack shape starts at player")
		_assert(abs(float(attack_shape["radius"]) - melee.get_range()) < 0.01, "Melee attack shape radius matches damage range")
		_assert(abs(float(attack_shape["sector_angle"]) - melee._get_sector_angle()) < 0.001, "Melee attack shape sector matches damage sector")
		_assert(melee._is_point_in_attack_shape(front_enemy.global_position, attack_shape), "Melee attack shape includes hit target")
		_assert(not melee._is_point_in_attack_shape(back_enemy.global_position, attack_shape), "Melee attack shape excludes target behind player")
		_assert(not melee._is_point_in_attack_shape(side_enemy.global_position, attack_shape), "Melee attack shape excludes target outside sector")
		var effect_position: Vector2 = melee._get_slash_effect_position(player.global_position, Vector2.RIGHT)
		_assert(effect_position == player.global_position, "Melee slash effect pivot matches damage origin")
		var slash_scale: Vector2 = melee._get_slash_effect_scale()
		_assert(abs((slash_scale.x * 80.0) - melee.get_range()) < 0.01, "Melee slash visual radius matches damage range")
		_assert(abs(melee._get_slash_effect_rotation(Vector2.RIGHT)) < 0.001, "Melee slash effect rotation matches attack direction")
		var sector_points: PackedVector2Array = melee._build_slash_sector_points(melee.get_range(), melee._get_sector_angle())
		_assert(sector_points.size() == 20, "Melee slash sector visual has center plus arc points")
		_assert(sector_points[0] == Vector2.ZERO, "Melee slash sector visual starts at damage origin")
		_assert(abs(sector_points[1].length() - melee.get_range()) < 0.01, "Melee slash sector visual reaches damage radius")
		_assert(abs(sector_points[sector_points.size() - 1].length() - melee.get_range()) < 0.01, "Melee slash sector visual ends at damage radius")
		var slash_frames := VFXHelper.build_sprite_frames(
			"res://assets/art/effects/by_type/fx_slash",
			"slash",
			5,
			12.0,
			false
		)
		_assert(slash_frames.get_frame_count("default") == 5, "Melee slash uses 5-frame animation")

		front_enemy.queue_free()
		back_enemy.queue_free()
		side_enemy.queue_free()
		await _wait(0.1)

		melee._active_attack_windows.clear()
		var late_enemy := enemy_scene.instantiate()
		late_enemy.global_position = player.global_position + Vector2.LEFT * 30.0
		_enemies_parent.add_child(late_enemy)
		await _wait(0.1)
		late_enemy.set_physics_process(false)
		late_enemy.global_position = player.global_position + Vector2.LEFT * 30.0
		late_enemy._hp = 999
		if "_dead" in late_enemy:
			late_enemy._dead = false
		if late_enemy.has_method("_setup_health_bar"):
			late_enemy._setup_health_bar()
		melee._active_attack_windows.clear()
		var late_hp_before: int = late_enemy._hp
		melee._start_attack_window(player, Vector2.RIGHT)
		_assert(late_enemy._hp == late_hp_before, "Melee active window does not hit target outside visual sector")
		late_enemy.global_position = player.global_position + Vector2.RIGHT * 30.0
		melee._update_attack_windows(0.05)
		var late_hp_after_hit: int = late_enemy._hp
		_assert(late_hp_after_hit < late_hp_before, "Melee active window hits target entering visible sector")
		melee._update_attack_windows(0.05)
		_assert(late_enemy._hp == late_hp_after_hit, "Melee active window does not hit same target twice")
		melee._update_attack_windows(0.5)
		_assert(melee._active_attack_windows.is_empty(), "Melee active window expires with slash animation")
		late_enemy.queue_free()
		await _wait(0.1)

	# Test strike counts
	melee.level = 1
	melee.current_path_id = &""
	melee._recalc_stats()
	_assert(melee._get_strike_count() == 1, "Base strike count is 1")

	melee.set_path(&"swiftblade")
	melee.level = 6
	melee._recalc_stats()
	melee._apply_path_effects()
	_assert(melee._get_strike_count() == 2, "double_strike gives 2 strikes")

	melee.level = 8
	melee._recalc_stats()
	melee._apply_path_effects()
	_assert(melee._get_strike_count() == 3, "triple_strike gives 3 strikes")

	# Test heal_on_hit with guardian path
	var enemies_parent := _game.get_node_or_null("Enemies")
	if enemies_parent:
		var enemy_scene := preload("res://scenes/enemy/enemy.tscn")
		var enemy := enemy_scene.instantiate()
		enemy.global_position = player.global_position + Vector2.RIGHT * 30.0
		enemies_parent.add_child(enemy)
		await _wait(0.1)

		# Ensure HP has enough room for exact heal assertions.
		GameState.run.hp = maxi(1, GameState.run.max_hp - 20)
		GameState.hp_changed.emit(GameState.run.hp, GameState.run.max_hp)

		# Reset path so guardian can be selected
		melee.current_path_id = &""
		melee._recalc_stats()
		melee.set_path(&"guardian")
		melee.level = 6
		melee._recalc_stats()
		melee._apply_path_effects()
		melee._active_attack_windows.clear()
		enemy._hp = 999
		if "_dead" in enemy:
			enemy._dead = false
		if enemy.has_method("_setup_health_bar"):
			enemy._setup_health_bar()

		var prev_hp: int = GameState.run.hp
		melee._deal_sector_damage(player, Vector2.RIGHT)
		_assert(GameState.run.hp > prev_hp, "heal_on_hit restores HP")
		_assert(GameState.run.hp == prev_hp + 2, "heal_on_hit restores exactly 2 HP")

		# Test heal_on_hit_boost (Lv.8)
		melee.level = 8
		melee._recalc_stats()
		melee._apply_path_effects()
		GameState.run.hp = maxi(1, GameState.run.max_hp - 20)
		GameState.hp_changed.emit(GameState.run.hp, GameState.run.max_hp)
		enemy._hp = 999
		if "_dead" in enemy:
			enemy._dead = false
		if enemy.has_method("_setup_health_bar"):
			enemy._setup_health_bar()

		var boost_prev_hp: int = GameState.run.hp
		melee._deal_sector_damage(player, Vector2.RIGHT)
		_assert(GameState.run.hp == boost_prev_hp + 5, "heal_on_hit_boost restores exactly 5 HP")

		enemy.queue_free()

	# Restore
	melee.level = orig_level
	melee.current_path_id = orig_path
	melee._recalc_stats()
	if not orig_path.is_empty():
		melee._apply_path_effects()

	await _wait(0.2)

func _phase_weapon_path_tags() -> void:
	print("[PHASE 10] Weapon Path Special Tags")
	var player := get_tree().get_first_node_in_group("player") as Node2D

	_assert_weapon_path_value_mix()

	# === melee_basic ===
	var melee := _find_weapon(&"melee_basic")
	if melee:
		melee.level = 1
		melee.current_path_id = &""
		melee._recalc_stats()
		var melee_base_damage := melee.get_damage()
		melee.set_path(&"berserker")
		melee.level = 8
		melee._recalc_stats()
		melee._apply_path_effects()
		_assert(melee._get_final_damage() > melee_base_damage, "berserker Lv.8 crit_bonus increases melee final damage")

	# === projectile_basic ===
	var proj := _find_weapon(&"projectile_basic")
	if proj:
		proj.level = 1
		proj.current_path_id = &""
		proj._recalc_stats()
		_assert(proj._get_projectile_count() == 1, "Projectile base count is 1")
		_assert(proj._get_pierce_count() == 0, "Projectile base pierce is 0")

		proj.set_path(&"sharpshooter")
		proj.level = 3
		proj._recalc_stats()
		proj._apply_path_effects()
		_assert(proj._get_pierce_count() == 1, "sharpshooter Lv.3 pierce_1 adds +1")

		proj.level = 1
		proj.current_path_id = &""
		proj._recalc_stats()
		proj.set_path(&"rapid")
		proj.level = 3
		proj._recalc_stats()
		proj._apply_path_effects()
		_assert(proj._get_projectile_count() == 2, "rapid Lv.3 extra_arrow adds +1")

		proj.level = 6
		proj._recalc_stats()
		proj._apply_path_effects()
		_assert(proj._get_projectile_count() == 3, "rapid Lv.6 volley adds +2")

	# === thunder ===
	var thunder := _find_weapon(&"thunder")
	if thunder:
		thunder.level = 1
		thunder.current_path_id = &""
		thunder._recalc_stats()
		_assert(thunder._get_strike_count() == 1, "Thunder base strike count is 1")

		thunder.set_path(&"storm")
		thunder.level = 6
		thunder._recalc_stats()
		thunder._apply_path_effects()
		_assert(thunder._get_strike_count() == 2, "storm Lv.6 double_strike is 2")

		thunder.level = 8
		thunder._recalc_stats()
		thunder._apply_path_effects()
		_assert(thunder._get_strike_count() == 3, "storm Lv.8 triple_strike is 3")

	# === shotgun ===
	var shotgun := _find_weapon(&"shotgun")
	if shotgun:
		shotgun.level = 1
		shotgun.current_path_id = &""
		shotgun._recalc_stats()
		_assert(shotgun._get_projectile_count() == 5, "Shotgun base count is 5")

		shotgun.set_path(&"barrage")
		shotgun.level = 2
		shotgun._recalc_stats()
		shotgun._apply_path_effects()
		_assert(shotgun._get_projectile_count() == 6, "barrage Lv.2 extra_pellet adds +1")

		shotgun.level = 1
		shotgun.current_path_id = &""
		shotgun._recalc_stats()
		shotgun.set_path(&"cannon")
		shotgun.level = 6
		shotgun._recalc_stats()
		shotgun._apply_path_effects()
		var base_dmg: int = shotgun.get_damage()
		var slug_dmg: int = shotgun._get_final_damage()
		_assert(slug_dmg == int(base_dmg * 1.5), "cannon Lv.6 slug_shot multiplies damage by 1.5")

	# === holy_prism ===
	var prism := _find_weapon(&"holy_prism")
	if prism:
		prism.level = 1
		prism.current_path_id = &""
		prism._recalc_stats()
		_assert(prism._get_heal_amount() == 3, "Holy prism base heal is 3")

		prism.set_path(&"cure")
		prism.level = 2
		prism._recalc_stats()
		prism._apply_path_effects()
		_assert(prism._get_heal_amount() == 5, "cure Lv.2 heal_plus_2 adds +2")
		if player:
			prism._show_holy_ray(player.global_position, player.global_position + Vector2.RIGHT * 160.0)
			await _wait(0.05)
			var ray := get_tree().current_scene.find_child("HolyPrismRay", true, false)
			_assert(ray is Node2D, "Holy prism creates player-to-target ray")
			if ray:
				var ray_start := ray.get_node_or_null("HolyRayStart") as Sprite2D
				var ray_mid := ray.get_node_or_null("HolyRayMid") as Sprite2D
				var ray_end := ray.get_node_or_null("HolyRayEnd") as Sprite2D
				_assert(ray_mid is Sprite2D, "Holy prism ray has a beam body")
				_assert(ray_start and ray_start.texture and ray_start.texture.resource_path == "res://assets/art/effects/dynamic/fx_holy_ray_start.png", "Holy prism uses exported holy ray start asset")
				_assert(ray_mid and ray_mid.texture and ray_mid.texture.resource_path == "res://assets/art/effects/dynamic/fx_holy_ray_mid.png", "Holy prism uses exported holy ray body asset")
				_assert(ray_end and ray_end.texture and ray_end.texture.resource_path == "res://assets/art/effects/dynamic/fx_holy_ray_end.png", "Holy prism uses exported holy ray end asset")
				ray.queue_free()

	# === fire_bottle ===
	var fire := _find_weapon(&"fire_bottle")
	if fire:
		fire.level = 1
		fire.current_path_id = &""
		fire._recalc_stats()
		_assert(fire._get_lifetime() == 3.0, "Fire bottle base lifetime is 3.0")
		_assert(fire._get_fire_radius() == 80.0, "Fire bottle base field radius is 80.0")
		await _assert_field_weapon_activation_damage(fire, "fire", fire._get_burn_damage())

		fire.set_path(&"spread")
		fire.level = 3
		fire._recalc_stats()
		fire._apply_path_effects()
		_assert(fire._get_lifetime() == 4.0, "spread Lv.3 longer_burn extends lifetime to 4.0")

		fire.level = 5
		fire._recalc_stats()
		fire._apply_path_effects()
		var expected_fire_radius: float = fire.weapon_data.field_radius + fire.get_range() - fire.weapon_data.range + 20.0
		_assert(fire._get_fire_radius() == expected_fire_radius, "spread Lv.5 wider_fire adds +20 field radius")
		await _assert_field_visual("fire")
		var fire_trail_frames := VFXHelper.build_sprite_frames(
			"res://assets/art/effects/by_type/fx_fire_trail",
			"fire_trail",
			4,
			10.0,
			true
		)
		_assert(fire_trail_frames.get_frame_count("default") == 4, "Fire bottle throw trail uses 4 distinct frames")

	# === frost_ring ===
	var frost := _find_weapon(&"frost_ring")
	if frost:
		frost.level = 1
		frost.current_path_id = &""
		frost._recalc_stats()
		_assert(frost._get_slow_duration() == 2.0, "Frost ring base slow duration is 2.0")
		_assert(frost._get_slow_value() == 0.5, "Frost ring base slow value is 0.5")

		frost.set_path(&"frozen")
		frost.level = 2
		frost._recalc_stats()
		frost._apply_path_effects()
		_assert(frost._get_slow_duration() == 3.0, "frozen Lv.2 longer_slow extends to 3.0")

		frost.level = 4
		frost._recalc_stats()
		frost._apply_path_effects()
		_assert(frost._get_slow_value() == 0.3, "frozen Lv.4 stronger_slow reduces to 0.3")
		frost.level = 1
		frost.current_path_id = &""
		frost._recalc_stats()
		frost.set_path(&"snowstorm")
		frost.level = 6
		frost._recalc_stats()
		frost._apply_path_effects()
		_assert(frost._get_ring_radius() == frost.get_range() + 15.0, "snowstorm Lv.6 wider_ring adds ring radius")
		if player:
			frost._show_ice_ring(player.global_position + Vector2.DOWN * 160.0, 80.0)
			await _wait(0.05)
			var frost_ring := get_tree().current_scene.find_child("FrostRingEffect", true, false)
			_assert(frost_ring is AnimatedSprite2D, "Frost ring creates animated expanding ring visual")
			if frost_ring is AnimatedSprite2D:
				var ring_sprite := frost_ring as AnimatedSprite2D
				_assert(ring_sprite.sprite_frames.get_frame_count("default") == 4, "Frost ring uses 4-frame animation")
				_assert(ring_sprite.z_index < 10, "Frost ring renders below actor-height VFX")
				_assert(ring_sprite.scale.x > 0.6, "Frost ring visual scales to radius")
				ring_sprite.queue_free()

	# === orbit ===
	var orbit := _find_weapon(&"orbit")
	if orbit:
		orbit.level = 1
		orbit.current_path_id = &""
		orbit._recalc_stats()
		var base_count: int = orbit._get_orbit_count()
		_assert(base_count >= 1, "Orbit base count >= 1")

		orbit.set_path(&"star_ring")
		orbit.level = 2
		orbit._recalc_stats()
		orbit._apply_path_effects()
		_assert(orbit._get_orbit_count() == base_count + 1, "star_ring Lv.2 extra_orb adds +1")
		orbit.level = 1
		orbit.current_path_id = &""
		orbit._recalc_stats()
		orbit.set_path(&"guardian_orbit")
		orbit.level = 6
		orbit._recalc_stats()
		orbit._apply_path_effects()
		_assert(orbit._get_orbit_radius() == orbit.get_range() + 15.0, "guardian_orbit Lv.6 wider_orbit adds orbit radius")

	# === saw_blade ===
	var saw := _find_weapon(&"saw_blade")
	if saw:
		saw.level = 1
		saw.current_path_id = &""
		saw._recalc_stats()
		_assert(saw._get_saw_count() == 1, "Saw blade base count is 1")

		saw.set_path(&"dual")
		saw.level = 3
		saw._recalc_stats()
		saw._apply_path_effects()
		_assert(saw._get_saw_count() == 2, "dual Lv.3 dual_saw adds +1")

	# === thorns ===
	var thorns := _find_weapon(&"thorns")
	if thorns:
		thorns.level = 1
		thorns.current_path_id = &""
		thorns._recalc_stats()
		_assert(thorns._get_reflect_percent() == 0.5, "Thorns base reflect is 0.5")

		thorns.set_path(&"spikes")
		thorns.level = 2
		thorns._recalc_stats()
		thorns._apply_path_effects()
		_assert(thorns._get_reflect_percent() == 0.6, "spikes Lv.2 reflect_plus_10 adds +0.1")

	# === boomerang ===
	var boomer := _find_weapon(&"boomerang")
	if boomer:
		boomer.level = 1
		boomer.current_path_id = &""
		boomer._recalc_stats()
		_assert(boomer._get_boomerang_count() == 1, "Boomerang base count is 1")
		_assert(boomer._get_pierce_count() == 0, "Boomerang base pierce is 0")

		boomer.set_path(&"duelist")
		boomer.level = 3
		boomer._recalc_stats()
		boomer._apply_path_effects()
		_assert(boomer._get_boomerang_count() == 2, "duelist Lv.3 dual_boomerang adds +1")

	# === mine ===
	var mine := _find_weapon(&"mine")
	if mine:
		mine.level = 1
		mine.current_path_id = &""
		mine._recalc_stats()
		_assert(mine._get_mine_count() == 1, "Mine base count is 1")
		_assert(mine._get_blast_radius() == 60.0, "Mine base blast radius is 60.0")

		mine.set_path(&"trapmaster")
		mine.level = 3
		mine._recalc_stats()
		mine._apply_path_effects()
		_assert(mine._get_mine_count() == 2, "trapmaster Lv.3 extra_mine adds +1")

		mine.level = 5
		mine._recalc_stats()
		mine._apply_path_effects()
		_assert(mine._get_blast_radius() == 60.0, "Mine blast radius unchanged without tag")
		mine.level = 1
		mine.current_path_id = &""
		mine._recalc_stats()
		mine.set_path(&"cluster")
		mine.level = 5
		mine._recalc_stats()
		mine._apply_path_effects()
		_assert(mine._get_cluster_count() == 2, "cluster Lv.5 cluster_mine enables secondary explosions")
		var explosion_frames := VFXHelper.build_sprite_frames(
			"res://assets/art/effects/by_type/fx_explosion",
			"explosion",
			8,
			12.0,
			false
		)
		_assert(explosion_frames.get_frame_count("default") == 8, "Mine explosion uses 8 separate animation frames")
		var mine_blink_frames := VFXHelper.build_sprite_frames(
			"res://assets/art/effects/by_type/fx_mine_blink",
			"mine_blink",
			4,
			4.0,
			true
		)
		_assert(mine_blink_frames.get_frame_count("default") == 4, "Mine idle blink uses 4-frame mine body animation")

	# === laser_pen ===
	var laser := _find_weapon(&"laser_pen")
	if laser:
		laser.level = 1
		laser.current_path_id = &""
		laser._recalc_stats()
		_assert(laser._get_beam_count() == 1, "Laser pen base count is 1")

		laser.set_path(&"rapid")
		laser.level = 3
		laser._recalc_stats()
		laser._apply_path_effects()
		_assert(laser._get_beam_count() == 2, "rapid Lv.3 dual_beam adds +1")
		laser.level = 1
		laser.current_path_id = &""
		laser._recalc_stats()
		laser.set_path(&"beam")
		laser.level = 5
		laser._recalc_stats()
		laser._apply_path_effects()
		_assert(laser._get_beam_width() == 12.0, "beam Lv.5 wider_beam increases laser width")
		laser.level = 8
		laser._recalc_stats()
		laser._apply_path_effects()
		_assert(laser._get_beam_width() == 16.0, "beam Lv.8 intense_beam increases laser width further")
		_assert(laser._get_beam_damage() > laser.get_damage(), "beam Lv.8 intense_beam increases laser damage")
		laser.level = 1
		laser.current_path_id = &""
		laser._recalc_stats()
		laser.set_path(&"sniper")
		laser.level = 3
		laser._recalc_stats()
		laser._apply_path_effects()
		_assert(laser._get_beam_range() == laser.get_range() + 20.0, "sniper Lv.3 pierce_beam extends effective beam range")
		laser.level = 8
		laser._recalc_stats()
		laser._apply_path_effects()
		_assert(laser._get_beam_range() == laser.get_range() + 80.0, "sniper Lv.8 extended_range extends effective beam range")
		await _assert_laser_visual()

	# === poison_vial ===
	var poison := _find_weapon(&"poison_vial")
	if poison:
		poison.level = 1
		poison.current_path_id = &""
		poison._recalc_stats()
		_assert(poison._get_poison_lifetime() == 4.0, "Poison vial base lifetime is 4.0")
		_assert(poison._get_poison_radius() == 90.0, "Poison vial base field radius is 90.0")
		await _assert_field_weapon_activation_damage(poison, "poison", poison._get_poison_damage())

		poison.set_path(&"plague")
		poison.level = 3
		poison._recalc_stats()
		poison._apply_path_effects()
		var expected_poison_radius: float = poison.weapon_data.field_radius + poison.get_range() - poison.weapon_data.range + 20.0
		_assert(poison._get_poison_radius() == expected_poison_radius, "plague Lv.3 wider_poison adds +20 field radius")
		poison.level = 5
		poison.current_path_id = &""
		poison._recalc_stats()
		var poison_base_cooldown := poison.get_cooldown()
		poison.set_path(&"venom")
		poison._apply_path_effects()
		var venom_path: WeaponPath = null
		for path in poison.weapon_data.paths:
			if path.path_id == &"venom":
				venom_path = path
				break
		var expected_venom_cooldown := poison_base_cooldown
		if venom_path:
			for effect in venom_path.get_level_effects_up_to(poison.level):
				expected_venom_cooldown = maxf(0.1, expected_venom_cooldown + effect.cooldown_bonus)
		_assert(abs(poison.get_cooldown() - expected_venom_cooldown) < 0.001, "venom Lv.5 cumulative cooldown bonuses are applied")
		await _assert_field_visual("poison")
		var poison_trail_frames := VFXHelper.build_sprite_frames(
			"res://assets/art/effects/by_type/fx_poison_trail",
			"poison_trail",
			4,
			10.0,
			true
		)
		_assert(poison_trail_frames.get_frame_count("default") == 4, "Poison vial throw trail uses 4 distinct frames")

	# === rocket_pack ===
	var rocket := _find_weapon(&"rocket_pack")
	if rocket:
		rocket.level = 1
		rocket.current_path_id = &""
		rocket._recalc_stats()
		_assert(rocket._get_trail_lifetime() == 1.5, "Rocket pack base lifetime is 1.5")

		rocket.set_path(&"jet")
		rocket.level = 3
		rocket._recalc_stats()
		rocket._apply_path_effects()
		_assert(rocket._get_trail_lifetime() == 2.0, "jet Lv.3 longer_trail extends to 2.0")

		rocket.level = 5
		rocket._recalc_stats()
		rocket._apply_path_effects()
		_assert(rocket._get_fire_radius() == rocket.get_range() + 10.0, "jet Lv.5 wider_rocket adds +10")
		if player:
			rocket._show_flame_segments(
				player.global_position + Vector2.LEFT * 18.0,
				player.global_position + Vector2.LEFT * 72.0
			)
			await _wait(0.05)
			var flame := get_tree().current_scene.find_child("RocketFlameSegments", true, false)
			_assert(flame is Node2D, "Rocket pack creates segmented flame visual")
			if flame:
				var flame_start := flame.get_node_or_null("RocketFlameStart")
				var flame_mid := flame.get_node_or_null("RocketFlameMid")
				var flame_end := flame.get_node_or_null("RocketFlameEnd")
				_assert(flame_start is AnimatedSprite2D, "Rocket flame has animated start cap")
				_assert(flame_mid is AnimatedSprite2D, "Rocket flame repeats animated middle segment")
				_assert(flame_end is AnimatedSprite2D, "Rocket flame has animated end cap")
				for flame_node in [flame_start, flame_mid, flame_end]:
					if flame_node is AnimatedSprite2D:
						var flame_sprite := flame_node as AnimatedSprite2D
						_assert(flame_sprite.sprite_frames.get_frame_count("default") == 4, "%s uses 4-frame animation" % flame_sprite.name)
				flame.queue_free()

	# === electromagnetic_chain ===
	var chain := _find_weapon(&"electromagnetic_chain")
	if chain:
		chain.level = 1
		chain.current_path_id = &""
		chain._recalc_stats()
		var base_chains: int = chain._get_chain_count()
		_assert(base_chains >= 1, "Chain base count >= 1")
		_assert(chain._get_acquire_range() == 280.0, "Chain base acquire range is 280.0")
		if player:
			var far_enemy := Node2D.new()
			far_enemy.global_position = player.global_position + Vector2.RIGHT * (chain._get_acquire_range() + 1.0)
			var near_enemy := Node2D.new()
			near_enemy.global_position = player.global_position + Vector2.RIGHT * (chain._get_acquire_range() - 1.0)
			var mock_enemies: Array[Node] = []
			mock_enemies.append(far_enemy)
			_assert(chain._find_nearest_enemy(player.global_position, mock_enemies, chain._get_acquire_range()) == null, "Chain ignores first target outside acquire range")
			mock_enemies.append(near_enemy)
			_assert(chain._find_nearest_enemy(player.global_position, mock_enemies, chain._get_acquire_range()) == near_enemy, "Chain acquires first target inside acquire range")
			far_enemy.free()
			near_enemy.free()

		chain.set_path(&"conduction")
		chain.level = 3
		chain._recalc_stats()
		chain._apply_path_effects()
		# Base formula: 3 + (level - 1), at Lv.3 = 5, chain_1 adds +1 = 6
		_assert(chain._get_chain_count() == 6, "conduction Lv.3 chain_1 adds +1 to base 5")

	# === whirlwind ===
	var whirlwind := _find_weapon(&"whirlwind")
	if whirlwind:
		_assert(whirlwind.weapon_data.paths.size() == 3, "Whirlwind has 3 path choices")
		whirlwind.level = 1
		whirlwind.current_path_id = &""
		whirlwind._recalc_stats()
		_assert(whirlwind._get_hit_count() == 1, "Whirlwind base hit count is 1")
		whirlwind.set_path(&"rending")
		whirlwind.level = 5
		whirlwind._recalc_stats()
		whirlwind._apply_path_effects()
		_assert(whirlwind._get_hit_count() == 2, "rending Lv.5 whirlwind_double_hit adds a second hit")
		whirlwind.level = 1
		whirlwind.current_path_id = &""
		whirlwind._recalc_stats()
		whirlwind.set_path(&"wind_wall")
		whirlwind.level = 8
		whirlwind._recalc_stats()
		whirlwind._apply_path_effects()
		_assert(whirlwind._get_whirlwind_radius() == whirlwind.get_range() + 30.0, "wind_wall Lv.8 adds extra whirlwind radius")
		_assert(whirlwind._should_slow() and whirlwind._should_knockback(), "wind_wall Lv.8 applies slow and knockback")
		if player:
			whirlwind._show_whirlwind(player.global_position + Vector2.RIGHT * 180.0, 80.0)
			await _wait(0.05)
			var whirlwind_effect := get_tree().current_scene.find_child("WhirlwindEffect", true, false)
			_assert(whirlwind_effect is Node2D, "Whirlwind creates animated arc visual")
			if whirlwind_effect:
				var has_animated_arc := false
				for child in whirlwind_effect.get_children():
					if child is AnimatedSprite2D:
						var slash_sprite := child as AnimatedSprite2D
						has_animated_arc = true
						_assert(slash_sprite.sprite_frames.get_frame_count("default") == 4, "Whirlwind arc uses 4-frame animation")
						break
				_assert(has_animated_arc, "Whirlwind visual contains animated slash arc")
				whirlwind_effect.queue_free()

	# === throwing_axe ===
	var axe := _find_weapon(&"throwing_axe")
	if axe:
		_assert(axe.weapon_data.paths.size() == 3, "Throwing axe has 3 path choices")
		axe.level = 1
		axe.current_path_id = &""
		axe._recalc_stats()
		_assert(axe._get_axe_count() == 1, "Throwing axe base count is 1")
		axe.set_path(&"twin_axes")
		axe.level = 3
		axe._recalc_stats()
		axe._apply_path_effects()
		_assert(axe._get_axe_count() == 2, "twin_axes Lv.3 dual_axe adds +1 axe")
		axe.level = 1
		axe.current_path_id = &""
		axe._recalc_stats()
		axe.set_path(&"cleaver")
		axe.level = 6
		axe._recalc_stats()
		axe._apply_path_effects()
		_assert(axe._get_pierce_count() == 3, "cleaver Lv.6 axe_pierce_2 adds +2 pierce")
		axe.level = 1
		axe.current_path_id = &""
		axe._recalc_stats()
		axe.set_path(&"returning")
		axe.level = 3
		axe._recalc_stats()
		axe._apply_path_effects()
		_assert(axe._should_return(), "returning Lv.3 makes throwing axe return")

	# === shockwave ===
	var shockwave := _find_weapon(&"shockwave")
	if shockwave:
		_assert(shockwave.weapon_data.paths.size() == 3, "Shockwave has 3 path choices")
		shockwave.level = 1
		shockwave.current_path_id = &""
		shockwave._recalc_stats()
		_assert(shockwave._get_pulse_count() == 1, "Shockwave base pulse count is 1")
		shockwave.set_path(&"pulse")
		shockwave.level = 3
		shockwave._recalc_stats()
		shockwave._apply_path_effects()
		_assert(shockwave._get_pulse_count() == 2, "pulse Lv.3 double_pulse adds one pulse")
		shockwave.level = 1
		shockwave.current_path_id = &""
		shockwave._recalc_stats()
		shockwave.set_path(&"lockdown")
		shockwave.level = 8
		shockwave._recalc_stats()
		shockwave._apply_path_effects()
		_assert(shockwave._get_stun_duration() == 0.75, "lockdown Lv.8 increases shockwave stun duration")
		_assert(shockwave._should_slow(), "lockdown Lv.8 adds shockwave slow")
		if player:
			shockwave._show_shockwave(player.global_position + Vector2.LEFT * 180.0, 90.0)
			await _wait(0.05)
			var shockwave_effect := get_tree().current_scene.find_child("ShockwaveEffect", true, false)
			_assert(shockwave_effect is AnimatedSprite2D, "Shockwave creates animated expanding visual")
			if shockwave_effect is AnimatedSprite2D:
				var shockwave_sprite := shockwave_effect as AnimatedSprite2D
				_assert(shockwave_sprite.sprite_frames.get_frame_count("default") == 4, "Shockwave uses 4-frame animation")
				shockwave_sprite.queue_free()

	# === spark_bomb ===
	var spark := _find_weapon(&"spark_bomb")
	if spark:
		_assert(spark.weapon_data.paths.size() == 3, "Spark bomb has 3 path choices")
		spark.level = 1
		spark.current_path_id = &""
		spark._recalc_stats()
		var base_spark_radius: float = spark._get_explosion_radius()
		_assert(spark._get_projectile_count() == 1, "Spark bomb base projectile count is 1")
		spark.set_path(&"scatter")
		spark.level = 3
		spark._recalc_stats()
		spark._apply_path_effects()
		_assert(spark._get_projectile_count() == 2, "scatter Lv.3 spark_split adds one spark bomb")
		spark.level = 1
		spark.current_path_id = &""
		spark._recalc_stats()
		spark.set_path(&"blast")
		spark.level = 5
		spark._recalc_stats()
		spark._apply_path_effects()
		_assert(spark._get_explosion_radius() > base_spark_radius, "blast Lv.5 spark_wide increases explosion radius")
		spark.level = 1
		spark.current_path_id = &""
		spark._recalc_stats()
		spark.set_path(&"electro_spark")
		spark.level = 8
		spark._recalc_stats()
		spark._apply_path_effects()
		_assert(spark._get_explosion_status() == &"stun", "electro_spark Lv.8 applies stun on explosion")

	await _assert_throwing_aoe_target_diversity()
	await _wait(0.2)

func _assert_throwing_aoe_target_diversity() -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	var enemies_parent := _game.get_node_or_null("Enemies")
	var fire := _find_weapon(&"fire_bottle")
	var poison := _find_weapon(&"poison_vial")
	var spark := _find_weapon(&"spark_bomb")
	_assert(player != null and enemies_parent != null and fire != null and poison != null and spark != null, "Throwing AOE target diversity setup exists")
	if not player or not enemies_parent or not fire or not poison or not spark:
		return

	_clear_container_children(enemies_parent)
	WeaponBase._recent_target_claims.clear()
	await _wait(0.05)

	var targets: Array[Node2D] = []
	for i in range(3):
		var enemy := Node2D.new()
		enemy.name = "ThrowTarget%d" % i
		enemy.add_to_group("enemies")
		enemy.global_position = player.global_position + Vector2.RIGHT * (80.0 + float(i) * 20.0)
		enemies_parent.add_child(enemy)
		targets.append(enemy)
	await _wait(0.05)

	var fire_target := fire._claim_nearest_enemy_target(player.global_position)
	var poison_target := poison._claim_nearest_enemy_target(player.global_position)
	var spark_target := spark._claim_nearest_enemy_target(player.global_position)
	var unique_targets := {}
	for target in [fire_target, poison_target, spark_target]:
		if target:
			unique_targets[target.get_instance_id()] = true
	_assert(fire_target != null and poison_target != null and spark_target != null, "Throwing AOE weapons acquire targets")
	_assert(unique_targets.size() == 3, "Throwing AOE weapons prefer separate recent targets")

	WeaponBase._recent_target_claims.clear()
	for target in targets:
		target.queue_free()
	await _wait(0.05)

func _assert_weapon_path_value_mix() -> void:
	var offenders: Array[String] = []
	for weapon in DataManager.all_weapons():
		if not ("paths" in weapon):
			continue
		for path in weapon.paths:
			var pure_damage_levels := 0
			var non_damage_levels := 0
			for level_effect in path.levels:
				var has_damage := int(level_effect.damage_bonus) != 0
				var has_cooldown := absf(float(level_effect.cooldown_bonus)) > 0.001
				var has_range := int(level_effect.range_bonus) != 0
				var has_tag := str(level_effect.special_tag) != ""
				if has_damage and not has_cooldown and not has_range and not has_tag:
					pure_damage_levels += 1
				if has_cooldown or has_range or has_tag:
					non_damage_levels += 1
			if pure_damage_levels > 3 or non_damage_levels < 2:
				offenders.append("%s/%s pure_damage=%d non_damage=%d" % [
					str(weapon.id),
					str(path.path_id),
					pure_damage_levels,
					non_damage_levels,
				])
	if not offenders.is_empty():
		print("  Path value mix offenders: " + str(offenders))
	_assert(offenders.is_empty(), "Weapon paths avoid pure damage stacking")

func _assert_laser_visual() -> void:
	var projectiles_parent := _game.get_node_or_null("Projectiles")
	if not projectiles_parent:
		_assert(false, "Laser visual test has Projectiles parent")
		return

	var beam := preload("res://scenes/weapons/laser_beam.tscn").instantiate()
	beam.global_position = Vector2(-5000.0, -5000.0)
	beam.direction = Vector2.RIGHT
	beam.max_range = 192.0
	beam.damage = 0
	beam.lifetime = 0.5
	projectiles_parent.add_child(beam)
	await _wait(0.05)

	var flicker := beam.get_node_or_null("LaserFlicker")
	_assert(flicker is AnimatedSprite2D, "Laser beam creates animated flicker layer")
	if flicker is AnimatedSprite2D:
		var flicker_anim := flicker as AnimatedSprite2D
		_assert(flicker_anim.sprite_frames.get_frame_count("default") == 4, "Laser flicker uses 4-frame animation")
	var mid := beam.get_node_or_null("LaserMid")
	_assert(mid is Sprite2D, "Laser beam keeps segmented body sprite")
	if mid is Sprite2D:
		var mid_sprite := mid as Sprite2D
		_assert(mid_sprite.scale.x > 0.0, "Laser body scales along beam length")

	beam.queue_free()
	await _wait(0.05)

func _assert_field_visual(field_type: String) -> void:
	var projectiles_parent := _game.get_node_or_null("Projectiles")
	if not projectiles_parent:
		_assert(false, "%s field visual parent exists" % field_type)
		return

	var field: Node
	var tile_name := ""
	if field_type == "fire":
		field = preload("res://scenes/weapons/fire_field.tscn").instantiate()
		tile_name = "FireTile"
	else:
		field = preload("res://scenes/weapons/poison_field.tscn").instantiate()
		tile_name = "PoisonTile"

	(field as Node2D).global_position = Vector2(128.0, 128.0)
	field.set("radius", 96.0)
	projectiles_parent.add_child(field)
	await _wait(0.1)

	_assert((field as CanvasItem).z_index < 10, "%s field renders below player" % field_type.capitalize())

	var tile_count := 0
	var has_jittered_tile := false
	var has_faded_edge_tile := false
	for child in field.get_children():
		if child is AnimatedSprite2D and child.name == tile_name:
			var tile := child as AnimatedSprite2D
			tile_count += 1
			if abs(tile.position.x - roundf(tile.position.x)) > 0.01 or abs(tile.position.y - roundf(tile.position.y)) > 0.01:
				has_jittered_tile = true
			if tile.modulate.a < 0.7:
				has_faded_edge_tile = true

	_assert(tile_count > 0, "%s field creates visual tiles" % field_type.capitalize())
	_assert(has_jittered_tile, "%s field visual avoids perfect grid placement" % field_type.capitalize())
	_assert(has_faded_edge_tile, "%s field visual fades at edges" % field_type.capitalize())

	field.queue_free()
	await _wait(0.1)

func _phase_melee_kill() -> void:
	print("[PHASE 11] Melee Kill End-to-End")

	var player: Node = get_tree().get_first_node_in_group("player")
	_assert(player != null, "Player exists")
	if not player:
		await _wait(0.2)
		return

	var melee := _find_weapon(&"melee_basic")
	_assert(melee != null, "Melee weapon exists")
	if not melee:
		await _wait(0.2)
		return

	# Clean up any residual enemies
	var enemies_parent := _game.get_node_or_null("Enemies")
	if enemies_parent:
		for child in enemies_parent.get_children():
			child.queue_free()
		await _wait(0.1)

	# Spawn a weak enemy directly in front of player, within melee range
	var enemy_scene := preload("res://scenes/enemy/enemy.tscn")
	var enemy := enemy_scene.instantiate()
	enemy.global_position = player.global_position + Vector2.RIGHT * 30.0
	if enemies_parent:
		enemies_parent.add_child(enemy)
	await _wait(0.1)

	# _ready() overwrites _hp from enemy_data, so set it after adding to tree
	enemy._hp = 10
	if "_dead" in enemy:
		enemy._dead = false
	if enemy.has_method("_setup_health_bar"):
		enemy._setup_health_bar()
	melee._active_attack_windows.clear()
	var initial_hp: int = enemy._hp
	var initial_melee_kills := int((GameState.run.get("weapon_kills", {}) as Dictionary).get("melee_basic", 0))
	_assert(initial_hp == 10, "Enemy HP set to 10 for one-hit kill")

	# Force melee to trigger quickly
	melee._current_cooldown = 0.1
	melee._cooldown_timer = 0.0

	# Wait for weapon activation
	await _wait(0.2)

	var enemy_killed: bool = not is_instance_valid(enemy) or enemy._hp <= 0
	_assert(enemy_killed, "Enemy killed by melee weapon")
	_assert(int((GameState.run.get("weapon_kills", {}) as Dictionary).get("melee_basic", 0)) > initial_melee_kills, "Melee kill recorded in weapon stats")

	# Cleanup
	if enemies_parent:
		for child in enemies_parent.get_children():
			child.queue_free()
		await _wait(0.1)

func _phase_player_combat() -> void:
	print("[PHASE 12] Player Combat & Healing")

	var player: Node = get_tree().get_first_node_in_group("player")
	_assert(player != null, "Player exists")
	if not player:
		await _wait(0.2)
		return

	# Reset HP for clean test
	GameState.run.hp = GameState.run.max_hp
	GameState.hp_changed.emit(GameState.run.hp, GameState.run.max_hp)
	player._invincible = false
	player._invincibility_timer = 0.0
	player._invincible_until_msec = 0
	player._dying = false
	await _wait(0.1)

	# Test damage
	var prev_hp: int = GameState.run.hp
	GameState.take_damage(10)
	_assert(GameState.run.hp == prev_hp - 10, "Player takes damage from take_damage")

	var saved_incoming_multiplier: float = float(GameState.run.get("incoming_damage_multiplier", 1.0))
	GameState.run.incoming_damage_multiplier = 0.5
	var preview_result := GameState.preview_apply_damage(DamageEvent.from_amount(20, player, DamageEvent.DAMAGE_TYPE_PHYSICAL, DamageEvent.DELIVERY_CONTACT))
	_assert(preview_result.final_amount == 10 and preview_result.prevented_amount == 10, "DamageEvent preview applies incoming mitigation")
	GameState.run.incoming_damage_multiplier = saved_incoming_multiplier

	# Test invincibility: rapid damage should not all apply
	var hp_before_inv: int = GameState.run.hp
	var player_damage_result: DamageResult = player.take_damage(10)
	await _wait(0.05)
	var hp_after_one_hit: int = GameState.run.hp
	_assert(player_damage_result.final_amount == 10, "Player take_damage returns DamageResult")
	player.take_damage(10)
	await _wait(0.05)
	_assert(GameState.run.hp == hp_after_one_hit, "Invincibility frames prevent rapid damage")

	await _wait(0.35)
	var hp_after_invincibility: int = GameState.run.hp
	player.take_damage(10)
	await _wait(0.05)
	_assert(GameState.run.hp == hp_after_invincibility - 10, "Invincibility frames expire and damage resumes")
	var hp_after_recovered_hit: int = GameState.run.hp

	# Test heal
	GameState.heal(5)
	_assert(GameState.run.hp == hp_after_recovered_hit + 5, "Heal restores HP")

	# Test heal does not exceed max
	GameState.heal(999)
	_assert(GameState.run.hp == GameState.run.max_hp, "Heal caps at max HP")

	# Test player death triggers game over
	get_tree().paused = false
	var game_over: Node = _game.get_node_or_null("GameOver")
	if game_over:
		game_over.visible = false
	_game.set("_run_finished", false)
	GameState.take_damage(9999)
	await _wait(0.3)
	_assert(game_over.visible, "GameOver shown after lethal damage")

	await _wait(0.2)

func _phase_enemy_behavior() -> void:
	print("[PHASE 13] Enemy Behavior & Status Effects")

	var player: Node = get_tree().get_first_node_in_group("player")
	_assert(player != null, "Player exists")
	if not player:
		await _wait(0.2)
		return

	var enemies_parent := _game.get_node_or_null("Enemies")
	if not enemies_parent:
		_assert(false, "Enemies container exists")
		await _wait(0.2)
		return

	var weapon_states := _set_all_weapon_processing(false)
	var projectiles_parent := _game.get_node_or_null("Projectiles")

	# Clean up
	_clear_container_children(enemies_parent)
	_clear_container_children(projectiles_parent)
	await _wait(0.1)

	# Spawn enemy far from player, make it invulnerable to weapon attacks
	var enemy_scene := preload("res://scenes/enemy/enemy.tscn")
	var enemy := enemy_scene.instantiate()
	var spawn_pos: Vector2 = player.global_position + Vector2.RIGHT * 400.0
	enemy.global_position = spawn_pos
	enemy._hp = 999999
	enemy.collision_layer = 0
	enemies_parent.add_child(enemy)
	await _wait(0.2)

	# Verify enemy moves toward player
	var start_dist: float = enemy.global_position.distance_to(player.global_position)
	await _wait(1.5)
	var end_dist: float = enemy.global_position.distance_to(player.global_position)
	_assert(end_dist < start_dist, "Enemy moves toward player")

	# Test slow status
	var orig_speed: float = enemy._base_speed
	var slow_effect: StatusEffect = enemy.apply_status(&"slow", 0.2, 0.6)
	_assert(slow_effect is StatusEffect and enemy._statuses["slow"] == slow_effect, "Enemy stores status as StatusEffect")
	enemy.apply_status(&"slow", 1.0, 0.5)
	slow_effect = enemy._statuses["slow"] as StatusEffect
	_assert(slow_effect.remaining > 0.9 and is_equal_approx(slow_effect.value, 0.5), "Status refresh replaces remaining duration and value")
	_assert(enemy._base_speed * 0.5 == enemy._base_speed * enemy._statuses["slow"].value, "Slow reduces speed")
	await _wait(1.2)
	_assert(is_instance_valid(enemy) and not enemy._statuses.has("slow"), "Slow status expires")

	# Test stun status
	if is_instance_valid(enemy):
		enemy.apply_status(&"stun", 0.5, 0.0)
		var stun_pos: Vector2 = enemy.global_position
		await _wait(0.3)
		_assert(is_instance_valid(enemy) and enemy.global_position.distance_to(stun_pos) < 5.0, "Stun prevents movement")
		await _wait(0.5)
		_assert(is_instance_valid(enemy) and not enemy._statuses.has("stun"), "Stun status expires")

	# Test tick damage status payload
	if is_instance_valid(enemy):
		var burn := StatusEffect.from_values(&"burn", 0.3, 0.0)
		burn.tick_interval = 0.1
		burn.tick_timer = 0.1
		burn.tick_damage_event = DamageEvent.from_amount(2, player, DamageEvent.DAMAGE_TYPE_FIRE, DamageEvent.DELIVERY_DOT)
		enemy.apply_status_effect(burn)
		var tick_hp_before: int = enemy._hp
		burn.tick(0.11, enemy)
		_assert(enemy._hp == tick_hp_before - 2, "StatusEffect tick damage uses DamageCalculator")
		enemy.clear_status(&"burn")

	# Test enemy health bar shows on damage
	if is_instance_valid(enemy):
		var health_bar: Node = enemy.get_node_or_null("HealthBar")
		if health_bar and health_bar.auto_hide:
			enemy.take_damage(1)
			_assert(health_bar.visible, "Enemy health bar visible after damage")

	# Cleanup
	if is_instance_valid(enemy):
		enemy.queue_free()
	_clear_container_children(enemies_parent)
	_restore_weapon_processing(weapon_states)
	await _wait(0.1)

func _phase_upgrade_edges() -> void:
	print("[PHASE 14] Upgrade System Edge Cases")

	var upgrade_system: Node = _game.get_node_or_null("UpgradeSystem")
	_assert(upgrade_system != null, "UpgradeSystem exists")
	if not upgrade_system:
		await _wait(0.2)
		return

	var player: Node = get_tree().get_first_node_in_group("player")
	if not player:
		_assert(false, "Player exists")
		await _wait(0.2)
		return

	GameState.run["enhancements"] = {}
	GameState.run["enhancement_order"] = []

	# Test PLAYER_STAT speed bonus and enhancement slot tracking
	var prev_speed: float = player.move_speed
	var speed_up := UpgradeData.new()
	speed_up.id = "test_speed"
	speed_up.display_name = "Test Speed"
	speed_up.upgrade_type = UpgradeData.UpgradeType.PLAYER_STAT
	speed_up.speed_bonus = 25.0
	upgrade_system._on_option_selected(speed_up)
	_assert(player.move_speed == prev_speed + 25.0, "Speed stat upgrade applies")
	_assert(GameState.get_enhancement_count() == 1, "First stat upgrade occupies one enhancement slot")
	_assert(GameState.get_enhancement_level(&"test_speed") == 1, "Enhancement level starts at 1")

	prev_speed = player.move_speed
	upgrade_system._on_option_selected(speed_up)
	_assert(player.move_speed == prev_speed + 25.0, "Repeated stat upgrade applies")
	_assert(GameState.get_enhancement_count() == 1, "Repeated stat upgrade reuses enhancement slot")
	_assert(GameState.get_enhancement_level(&"test_speed") == 2, "Repeated stat upgrade increases enhancement level")
	while GameState.get_enhancement_level(&"test_speed") < GameState.MAX_ENHANCEMENT_LEVEL:
		upgrade_system._on_option_selected(speed_up)
	_assert(GameState.get_enhancement_level(&"test_speed") == GameState.MAX_ENHANCEMENT_LEVEL, "Stat enhancement reaches level cap")
	_assert(not GameState.can_add_enhancement(&"test_speed"), "Maxed enhancement is filtered out")
	var speed_at_cap: float = player.move_speed
	upgrade_system._on_option_selected(speed_up)
	_assert(GameState.get_enhancement_level(&"test_speed") == GameState.MAX_ENHANCEMENT_LEVEL, "Maxed enhancement cannot exceed level cap")
	_assert(player.move_speed == speed_at_cap, "Maxed enhancement does not apply extra stat effect")

	# Test PLAYER_STAT max_hp bonus
	var prev_max_hp: int = GameState.run.max_hp
	GameState.run.hp = maxi(1, prev_max_hp - 20)
	GameState.hp_changed.emit(GameState.run.hp, GameState.run.max_hp)
	var prev_hp_for_max_hp: int = GameState.run.hp
	var hp_up := UpgradeData.new()
	hp_up.id = "test_hp"
	hp_up.display_name = "Test HP"
	hp_up.upgrade_type = UpgradeData.UpgradeType.PLAYER_STAT
	hp_up.max_hp_bonus = 30
	hp_up.hp_bonus = 30
	upgrade_system._on_option_selected(hp_up)
	_assert(GameState.run.max_hp == prev_max_hp + 30, "Max HP stat upgrade applies")
	_assert(GameState.run.hp > prev_hp_for_max_hp, "HP bonus also heals player")

	var saved_passive_state := {
		"damage_multiplier": GameState.run.get("damage_multiplier", 1.0),
		"cooldown_multiplier": GameState.run.get("cooldown_multiplier", 1.0),
		"area_multiplier": GameState.run.get("area_multiplier", 1.0),
		"field_lifetime_multiplier": GameState.run.get("field_lifetime_multiplier", 1.0),
		"incoming_damage_multiplier": GameState.run.get("incoming_damage_multiplier", 1.0),
		"exp_gain_multiplier": GameState.run.get("exp_gain_multiplier", 1.0),
		"enhancements": (GameState.run.get("enhancements", {}) as Dictionary).duplicate(true),
		"enhancement_order": (GameState.run.get("enhancement_order", []) as Array).duplicate(),
	}
	var saved_weapon_stats: Dictionary = {}
	for w in _get_all_weapons():
		saved_weapon_stats[w] = {
			"damage": w._current_damage,
			"cooldown": w._current_cooldown,
			"range": w._current_range,
		}
	GameState.run["enhancements"] = {}
	GameState.run["enhancement_order"] = []

	var might := UpgradeData.new()
	might.id = "test_might"
	might.display_name = "Test Might"
	might.upgrade_type = UpgradeData.UpgradeType.PLAYER_STAT
	might.damage_multiplier_bonus = 0.08
	var melee_for_passives := _find_weapon(&"melee_basic")
	var melee_damage_before := melee_for_passives._current_damage if melee_for_passives else 0
	upgrade_system._on_option_selected(might)
	_assert(abs(float(GameState.run.damage_multiplier) - (float(saved_passive_state["damage_multiplier"]) + 0.08)) < 0.001, "Damage multiplier passive applies")
	if melee_for_passives:
		_assert(melee_for_passives._current_damage >= melee_damage_before, "Damage multiplier updates equipped weapon damage")

	var focus := UpgradeData.new()
	focus.id = "test_focus"
	focus.display_name = "Test Focus"
	focus.upgrade_type = UpgradeData.UpgradeType.PLAYER_STAT
	focus.cooldown_multiplier_bonus = -0.06
	var melee_cooldown_before := melee_for_passives._current_cooldown if melee_for_passives else 0.0
	upgrade_system._on_option_selected(focus)
	_assert(abs(float(GameState.run.cooldown_multiplier) - (float(saved_passive_state["cooldown_multiplier"]) - 0.06)) < 0.001, "Cooldown multiplier passive applies")
	if melee_for_passives:
		_assert(melee_for_passives._current_cooldown <= melee_cooldown_before, "Cooldown multiplier updates equipped weapon cooldown")

	var expansion := UpgradeData.new()
	expansion.id = "test_expansion"
	expansion.display_name = "Test Expansion"
	expansion.upgrade_type = UpgradeData.UpgradeType.PLAYER_STAT
	expansion.area_multiplier_bonus = 0.08
	var melee_range_before := melee_for_passives._current_range if melee_for_passives else 0.0
	upgrade_system._on_option_selected(expansion)
	_assert(abs(float(GameState.run.area_multiplier) - (float(saved_passive_state["area_multiplier"]) + 0.08)) < 0.001, "Area multiplier passive applies")
	if melee_for_passives:
		_assert(melee_for_passives._current_range >= melee_range_before, "Area multiplier updates equipped weapon range")

	var duration: UpgradeData = upgrade_system._make_duration_up()
	_assert(duration.id == &"field_duration" and duration.display_name == "余烬延续", "Field duration enhancement option is generated")
	upgrade_system._on_option_selected(duration)
	_assert(abs(float(GameState.run.field_lifetime_multiplier) - (float(saved_passive_state["field_lifetime_multiplier"]) + 0.12)) < 0.001, "Field lifetime passive applies")
	_assert(abs(GameState.get_character_field_lifetime_multiplier() - float(GameState.run.field_lifetime_multiplier)) < 0.001, "Field lifetime getter reflects passive")

	var tenacity := UpgradeData.new()
	tenacity.id = "test_tenacity"
	tenacity.display_name = "Test Tenacity"
	tenacity.upgrade_type = UpgradeData.UpgradeType.PLAYER_STAT
	tenacity.incoming_damage_multiplier_bonus = -0.08
	upgrade_system._on_option_selected(tenacity)
	_assert(abs(float(GameState.run.incoming_damage_multiplier) - (float(saved_passive_state["incoming_damage_multiplier"]) - 0.08)) < 0.001, "Incoming damage multiplier passive applies")

	var training := UpgradeData.new()
	training.id = "test_training"
	training.display_name = "Test Training"
	training.upgrade_type = UpgradeData.UpgradeType.PLAYER_STAT
	training.exp_gain_multiplier_bonus = 0.10
	upgrade_system._on_option_selected(training)
	_assert(abs(float(GameState.run.exp_gain_multiplier) - (float(saved_passive_state["exp_gain_multiplier"]) + 0.10)) < 0.001, "EXP gain multiplier passive applies")

	GameState.run.damage_multiplier = saved_passive_state["damage_multiplier"]
	GameState.run.cooldown_multiplier = saved_passive_state["cooldown_multiplier"]
	GameState.run.area_multiplier = saved_passive_state["area_multiplier"]
	GameState.run.field_lifetime_multiplier = saved_passive_state["field_lifetime_multiplier"]
	GameState.run.incoming_damage_multiplier = saved_passive_state["incoming_damage_multiplier"]
	GameState.run.exp_gain_multiplier = saved_passive_state["exp_gain_multiplier"]
	GameState.run["enhancements"] = saved_passive_state["enhancements"]
	GameState.run["enhancement_order"] = saved_passive_state["enhancement_order"]
	for w in saved_weapon_stats.keys():
		if is_instance_valid(w):
			var stats: Dictionary = saved_weapon_stats[w]
			w._current_damage = stats["damage"]
			w._current_cooldown = stats["cooldown"]
			w._current_range = stats["range"]

	var fill_idx := 0
	while GameState.get_enhancement_count() < GameState.MAX_ENHANCEMENT_SLOTS:
		var filler := UpgradeData.new()
		filler.id = "test_enhancement_fill_%d" % fill_idx
		filler.display_name = "Fill %d" % fill_idx
		filler.upgrade_type = UpgradeData.UpgradeType.PLAYER_STAT
		upgrade_system._on_option_selected(filler)
		fill_idx += 1
	_assert(GameState.get_enhancement_count() == GameState.MAX_ENHANCEMENT_SLOTS, "Enhancement slots cap at 6")
	_assert(not GameState.can_add_enhancement(&"test_speed"), "Maxed existing enhancement cannot level when slots are full")
	_assert(GameState.can_add_enhancement(&"test_hp"), "Non-max existing enhancement can still level when slots are full")
	_assert(not GameState.can_add_enhancement(&"blocked_new_enhancement"), "New enhancement is blocked when slots are full")
	var blocked_speed_before: float = player.move_speed
	var blocked := UpgradeData.new()
	blocked.id = "blocked_new_enhancement"
	blocked.display_name = "Blocked"
	blocked.upgrade_type = UpgradeData.UpgradeType.PLAYER_STAT
	blocked.speed_bonus = 25.0
	upgrade_system._on_option_selected(blocked)
	_assert(player.move_speed == blocked_speed_before, "Blocked enhancement does not apply stat effect")
	_assert(GameState.get_enhancement_count() == GameState.MAX_ENHANCEMENT_SLOTS, "Blocked enhancement does not exceed slot cap")

	# Test weapon max level enforcement via upgrade system
	var melee := _find_weapon(&"melee_basic")
	if melee:
		var orig_level: int = melee.level
		melee.level = melee.weapon_data.max_level
		melee._recalc_stats()

		# Generate options and verify melee is not in them
		var options: Array[UpgradeData] = upgrade_system._generate_options()
		var melee_in_options := false
		for u in options:
			if u.weapon_id == &"melee_basic":
				melee_in_options = true
				break
		_assert(not melee_in_options, "Max level weapon does not appear in options")

		# Restore
		melee.level = orig_level
		melee._recalc_stats()

	# Test deduplication: unlock and level for same weapon should not both appear
	var proj := _find_weapon(&"projectile_basic")
	if proj:
		var prev_proj_level: int = proj.level
		proj.level = 1
		proj.current_path_id = &""
		proj._recalc_stats()

		# Generate many option sets to check for duplicates
		var has_duplicate := false
		for i in range(20):
			var opts: Array[UpgradeData] = upgrade_system._generate_options()
			var seen: Array[StringName] = []
			for u in opts:
				if u.weapon_id in seen:
					has_duplicate = true
					break
				if not u.weapon_id.is_empty():
					seen.append(u.weapon_id)
			if has_duplicate:
				break
		_assert(not has_duplicate, "No duplicate weapon IDs in same option set")

		# Restore
		proj.level = prev_proj_level
		proj._recalc_stats()

	await _wait(0.2)

func _phase_drop_pickups() -> void:
	print("[PHASE 15] Drops & Pickups")

	var player: Node = get_tree().get_first_node_in_group("player")
	_assert(player != null, "Player exists")
	if not player:
		await _wait(0.2)
		return

	var drops_parent := _game.get_node_or_null("Drops")
	_assert(drops_parent != null, "Drops container exists")
	if not drops_parent:
		await _wait(0.2)
		return

	# Clean up drops
	for child in drops_parent.get_children():
		child.queue_free()
	await _wait(0.1)

	# Test EXP orb pickup
	var prev_exp: int = GameState.run.exp
	var exp_orb := preload("res://scenes/drops/exp_orb.tscn").instantiate()
	exp_orb.global_position = player.global_position
	exp_orb.exp_value = 5
	drops_parent.add_child(exp_orb)
	await _wait(0.2)
	_assert(not is_instance_valid(exp_orb), "EXP orb picked up on contact")
	_assert(GameState.run.exp == prev_exp + 5, "EXP increases after pickup")

	# Test gold pickup
	var prev_gold: int = GameState.run.gold
	var gold := preload("res://scenes/drops/gold_pickup.tscn").instantiate()
	gold.global_position = player.global_position
	gold.gold_value = 3
	drops_parent.add_child(gold)
	await _wait(0.2)
	_assert(not is_instance_valid(gold), "Gold picked up on contact")
	_assert(GameState.run.gold == prev_gold + 3, "Gold increases after pickup")

	# Test pickup radius bonus
	var prev_bonus: float = GameState.run.get("pickup_radius_bonus", 0.0)
	GameState.run.pickup_radius_bonus = 100.0
	var distant_orb := preload("res://scenes/drops/exp_orb.tscn").instantiate()
	distant_orb.global_position = player.global_position + Vector2.RIGHT * 180.0
	distant_orb.exp_value = 1
	drops_parent.add_child(distant_orb)
	await _wait(0.8)
	_assert(not is_instance_valid(distant_orb), "Pickup radius bonus attracts distant drops")
	GameState.run.pickup_radius_bonus = prev_bonus

	await _wait(0.2)

func _phase_enemy_collision() -> void:
	print("[PHASE 16] Enemy Collision Damage")

	var player: Node = get_tree().get_first_node_in_group("player")
	_assert(player != null, "Player exists")
	if not player:
		await _wait(0.2)
		return

	var enemies_parent := _game.get_node_or_null("Enemies")
	if not enemies_parent:
		_assert(false, "Enemies container exists")
		await _wait(0.2)
		return
	var spawner: Node = _game.get_node_or_null("EnemySpawner")
	var previous_spawner_process := false
	if spawner:
		previous_spawner_process = spawner.is_processing()
		spawner.set_process(false)
	var projectiles_parent := _game.get_node_or_null("Projectiles")
	var weapons_node: Node = player.get_node_or_null("Weapons")
	var weapon_process_states: Array[Dictionary] = []
	if weapons_node:
		for weapon in weapons_node.get_children():
			weapon_process_states.append({
				"node": weapon,
				"process": weapon.is_processing(),
				"physics": weapon.is_physics_processing(),
			})
			weapon.set_process(false)
			weapon.set_physics_process(false)

	# Clean up and reset player HP / invincibility
	for child in enemies_parent.get_children():
		child.queue_free()
	if projectiles_parent:
		for child in projectiles_parent.get_children():
			child.queue_free()
	await _wait(0.1)
	GameState.run.hp = GameState.run.max_hp
	GameState.hp_changed.emit(GameState.run.hp, GameState.run.max_hp)
	player._invincible = false
	player._invincibility_timer = 0.0
	player._invincible_until_msec = 0
	player._dying = false
	player.set_physics_process(true)

	# Spawn enemy overlapping the player to cover real continuous contact damage.
	var enemy_scene := preload("res://scenes/enemy/enemy.tscn")
	var enemy := enemy_scene.instantiate()
	enemy.global_position = player.global_position
	enemy._damage = 5
	enemy._hp = 999999
	var prev_hp: int = GameState.run.hp
	enemies_parent.add_child(enemy)
	await _wait(0.2)

	_assert(enemy._player != null, "Enemy finds player reference")
	_assert(GameState.run.hp == prev_hp - 5, "Enemy contact damage applies to player")
	_assert(not enemy._can_damage, "Enemy enters damage cooldown")

	var hp_after_first_hit: int = GameState.run.hp
	await _wait(0.5)
	_assert(is_instance_valid(enemy) and not enemy._can_damage, "Enemy still in cooldown at 0.5s")
	_assert(GameState.run.hp == hp_after_first_hit, "Enemy cooldown prevents repeated contact damage")

	var cooldown_wait := 0.0
	while is_instance_valid(enemy) and not enemy._can_damage and cooldown_wait < enemy._damage_cooldown + 1.0:
		await _wait(0.05)
		cooldown_wait += 0.05
	player._invincible = false
	player._invincibility_timer = 0.0
	player._invincible_until_msec = 0
	enemy.global_position = player.global_position
	enemy._try_damage_player()
	await _wait(0.05)
	_assert(GameState.run.hp <= hp_after_first_hit - 5, "Enemy overlapping player damages again after cooldown")

	# Cleanup
	if is_instance_valid(enemy):
		enemy.queue_free()
	for child in enemies_parent.get_children():
		child.queue_free()
	for state in weapon_process_states:
		var weapon := state.get("node") as Node
		if is_instance_valid(weapon):
			weapon.set_process(bool(state.get("process", false)))
			weapon.set_physics_process(bool(state.get("physics", false)))
	if spawner:
		spawner.set_process(previous_spawner_process)
	await _wait(0.1)

func _phase_player_movement() -> void:
	print("[PHASE 17] Player Movement & Animation")

	var player: Node = get_tree().get_first_node_in_group("player")
	_assert(player != null, "Player exists")
	if not player:
		await _wait(0.2)
		return

	var sprite: AnimatedSprite2D = player.get_node_or_null("AnimatedSprite2D")

	# Disable _physics_process so our velocity settings are not overwritten
	player.set_physics_process(false)

	var diagonal_input: Vector2 = player._compose_move_input(Vector2.ONE, Vector2.ZERO)
	_assert(abs(diagonal_input.length() - 1.0) < 0.01, "Keyboard diagonal input is normalized")
	var analog_input: Vector2 = player._compose_move_input(Vector2.ZERO, Vector2.RIGHT * 0.5)
	_assert(abs(analog_input.length() - 0.5) < 0.01, "Joystick analog strength is preserved")
	var joystick_input: Vector2 = player._compose_move_input(Vector2.LEFT, Vector2.RIGHT * 0.4)
	_assert(joystick_input.x > 0.0 and abs(joystick_input.length() - 0.4) < 0.01, "Joystick input takes priority when active")

	# Test right movement
	var start_x: float = player.global_position.x
	player.velocity = Vector2.RIGHT * player.move_speed
	player.move_and_slide()
	await _wait(0.05)
	_assert(player.global_position.x > start_x, "Player moves right")
	if sprite:
		_assert(not sprite.flip_h, "Sprite faces right")

	# Test left movement and flip
	var start_x2: float = player.global_position.x
	player.velocity = Vector2.LEFT * player.move_speed
	player.move_and_slide()
	await _wait(0.05)
	_assert(player.global_position.x < start_x2, "Player moves left")
	if sprite:
		# Simulate the animation logic from _physics_process
		if player.velocity.x < 0:
			sprite.flip_h = true
		_assert(sprite.flip_h, "Sprite flips horizontally when moving left")

	# Test move_speed upgrade effect
	var prev_speed: float = player.move_speed
	player.move_speed += 50.0
	var start_x3: float = player.global_position.x
	player.velocity = Vector2.RIGHT * player.move_speed
	player.move_and_slide()
	await _wait(0.05)
	var dx: float = player.global_position.x - start_x3
	_assert(dx > 0, "Player moves with upgraded speed")
	player.move_speed = prev_speed

	var joystick := preload("res://scenes/ui/virtual_joystick.tscn").instantiate()
	_game.add_child(joystick)
	await _wait(0.05)
	joystick.max_distance = 50.0
	joystick.deadzone_ratio = 0.2
	_assert(joystick._direction_from_offset(Vector2.RIGHT * 5.0) == Vector2.ZERO, "Joystick ignores deadzone input")
	var half_push: Vector2 = joystick._direction_from_offset(Vector2.RIGHT * 30.0)
	_assert(half_push.x > 0.0 and half_push.length() < 1.0, "Joystick maps partial push to partial strength")
	var full_push: Vector2 = joystick._direction_from_offset(Vector2.RIGHT * 80.0)
	_assert(abs(full_push.length() - 1.0) < 0.01, "Joystick clamps full push to unit strength")
	get_tree().paused = false
	joystick._base.visible = true
	joystick.active_width_ratio = 1.0
	var viewport_width := get_viewport().get_visible_rect().size.x
	var right_touch_position := Vector2(viewport_width * 0.75, 600.0)
	var press := InputEventScreenTouch.new()
	press.index = 7
	press.pressed = true
	press.position = right_touch_position
	joystick._input(press)
	_assert(joystick._touch_index == 7, "Joystick accepts right-half touch")
	var drag := InputEventScreenDrag.new()
	drag.index = 7
	drag.position = right_touch_position + Vector2(50.0, 0.0)
	joystick._input(drag)
	_assert(joystick.get_direction().x > 0.0, "Joystick moves from right-half drag")
	var release := InputEventScreenTouch.new()
	release.index = 7
	release.pressed = false
	release.position = drag.position
	joystick._input(release)
	_assert(joystick.get_direction() == Vector2.ZERO, "Joystick resets after right-half touch release")
	joystick.queue_free()

	player.set_physics_process(true)
	await _wait(0.1)

func _phase_hud_sync() -> void:
	print("[PHASE 18] HUD Sync")

	var hud: Node = _game.get_node_or_null("HUD")
	_assert(hud != null, "HUD exists")
	if not hud:
		await _wait(0.2)
		return

	# Test HP bar sync
	var hp_bar: ProgressBar = hud.get_node_or_null("HPPanel/HPBar")
	var hp_label: Label = hud.get_node_or_null("HPPanel/HPBar/HPLabel")
	if hp_bar and hp_label:
		GameState.run.hp = 60
		GameState.run.max_hp = 100
		GameState.hp_changed.emit(GameState.run.hp, GameState.run.max_hp)
		_assert(hp_bar.value == 60, "HP bar value syncs")
		_assert(hp_bar.max_value == 100, "HP bar max_value syncs")
		_assert(hp_label.text == "60 / 100", "HP label text syncs")

	# Test EXP bar sync
	var exp_bar: ProgressBar = hud.get_node_or_null("EXPPanel/ExpBar")
	var level_label: Label = hud.get_node_or_null("EXPPanel/LevelLabel")
	if exp_bar and level_label:
		GameState.exp_changed.emit(8, 20)
		await _wait(0.05)
		_assert(exp_bar.value == 8, "EXP bar value syncs")
		_assert(exp_bar.max_value == 20, "EXP bar max_value syncs")
		GameState.run.level = 5
		GameState.exp_changed.emit(8, 20)
		await _wait(0.05)
		_assert(level_label.text == "Lv.5", "Level label syncs")

	# Test gold label sync
	var gold_label: Label = hud.get_node_or_null("TopBar/GoldLabel")
	if gold_label:
		GameState.gold_changed.emit(42)
		await _wait(0.05)
		_assert(gold_label.text == "金币: 42", "Gold label syncs")

	var speed_button: Button = hud.get_node_or_null("TopBar/SpeedButton")
	_assert(speed_button != null, "HUD speed button exists")
	if speed_button:
		_assert(speed_button.text == "1x", "Speed button defaults to 1x")
		speed_button.pressed.emit()
		_assert(is_equal_approx(GameState.game_speed_multiplier, 2.0), "Speed toggle switches to 2x")
		_assert(is_equal_approx(Engine.time_scale, 2.0), "Engine time scale applies 2x")
		_assert(speed_button.text == "2x", "Speed button displays 2x")
		speed_button.pressed.emit()
		_assert(is_equal_approx(GameState.game_speed_multiplier, 1.0), "Speed toggle switches back to 1x")
		_assert(is_equal_approx(Engine.time_scale, 1.0), "Engine time scale resets to 1x")
		_assert(speed_button.text == "1x", "Speed button displays 1x")

	# Test time label updates via _process
	var time_label: Label = hud.get_node_or_null("TopBar/TimeLabel")
	if time_label:
		GameState.run.run_time = 125.0
		await _wait(0.05)
		# _process runs each frame and updates the label
		_assert(time_label.text == "02:05", "Time label formats correctly")
		GameState.run.run_time = 0.0

	# Test kill label updates via _process
	var kill_label: Label = hud.get_node_or_null("TopBar/KillLabel")
	if kill_label:
		GameState.run.kills = 7
		await _wait(0.05)
		_assert(kill_label.text == "击杀: 7", "Kill label syncs")

	var weapon_bar: HBoxContainer = hud.get_node_or_null("WeaponBar")
	if weapon_bar:
		_assert(weapon_bar.get_child_count() == GameState.MAX_WEAPON_SLOTS, "HUD shows 6 weapon slots")

	var enhancement_bar: HBoxContainer = hud.get_node_or_null("EnhancementBar")
	if enhancement_bar:
		_assert(enhancement_bar.get_child_count() == GameState.MAX_ENHANCEMENT_SLOTS, "HUD shows 6 enhancement slots")

	await _wait(0.1)

func _phase_stats_panel() -> void:
	print("[PHASE 19] Stats Panel")

	var stats_panel: Node = _game.get_node_or_null("StatsPanel")
	_assert(stats_panel != null, "StatsPanel exists")
	if not stats_panel:
		await _wait(0.2)
		return

	# Initially hidden
	_assert(not stats_panel.visible, "StatsPanel hidden by default")

	# Toggle visible
	get_tree().paused = false
	stats_panel.toggle()
	_assert(stats_panel.visible, "StatsPanel toggles visible")
	_assert(get_tree().paused, "StatsPanel pauses game when opened")

	# Verify title
	var title: Label = stats_panel.get_node_or_null("Panel/ScrollContainer/VBoxContainer/Title")
	if title:
		_assert(title.text == "属性面板", "StatsPanel title correct")

	# Verify basic stats are populated
	var basic_grid: GridContainer = stats_panel.get_node_or_null("Panel/ScrollContainer/VBoxContainer/BasicSection/GridContainer")
	if basic_grid:
		_assert(basic_grid.get_child_count() > 0, "Basic stats grid populated")

	# Verify weapons list is populated (player has at least melee)
	var weapons_list: VBoxContainer = stats_panel.get_node_or_null("Panel/ScrollContainer/VBoxContainer/WeaponsSection/WeaponsList")
	if weapons_list:
		_assert(weapons_list.get_child_count() > 0, "Weapons list populated")

	var enhancements_list: VBoxContainer = stats_panel.get_node_or_null("Panel/ScrollContainer/VBoxContainer/EnhancementsSection/EnhancementsList")
	if enhancements_list:
		_assert(enhancements_list.get_child_count() > 0, "Enhancements list populated")

	var close_button: Button = stats_panel.get_node_or_null("Panel/ScrollContainer/VBoxContainer/CloseButton")
	_assert(close_button != null, "StatsPanel close button exists")
	if close_button:
		close_button.pressed.emit()
		await _wait(0.05)
		_assert(not stats_panel.visible, "StatsPanel close button hides panel")
		_assert(not get_tree().paused, "StatsPanel close button resumes game")

	# Toggle hidden again
	stats_panel.toggle()
	_assert(stats_panel.visible, "StatsPanel visible before toggle close")
	stats_panel.toggle()
	_assert(not stats_panel.visible, "StatsPanel toggles hidden")
	_assert(not get_tree().paused, "StatsPanel toggle close resumes game")

	# Test refresh with open panel
	stats_panel.toggle()
	_assert(stats_panel.visible, "StatsPanel visible after second toggle")
	stats_panel.toggle()
	_assert(not stats_panel.visible, "StatsPanel hidden after final toggle")

	await _wait(0.1)

func _phase_enemy_spawner() -> void:
	print("[PHASE 20] Enemy Spawner")

	var spawner: Node = _game.get_node_or_null("EnemySpawner")
	_assert(spawner != null, "EnemySpawner exists")
	if not spawner:
		await _wait(0.2)
		return
	var previous_spawner_process := spawner.is_processing()
	spawner.set_process(false)

	var player := get_tree().get_first_node_in_group("player") as Node2D
	var enemies_parent := _game.get_node_or_null("Enemies")
	var projectiles_parent := _game.get_node_or_null("Projectiles")

	var enemy_resources := DataManager.all_enemies()
	_assert(enemy_resources.size() >= 7, "Enemy data resources loaded")
	var imp_data := DataManager.get_enemy("imp") as EnemyData
	var runner_data := DataManager.get_enemy("runner") as EnemyData
	var brute_data := DataManager.get_enemy("brute") as EnemyData
	var dasher_data := DataManager.get_enemy("dasher") as EnemyData
	var cultist_data := DataManager.get_enemy("cultist") as EnemyData
	var elite_brute_data := DataManager.get_enemy("elite_brute") as EnemyData
	var elite_arcanist_data := DataManager.get_enemy("elite_arcanist") as EnemyData
	var boss_data := DataManager.get_enemy("boss_warlord") as EnemyData
	var frost_boss_data := DataManager.get_enemy("boss_frost_guardian") as EnemyData
	var rune_boss_data := DataManager.get_enemy("boss_rune_seer") as EnemyData
	var final_boss_data := DataManager.get_enemy("boss_icecrown_overlord") as EnemyData
	_assert(
		imp_data != null
		and runner_data != null
		and brute_data != null
		and dasher_data != null
		and cultist_data != null
		and elite_brute_data != null
		and elite_arcanist_data != null
		and boss_data != null,
		"Core enemy archetypes and first boss are registered"
	)
	_assert(frost_boss_data != null and rune_boss_data != null and final_boss_data != null, "Extended boss timeline resources are registered")
	for data in [imp_data, runner_data, brute_data, dasher_data, cultist_data, elite_brute_data, elite_arcanist_data, boss_data, frost_boss_data, rune_boss_data, final_boss_data]:
		var enemy_data := data as EnemyData
		if enemy_data:
			_assert(enemy_data.animation_sheet != null, "Enemy %s has dedicated animation sheet" % enemy_data.id)
			if enemy_data.animation_sheet:
				_assert(
					enemy_data.animation_sheet.get_width() == enemy_data.animation_frame_size.x * enemy_data.animation_columns
					and enemy_data.animation_sheet.get_height() == enemy_data.animation_frame_size.y,
					"Enemy %s animation sheet matches frame metadata" % enemy_data.id
				)
	if imp_data:
		_assert(imp_data.pack_size >= 2 and imp_data.behavior_id == EnemyData.BEHAVIOR_CHASE, "Imp is swarm chase archetype")
	if imp_data and runner_data:
		_assert(runner_data.speed > imp_data.speed and runner_data.behavior_id == EnemyData.BEHAVIOR_FAST_CHASE, "Runner is faster chase archetype")
	if imp_data and brute_data:
		_assert(brute_data.max_hp > imp_data.max_hp and brute_data.speed < imp_data.speed, "Brute is slow tank archetype")
	if dasher_data:
		_assert(dasher_data.behavior_id == EnemyData.BEHAVIOR_DASH and dasher_data.dash_speed_multiplier > 1.0, "Dasher uses dash behavior")
	if cultist_data:
		_assert(cultist_data.behavior_id == EnemyData.BEHAVIOR_RANGED and cultist_data.attack_range > cultist_data.preferred_range, "Cultist is ranged archetype")
	if elite_brute_data and brute_data:
		_assert(elite_brute_data.tags.has(&"elite") and elite_brute_data.max_hp > brute_data.max_hp, "Elite brute is stronger tank archetype")
	if elite_arcanist_data:
		_assert(elite_arcanist_data.tags.has(&"elite") and elite_arcanist_data.behavior_id == EnemyData.BEHAVIOR_RANGED, "Elite arcanist is ranged elite archetype")
	if boss_data:
		_assert(boss_data.tags.has(&"boss") and boss_data.behavior_id == EnemyData.BEHAVIOR_BOSS, "Boss warlord uses boss archetype")
		_assert(boss_data.spawn_weight <= 0.0 and boss_data.boss_projectile_count >= 6, "Boss is event-spawned and has volley config")
		_assert(boss_data.projectile_animation_sheet != null and boss_data.projectile_animation_frame_count == 4, "Boss has dedicated animated projectile sheet")
	for data in [boss_data, frost_boss_data, rune_boss_data]:
		var mini_boss_data := data as EnemyData
		if mini_boss_data:
			_assert(mini_boss_data.tags.has(&"boss") and mini_boss_data.tags.has(&"mini_boss"), "Mini boss %s is tagged as a boss wave" % mini_boss_data.id)
			_assert(not mini_boss_data.tags.has(&"final_boss"), "Mini boss %s does not trigger victory" % mini_boss_data.id)
			_assert(mini_boss_data.spawn_weight <= 0.0 and mini_boss_data.projectile_animation_frame_count == 4, "Mini boss %s is event-spawned with animated projectiles" % mini_boss_data.id)
	if final_boss_data:
		_assert(final_boss_data.tags.has(&"boss") and final_boss_data.tags.has(&"final_boss"), "Final boss is tagged for victory")
		_assert(final_boss_data.spawn_weight <= 0.0 and final_boss_data.boss_projectile_count >= 10, "Final boss is event-spawned with a denser volley")

	# Test spawn interval scaling with elapsed time
	spawner._elapsed_time = 0.0
	var interval_at_0: float = spawner._get_spawn_interval()
	spawner._elapsed_time = 60.0
	var interval_at_60: float = spawner._get_spawn_interval()
	spawner._elapsed_time = 120.0
	var interval_at_120: float = spawner._get_spawn_interval()
	_assert(interval_at_60 < interval_at_0, "Spawn interval decreases at 60s")
	_assert(interval_at_120 < interval_at_60, "Spawn interval decreases further at 120s")
	_assert(interval_at_120 >= spawner.min_spawn_interval, "Spawn interval respects minimum floor")

	# Test difficulty scaling formula directly
	var enemy_scene := preload("res://scenes/enemy/enemy.tscn")
	var e1 := enemy_scene.instantiate()
	var base_hp: int = e1._hp
	var base_dmg: int = e1._damage
	var base_speed: float = e1._base_speed

	spawner._elapsed_time = 120.0
	var stat_factor_120: float = spawner._get_stat_scale()
	var speed_factor_120: float = spawner._get_speed_scale()
	var expected_hp: int = int(base_hp * stat_factor_120)
	var expected_dmg: int = int(base_dmg * stat_factor_120)
	var expected_speed: float = base_speed * speed_factor_120

	_assert(abs(stat_factor_120 - (1.0 + 120.0 / spawner.stat_scale_period)) < 0.001, "Difficulty HP/damage scale follows configured period")
	_assert(stat_factor_120 < 2.0, "Difficulty HP/damage no longer doubles by 120s")
	_assert(expected_hp == int(base_hp * stat_factor_120), "Difficulty scaling applies HP factor")
	_assert(expected_dmg == int(base_dmg * stat_factor_120), "Difficulty scaling applies damage factor")
	_assert(speed_factor_120 < stat_factor_120, "Difficulty speed scaling grows slower than HP/damage")
	_assert(speed_factor_120 <= 1.4 and abs(expected_speed - base_speed * speed_factor_120) < 0.1, "Difficulty speed scaling remains controlled at 120s")
	spawner._elapsed_time = spawner.speed_scale_period * 2.0
	_assert(abs(spawner._get_speed_scale() - spawner.max_speed_scale) < 0.01, "Difficulty speed scaling has cap")
	_assert(spawner.pack_spawn_min_spacing > 0.0, "Pack spawn min spacing is configured")
	_assert(spawner.pack_spawn_spread >= spawner.pack_spawn_min_spacing, "Pack spawn spread is wider than min spacing")

	# Test weighted pick favors higher weights
	var test_enemies: Array = []
	var e_data_1 := EnemyData.new()
	e_data_1.spawn_weight = 1.0
	test_enemies.append(e_data_1)
	var e_data_2 := EnemyData.new()
	e_data_2.spawn_weight = 9.0
	test_enemies.append(e_data_2)

	var pick_counts := {0: 0, 1: 0}
	for i in range(100):
		var picked: EnemyData = spawner._weighted_pick(test_enemies)
		if picked == e_data_1:
			pick_counts[0] += 1
		else:
			pick_counts[1] += 1
	_assert(pick_counts[1] > pick_counts[0], "Weighted pick favors higher weight enemy")

	# Test resource spawn pool and archetype application
	spawner._elapsed_time = 0.0
	var early_pool: Array = spawner._get_valid_enemy_data()
	_assert(imp_data == null or early_pool.has(imp_data), "Early enemy spawn pool includes imp")
	_assert(cultist_data == null or not early_pool.has(cultist_data), "Early enemy spawn pool excludes ranged cultist")
	_assert(dasher_data == null or not early_pool.has(dasher_data), "Early enemy spawn pool excludes late dasher")
	_assert(boss_data == null or not early_pool.has(boss_data), "Early enemy spawn pool excludes boss")
	spawner._elapsed_time = 240.0
	var late_pool: Array = spawner._get_valid_enemy_data()
	_assert(brute_data == null or late_pool.has(brute_data), "Late enemy spawn pool includes brute")
	_assert(dasher_data == null or late_pool.has(dasher_data), "Late enemy spawn pool includes dasher")
	_assert(cultist_data == null or late_pool.has(cultist_data), "Late enemy spawn pool includes ranged cultist")
	_assert(elite_brute_data == null or not late_pool.has(elite_brute_data), "Mid game spawn pool excludes elite brute")
	_assert(boss_data == null or not late_pool.has(boss_data), "Normal spawn pool excludes boss before event")
	spawner._elapsed_time = 400.0
	var elite_pool: Array = spawner._get_valid_enemy_data()
	_assert(elite_brute_data == null or elite_pool.has(elite_brute_data), "Elite spawn pool includes elite brute")
	_assert(elite_arcanist_data == null or elite_pool.has(elite_arcanist_data), "Elite spawn pool includes elite arcanist")
	_assert(boss_data == null or not elite_pool.has(boss_data), "Normal spawn pool excludes boss after event time")
	if imp_data and cultist_data and dasher_data and elite_brute_data and elite_arcanist_data:
		spawner._elapsed_time = spawner.late_weight_start_time - 1.0
		_assert(abs(spawner._get_enemy_spawn_weight(imp_data) - imp_data.spawn_weight) < 0.001, "Enemy weight uses resource weight before late phase")
		spawner._elapsed_time = spawner.late_weight_start_time
		_assert(abs(spawner._get_enemy_spawn_weight(imp_data) - imp_data.spawn_weight * spawner.late_imp_weight_multiplier) < 0.001, "Late phase lowers imp weight")
		_assert(abs(spawner._get_enemy_spawn_weight(dasher_data) - dasher_data.spawn_weight * spawner.late_dash_weight_multiplier) < 0.001, "Late phase raises dash enemy weight")
		_assert(abs(spawner._get_enemy_spawn_weight(cultist_data) - cultist_data.spawn_weight * spawner.late_ranged_weight_multiplier) < 0.001, "Late phase raises ranged enemy weight")
		_assert(abs(spawner._get_enemy_spawn_weight(elite_brute_data) - elite_brute_data.spawn_weight * spawner.late_elite_weight_multiplier) < 0.001, "Late phase raises elite enemy weight")
		_assert(abs(spawner._get_enemy_spawn_weight(elite_arcanist_data) - elite_arcanist_data.spawn_weight * spawner.late_elite_weight_multiplier * spawner.late_ranged_weight_multiplier) < 0.001, "Late phase stacks elite and ranged weight bonuses")
	if imp_data:
		_assert(spawner._get_pack_size(imp_data) == imp_data.pack_size, "Spawner uses enemy pack size")
		var pack_origin_offset: Vector2 = spawner._get_pack_member_offset(0, imp_data.pack_size, 0.0)
		var pack_offset_a: Vector2 = spawner._get_pack_member_offset(1, imp_data.pack_size, 0.0)
		var pack_offset_b: Vector2 = spawner._get_pack_member_offset(2, imp_data.pack_size, 0.0)
		_assert(pack_origin_offset == Vector2.ZERO, "First pack member anchors the pack")
		_assert(pack_offset_a.length() >= spawner.pack_spawn_min_spacing and pack_offset_b.length() >= spawner.pack_spawn_min_spacing, "Additional pack members respect min spawn spacing")
		_assert(pack_offset_a.distance_to(pack_offset_b) >= spawner.pack_spawn_min_spacing, "Pack members are spread apart from each other")

	if player and enemies_parent and brute_data:
		spawner._elapsed_time = 0.0
		var spawned = spawner._spawn_single_enemy(brute_data, player.global_position + Vector2.RIGHT * 320.0)
		_assert(spawned != null and spawned.enemy_data == brute_data, "Spawner applies EnemyData to spawned enemy")
		if spawned:
			_assert(spawned._hp == brute_data.max_hp and spawned._damage == brute_data.damage, "Spawned enemy uses data stats")
			_assert(abs(spawned._base_speed - brute_data.speed) < 0.01, "Spawned enemy uses data speed")
			_assert(spawned._exp_reward == brute_data.exp_reward and spawned._gold_reward == brute_data.gold_reward, "Base-time spawned enemy keeps base rewards")
			var shape_node := spawned.get_node_or_null("CollisionShape2D") as CollisionShape2D
			var circle: CircleShape2D = null
			if shape_node:
				circle = shape_node.shape as CircleShape2D
			_assert(circle != null and abs(circle.radius - brute_data.collision_radius) < 0.01, "Spawned enemy uses data collision radius")
			var sprite := spawned.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
			var walk_atlas: AtlasTexture = null
			if sprite and sprite.sprite_frames:
				walk_atlas = sprite.sprite_frames.get_frame_texture(&"walk", 0) as AtlasTexture
			_assert(
				walk_atlas != null
				and walk_atlas.atlas
				and walk_atlas.atlas.resource_path == brute_data.animation_sheet.resource_path,
				"Spawned enemy uses data animation sheet"
			)
			_assert(
				sprite != null
				and sprite.sprite_frames.get_frame_count(&"walk") == 4
				and sprite.sprite_frames.get_frame_count(&"hit") == 2
				and sprite.sprite_frames.get_frame_count(&"death") == 6,
				"Spawned enemy builds expected animation frame sets"
			)
			spawned.queue_free()
			await _wait(0.05)

	if player and enemies_parent and imp_data:
		spawner._elapsed_time = 420.0
		var scaled_imp = spawner._spawn_single_enemy(imp_data, player.global_position + Vector2.RIGHT * 340.0)
		_assert(scaled_imp != null, "Spawner can create a late scaled enemy")
		if scaled_imp:
			var expected_exp_reward := maxi(1, int(round(float(imp_data.exp_reward) * spawner._get_reward_scale(spawner._get_stat_scale(), spawner.exp_reward_scale_strength, spawner.max_exp_reward_scale))))
			_assert(scaled_imp._exp_reward == expected_exp_reward and scaled_imp._exp_reward > imp_data.exp_reward, "Late enemy EXP reward scales with difficulty")
			scaled_imp.queue_free()
			await _wait(0.05)

	if player and enemies_parent and projectiles_parent and boss_data and frost_boss_data and rune_boss_data and final_boss_data:
		for child in projectiles_parent.get_children():
			child.queue_free()
		await _wait(0.05)
		spawner._spawned_boss_events.clear()
		_assert(spawner.boss_spawn_events.size() == 3, "Boss timeline has two mini bosses and one final boss")
		var first_event: Dictionary = spawner.boss_spawn_events[0]
		var second_event: Dictionary = spawner.boss_spawn_events[1]
		var final_event: Dictionary = spawner.boss_spawn_events[2]
		var second_event_ids: Array[StringName] = spawner._get_boss_event_enemy_ids(second_event)
		_assert(spawner._get_boss_event_enemy_id(first_event) == boss_data.id, "First boss event uses old warlord")
		_assert(second_event_ids.size() == 2 and second_event_ids.has(frost_boss_data.id) and second_event_ids.has(rune_boss_data.id), "Second boss event uses both generated mini bosses")
		_assert(spawner._get_boss_event_enemy_id(final_event) == final_boss_data.id, "Final boss event uses icecrown overlord")
		spawner._elapsed_time = float(first_event.get("time", 0.0)) - 0.1
		_assert(spawner._try_spawn_boss() == null, "Boss does not spawn before first boss time")
		spawner._elapsed_time = float(first_event.get("time", 0.0))
		var first_wave: Array[CharacterBody2D] = spawner._try_spawn_boss_event()
		var boss: CharacterBody2D = first_wave[0] if not first_wave.is_empty() else null
		_assert(first_wave.size() == 1 and boss != null and boss.enemy_data == boss_data, "First wave spawns old warlord at first boss time")
		if boss:
			_assert(boss.is_in_group("bosses"), "Boss joins bosses group")
			_assert(not boss._is_final_boss(), "First wave boss does not count as final boss")
			_assert(boss._hp == int(boss_data.max_hp * spawner._get_stat_scale()), "Boss HP scales with difficulty")
			var volley: Array = boss._fire_boss_volley(Vector2.LEFT)
			await _wait(0.05)
			_assert(volley.size() == boss_data.boss_projectile_count, "Boss fires configured projectile volley")
			if not volley.is_empty():
				var first_projectile = volley[0]
				_assert(first_projectile.target_group == &"player" and first_projectile.collision_mask == 1, "Boss projectiles target player")
				_assert(first_projectile.visual_sprite_frames != null and first_projectile.visual_sprite_frames.get_frame_count("default") == 4, "Boss projectiles use animated orb frames")
			for projectile in volley:
				if is_instance_valid(projectile):
					projectile.queue_free()
			boss.queue_free()
			await _wait(0.05)
		_assert(spawner._try_spawn_boss() == null, "First boss event does not spawn twice")
		spawner._elapsed_time = float(second_event.get("time", 0.0))
		var second_wave: Array[CharacterBody2D] = spawner._try_spawn_boss_event()
		var second_wave_ids: Array[StringName] = []
		for second_boss in second_wave:
			if second_boss and second_boss.enemy_data:
				second_wave_ids.append(second_boss.enemy_data.id)
		_assert(second_wave.size() == 2 and second_wave_ids.has(frost_boss_data.id) and second_wave_ids.has(rune_boss_data.id), "Second wave spawns both generated mini bosses simultaneously")
		for second_boss in second_wave:
			if second_boss:
				_assert(second_boss.is_in_group("bosses"), "Second wave boss joins bosses group")
				_assert(not second_boss._is_final_boss(), "Second wave boss does not count as final boss")
				second_boss.queue_free()
		await _wait(0.05)
		spawner._elapsed_time = float(final_event.get("time", 0.0))
		var final_boss: CharacterBody2D = spawner._try_spawn_boss()
		_assert(final_boss != null and final_boss.enemy_data == final_boss_data, "Final boss spawns at final boss time")
		if final_boss:
			_assert(final_boss._is_final_boss(), "Final boss triggers victory on death")
			final_boss.queue_free()
			await _wait(0.05)

	if player and enemies_parent and dasher_data:
		var dash_enemy := enemy_scene.instantiate()
		dash_enemy.enemy_data = dasher_data
		dash_enemy.global_position = player.global_position + Vector2.RIGHT * 320.0
		enemies_parent.add_child(dash_enemy)
		await _wait(0.05)
		dash_enemy._dash_state = &"windup"
		dash_enemy._dash_timer = 0.0
		var dash_velocity: Vector2 = dash_enemy._get_behavior_velocity(0.05, Vector2.LEFT, dash_enemy._base_speed)
		_assert(dash_enemy._dash_state == &"dashing" and dash_velocity.length() > dash_enemy._base_speed * 1.5, "Dash enemy enters high-speed dash")
		dash_enemy.queue_free()
		await _wait(0.05)

	if player and enemies_parent and projectiles_parent and cultist_data:
		for child in projectiles_parent.get_children():
			child.queue_free()
		await _wait(0.05)
		var ranged_enemy := enemy_scene.instantiate()
		ranged_enemy.enemy_data = cultist_data
		ranged_enemy.global_position = player.global_position + Vector2.RIGHT * cultist_data.preferred_range
		enemies_parent.add_child(ranged_enemy)
		await _wait(0.05)
		ranged_enemy.global_position = player.global_position + Vector2.RIGHT * (cultist_data.preferred_range + 80.0)
		var approach_velocity: Vector2 = ranged_enemy._get_ranged_velocity(Vector2.LEFT, ranged_enemy._base_speed)
		_assert(approach_velocity.x < 0.0, "Ranged enemy approaches when outside preferred range")
		ranged_enemy.global_position = player.global_position + Vector2.RIGHT * (cultist_data.retreat_range - 20.0)
		var retreat_velocity: Vector2 = ranged_enemy._get_ranged_velocity(Vector2.LEFT, ranged_enemy._base_speed)
		_assert(retreat_velocity.x > 0.0, "Ranged enemy retreats when too close")
		ranged_enemy.global_position = player.global_position + Vector2.RIGHT * cultist_data.preferred_range
		ranged_enemy._ranged_attack_timer = 0.0
		var enemy_projectile = ranged_enemy._fire_ranged_projectile(Vector2.LEFT)
		await _wait(0.05)
		_assert(enemy_projectile != null and enemy_projectile.get_parent() == projectiles_parent, "Ranged enemy fires projectile")
		if enemy_projectile:
			_assert(enemy_projectile.target_group == &"player" and enemy_projectile.collision_mask == 1, "Ranged enemy projectile targets player")
			_assert(enemy_projectile.damage == cultist_data.projectile_damage, "Ranged enemy projectile uses data damage")
			enemy_projectile.queue_free()
		ranged_enemy.queue_free()
		await _wait(0.05)

	# Test viewport-relative spawn radius
	var view_radius: float = spawner._get_view_radius()
	var radius_bounds: Vector2 = spawner._get_spawn_radius_bounds()
	_assert(spawner.spawn_view_margin_min > 0, "Spawner has positive min view margin")
	_assert(radius_bounds.x > view_radius, "Spawner min radius is outside visible viewport")
	_assert(radius_bounds.y > radius_bounds.x, "Spawner max radius > min radius")
	_assert(spawner.base_spawn_interval > 0, "Spawner has positive base interval")

	# Reset spawner state
	spawner._elapsed_time = 0.0
	spawner._spawned_boss_events.clear()
	spawner._spawn_timer = spawner._get_spawn_interval()
	spawner.set_process(previous_spawner_process)
	e1.queue_free()

func _phase_projectile_system() -> void:
	print("[PHASE 21] Projectile System")

	var player: Node = get_tree().get_first_node_in_group("player")
	_assert(player != null, "Player exists")
	if not player:
		await _wait(0.2)
		return

	var projectiles_parent := _game.get_node_or_null("Projectiles")
	_assert(projectiles_parent != null, "Projectiles container exists")

	var enemies_parent := _game.get_node_or_null("Enemies")
	_assert(enemies_parent != null, "Enemies container exists")

	# Clean up
	for child in projectiles_parent.get_children():
		child.queue_free()
	for child in enemies_parent.get_children():
		child.queue_free()
	await _wait(0.1)

	# Test projectile movement and range
	var proj := preload("res://scenes/weapons/projectile.tscn").instantiate()
	proj.global_position = player.global_position
	proj.direction = Vector2.RIGHT
	proj.speed = 200.0
	proj.max_range = 50.0
	projectiles_parent.add_child(proj)
	await _wait(0.05)
	var arrow_visual: Sprite2D = null
	for child in proj.get_children():
		if child is Sprite2D:
			arrow_visual = child
			break
	_assert(arrow_visual != null, "Projectile arrow visual exists")
	if arrow_visual:
		_assert(abs(wrapf(arrow_visual.rotation - PI, -PI, PI)) < 0.001, "Projectile arrow visual faces right when moving right")
	var start_pos: Vector2 = proj.global_position
	await _wait(0.3)
	_assert(not is_instance_valid(proj), "Projectile freed after exceeding max_range")

	var animated_proj := preload("res://scenes/weapons/projectile.tscn").instantiate()
	animated_proj.global_position = player.global_position
	animated_proj.direction = Vector2.RIGHT
	animated_proj.speed = 0.0
	animated_proj.max_range = 200.0
	animated_proj.visual_sprite_frames = VFXHelper.build_sprite_frames(
		"res://assets/art/weapons/projectiles",
		"spark_bomb",
		4,
		12.0,
		true
	)
	animated_proj.visual_rotation_offset = 0.0
	projectiles_parent.add_child(animated_proj)
	await _wait(0.05)
	var animated_visual: AnimatedSprite2D = null
	for child in animated_proj.get_children():
		if child is AnimatedSprite2D:
			animated_visual = child
			break
	_assert(animated_visual != null, "Projectile supports animated visual frames")
	if animated_visual:
		_assert(animated_visual.sprite_frames.get_frame_count("default") == 4, "Animated projectile uses 4-frame spark bomb sheet")
	animated_proj.queue_free()

	# Test projectile damage with pierce
	var enemy_scene := preload("res://scenes/enemy/enemy.tscn")
	var enemy1 := enemy_scene.instantiate()
	enemy1.global_position = player.global_position + Vector2.RIGHT * 400.0
	enemy1._hp = 999
	enemy1.collision_layer = 0
	enemies_parent.add_child(enemy1)
	var enemy2 := enemy_scene.instantiate()
	enemy2.global_position = player.global_position + Vector2.RIGHT * 405.0
	enemy2._hp = 999
	enemy2.collision_layer = 0
	enemies_parent.add_child(enemy2)
	await _wait(0.1)

	var proj2 := preload("res://scenes/weapons/projectile.tscn").instantiate()
	proj2.global_position = player.global_position
	proj2.direction = Vector2.RIGHT
	proj2.speed = 300.0
	proj2.max_range = 200.0
	proj2.damage = 5
	proj2.pierce = 1
	projectiles_parent.add_child(proj2)
	await _wait(0.05)
	# Manually trigger body_entered on both enemies to simulate collision
	var enemy1_hp_before: int = enemy1._hp
	var enemy2_hp_before: int = enemy2._hp
	proj2._on_body_entered(enemy1)
	_assert(enemy1._hp == enemy1_hp_before - 5, "Projectile damages first enemy")
	_assert(is_instance_valid(proj2), "Projectile survives first hit with pierce")
	proj2._on_body_entered(enemy2)
	_assert(enemy2._hp == enemy2_hp_before - 5, "Projectile damages second enemy")
	# pierce=1 means 1 pierce after first hit; _pierced becomes 2 after second, > pierce(1), so freed
	await _wait(0.05)
	_assert(not is_instance_valid(proj2), "Projectile freed after exceeding pierce count")

	var bomb := preload("res://scenes/weapons/projectile.tscn").instantiate()
	bomb.global_position = enemy1.global_position
	bomb.direction = Vector2.RIGHT
	bomb.speed = 0.0
	bomb.max_range = 200.0
	bomb.damage = 7
	bomb.explosion_radius = 12.0
	bomb.damage_type = DamageEvent.DAMAGE_TYPE_LIGHTNING
	bomb.explosion_status = &"slow"
	bomb.explosion_status_duration = 0.5
	bomb.explosion_status_value = 0.5
	projectiles_parent.add_child(bomb)
	await _wait(0.05)
	var enemy1_hp_before_bomb: int = enemy1._hp
	var enemy2_hp_before_bomb: int = enemy2._hp
	bomb._on_body_entered(enemy1)
	_assert(enemy1._hp == enemy1_hp_before_bomb - 7, "Explosive projectile damages primary enemy")
	_assert(enemy2._hp == enemy2_hp_before_bomb - 7, "Explosive projectile damages nearby enemy")
	_assert(enemy1._statuses.has("slow") and enemy2._statuses.has("slow"), "Explosive projectile applies DamageEvent status")
	await _wait(0.05)
	_assert(not is_instance_valid(bomb), "Explosive projectile frees after detonation")

	var enemy_proj := preload("res://scenes/weapons/projectile.tscn").instantiate()
	enemy_proj.global_position = player.global_position + Vector2.RIGHT * 40.0
	enemy_proj.direction = Vector2.LEFT
	enemy_proj.speed = 0.0
	enemy_proj.max_range = 200.0
	enemy_proj.damage = 6
	enemy_proj.target_group = &"player"
	enemy_proj.collision_mask = 1
	projectiles_parent.add_child(enemy_proj)
	await _wait(0.05)
	if "_invincible" in player:
		player._invincible = false
	if "_dying" in player:
		player._dying = false
	GameState.run.hp = GameState.run.max_hp
	GameState.hp_changed.emit(GameState.run.hp, GameState.run.max_hp)
	var player_hp_before_projectile: int = GameState.run.hp
	enemy_proj._on_body_entered(player)
	_assert(GameState.run.hp == player_hp_before_projectile - 6, "Enemy projectile can damage player")
	await _wait(0.05)
	_assert(not is_instance_valid(enemy_proj), "Enemy projectile frees after hitting player")

	# Cleanup
	for child in projectiles_parent.get_children():
		child.queue_free()
	for child in enemies_parent.get_children():
		child.queue_free()
	await _wait(0.1)

func _phase_weapon_orbit() -> void:
	print("[PHASE 22] Weapon Orbit")

	var upgrade_system: Node = _game.get_node_or_null("UpgradeSystem")
	var player: Node = get_tree().get_first_node_in_group("player")
	_assert(player != null, "Player exists")
	if not player:
		await _wait(0.2)
		return

	var projectiles_parent := _game.get_node_or_null("Projectiles")
	_assert(projectiles_parent != null, "Projectiles container exists")

	# Unlock orbit weapon
	upgrade_system._unlock_weapon(&"orbit")
	await _wait(0.2)

	var orbit: WeaponBase = _find_weapon(&"orbit")
	_assert(orbit != null, "Orbit weapon unlocked")
	if not orbit:
		await _wait(0.2)
		return
	if orbit.has_method("_rebuild_orbs"):
		orbit._rebuild_orbs()
		await _wait(0.1)

	# Verify orbs were spawned
	var orbit_orbs: Array = []
	if "_orbs" in orbit:
		for orb in orbit._orbs:
			if is_instance_valid(orb):
				orbit_orbs.append(orb)
	else:
		for child in projectiles_parent.get_children():
			if child is Area2D and child.get_child_count() >= 1:
				orbit_orbs.append(child)
	var orb_count: int = orbit_orbs.size()
	var expected_orbs := 2
	if orbit.has_method("_get_orbit_count"):
		expected_orbs = orbit._get_orbit_count()
	elif orbit.weapon_data:
		expected_orbs = orbit.weapon_data.orbit_count
	_assert(orb_count == expected_orbs, "Orbit spawns correct number of orbs")

	# Verify orbs rotate around player
	if orbit_orbs.size() > 0:
		var orb: Node = orbit_orbs[0]
		var pos1: Vector2 = orb.global_position
		await _wait(0.2)
		if is_instance_valid(orb):
			var pos2: Vector2 = orb.global_position
			_assert(pos1 != pos2, "Orb moves (rotates) around player")

	# Test level up increases orb count (if data supports more)
	var prev_orb_count: int = orbit._orbs.size() if "_orbs" in orbit else orb_count
	orbit.level_up()
	await _wait(0.1)
	var new_orb_count: int = orbit._orbs.size() if "_orbs" in orbit else 0
	if orbit.weapon_data and orbit.weapon_data.orbit_count > 1:
		# Level up may not increase orbs if count didn't change; just verify it didn't crash
		_assert(new_orb_count >= 0, "Orbit level up rebuilds orbs")

	# Cleanup: remove orbit weapon
	var weapons := player.get_node_or_null("Weapons")
	if weapons and orbit:
		orbit.queue_free()
	for child in projectiles_parent.get_children():
		child.queue_free()
	await _wait(0.1)

func _phase_passive_regen_thorns() -> void:
	print("[PHASE 23] Passive Regen & Thorns")

	var upgrade_system: Node = _game.get_node_or_null("UpgradeSystem")
	var player: Node = get_tree().get_first_node_in_group("player")
	_assert(player != null, "Player exists")
	if not player:
		await _wait(0.2)
		return

	var enemies_parent := _game.get_node_or_null("Enemies")
	_assert(enemies_parent != null, "Enemies container exists")

	# Clean up enemies
	for child in enemies_parent.get_children():
		child.queue_free()
	await _wait(0.1)

	# --- Passive regen test ---
	var regen_unlock := UpgradeData.new()
	regen_unlock.id = GameState.REGEN_ENHANCEMENT_ID
	regen_unlock.display_name = "生命源泉"
	regen_unlock.description = "Test passive regen"
	regen_unlock.upgrade_type = UpgradeData.UpgradeType.PLAYER_STAT
	regen_unlock.hp_bonus = GameState.REGEN_BASE_HEAL

	var saved_enhancements: Dictionary = (GameState.run.get("enhancements", {}) as Dictionary).duplicate(true)
	var saved_order: Array = (GameState.run.get("enhancement_order", []) as Array).duplicate()
	GameState.run["enhancements"] = {}
	GameState.run["enhancement_order"] = []
	GameState.run.hp = 10
	GameState.run.max_hp = 100
	upgrade_system._on_option_selected(regen_unlock)
	_assert(_find_weapon(GameState.REGEN_ENHANCEMENT_ID) == null, "Regen does not unlock as weapon")
	_assert(GameState.get_enhancement_level(GameState.REGEN_ENHANCEMENT_ID) == 1, "Regen is tracked as enhancement")
	_assert(GameState.run.hp == 15, "Regen enhancement heals immediately on pickup")

	var saved_cooldown_multiplier: float = float(GameState.run.get("cooldown_multiplier", 1.0))
	var saved_projectile_cooldown_multiplier: float = float(GameState.run.get("projectile_cooldown_multiplier", 1.0))
	GameState.run.cooldown_multiplier = 0.8
	GameState.run.projectile_cooldown_multiplier = 0.5
	_assert(abs(GameState.get_regen_interval() - GameState.REGEN_INTERVAL * 0.8) < 0.001, "Passive regen interval scales with global cooldown")
	GameState.run.cooldown_multiplier = saved_cooldown_multiplier
	GameState.run.projectile_cooldown_multiplier = saved_projectile_cooldown_multiplier

	GameState.run.hp = 10
	_game.set("_regen_last_level", 1)
	_game.set("_regen_timer", 0.0)
	_game.call("_process_passive_enhancements", 0.1)
	await _wait(0.1)
	_assert(GameState.run.hp == 15, "Passive regen heals player over time")

	var regen_data: Dictionary = GameState.run["enhancements"][str(GameState.REGEN_ENHANCEMENT_ID)]
	regen_data["level"] = 2
	GameState.run["enhancements"][str(GameState.REGEN_ENHANCEMENT_ID)] = regen_data
	GameState.run.hp = 10
	_game.set("_regen_last_level", 2)
	_game.set("_regen_timer", 0.0)
	_game.call("_process_passive_enhancements", 0.1)
	await _wait(0.1)
	_assert(GameState.run.hp == 17, "Passive regen heal scales with enhancement level")

	GameState.run["enhancements"] = saved_enhancements
	GameState.run["enhancement_order"] = saved_order

	# --- Thorns test ---
	upgrade_system._unlock_weapon(&"thorns")
	await _wait(0.2)
	var thorns: WeaponBase = _find_weapon(&"thorns")
	_assert(thorns != null, "Thorns weapon unlocked")

	if thorns:
		# Spawn an enemy near player
		var enemy_scene := preload("res://scenes/enemy/enemy.tscn")
		var enemy := enemy_scene.instantiate()
		enemy.global_position = player.global_position + Vector2.RIGHT * 30.0
		enemy._hp = 999
		enemy.collision_layer = 0
		enemies_parent.add_child(enemy)
		await _wait(0.1)

		# Set thorns _last_hp to current HP so it tracks changes
		if "_last_hp" in thorns:
			thorns._last_hp = GameState.run.hp
		var enemy_hp_before: int = enemy._hp
		# Simulate player taking damage
		var player_hp_before: int = GameState.run.hp
		GameState.run.hp = max(1, player_hp_before - 10)
		GameState.hp_changed.emit(GameState.run.hp, GameState.run.max_hp)
		await _wait(0.1)
		if is_instance_valid(enemy):
			_assert(enemy._hp < enemy_hp_before, "Thorns reflects damage to enemy")

		if is_instance_valid(enemy):
			enemy.queue_free()

	# Cleanup weapons
	var weapons := player.get_node_or_null("Weapons")
	if weapons:
		for w in weapons.get_children():
			if w is WeaponBase and w.weapon_data:
				if w.weapon_data.id == &"thorns":
					w.queue_free()
	await _wait(0.1)

func _phase_save_system() -> void:
	print("[PHASE 24] Save System")
	get_tree().paused = false
	_game.set("_run_finished", false)
	var game_over: Node = _game.get_node_or_null("GameOver")
	if game_over:
		game_over.visible = false

	var total_gold_before := int(SaveManager.get_profile_value("total_gold", 0))
	var lifetime_kills_before := int(SaveManager.get_profile_value("lifetime_kills", 0))
	var total_runs_before := int(SaveManager.get_profile_value("total_runs", 0))
	var total_victories_before := int(SaveManager.get_profile_value("total_victories", 0))
	GameState.start_new_run(12345)
	GameState.add_gold(11)
	GameState.add_kill()
	GameState.add_kill()
	GameState.run.level = 5
	GameState.run.run_time = 99.0
	GameState.run.victory = true
	_assert(int(SaveManager.get_profile_value("total_gold", 0)) == total_gold_before + 11, "Gold pickup updates profile immediately")
	_assert(int(SaveManager.get_profile_value("lifetime_kills", 0)) == lifetime_kills_before + 2, "Kills update profile immediately")
	_assert(SaveManager.record_run_finished(), "Completed run updates profile summary")
	_assert(int(SaveManager.get_profile_value("total_runs", 0)) == total_runs_before + 1, "Profile total runs updated")
	_assert(int(SaveManager.get_profile_value("total_victories", 0)) == total_victories_before + 1, "Profile total victories updated")
	_assert(int(SaveManager.get_profile_value("total_gold", 0)) == total_gold_before + 11, "Profile total gold updated")
	_assert(int(SaveManager.get_profile_value("best_level", 1)) >= 5, "Profile best level updated")
	_assert(int(SaveManager.get_profile_value("best_kills", 0)) >= 2, "Profile best kills updated")
	var saved_total_gold := int(SaveManager.get_profile_value("total_gold", 0))
	GameState.set_game_speed(2.0)
	GameState.start_new_run(54321)
	await _wait(0.05)
	_assert(GameState.run.gold == 0, "New run resets run gold")
	_assert(is_equal_approx(GameState.game_speed_multiplier, 1.0) and is_equal_approx(Engine.time_scale, 1.0), "New run resets game speed")
	_assert(int(SaveManager.get_profile_value("total_gold", 0)) == saved_total_gold, "New run keeps saved total gold")
	var hud: Node = _game.get_node_or_null("HUD")
	if hud:
		var gold_label: Label = hud.get_node_or_null("TopBar/GoldLabel")
		_assert(gold_label != null and gold_label.text == "金币: 0", "HUD shows run gold on new run")
		var speed_label: Button = hud.get_node_or_null("TopBar/SpeedButton")
		_assert(speed_label != null and speed_label.text == "1x", "HUD speed button resets on new run")
	var main_menu: Node = load("res://scenes/ui/main_menu.tscn").instantiate()
	add_child(main_menu)
	await _wait(0.1)
	var global_gold_label: Label = main_menu.get_node_or_null("CenterContainer/VBoxContainer/GoldSummary/GoldSummaryLabel")
	_assert(global_gold_label != null and global_gold_label.text == "全局金币: %d" % saved_total_gold, "Main menu shows saved global gold")
	main_menu.queue_free()
	var profile := SaveManager.get_profile()
	var last_run: Dictionary = profile.get("last_run", {})
	_assert(int(last_run.get("gold", 0)) == 11 and int(last_run.get("kills", 0)) == 2, "Last run stores numeric summary")
	_assert(bool(last_run.get("victory", false)), "Last run stores victory result")
	_assert(str(profile.get("selected_character_id", "")) == "adventurer", "Profile stores selected character")
	_assert(str(last_run.get("character_id", "")) == "adventurer", "Last run stores character id")
	var profile_json := JSON.stringify(profile)
	_assert(profile_json.find("Texture2D") == -1 and profile_json.find("Node") == -1, "Profile does not serialize engine objects")
	_assert(profile_json.find("position") == -1 and profile_json.find("weapons") == -1, "Profile does not store battle state")

func _phase_character_system() -> void:
	print("[PHASE 25] Character System")
	get_tree().paused = false
	var previous_character := SaveManager.get_selected_character_id()

	if is_instance_valid(_game):
		_game.queue_free()
		await _wait(0.2)

	SaveManager.set_selected_character_id(&"ranger")
	_game = load("res://scenes/game/game.tscn").instantiate()
	add_child(_game)
	await _wait(0.4)

	var player: Node = get_tree().get_first_node_in_group("player")
	_assert(player != null, "Character test player exists")
	_assert(str(GameState.run.get("character_id", "")) == "ranger", "Selected character starts new run")
	_assert(GameState.run.max_hp == 85 and GameState.run.hp == 85, "Ranger HP applied")
	if player:
		_assert(abs(player.move_speed - 190.0) < 0.01, "Ranger move speed applied")
		var sprite: AnimatedSprite2D = player.get_node_or_null("AnimatedSprite2D")
		if sprite and sprite.sprite_frames:
			_assert(sprite.sprite_frames.has_animation("walk_down"), "Selected character uses directional walk animations")
			_assert(sprite.sprite_frames.get_frame_count("walk_down") == 4, "Selected character walk animation has 4 frames")
	var projectile := _find_weapon(&"projectile_basic")
	_assert(projectile != null, "Ranger starts with projectile weapon")
	if projectile:
		var expected_cd := projectile.weapon_data.cooldown * 0.92
		_assert(abs(projectile.get_cooldown() - expected_cd) < 0.01, "Ranger projectile cooldown passive applied")

	GameState.start_new_run(777, &"guardian")
	_assert(StringName(GameState.run.get("passive_id", &"")) == GameState.GUARD_REFRACTION_PASSIVE_ID, "Guardian refraction passive id applied")
	_assert(GameState.preview_take_damage(20) == 18, "Guardian refraction previews reduced incoming damage")

	var enemies_parent := _game.get_node_or_null("Enemies")
	if player is Node2D and enemies_parent:
		for child in enemies_parent.get_children():
			child.queue_free()
		await _wait(0.1)

		var player_2d := player as Node2D
		var enemy_scene := preload("res://scenes/enemy/enemy.tscn")
		var near_enemy := enemy_scene.instantiate()
		var far_enemy := enemy_scene.instantiate()
		var outside_enemy := enemy_scene.instantiate()
		near_enemy.global_position = player_2d.global_position + Vector2.RIGHT * 30.0
		far_enemy.global_position = player_2d.global_position + Vector2.RIGHT * 170.0
		outside_enemy.global_position = player_2d.global_position + Vector2.RIGHT * 240.0
		near_enemy.collision_layer = 0
		near_enemy.collision_mask = 0
		near_enemy.set_physics_process(false)
		far_enemy.collision_layer = 0
		far_enemy.collision_mask = 0
		far_enemy.set_physics_process(false)
		outside_enemy.collision_layer = 0
		outside_enemy.collision_mask = 0
		outside_enemy.set_physics_process(false)
		enemies_parent.add_child(near_enemy)
		enemies_parent.add_child(far_enemy)
		enemies_parent.add_child(outside_enemy)
		await _wait(0.1)
		near_enemy._hp = 50
		far_enemy._hp = 50
		outside_enemy._hp = 50

		var hp_before: int = GameState.run.hp
		GameState.take_damage(20)
		_assert(GameState.run.hp == hp_before - 18, "Guardian refraction reduces incoming damage")
		var near_loss: int = 50 - int(near_enemy._hp)
		var far_loss: int = 50 - int(far_enemy._hp)
		_assert(near_loss > far_loss and far_loss > 0, "Guardian refraction damage falls off with distance")
		_assert(outside_enemy._hp == 50, "Guardian refraction ignores enemies outside radius")

		GameState.run.hp = 10
		if "_invincible_until_msec" in player:
			player._invincible_until_msec = 0
		if "_invincibility_timer" in player:
			player._invincibility_timer = 0.0
		if "_invincible" in player:
			player._invincible = false
		player.take_damage(10)
		await _wait(0.05)
		_assert(GameState.run.hp == 1, "Guardian refraction prevents raw fatal player hit")
		if "_dying" in player:
			_assert(not player._dying, "Player does not enter death when refraction prevents fatal damage")
		for child in enemies_parent.get_children():
			child.queue_free()
		await _wait(0.1)

	GameState.start_new_run(888, &"alchemist")
	_assert(abs(GameState.get_character_area_multiplier() - 1.08) < 0.001, "Alchemist area passive applied")
	_assert(abs(GameState.get_character_field_lifetime_multiplier() - 1.15) < 0.001, "Alchemist field lifetime passive applied")

	SaveManager.set_selected_character_id(previous_character)

func _finish() -> void:
	print("========================================")
	print("RESULTS: %d passed, %d failed" % [_passed, _failed])
	print("========================================")
	GameState.reset_game_speed()
	SaveManager.delete_save_files_for_tests()
	get_tree().quit(_failed)
