extends "res://scripts/main_hud_final.gd"

const FIXED_JOYSTICK_RADIUS := 72.0
const JOYSTICK_DEAD_ZONE := 0.10

var fixed_joystick_base: Control
var fixed_joystick_label: Label


func _build_joystick(root):
	fixed_joystick_base = ColorRect.new()
	fixed_joystick_base.name = "FixedMovementJoystick"
	fixed_joystick_base.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	fixed_joystick_base.position = Vector2(28.0, -190.0)
	fixed_joystick_base.size = Vector2(160.0, 160.0)
	fixed_joystick_base.color = Color(0.055, 0.16, 0.34, 0.78)
	fixed_joystick_base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(fixed_joystick_base)

	var cross_vertical := ColorRect.new()
	cross_vertical.position = Vector2(76.0, 20.0)
	cross_vertical.size = Vector2(8.0, 120.0)
	cross_vertical.color = Color(0.46, 0.70, 0.96, 0.24)
	cross_vertical.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fixed_joystick_base.add_child(cross_vertical)

	var cross_horizontal := ColorRect.new()
	cross_horizontal.position = Vector2(20.0, 76.0)
	cross_horizontal.size = Vector2(120.0, 8.0)
	cross_horizontal.color = Color(0.46, 0.70, 0.96, 0.24)
	cross_horizontal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fixed_joystick_base.add_child(cross_horizontal)

	joystick_knob = ColorRect.new()
	joystick_knob.name = "MovementKnob"
	joystick_knob.position = Vector2(52.0, 52.0)
	joystick_knob.size = Vector2(56.0, 56.0)
	joystick_knob.color = Color(0.66, 0.86, 1.0, 0.96)
	joystick_knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fixed_joystick_base.add_child(joystick_knob)

	fixed_joystick_label = Label.new()
	fixed_joystick_label.text = "DÉPLACEMENT"
	fixed_joystick_label.position = Vector2(8.0, 132.0)
	fixed_joystick_label.size = Vector2(144.0, 24.0)
	fixed_joystick_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fixed_joystick_label.add_theme_font_size_override("font_size", 12)
	fixed_joystick_label.add_theme_constant_override("outline_size", 4)
	fixed_joystick_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fixed_joystick_base.add_child(fixed_joystick_label)


func _input(event):
	if is_instance_valid(map_panel) and map_panel.visible:
		_release_movement_touch()
		return

	if event is InputEventScreenTouch:
		_handle_screen_touch(event)
	elif event is InputEventScreenDrag:
		_handle_screen_drag(event)


# The parent implementation used the first touch position as the joystick
# centre. A simple press therefore produced Vector2.ZERO and the hero stayed
# still. All mobile touch handling is performed in _input() above instead.
func _unhandled_input(_event):
	pass


func _handle_screen_touch(event: InputEventScreenTouch):
	var screen_size := get_viewport().get_visible_rect().size

	if event.pressed:
		if move_touch_id < 0 and _is_movement_area(event.position, screen_size):
			move_touch_id = event.index
			move_origin = _fixed_joystick_center()
			_update_fixed_joystick(event.position)
			get_viewport().set_input_as_handled()
			return

		if look_touch_id < 0 and _is_camera_area(event.position, screen_size):
			look_touch_id = event.index
			get_viewport().set_input_as_handled()
			return
	else:
		if event.index == move_touch_id:
			_release_movement_touch()
			get_viewport().set_input_as_handled()
			return
		if event.index == look_touch_id:
			look_touch_id = -1
			get_viewport().set_input_as_handled()
			return


func _handle_screen_drag(event: InputEventScreenDrag):
	if event.index == move_touch_id:
		_update_fixed_joystick(event.position)
		get_viewport().set_input_as_handled()
		return

	if event.index == look_touch_id and is_instance_valid(player):
		player.add_camera_look(event.relative * 0.0042)
		get_viewport().set_input_as_handled()


func _is_movement_area(position: Vector2, screen_size: Vector2) -> bool:
	if position.x > screen_size.x * 0.48:
		return false
	if position.y < screen_size.y * 0.34:
		return false
	return true


func _is_camera_area(position: Vector2, screen_size: Vector2) -> bool:
	# Keep the four action buttons and the map button fully clickable.
	if position.x > screen_size.x * 0.70 and position.y > screen_size.y * 0.67:
		return false
	if position.x > screen_size.x * 0.78 and position.y < 105.0:
		return false
	return position.x >= screen_size.x * 0.42


func _fixed_joystick_center() -> Vector2:
	if is_instance_valid(fixed_joystick_base):
		var rect := fixed_joystick_base.get_global_rect()
		return rect.position + rect.size * 0.5
	var visible_size := get_viewport().get_visible_rect().size
	return Vector2(108.0, visible_size.y - 110.0)


func _update_fixed_joystick(screen_position: Vector2):
	move_origin = _fixed_joystick_center()
	var offset := (screen_position - move_origin).limit_length(FIXED_JOYSTICK_RADIUS)
	var direction := offset / FIXED_JOYSTICK_RADIUS
	if direction.length() < JOYSTICK_DEAD_ZONE:
		direction = Vector2.ZERO
	virtual_move = direction

	if is_instance_valid(joystick_knob):
		joystick_knob.position = Vector2(52.0, 52.0) + offset
	if is_instance_valid(fixed_joystick_label):
		fixed_joystick_label.text = "AVANCE" if virtual_move.length() > JOYSTICK_DEAD_ZONE else "DÉPLACEMENT"


func _release_movement_touch():
	move_touch_id = -1
	virtual_move = Vector2.ZERO
	if is_instance_valid(joystick_knob):
		joystick_knob.position = Vector2(52.0, 52.0)
	if is_instance_valid(fixed_joystick_label):
		fixed_joystick_label.text = "DÉPLACEMENT"
