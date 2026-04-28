extends Area2D

var damage: int = 20
var explosion_radius: float = 60.0
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
		2,
		4.0
	)

func _on_body_entered(body: Node2D) -> void:
	if _triggered:
		return
	if body.is_in_group("enemies"):
		_triggered = true
		_explode()

func _explode() -> void:
	# 范围伤害
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.global_position.distance_to(global_position) <= explosion_radius:
			enemy.take_damage(damage)

	# 爆炸视觉效果
	var scale_factor := maxf(1.0, explosion_radius * 2.0 / 64.0)
	VFXHelper.spawn_animated_one_shot(
		get_tree().current_scene,
		"res://assets/art/effects/by_type/fx_explosion",
		"explosion",
		8,
		global_position,
		12.0,
		Vector2(scale_factor, scale_factor)
	)

	queue_free()
