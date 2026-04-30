extends Node

const WEAPON_SCENES: Dictionary = {
	&"melee_basic": "res://scenes/weapons/weapon_melee.tscn",
	&"projectile_basic": "res://scenes/weapons/weapon_projectile.tscn",
	&"thunder": "res://scenes/weapons/weapon_thunder.tscn",
	&"orbit": "res://scenes/weapons/weapon_orbit.tscn",
	&"thorns": "res://scenes/weapons/weapon_thorns.tscn",
	&"shotgun": "res://scenes/weapons/weapon_shotgun.tscn",
	&"fire_bottle": "res://scenes/weapons/weapon_fire_bottle.tscn",
	&"frost_ring": "res://scenes/weapons/weapon_frost_ring.tscn",
	&"holy_prism": "res://scenes/weapons/weapon_holy_prism.tscn",
	&"poison_vial": "res://scenes/weapons/weapon_poison_vial.tscn",
	&"mine": "res://scenes/weapons/weapon_mine.tscn",
	&"laser_pen": "res://scenes/weapons/weapon_laser_pen.tscn",
	&"boomerang": "res://scenes/weapons/weapon_boomerang.tscn",
	&"electromagnetic_chain": "res://scenes/weapons/weapon_electromagnetic_chain.tscn",
	&"saw_blade": "res://scenes/weapons/weapon_saw_blade.tscn",
	&"rocket_pack": "res://scenes/weapons/weapon_rocket_pack.tscn",
	&"whirlwind": "res://scenes/weapons/weapon_whirlwind.tscn",
	&"throwing_axe": "res://scenes/weapons/weapon_throwing_axe.tscn",
	&"shockwave": "res://scenes/weapons/weapon_shockwave.tscn",
	&"spark_bomb": "res://scenes/weapons/weapon_spark_bomb.tscn",
}

const ICON_SPEED_UP := preload("res://assets/art/upgrades/icons/speed_up.png")
const ICON_HP_UP := preload("res://assets/art/upgrades/icons/hp_up.png")
const ICON_PICKUP_UP := preload("res://assets/art/upgrades/icons/pickup_up.png")
const ICON_REGEN := preload("res://assets/art/upgrades/icons/regen.png")
const ICON_MIGHT := preload("res://assets/art/upgrades/icons/might.png")
const ICON_FOCUS := preload("res://assets/art/upgrades/icons/focus.png")
const ICON_EXPANSION := preload("res://assets/art/upgrades/icons/expansion.png")
const ICON_FIELD_DURATION := preload("res://assets/art/upgrades/icons/field_duration.png")
const ICON_TENACITY := preload("res://assets/art/upgrades/icons/tenacity.png")
const ICON_TRAINING := preload("res://assets/art/upgrades/icons/training.png")

func _ready() -> void:
	GameState.level_up.connect(_on_level_up)

func _on_level_up(_new_level: int) -> void:
	get_tree().paused = true
	_show_generated_options()

func _show_generated_options() -> void:
	var upgrade_select := _get_upgrade_select()
	if upgrade_select:
		_connect_upgrade_select(upgrade_select)
		upgrade_select.show_options(_generate_options())

func _get_upgrade_select() -> Node:
	var upgrade_select := get_tree().get_first_node_in_group("upgrade_select")
	if upgrade_select:
		return upgrade_select

	var current_scene := get_tree().current_scene
	if not current_scene:
		return null

	upgrade_select = current_scene.get_node_or_null("UpgradeSelect")
	if upgrade_select:
		return upgrade_select

	return current_scene.find_child("UpgradeSelect", true, false)

func _connect_upgrade_select(upgrade_select) -> void:
	if not upgrade_select.option_selected.is_connected(_on_option_selected):
		upgrade_select.option_selected.connect(_on_option_selected)
	if not upgrade_select.reroll_requested.is_connected(_on_reroll_requested):
		upgrade_select.reroll_requested.connect(_on_reroll_requested)
	if not upgrade_select.skip_requested.is_connected(_on_skip_requested):
		upgrade_select.skip_requested.connect(_on_skip_requested)

func _on_reroll_requested() -> void:
	get_tree().paused = true
	_show_generated_options()

func _on_skip_requested() -> void:
	var upgrade_select := _get_upgrade_select()
	if upgrade_select:
		upgrade_select.visible = false
	get_tree().paused = false

func _generate_options() -> Array[UpgradeData]:
	var pool: Array[UpgradeData] = []

	# === 角色强化 ===
	for stat_upgrade in [
		_make_speed_up(),
		_make_hp_up(),
		_make_pickup_up(),
		_make_regen_up(),
		_make_might_up(),
		_make_focus_up(),
		_make_expansion_up(),
		_make_duration_up(),
		_make_tenacity_up(),
		_make_training_up(),
	]:
		if GameState.can_add_enhancement(stat_upgrade.id):
			pool.append(stat_upgrade)

	# === 武器解锁 ===
	for weapon_id in WEAPON_SCENES.keys():
		if _can_unlock_weapon(weapon_id):
			pool.append(_make_unlock(weapon_id))

	# === 已解锁武器：流派选择或升级 ===
	var player := get_tree().get_first_node_in_group("player")
	if player:
		var weapons := player.get_node_or_null("Weapons")
		if weapons:
			for w in weapons.get_children():
				if not (w is WeaponBase and w.weapon_data):
					continue
				if w.level >= w.weapon_data.max_level:
					continue

				if w.weapon_data.paths.size() > 0:
					# 有定义流派的武器
					if w.level == 1 and w.current_path_id.is_empty():
						# 未选流派：提供流派选择
						for path in w.weapon_data.paths:
							pool.append(_make_path_option(w, path))
					elif not w.current_path_id.is_empty():
						# 已选流派：提供下一级升级
						var effect = w.get_path_effect(w.level + 1) as WeaponPathLevel
						var current_path: WeaponPath = null
						for p in w.weapon_data.paths:
							if p.path_id == w.current_path_id:
								current_path = p
								break
						if effect:
							pool.append(_make_level_from_path(w, current_path, effect))
				else:
					# 无流派定义：使用硬编码升级
					var hardcoded := _get_hardcoded_level_option(w.weapon_data.id)
					if hardcoded:
						pool.append(hardcoded)

	# Add external upgrades from DataManager if any
	for u in DataManager.all_upgrades():
		pool.append(u)

	# Filter and deduplicate
	var filtered: Array[UpgradeData] = []
	for u in pool:
		if u.upgrade_type in [UpgradeData.UpgradeType.WEAPON_UNLOCK, UpgradeData.UpgradeType.WEAPON_LEVEL, UpgradeData.UpgradeType.WEAPON_PATH]:
			var w := _find_weapon(u.weapon_id)
			if w:
				if u.upgrade_type == UpgradeData.UpgradeType.WEAPON_UNLOCK:
					continue
				if w.weapon_data and w.level >= w.weapon_data.max_level:
					continue
				# Hide hardcoded level options for weapons with paths at level 1
				if u.upgrade_type == UpgradeData.UpgradeType.WEAPON_LEVEL and w.weapon_data.paths.size() > 0 and w.level == 1:
					continue
				# Hide path options for weapons that already have a path
				if u.upgrade_type == UpgradeData.UpgradeType.WEAPON_PATH and not w.current_path_id.is_empty():
					continue
			else:
				if u.upgrade_type != UpgradeData.UpgradeType.WEAPON_UNLOCK:
					continue
				if not _has_weapon_slot_available():
					continue
			filtered.append(u)
		else:
			if u.upgrade_type == UpgradeData.UpgradeType.PLAYER_STAT and not GameState.can_add_enhancement(u.id):
				continue
			filtered.append(u)

	filtered.shuffle()
	var result: Array[UpgradeData] = []
	var seen_weapons: Array[StringName] = []
	for u in filtered:
		if u.upgrade_type in [UpgradeData.UpgradeType.WEAPON_UNLOCK, UpgradeData.UpgradeType.WEAPON_LEVEL, UpgradeData.UpgradeType.WEAPON_PATH]:
			if u.weapon_id in seen_weapons:
				continue
			seen_weapons.append(u.weapon_id)
		result.append(u)
		if result.size() >= 3:
			break
	return result

func _on_option_selected(upgrade: UpgradeData) -> void:
	_apply_upgrade(upgrade)
	get_tree().paused = false

func _apply_upgrade(upgrade: UpgradeData) -> void:
	var player := get_tree().get_first_node_in_group("player")
	if not player:
		return

	var applied := true
	match upgrade.upgrade_type:
		UpgradeData.UpgradeType.WEAPON_UNLOCK:
			_level_up_weapon(upgrade.weapon_id, upgrade)
		UpgradeData.UpgradeType.WEAPON_LEVEL:
			_level_up_weapon(upgrade.weapon_id, upgrade)
		UpgradeData.UpgradeType.WEAPON_PATH:
			_apply_path_choice(upgrade)
		UpgradeData.UpgradeType.PLAYER_STAT:
			if not GameState.add_enhancement(upgrade):
				return
			_apply_stat_upgrade(player, upgrade)
		_:
			applied = false
	if applied:
		GameState.record_upgrade_selected(upgrade)

func _get_weapon_count() -> int:
	var player := get_tree().get_first_node_in_group("player")
	if not player:
		return 0
	var weapons := player.get_node_or_null("Weapons")
	if not weapons:
		return 0
	var count := 0
	for w in weapons.get_children():
		if w is WeaponBase and w.weapon_data:
			count += 1
	return count

func _has_weapon_slot_available() -> bool:
	return _get_weapon_count() < GameState.MAX_WEAPON_SLOTS

func _can_unlock_weapon(weapon_id: StringName) -> bool:
	return not _find_weapon(weapon_id) and _has_weapon_slot_available()

func _find_weapon(weapon_id: StringName) -> WeaponBase:
	var player := get_tree().get_first_node_in_group("player")
	if not player:
		return null
	var weapons := player.get_node_or_null("Weapons")
	if not weapons:
		return null
	for w in weapons.get_children():
		if w is WeaponBase and w.weapon_data and w.weapon_data.id == weapon_id:
			return w
	return null

func _unlock_weapon(weapon_id: StringName, ignore_slot_limit: bool = false) -> void:
	var scene_path: String = WEAPON_SCENES.get(weapon_id, "")
	if scene_path.is_empty():
		push_warning("Unknown weapon_id: %s" % weapon_id)
		return
	if not ignore_slot_limit and not _can_unlock_weapon(weapon_id):
		return

	var player := get_tree().get_first_node_in_group("player")
	if not player:
		return
	var weapons := player.get_node_or_null("Weapons")
	if not weapons:
		return

	var weapon_scene := ResourceLoader.load(scene_path) as PackedScene
	if not weapon_scene:
		push_warning("UpgradeSystem: failed to load weapon scene %s" % scene_path)
		return
	var weapon: Node = weapon_scene.instantiate()
	weapons.add_child(weapon)
	GameState.notify_weapons_changed()

func _level_up_weapon(weapon_id: StringName, bonus: UpgradeData) -> void:
	var w := _find_weapon(weapon_id)
	if w:
		var apply_bonus := not _is_path_managed_level_bonus(w, bonus)
		w.level_up()
		if apply_bonus:
			_apply_bonus(w, bonus)
	else:
		_unlock_weapon(weapon_id)

func _is_path_managed_level_bonus(w: WeaponBase, bonus: UpgradeData) -> bool:
	return (
		bonus
		and bonus.upgrade_type == UpgradeData.UpgradeType.WEAPON_LEVEL
		and w
		and w.weapon_data
		and not w.current_path_id.is_empty()
		and bonus.path_id == w.current_path_id
	)

func _apply_path_choice(upgrade: UpgradeData) -> void:
	var w := _find_weapon(upgrade.weapon_id)
	if not w:
		return
	if not w.current_path_id.is_empty():
		push_warning("Weapon %s already has path, ignoring path choice" % upgrade.weapon_id)
		return
	w.set_path(upgrade.path_id)
	w.level_up()

func _apply_bonus(w: WeaponBase, bonus: UpgradeData) -> void:
	if bonus.damage_bonus != 0:
		w._current_damage += bonus.damage_bonus
	if bonus.cooldown_bonus != 0:
		w._current_cooldown = max(0.1, w._current_cooldown + bonus.cooldown_bonus)
	if bonus.range_bonus != 0:
		w._current_range += bonus.range_bonus

func _apply_stat_upgrade(player: Node, upgrade: UpgradeData) -> void:
	if upgrade.speed_bonus != 0.0:
		player.move_speed = minf(GameState.MAX_PLAYER_MOVE_SPEED, player.move_speed + upgrade.speed_bonus)
		GameState.run.move_speed = player.move_speed
	if upgrade.max_hp_bonus != 0:
		GameState.run.max_hp += upgrade.max_hp_bonus
		GameState.hp_changed.emit(GameState.run.hp, GameState.run.max_hp)
	if upgrade.hp_bonus != 0:
		GameState.heal(upgrade.hp_bonus)
	if upgrade.pickup_radius_bonus != 0.0:
		GameState.run.pickup_radius_bonus = minf(
			GameState.MAX_PICKUP_RADIUS_BONUS,
			float(GameState.run.get("pickup_radius_bonus", 0.0)) + upgrade.pickup_radius_bonus
		)
	if upgrade.damage_multiplier_bonus != 0.0:
		var old_damage_multiplier := GameState.get_character_damage_multiplier()
		GameState.run.damage_multiplier = clampf(
			float(GameState.run.get("damage_multiplier", 1.0)) + upgrade.damage_multiplier_bonus,
			0.05,
			GameState.MAX_DAMAGE_MULTIPLIER
		)
		_scale_weapon_damage(player, old_damage_multiplier, GameState.get_character_damage_multiplier())
	if upgrade.cooldown_multiplier_bonus != 0.0:
		_apply_cooldown_multiplier_bonus(player, upgrade.cooldown_multiplier_bonus)
	if upgrade.area_multiplier_bonus != 0.0:
		var old_area_multiplier := GameState.get_character_area_multiplier()
		GameState.run.area_multiplier = clampf(
			float(GameState.run.get("area_multiplier", 1.0)) + upgrade.area_multiplier_bonus,
			0.05,
			GameState.MAX_AREA_MULTIPLIER
		)
		_scale_weapon_range(player, old_area_multiplier, GameState.get_character_area_multiplier())
	if upgrade.field_lifetime_multiplier_bonus != 0.0:
		GameState.run.field_lifetime_multiplier = clampf(
			float(GameState.run.get("field_lifetime_multiplier", 1.0)) + upgrade.field_lifetime_multiplier_bonus,
			0.05,
			GameState.MAX_FIELD_LIFETIME_MULTIPLIER
		)
	if upgrade.incoming_damage_multiplier_bonus != 0.0:
		GameState.run.incoming_damage_multiplier = clampf(
			float(GameState.run.get("incoming_damage_multiplier", 1.0)) + upgrade.incoming_damage_multiplier_bonus,
			GameState.MIN_INCOMING_DAMAGE_MULTIPLIER,
			5.0
		)
	if upgrade.exp_gain_multiplier_bonus != 0.0:
		GameState.run.exp_gain_multiplier = clampf(
			float(GameState.run.get("exp_gain_multiplier", 1.0)) + upgrade.exp_gain_multiplier_bonus,
			0.05,
			GameState.MAX_EXP_GAIN_MULTIPLIER
		)
	if (
		upgrade.damage_multiplier_bonus != 0.0
		or upgrade.cooldown_multiplier_bonus != 0.0
		or upgrade.area_multiplier_bonus != 0.0
	):
		GameState.notify_weapons_changed()

func _scale_weapon_damage(player: Node, old_multiplier: float, new_multiplier: float) -> void:
	if old_multiplier <= 0.0:
		return
	for w in _get_player_weapons(player):
		w._current_damage = maxi(0, int(round(float(w._current_damage) * new_multiplier / old_multiplier)))

func _apply_cooldown_multiplier_bonus(player: Node, bonus: float) -> void:
	var old_multipliers: Dictionary = {}
	for w in _get_player_weapons(player):
		old_multipliers[w] = GameState.get_character_cooldown_multiplier(w.weapon_data)
	GameState.run.cooldown_multiplier = clampf(
		float(GameState.run.get("cooldown_multiplier", 1.0)) + bonus,
		GameState.MIN_COOLDOWN_MULTIPLIER,
		5.0
	)
	for w in _get_player_weapons(player):
		var old_multiplier := float(old_multipliers.get(w, 1.0))
		if old_multiplier > 0.0:
			var new_multiplier := GameState.get_character_cooldown_multiplier(w.weapon_data)
			w._current_cooldown = maxf(0.1, w._current_cooldown * new_multiplier / old_multiplier)

func _scale_weapon_range(player: Node, old_multiplier: float, new_multiplier: float) -> void:
	if old_multiplier <= 0.0:
		return
	for w in _get_player_weapons(player):
		w._current_range = maxf(0.0, w._current_range * new_multiplier / old_multiplier)

func _get_player_weapons(player: Node) -> Array[WeaponBase]:
	var result: Array[WeaponBase] = []
	if not player:
		return result
	var weapons := player.get_node_or_null("Weapons")
	if not weapons:
		return result
	for w in weapons.get_children():
		if w is WeaponBase and w.weapon_data:
			result.append(w)
	return result

# === Helper methods for option generation ===

func _make_speed_up() -> UpgradeData:
	var d := UpgradeData.new()
	d.id = "speed_up"
	d.display_name = "疾风步"
	d.description = "移动速度 +25"
	d.upgrade_type = UpgradeData.UpgradeType.PLAYER_STAT
	d.speed_bonus = 25.0
	d.icon = ICON_SPEED_UP
	return d

func _make_hp_up() -> UpgradeData:
	var d := UpgradeData.new()
	d.id = "hp_up"
	d.display_name = "生命强化"
	d.description = "最大生命值 +30"
	d.upgrade_type = UpgradeData.UpgradeType.PLAYER_STAT
	d.max_hp_bonus = 30
	d.hp_bonus = 30
	d.icon = ICON_HP_UP
	return d

func _make_pickup_up() -> UpgradeData:
	var d := UpgradeData.new()
	d.id = "pickup_up"
	d.display_name = "磁力增幅"
	d.description = "拾取范围 +30"
	d.upgrade_type = UpgradeData.UpgradeType.PLAYER_STAT
	d.pickup_radius_bonus = 30.0
	d.icon = ICON_PICKUP_UP
	return d

func _make_regen_up() -> UpgradeData:
	var d := UpgradeData.new()
	d.id = GameState.REGEN_ENHANCEMENT_ID
	d.display_name = "生命源泉"
	d.description = "立即恢复 5 点生命；之后每 5 秒自动恢复生命，等级越高治疗量越高"
	d.upgrade_type = UpgradeData.UpgradeType.PLAYER_STAT
	d.hp_bonus = GameState.REGEN_BASE_HEAL
	d.icon = ICON_REGEN
	return d

func _make_might_up() -> UpgradeData:
	var d := UpgradeData.new()
	d.id = "might"
	d.display_name = "强攻"
	d.description = "所有武器伤害 +8%"
	d.upgrade_type = UpgradeData.UpgradeType.PLAYER_STAT
	d.damage_multiplier_bonus = 0.08
	d.icon = ICON_MIGHT
	return d

func _make_focus_up() -> UpgradeData:
	var d := UpgradeData.new()
	d.id = "focus"
	d.display_name = "专注"
	d.description = "所有武器冷却 -6%"
	d.upgrade_type = UpgradeData.UpgradeType.PLAYER_STAT
	d.cooldown_multiplier_bonus = -0.06
	d.icon = ICON_FOCUS
	return d

func _make_expansion_up() -> UpgradeData:
	var d := UpgradeData.new()
	d.id = "expansion"
	d.display_name = "扩张"
	d.description = "所有武器范围 +8%"
	d.upgrade_type = UpgradeData.UpgradeType.PLAYER_STAT
	d.area_multiplier_bonus = 0.08
	d.icon = ICON_EXPANSION
	return d

func _make_duration_up() -> UpgradeData:
	var d := UpgradeData.new()
	d.id = "field_duration"
	d.display_name = "余烬延续"
	d.description = "火焰 / 毒雾等持续场地持续时间 +12%"
	d.upgrade_type = UpgradeData.UpgradeType.PLAYER_STAT
	d.field_lifetime_multiplier_bonus = 0.12
	d.icon = ICON_FIELD_DURATION
	return d

func _make_tenacity_up() -> UpgradeData:
	var d := UpgradeData.new()
	d.id = "tenacity"
	d.display_name = "坚韧"
	d.description = "受到伤害 -8%"
	d.upgrade_type = UpgradeData.UpgradeType.PLAYER_STAT
	d.incoming_damage_multiplier_bonus = -0.08
	d.icon = ICON_TENACITY
	return d

func _make_training_up() -> UpgradeData:
	var d := UpgradeData.new()
	d.id = "training"
	d.display_name = "历练"
	d.description = "经验获取 +10%"
	d.upgrade_type = UpgradeData.UpgradeType.PLAYER_STAT
	d.exp_gain_multiplier_bonus = 0.10
	d.icon = ICON_TRAINING
	return d

func _make_unlock(weapon_id: StringName) -> UpgradeData:
	var d := UpgradeData.new()
	d.id = "unlock_%s" % weapon_id
	d.upgrade_type = UpgradeData.UpgradeType.WEAPON_UNLOCK
	d.weapon_id = weapon_id

	var weapon_data_path := "res://resources/weapons/%s.tres" % weapon_id
	if ResourceLoader.exists(weapon_data_path):
		var wdata := load(weapon_data_path)
		if wdata is WeaponData:
			d.display_name = wdata.display_name
			d.description = "解锁%s：%s" % [wdata.display_name, wdata.description]
			d.icon = wdata.icon
	else:
		d.display_name = str(weapon_id)
		d.description = "解锁新武器"
	return d

func _make_path_option(weapon: WeaponBase, path: WeaponPath) -> UpgradeData:
	var d := UpgradeData.new()
	d.id = "path_%s_%s" % [weapon.weapon_data.id, path.path_id]
	d.display_name = path.display_name
	d.description = path.description
	d.upgrade_type = UpgradeData.UpgradeType.WEAPON_PATH
	d.weapon_id = weapon.weapon_data.id
	d.path_id = path.path_id
	d.icon = path.icon if path.icon else weapon.weapon_data.icon
	d.build_tags = _infer_path_build_tags(path)
	var first_effect := path.get_level_effect(2)
	if first_effect:
		var effect_desc := _describe_path_effect(weapon, first_effect)
		var immediate_desc := "选择后升到 Lv.2，立即获得：%s" % effect_desc
		d.description = immediate_desc if d.description.is_empty() else "%s\n%s" % [d.description, immediate_desc]
		d.damage_bonus = first_effect.damage_bonus
		d.cooldown_bonus = first_effect.cooldown_bonus
		d.range_bonus = first_effect.range_bonus
	return d

func _make_level_from_path(weapon: WeaponBase, path: WeaponPath, effect: WeaponPathLevel) -> UpgradeData:
	var d := UpgradeData.new()
	d.id = "level_%s_%d" % [weapon.weapon_data.id, weapon.level + 1]
	var path_name := path.display_name if path else ""
	if path_name.is_empty():
		d.display_name = "%s Lv.%d" % [weapon.weapon_data.display_name, weapon.level + 1]
	else:
		d.display_name = "%s·%s Lv.%d" % [weapon.weapon_data.display_name, path_name, weapon.level + 1]
	d.description = _describe_path_effect(weapon, effect)
	d.upgrade_type = UpgradeData.UpgradeType.WEAPON_LEVEL
	d.weapon_id = weapon.weapon_data.id
	d.path_id = path.path_id if path else &""
	d.damage_bonus = effect.damage_bonus
	d.cooldown_bonus = effect.cooldown_bonus
	d.range_bonus = effect.range_bonus
	d.icon = weapon.weapon_data.icon
	if path:
		d.build_tags = _infer_path_build_tags(path)
	return d

func _describe_path_effect(weapon: WeaponBase, effect: WeaponPathLevel) -> String:
	if not effect:
		return ""
	if effect.description:
		return effect.description
	var parts: Array[String] = []
	if effect.damage_bonus != 0:
		parts.append("伤害+%d" % effect.damage_bonus)
	if effect.cooldown_bonus != 0:
		parts.append("冷却%+.2f" % effect.cooldown_bonus)
	if effect.range_bonus != 0:
		parts.append("范围+%d" % int(effect.range_bonus))
	if parts.is_empty():
		parts.append("%s强化" % weapon.weapon_data.display_name)
	return "  |  ".join(parts)

func _infer_path_build_tags(path: WeaponPath) -> Array[String]:
	if not path:
		return []
	var scores: Dictionary = {
		"输出": 0,
		"范围": 0,
		"控制": 0,
		"频率": 0,
		"生存": 0,
		"穿透": 0,
	}
	var text := "%s %s" % [path.display_name, path.description]
	for effect in path.levels:
		if effect.damage_bonus != 0:
			scores["输出"] += 2
		if effect.cooldown_bonus != 0.0:
			scores["频率"] += 2
		if effect.range_bonus != 0:
			scores["范围"] += 2
		text += " %s %s" % [effect.description, str(effect.special_tag)]
	_score_path_keywords(text.to_lower(), scores)

	var priority := ["输出", "范围", "控制", "频率", "生存", "穿透"]
	var tags: Array[String] = []
	for tag in priority:
		if int(scores.get(tag, 0)) > 0:
			tags.append(tag)
	tags.sort_custom(func(a: String, b: String) -> bool:
		var score_a := int(scores.get(a, 0))
		var score_b := int(scores.get(b, 0))
		if score_a == score_b:
			return priority.find(a) < priority.find(b)
		return score_a > score_b
	)
	return tags.slice(0, 3)

func _score_path_keywords(text: String, scores: Dictionary) -> void:
	_add_keyword_score(text, scores, "输出", [
		"伤害", "暴击", "燃烧", "毒素", "火焰", "高压",
		"damage", "crit", "heavy", "slug", "burn", "poison", "inferno", "overload", "rend", "fracture", "cleaver",
	])
	_add_keyword_score(text, scores, "范围", [
		"范围", "射程", "持续", "蔓延", "连锁", "弹丸", "数量", "轨道", "散射",
		"range", "wide", "wider", "longer", "eternal", "extra", "more", "triple", "quad", "volley", "swarm", "deluge", "chain", "split", "storm", "wall",
	])
	_add_keyword_score(text, scores, "控制", [
		"控制", "减速", "眩晕", "击退", "冰封", "震慑",
		"slow", "stun", "freeze", "frozen", "knockback", "paralyze", "lockdown",
	])
	_add_keyword_score(text, scores, "频率", [
		"冷却", "速度", "转速", "快速", "连发",
		"cooldown", "rapid", "faster", "fast", "speed", "double", "dual",
	])
	_add_keyword_score(text, scores, "生存", [
		"治疗", "恢复", "反伤", "防御", "守护", "复仇",
		"heal", "reflect", "thorns", "guardian", "vengeance", "cure",
	])
	_add_keyword_score(text, scores, "穿透", [
		"穿透", "穿甲",
		"pierce", "sniper", "armor",
	])

func _add_keyword_score(text: String, scores: Dictionary, tag: String, keywords: Array[String]) -> void:
	for keyword in keywords:
		if text.contains(keyword):
			scores[tag] += 1

func _get_hardcoded_level_option(weapon_id: StringName) -> UpgradeData:
	match weapon_id:
		&"projectile_basic":
			return _make_level_opt("projectile_dmg", "箭矢强化", "弹体伤害 +3", &"projectile_basic", 3)
		&"thunder":
			return _make_level_opt("thunder_dmg", "雷霆万钧", "落雷伤害 +8", &"thunder", 8)
		&"shotgun":
			return _make_level_opt("shotgun_dmg", "弹幕强化", "散弹枪伤害 +4", &"shotgun", 4)
		&"fire_bottle":
			return _make_level_opt("fire_dmg", "烈火焚身", "火焰瓶燃烧伤害 +2", &"fire_bottle", 2)
		&"frost_ring":
			return _make_level_opt("frost_dmg", "极寒之触", "冰霜环伤害 +3", &"frost_ring", 3)
		&"holy_prism":
			return _make_level_opt("prism_dmg", "圣光强化", "圣光棱镜伤害 +5", &"holy_prism", 5)
		&"poison_vial":
			return _make_level_opt("poison_dmg", "剧毒蔓延", "毒液罐伤害 +2", &"poison_vial", 2)
		&"mine":
			return _make_level_opt("mine_dmg", "爆破专家", "地雷爆炸伤害 +5", &"mine", 5)
		&"laser_pen":
			return _make_level_opt("laser_dmg", "高能聚焦", "激光笔伤害 +3", &"laser_pen", 3)
		&"boomerang":
			return _make_level_opt("boomerang_dmg", "锋刃强化", "回旋镖伤害 +4", &"boomerang", 4)
		&"electromagnetic_chain":
			return _make_level_opt("chain_dmg", "电弧增强", "电磁链伤害 +4", &"electromagnetic_chain", 4)
		&"saw_blade":
			return _make_level_opt("saw_dmg", "锯齿打磨", "锯片陷阱伤害 +3", &"saw_blade", 3)
		&"rocket_pack":
			return _make_level_opt("rocket_dmg", "燃料升级", "火箭背包伤害 +2", &"rocket_pack", 2)
		&"whirlwind":
			return _make_level_opt("whirlwind_dmg", "旋风打磨", "旋风斩伤害 +3", &"whirlwind", 3)
		&"throwing_axe":
			return _make_level_opt("axe_dmg", "重斧打磨", "投掷斧伤害 +5", &"throwing_axe", 5)
		&"shockwave":
			return _make_level_opt("shockwave_dmg", "震荡强化", "冲击波伤害 +3", &"shockwave", 3)
		&"spark_bomb":
			return _make_level_opt("spark_bomb_dmg", "火花增幅", "火花弹伤害 +3", &"spark_bomb", 3)
		&"melee_basic":
			return _make_level_opt("melee_dmg", "利刃强化", "近战武器伤害 +5", &"melee_basic", 5)
	return null

func _make_level_opt(id: String, name: String, desc: String, weapon_id: StringName, dmg: int) -> UpgradeData:
	var d := UpgradeData.new()
	d.id = id
	d.display_name = name
	d.description = desc
	d.upgrade_type = UpgradeData.UpgradeType.WEAPON_LEVEL
	d.weapon_id = weapon_id
	d.damage_bonus = dmg
	return d
