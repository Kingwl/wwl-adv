extends CanvasLayer

var _touch_index: int = -1
var _direction: Vector2 = Vector2.ZERO
var _base_center: Vector2
var _max_distance: float = 40.0

@onready var _base: Control = $Base
@onready var _knob: Control = $Base/Knob

func _ready() -> void:
	_base.visible = OS.has_feature("android") or OS.has_feature("ios") or OS.has_feature("web")
	_base_center = _base.global_position + _base.size / 2

func get_direction() -> Vector2:
	return _direction

func _input(event: InputEvent) -> void:
	if not _base.visible:
		return
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed and _touch_index == -1:
			if touch.position.x < get_viewport().get_visible_rect().size.x / 2:
				_touch_index = touch.index
				_update_knob(touch.position)
		elif not touch.pressed and touch.index == _touch_index:
			_touch_index = -1
			_direction = Vector2.ZERO
			_knob.position = (_base.size - _knob.size) / 2
	elif event is InputEventScreenDrag and _touch_index != -1:
		var drag := event as InputEventScreenDrag
		if drag.index == _touch_index:
			_update_knob(drag.position)

func _update_knob(touch_pos: Vector2) -> void:
	var offset := touch_pos - _base_center
	var distance := offset.length()
	if distance > _max_distance:
		offset = offset.normalized() * _max_distance
		distance = _max_distance
	_knob.position = (_base.size - _knob.size) / 2 + offset
	_direction = offset / _max_distance if _max_distance > 0 else Vector2.ZERO
