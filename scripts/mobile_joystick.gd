class_name MobileJoystick
extends Control

signal value_changed(value: Vector2)

@export var base_radius: float = 92.0
@export var knob_radius: float = 38.0
@export var dead_zone: float = 0.12

var value: Vector2 = Vector2.ZERO
var _touch_id: int = -1
var _mouse_active: bool = false

func _ready() -> void:
	custom_minimum_size = Vector2(base_radius * 2.4, base_radius * 2.4)
	mouse_filter = Control.MOUSE_FILTER_STOP
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event as InputEventScreenTouch
		if touch.pressed and _touch_id == -1:
			_touch_id = touch.index
			_update_from_local(touch.position)
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
				_update_from_local(mouse_button.position)
			else:
				_reset()
			accept_event()
	elif event is InputEventMouseMotion and _mouse_active:
		var mouse_motion: InputEventMouseMotion = event as InputEventMouseMotion
		_update_from_local(mouse_motion.position)
		accept_event()

func _update_from_local(local_position: Vector2) -> void:
	var center: Vector2 = size * 0.5
	var offset: Vector2 = local_position - center
	var limited: Vector2 = offset.limit_length(base_radius)
	var raw_value: Vector2 = limited / base_radius
	if raw_value.length() < dead_zone:
		value = Vector2.ZERO
	else:
		var normalized_strength: float = inverse_lerp(dead_zone, 1.0, raw_value.length())
		value = raw_value.normalized() * normalized_strength
	value_changed.emit(value)
	queue_redraw()

func _reset() -> void:
	value = Vector2.ZERO
	value_changed.emit(value)
	queue_redraw()

func _draw() -> void:
	var center: Vector2 = size * 0.5
	draw_circle(center, base_radius + 8.0, Color(0.02, 0.04, 0.08, 0.32))
	draw_circle(center, base_radius, Color(0.08, 0.16, 0.27, 0.62))
	draw_arc(center, base_radius, 0.0, TAU, 64, Color(0.35, 0.72, 1.0, 0.72), 4.0, true)
	var knob_center: Vector2 = center + value * base_radius
	draw_circle(knob_center, knob_radius + 5.0, Color(0.02, 0.04, 0.08, 0.45))
	draw_circle(knob_center, knob_radius, Color(0.40, 0.74, 1.0, 0.90))
	draw_arc(knob_center, knob_radius, 0.0, TAU, 48, Color(0.85, 0.95, 1.0, 0.96), 3.0, true)
