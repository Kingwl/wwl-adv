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
}

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
	for stat_upgrade in [_make_speed_up(), _make_hp_up(), _make_pickup_up(), _make_regen_up()]:
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
		w.level_up()
		_apply_bonus(w, bonus)
	else:
		_unlock_weapon(weapon_id)

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
		player.move_speed += upgrade.speed_bonus
	if upgrade.max_hp_bonus != 0:
		GameState.run.max_hp += upgrade.max_hp_bonus
		GameState.hp_changed.emit(GameState.run.hp, GameState.run.max_hp)
	if upgrade.hp_bonus != 0:
		GameState.heal(upgrade.hp_bonus)
	if upgrade.pickup_radius_bonus != 0.0:
		GameState.run.pickup_radius_bonus += upgrade.pickup_radius_bonus

# === Helper methods for option generation ===

func _make_speed_up() -> UpgradeData:
	var d := UpgradeData.new()
	d.id = "speed_up"
	d.display_name = "疾风步"
	d.description = "移动速度 +25"
	d.upgrade_type = UpgradeData.UpgradeType.PLAYER_STAT
	d.speed_bonus = 25.0
	return d

func _make_hp_up() -> UpgradeData:
	var d := UpgradeData.new()
	d.id = "hp_up"
	d.display_name = "生命强化"
	d.description = "最大生命值 +30"
	d.upgrade_type = UpgradeData.UpgradeType.PLAYER_STAT
	d.max_hp_bonus = 30
	d.hp_bonus = 30
	return d

func _make_pickup_up() -> UpgradeData:
	var d := UpgradeData.new()
	d.id = "pickup_up"
	d.display_name = "磁力增幅"
	d.description = "拾取范围 +30"
	d.upgrade_type = UpgradeData.UpgradeType.PLAYER_STAT
	d.pickup_radius_bonus = 30.0
	return d

func _make_regen_up() -> UpgradeData:
	var d := UpgradeData.new()
	d.id = GameState.REGEN_ENHANCEMENT_ID
	d.display_name = "生命源泉"
	d.description = "立即恢复 5 点生命；之后每 5 秒自动恢复生命，等级越高治疗量越高"
	d.upgrade_type = UpgradeData.UpgradeType.PLAYER_STAT
	d.hp_bonus = GameState.REGEN_BASE_HEAL
	d.icon = preload("res://assets/art/weapons/icons_sliced/icon_05.png")
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
	d.damage_bonus = effect.damage_bonus
	d.cooldown_bonus = effect.cooldown_bonus
	d.range_bonus = effect.range_bonus
	d.icon = weapon.weapon_data.icon
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
