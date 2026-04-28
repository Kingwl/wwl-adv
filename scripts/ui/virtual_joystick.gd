extends CanvasLayer

@export var max_distance: float = 48.0
@export_range(0.0, 0.9, 0.01) var deadzone_ratio: float = 0.16
@export var floating: bool = true

var _touch_index: int = -1
var _direction: Vector2 = Vector2.ZERO
var _base_center: Vector2
var _rest_base_position: Vector2

@onready var _base: Control = $Base
@onready var _knob: Control = $Base/Knob

func _ready() -> void:
	_base.visible = OS.has_feature("android") or OS.has_feature("ios") or OS.has_feature("web")
	_rest_base_position = _base.global_position
	_base_center = _get_base_center()
	_center_knob()

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
				if floating:
					_base.global_position = touch.position - _base.size * 0.5
					_base_center = _get_base_center()
				_update_knob(touch.position)
		elif not touch.pressed and touch.index == _touch_index:
			_touch_index = -1
			_direction = Vector2.ZERO
			if floating:
				_base.global_position = _rest_base_position
				_base_center = _get_base_center()
			_center_knob()
	elif event is InputEventScreenDrag and _touch_index != -1:
		var drag := event as InputEventScreenDrag
		if drag.index == _touch_index:
			_update_knob(drag.position)

func _update_knob(touch_pos: Vector2) -> void:
	var offset := touch_pos - _base_center
	var distance := offset.length()
	var visual_offset := offset.limit_length(max_distance)
	_knob.position = (_base.size - _knob.size) / 2 + visual_offset
	_direction = _direction_from_offset(offset, distance)

func _direction_from_offset(offset: Vector2, distance: float = -1.0) -> Vector2:
	if max_distance <= 0.0:
		return Vector2.ZERO
	if distance < 0.0:
		distance = offset.length()
	var deadzone := max_distance * deadzone_ratio
	if distance <= deadzone:
		return Vector2.ZERO
	var strength := clampf((distance - deadzone) / (max_distance - deadzone), 0.0, 1.0)
	return offset.normalized() * strength

func _get_base_center() -> Vector2:
	return _base.global_position + _base.size * 0.5

func _center_knob() -> void:
	_knob.position = (_base.size - _knob.size) / 2
