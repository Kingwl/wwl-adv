extends Area2D

var damage: int = 20
var explosion_radius: float = 60.0
var cluster_count: int = 0
var source: Node = null
var damage_owner: Node = null
var weapon_id: StringName = &""
var damage_type: StringName = DamageEvent.DAMAGE_TYPE_PHYSICAL
var delivery_type: StringName = DamageEvent.DELIVERY_AREA
var _triggered: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)

	var shape := CircleShape2D.new()
	shape.radius = 8.0
	var cs := CollisionShape2D.new()
	cs.shape = shape
	add_child(cs)

	VFXHelper.spawn_animated_loop(
		self,
		"res://assets/art/effects/by_type/fx_mine_blink",
		"mine_blink",
		4,
		4.0
	)

func _on_body_entered(body: Node2D) -> void:
	if _triggered:
		return
	if body.is_in_group("enemies"):
		_triggered = true
		_explode()

func _explode() -> void:
	var audio_manager := get_node_or_null("/root/AudioManager")
	if audio_manager and audio_manager.has_method("play_weapon_sfx"):
		audio_manager.call("play_weapon_sfx", weapon_id, 0.0, 0.05)
	_deal_area_damage(global_position, explosion_radius, damage)
	_show_explosion(global_position, explosion_radius)
	if cluster_count > 0:
		_explode_clusters()

	queue_free()

func _deal_area_damage(center: Vector2, radius: float, amount: int) -> void:
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.global_position.distance_to(center) <= radius:
			var event := DamageEvent.from_amount(amount, source if source else self, damage_type, delivery_type)
			event.owner = damage_owner
			event.target = enemy
			event.weapon_id = weapon_id
			event.position = center
			DamageCalculator.deal_damage(enemy, event)

func _show_explosion(pos: Vector2, radius: float) -> void:
	var scale_factor := maxf(1.0, radius * 2.0 / 64.0)
	VFXHelper.spawn_animated_one_shot(
		get_tree().current_scene,
		"res://assets/art/effects/by_type/fx_explosion",
		"explosion",
		8,
		pos,
		12.0,
		Vector2(scale_factor, scale_factor)
	)

func _explode_clusters() -> void:
	var cluster_radius := explosion_radius * 0.55
	var cluster_damage := maxi(1, int(round(float(damage) * 0.5)))
	for i in range(cluster_count):
		var angle := TAU * float(i) / float(cluster_count)
		var pos := global_position + Vector2(cos(angle), sin(angle)) * explosion_radius * 0.55
		_deal_area_damage(pos, cluster_radius, cluster_damage)
		_show_explosion(pos, cluster_radius)
