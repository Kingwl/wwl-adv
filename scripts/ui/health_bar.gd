extends ProgressBar

@export var bar_color: Color = Color(0.85, 0.2, 0.2, 1)
@export var auto_hide: bool = false
@export var hide_delay: float = 2.5

var _hide_timer: float = 0.0

func _ready() -> void:
	show_percentage = false
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.08, 0.08, 0.08, 0.85)
	add_theme_stylebox_override("background", bg)

	var fill := StyleBoxFlat.new()
	fill.bg_color = bar_color
	add_theme_stylebox_override("fill", fill)

	if auto_hide:
		visible = false

func _process(delta: float) -> void:
	if auto_hide and visible and _hide_timer > 0:
		_hide_timer -= delta
		if _hide_timer <= 0:
			visible = false

func update_health(current: int, max_hp: int) -> void:
	max_value = max_hp
	value = current
	if auto_hide:
		visible = true
		_hide_timer = hide_delay
