extends Area2D

var direction: Vector2 = Vector2.RIGHT
var speed: float = 300.0
var damage: int = 10
var max_range: float = 200.0
var pierce: int = 0
var is_boomerang: bool = false

var _start_pos: Vector2
var _pierced: int = 0
var _returning: bool = false
var _player: Node2D

func _ready() -> void:
	_start_pos = global_position
	_player = get_tree().get_first_node_in_group("player")
	body_entered.connect(_on_body_entered)

	# Remove scene's default visual to avoid duplicates
	var old_visual := get_node_or_null("Visual")
	if old_visual:
		old_visual.queue_free()

	if is_boomerang:
		var anim := AnimatedSprite2D.new()
		var frames := SpriteFrames.new()
		var sheet := preload("res://assets/art/weapons/projectiles/proj_boomerang_sheet.png")
		for i in range(4):
			var atlas := AtlasTexture.new()
			atlas.atlas = sheet
			atlas.region = Rect2(i * 24, 0, 24, 24)
			frames.add_frame("default", atlas)
		frames.set_animation_loop("default", true)
		frames.set_animation_speed("default", 12.0)
		anim.sprite_frames = frames
		anim.play("default")
		add_child(anim)
	else:
		var visual := Sprite2D.new()
		visual.texture = preload("res://assets/art/weapons/projectiles/arrow.png")
		visual.rotation = direction.angle() + PI
		add_child(visual)

func _process(delta: float) -> void:
	if is_boomerang and _returning:
		if _player:
			var dir := (_player.global_position - global_position).normalized()
			global_position += dir * speed * delta
			if global_position.distance_to(_player.global_position) < 20.0:
				queue_free()
		return

	global_position += direction * speed * delta
	if not _returning and global_position.distance_to(_start_pos) > max_range:
		if is_boomerang:
			_returning = true
		else:
			queue_free()

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("enemies"):
		body.take_damage(damage)
		_pierced += 1
		if _pierced > pierce and not is_boomerang:
			queue_free()
