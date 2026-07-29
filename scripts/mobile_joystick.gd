class_name MobileJoystick
extends Control

signal value_changed(value: Vector2)

@export var base_radius: float = 82.0
@export var knob_radius: float = 34.0
@export var dead_zone: float = 0.08
@export var response_power: float = 1.15

var value: Vector2 = Vector2.ZERO
var _touch_id: int = -1
var _mouse_active: bool = false
var _active: bool = false
var _center: Vector2 = Vector2.ZERO
var _knob_offset: Vector2 = Vector2.ZERO

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_center = Vector2(base_radius + 28.0, size.y - base_radius - 28.0)
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and not _active:
		_center = Vector2(base_radius + 28.0, size.y - base_radius - 28.0)
		queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event as InputEventScreenTouch
		if touch.pressed and _touch_id == -1:
			_touch_id = touch.index
			_begin_at(touch.position)
			accept_event()
		elif not touch.pressed and touch.index == _touch_id:
			_touch_id = -1
			_reset()
			accept_event()
	elif event is InputEventScreenDrag:
		var drag: InputEventScreenDrag = event as InputEventScreenDrag
		if drag.index == _touch_id:
			_update_from_local(drag.position)
			accept_event()
	elif event is InputEventMouseButton:
		var mouse_button: InputEventMouseButton = event as InputEventMouseButton
		if mouse_button.button_index == MOUSE_BUTTON_LEFT:
			_mouse_active = mouse_button.pressed
			if _mouse_active:
				_begin_at(mouse_button.position)
			else:
				_reset()
			accept_event()
	elif event is InputEventMouseMotion and _mouse_active:
		var mouse_motion: InputEventMouseMotion = event as InputEventMouseMotion
		_update_from_local(mouse_motion.position)
		accept_event()

func _begin_at(local_position: Vector2) -> void:
	_active = true
	var margin: float = base_radius + 10.0
	_center = Vector2(
		clampf(local_position.x, margin, maxf(margin, size.x - margin)),
		clampf(local_position.y, margin, maxf(margin, size.y - margin))
	)
	_knob_offset = Vector2.ZERO
	value = Vector2.ZERO
	value_changed.emit(value)
	queue_redraw()

func _update_from_local(local_position: Vector2) -> void:
	var offset: Vector2 = local_position - _center
	_knob_offset = offset.limit_length(base_radius)
	var raw_value: Vector2 = _knob_offset / base_radius
	var raw_strength: float = raw_value.length()
	if raw_strength <= dead_zone:
		value = Vector2.ZERO
	else:
		var normalized_strength: float = clampf(inverse_lerp(dead_zone, 1.0, raw_strength), 0.0, 1.0)
		normalized_strength = pow(normalized_strength, response_power)
		value = raw_value.normalized() * normalized_strength
	value_changed.emit(value)
	queue_redraw()

func _reset() -> void:
	_active = false
	value = Vector2.ZERO
	_knob_offset = Vector2.ZERO
	_center = Vector2(base_radius + 28.0, size.y - base_radius - 28.0)
	value_changed.emit(value)
	queue_redraw()

func _draw() -> void:
	var base_alpha: float = 0.72 if _active else 0.36
	var center_value: Vector2 = _center
	draw_circle(center_value, base_radius + 9.0, Color(0.01, 0.02, 0.04, base_alpha * 0.54))
	draw_circle(center_value, base_radius, Color(0.035, 0.10, 0.18, base_alpha))
	draw_arc(center_value, base_radius, 0.0, TAU, 72, Color(0.32, 0.74, 1.0, base_alpha + 0.14), 4.0, true)
	draw_circle(center_value, base_radius * 0.46, Color(0.10, 0.28, 0.45, base_alpha * 0.45))
	var knob_center: Vector2 = center_value + _knob_offset
	draw_circle(knob_center, knob_radius + 6.0, Color(0.01, 0.02, 0.04, 0.58))
	draw_circle(knob_center, knob_radius, Color(0.36, 0.76, 1.0, 0.94 if _active else 0.68))
	draw_arc(knob_center, knob_radius, 0.0, TAU, 56, Color(0.90, 0.97, 1.0, 0.98), 3.0, true)
