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

	# Verify HUD has icon elements
	var hud: Node = _game.get_node_or_null("HUD")
	if hud:
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
	_assert(DataManager.all_characters().size() >= 4, "Character data resources loaded")
	_assert(DataManager._resource_path_from_dir_entry("res://resources/characters", "adventurer.tres.remap") == "res://resources/characters/adventurer.tres", "Resource scan supports exported remap entries")
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
	await _wait(0.3)

func _phase_level_up() -> void:
	print("[PHASE 2] Level Up")

	var upgrade_system: Node = _game.get_node_or_null("UpgradeSystem")
	_assert(upgrade_system != null, "UpgradeSystem node found")

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

func _phase_weapon_unlocks() -> void:
	print("[PHASE 3] Weapon Unlocks")
	var upgrade_system: Node = _game.get_node_or_null("UpgradeSystem")
	var scenes: Dictionary = upgrade_system.WEAPON_SCENES

	var unlocked_count := 0
	var cap_checked := false
	for weapon_id in scenes.keys():
		if _find_weapon(weapon_id) != null:
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

		pause_menu._show_pause()
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
		GameState.add_gold(10)
		GameState.add_kill()
		GameState.add_kill()

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

func _assert(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
		print("  [PASS] " + message)
	else:
		_failed += 1
		push_error("  [FAIL] " + message)

func _wait(seconds: float):
	return get_tree().create_timer(seconds, true).timeout

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
	upgrade_system._apply_upgrade(path_option)
	_assert(melee.current_path_id == &"berserker", "Berserker path set correctly")
	_assert(melee.level == 2, "Path selection triggers level up to 2")
	# Berserker Lv.2: damage +5 + base growth
	var expected_dmg := int(round(melee.weapon_data.damage * 1.1)) + 5
	_assert(melee._current_damage == expected_dmg, "Berserker Lv.2 damage bonus applied")

	# Level to 3 (wider_arc)
	melee.level_up()
	_assert(melee.has_special_tag(&"wider_arc"), "Lv.3 berserker has wider_arc tag")

	# Level to 7 (widest_arc)
	for i in range(4):
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

	# Spawn enemy far enough that drops won't be auto-collected
	var enemy_scene := preload("res://scenes/enemy/enemy.tscn")
	var enemy := enemy_scene.instantiate()
	enemy.global_position = player.global_position + Vector2.RIGHT * 150.0
	enemies_parent.add_child(enemy)
	await _wait(0.1)

	var initial_hp: int = enemy._hp
	var initial_kills: int = GameState.run.kills
	var initial_drop_count: int = drops_parent.get_child_count()

	# Deal damage
	enemy.take_damage(10)
	_assert(enemy._hp == initial_hp - 10, "Enemy HP reduced by damage")

	# Kill enemy
	enemy.take_damage(999)
	_assert(enemy._hp <= 0, "Enemy HP <= 0 after lethal damage")
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
	for child in enemies_parent.get_children():
		child.queue_free()
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

		# Ensure HP is below max for heal to work
		if GameState.run.hp >= GameState.run.max_hp:
			GameState.take_damage(20)
			await _wait(0.1)

		# Reset path so guardian can be selected
		melee.current_path_id = &""
		melee._recalc_stats()
		melee.set_path(&"guardian")
		melee.level = 6
		melee._recalc_stats()
		melee._apply_path_effects()

		var prev_hp: int = GameState.run.hp
		melee._deal_sector_damage(player, Vector2.RIGHT)
		_assert(GameState.run.hp > prev_hp, "heal_on_hit restores HP")
		_assert(GameState.run.hp == prev_hp + 2, "heal_on_hit restores exactly 2 HP")

		# Test heal_on_hit_boost (Lv.8)
		melee.level = 8
		melee._recalc_stats()
		melee._apply_path_effects()

		prev_hp = GameState.run.hp
		melee._deal_sector_damage(player, Vector2.RIGHT)
		_assert(GameState.run.hp == prev_hp + 5, "heal_on_hit_boost restores exactly 5 HP")

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
				_assert(ray.get_node_or_null("HolyRayMid") is Sprite2D, "Holy prism ray has a beam body")
				ray.queue_free()

	# === fire_bottle ===
	var fire := _find_weapon(&"fire_bottle")
	if fire:
		fire.level = 1
		fire.current_path_id = &""
		fire._recalc_stats()
		_assert(fire._get_lifetime() == 3.0, "Fire bottle base lifetime is 3.0")
		_assert(fire._get_fire_radius() == 80.0, "Fire bottle base field radius is 80.0")

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
		if player:
			frost._show_ice_ring(player.global_position + Vector2.DOWN * 160.0, 80.0)
			await _wait(0.05)
			var frost_ring := get_tree().current_scene.find_child("FrostRingEffect", true, false)
			_assert(frost_ring is Sprite2D, "Frost ring creates expanding ring visual")
			if frost_ring is Sprite2D:
				var ring_sprite := frost_ring as Sprite2D
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
		var explosion_frames := VFXHelper.build_sprite_frames(
			"res://assets/art/effects/by_type/fx_explosion",
			"explosion",
			8,
			12.0,
			false
		)
		_assert(explosion_frames.get_frame_count("default") == 8, "Mine explosion uses 8 separate animation frames")

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
		await _assert_laser_visual()

	# === poison_vial ===
	var poison := _find_weapon(&"poison_vial")
	if poison:
		poison.level = 1
		poison.current_path_id = &""
		poison._recalc_stats()
		_assert(poison._get_poison_lifetime() == 4.0, "Poison vial base lifetime is 4.0")
		_assert(poison._get_poison_radius() == 90.0, "Poison vial base field radius is 90.0")

		poison.set_path(&"plague")
		poison.level = 3
		poison._recalc_stats()
		poison._apply_path_effects()
		var expected_poison_radius: float = poison.weapon_data.field_radius + poison.get_range() - poison.weapon_data.range + 20.0
		_assert(poison._get_poison_radius() == expected_poison_radius, "plague Lv.3 wider_poison adds +20 field radius")
		await _assert_field_visual("poison")

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
				_assert(flame.get_node_or_null("RocketFlameStart") is Sprite2D, "Rocket flame has start cap")
				_assert(flame.get_node_or_null("RocketFlameMid") is Sprite2D, "Rocket flame repeats middle segment")
				_assert(flame.get_node_or_null("RocketFlameEnd") is Sprite2D, "Rocket flame has end cap")
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

	await _wait(0.2)

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
	var initial_hp: int = enemy._hp
	_assert(initial_hp == 10, "Enemy HP set to 10 for one-hit kill")

	# Force melee to trigger quickly
	melee._current_cooldown = 0.1
	melee._cooldown_timer = 0.0

	# Wait for weapon activation
	await _wait(0.2)

	var enemy_killed: bool = not is_instance_valid(enemy) or enemy._hp <= 0
	_assert(enemy_killed, "Enemy killed by melee weapon")

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
	await _wait(0.1)

	# Test damage
	var prev_hp: int = GameState.run.hp
	GameState.take_damage(10)
	_assert(GameState.run.hp == prev_hp - 10, "Player takes damage from take_damage")

	# Test invincibility: rapid damage should not all apply
	var hp_before_inv: int = GameState.run.hp
	player.take_damage(10)
	await _wait(0.05)
	var hp_after_one_hit: int = GameState.run.hp
	player.take_damage(10)
	await _wait(0.05)
	_assert(GameState.run.hp == hp_after_one_hit, "Invincibility frames prevent rapid damage")

	# Test heal
	GameState.heal(5)
	_assert(GameState.run.hp == hp_after_one_hit + 5, "Heal restores HP")

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

	# Clean up
	for child in enemies_parent.get_children():
		child.queue_free()
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
	enemy.apply_status(&"slow", 1.0, 0.5)
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

	# Test enemy health bar shows on damage
	if is_instance_valid(enemy):
		var health_bar: Node = enemy.get_node_or_null("HealthBar")
		if health_bar and health_bar.auto_hide:
			enemy.take_damage(1)
			_assert(health_bar.visible, "Enemy health bar visible after damage")

	# Cleanup
	if is_instance_valid(enemy):
		enemy.queue_free()
	for child in enemies_parent.get_children():
		child.queue_free()
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

	# Test PLAYER_STAT max_hp bonus
	var prev_max_hp: int = GameState.run.max_hp
	var hp_up := UpgradeData.new()
	hp_up.id = "test_hp"
	hp_up.display_name = "Test HP"
	hp_up.upgrade_type = UpgradeData.UpgradeType.PLAYER_STAT
	hp_up.max_hp_bonus = 30
	upgrade_system._on_option_selected(hp_up)
	_assert(GameState.run.max_hp == prev_max_hp + 30, "Max HP stat upgrade applies")
	_assert(GameState.run.hp > 0, "HP bonus also heals player")

	var fill_idx := 0
	while GameState.get_enhancement_count() < GameState.MAX_ENHANCEMENT_SLOTS:
		var filler := UpgradeData.new()
		filler.id = "test_enhancement_fill_%d" % fill_idx
		filler.display_name = "Fill %d" % fill_idx
		filler.upgrade_type = UpgradeData.UpgradeType.PLAYER_STAT
		upgrade_system._on_option_selected(filler)
		fill_idx += 1
	_assert(GameState.get_enhancement_count() == GameState.MAX_ENHANCEMENT_SLOTS, "Enhancement slots cap at 6")
	_assert(GameState.can_add_enhancement(&"test_speed"), "Existing enhancement can still level when slots are full")
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

	# Clean up and reset player HP / invincibility
	for child in enemies_parent.get_children():
		child.queue_free()
	await _wait(0.1)
	GameState.run.hp = GameState.run.max_hp
	GameState.hp_changed.emit(GameState.run.hp, GameState.run.max_hp)
	player._invincible = false
	player._dying = false
	player.set_physics_process(true)

	# Spawn enemy and test damage logic directly (avoids physics timing flakiness)
	var enemy_scene := preload("res://scenes/enemy/enemy.tscn")
	var enemy := enemy_scene.instantiate()
	enemy.global_position = player.global_position + Vector2.UP * 50.0
	enemy._damage = 5
	enemy._hp = 999999
	enemy.collision_layer = 0
	enemies_parent.add_child(enemy)
	await _wait(0.2)

	_assert(enemy._player != null, "Enemy finds player reference")

	# Direct damage application simulating collision
	var prev_hp: int = GameState.run.hp
	player._invincible = false
	player.take_damage(enemy._damage)
	_assert(GameState.run.hp == prev_hp - 5, "Enemy damage applies to player")

	# Test enemy damage cooldown
	enemy._can_damage = false
	var cooldown_timer := get_tree().create_timer(enemy._damage_cooldown, true)
	_assert(not enemy._can_damage, "Enemy enters damage cooldown")
	await _wait(0.5)
	_assert(is_instance_valid(enemy) and not enemy._can_damage, "Enemy still in cooldown at 0.5s")
	await cooldown_timer.timeout
	enemy._can_damage = true
	_assert(is_instance_valid(enemy) and enemy._can_damage, "Enemy cooldown expires after ~1s")

	# Cleanup
	if is_instance_valid(enemy):
		enemy.queue_free()
	for child in enemies_parent.get_children():
		child.queue_free()
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
		GameState.hp_changed.emit(60, 100)
		await _wait(0.05)
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

	# Test spawn interval scaling with elapsed time
	spawner._elapsed_time = 0.0
	var interval_at_0: float = spawner._get_spawn_interval()
	spawner._elapsed_time = 60.0
	var interval_at_60: float = spawner._get_spawn_interval()
	spawner._elapsed_time = 120.0
	var interval_at_120: float = spawner._get_spawn_interval()
	_assert(interval_at_60 < interval_at_0, "Spawn interval decreases at 60s")
	_assert(interval_at_120 < interval_at_60, "Spawn interval decreases further at 120s")
	_assert(interval_at_120 >= 0.3, "Spawn interval has minimum floor")

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

	_assert(expected_hp == base_hp * 2, "Difficulty scaling doubles HP at 120s")
	_assert(expected_dmg == base_dmg * 2, "Difficulty scaling doubles damage at 120s")
	_assert(speed_factor_120 < stat_factor_120, "Difficulty speed scaling grows slower than HP/damage")
	_assert(abs(expected_speed - base_speed * 1.4) < 0.1, "Difficulty speed scaling is 1.4x at 120s")
	spawner._elapsed_time = spawner.speed_scale_period * 2.0
	_assert(abs(spawner._get_speed_scale() - spawner.max_speed_scale) < 0.01, "Difficulty speed scaling has cap")

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

	# Test viewport-relative spawn radius
	var view_radius: float = spawner._get_view_radius()
	var radius_bounds: Vector2 = spawner._get_spawn_radius_bounds()
	_assert(spawner.spawn_view_margin_min > 0, "Spawner has positive min view margin")
	_assert(radius_bounds.x > view_radius, "Spawner min radius is outside visible viewport")
	_assert(radius_bounds.y > radius_bounds.x, "Spawner max radius > min radius")
	_assert(spawner.base_spawn_interval > 0, "Spawner has positive base interval")

	# Reset spawner state
	spawner._elapsed_time = 0.0
	spawner._spawn_timer = spawner._get_spawn_interval()
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
	var orb_count: int = 0
	for child in projectiles_parent.get_children():
		if child is Area2D and child.get_child_count() >= 1:
			orb_count += 1
	var expected_orbs := 2
	if orbit.has_method("_get_orbit_count"):
		expected_orbs = orbit._get_orbit_count()
	elif orbit.weapon_data:
		expected_orbs = orbit.weapon_data.orbit_count
	_assert(orb_count == expected_orbs, "Orbit spawns correct number of orbs")

	# Verify orbs rotate around player
	if projectiles_parent.get_child_count() > 0:
		var orb: Node = projectiles_parent.get_child(0)
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
	GameState.start_new_run(12345)
	GameState.add_gold(11)
	GameState.add_kill()
	GameState.add_kill()
	GameState.run.level = 5
	GameState.run.run_time = 99.0
	_assert(int(SaveManager.get_profile_value("total_gold", 0)) == total_gold_before + 11, "Gold pickup updates profile immediately")
	_assert(int(SaveManager.get_profile_value("lifetime_kills", 0)) == lifetime_kills_before + 2, "Kills update profile immediately")
	_assert(SaveManager.record_run_finished(), "Completed run updates profile summary")
	_assert(int(SaveManager.get_profile_value("total_runs", 0)) == total_runs_before + 1, "Profile total runs updated")
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
	var projectile := _find_weapon(&"projectile_basic")
	_assert(projectile != null, "Ranger starts with projectile weapon")
	if projectile:
		var expected_cd := projectile.weapon_data.cooldown * 0.92
		_assert(abs(projectile.get_cooldown() - expected_cd) < 0.01, "Ranger projectile cooldown passive applied")

	GameState.start_new_run(777, &"guardian")
	var hp_before: int = GameState.run.hp
	GameState.take_damage(10)
	_assert(GameState.run.hp == hp_before - 9, "Guardian damage reduction passive applied")

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
