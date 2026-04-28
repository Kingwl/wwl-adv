extends CanvasLayer

@export var max_distance: float = 48.0
@export_range(0.0, 0.9, 0.01) var deadzone_ratio: float = 0.16
@export_range(0.1, 1.0, 0.01) var active_width_ratio: float = 1.0
@export var floating: bool = true

const MOUSE_POINTER_INDEX := -2

var _touch_index: int = -1
var _direction: Vector2 = Vector2.ZERO
var _base_center: Vector2
var _rest_base_position: Vector2

@onready var _base: Control = $Base
@onready var _knob: Control = $Base/Knob

func _ready() -> void:
	_base.visible = OS.has_feature("android") or OS.has_feature("ios") or OS.has_feature("web")
	_base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rest_base_position = _base.global_position
	_base_center = _get_base_center()
	_center_knob()

func get_direction() -> Vector2:
	return _direction

func _input(event: InputEvent) -> void:
	if not _base.visible:
		return
	if get_tree().paused:
		_release_pointer()
		return
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed and _touch_index == -1:
			if _is_position_in_active_area(touch.position):
				_begin_pointer(touch.index, touch.position)
		elif not touch.pressed and touch.index == _touch_index:
			_release_pointer()
	elif event is InputEventScreenDrag and _touch_index != -1:
		var drag := event as InputEventScreenDrag
		if drag.index == _touch_index:
			_update_knob(drag.position)
	elif event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.button_index != MOUSE_BUTTON_LEFT:
			return
		if mouse_button.pressed and _touch_index == -1:
			if _is_position_in_active_area(mouse_button.position):
				_begin_pointer(MOUSE_POINTER_INDEX, mouse_button.position)
		elif not mouse_button.pressed and _touch_index == MOUSE_POINTER_INDEX:
			_release_pointer()
	elif event is InputEventMouseMotion and _touch_index == MOUSE_POINTER_INDEX:
		var mouse_motion := event as InputEventMouseMotion
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			_update_knob(mouse_motion.position)

func _begin_pointer(pointer_index: int, pointer_position: Vector2) -> void:
	_touch_index = pointer_index
	if floating:
		_base.global_position = pointer_position - _base.size * 0.5
		_base_center = _get_base_center()
	_update_knob(pointer_position)

func _release_pointer() -> void:
	if _touch_index == -1:
		return
	_touch_index = -1
	_direction = Vector2.ZERO
	if floating:
		_base.global_position = _rest_base_position
		_base_center = _get_base_center()
	_center_knob()

func _is_position_in_active_area(position: Vector2) -> bool:
	var viewport_width := get_viewport().get_visible_rect().size.x
	return position.x <= viewport_width * active_width_ratio and not _is_position_on_button(position)

func _is_position_on_button(position: Vector2) -> bool:
	return _node_has_button_at_position(get_tree().root, position)

func _node_has_button_at_position(node: Node, position: Vector2) -> bool:
	if node == self or self.is_ancestor_of(node):
		return false
	if node is BaseButton:
		var button := node as BaseButton
		if button.is_visible_in_tree() and not button.disabled and button.mouse_filter != Control.MOUSE_FILTER_IGNORE:
			if button.get_global_rect().has_point(position):
				return true
	for child in node.get_children():
		if _node_has_button_at_position(child, position):
			return true
	return false

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
