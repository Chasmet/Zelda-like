extends Node

const MAX_WAIT_SECONDS := 120.0
const TEST_TOUCH_ID := 27


func _ready() -> void:
	if "--ci-walk-check" not in OS.get_cmdline_user_args():
		return
	call_deferred("_run_walk_check")


func _run_walk_check() -> void:
	var game := get_parent()
	var started_at := Time.get_ticks_msec()
	var player: Node = null
	var animator: Node = null
	var joystick_base: Control = null

	while (Time.get_ticks_msec() - started_at) < int(MAX_WAIT_SECONDS * 1000.0):
		await get_tree().process_frame
		player = game.get("player")
		joystick_base = game.get("fixed_joystick_base")
		if not is_instance_valid(player) or not is_instance_valid(joystick_base):
			continue
		animator = player.get("_model_animator")
		var loading_screen = game.get("loading_screen")
		if is_instance_valid(animator) and (not is_instance_valid(loading_screen) or not loading_screen.visible):
			break

	if not is_instance_valid(player) or not is_instance_valid(animator) or not is_instance_valid(joystick_base):
		push_error("CI TOUCH CHECK: player, joystick or animator was not created")
		get_tree().quit(4)
		return

	if not bool(animator.call("is_rig_ready")):
		push_error("CI TOUCH CHECK: Arm_L, Arm_R, Leg_L or Leg_R pivot is missing")
		get_tree().quit(5)
		return

	var joystick_rect: Rect2 = joystick_base.get_global_rect()
	var joystick_center: Vector2 = joystick_rect.position + joystick_rect.size * 0.5
	var forward_touch: Vector2 = joystick_center + Vector2(0.0, -60.0)
	var start_position: Vector3 = player.global_position

	var press := InputEventScreenTouch.new()
	press.index = TEST_TOUCH_ID
	press.position = forward_touch
	press.pressed = true
	Input.parse_input_event(press)
	await get_tree().process_frame

	var applied_move: Vector2 = game.get("virtual_move")
	if applied_move.length() < 0.45 or applied_move.y > -0.35:
		push_error("CI TOUCH CHECK: touching above the joystick did not create forward movement: %s" % applied_move)
		_release_touch(forward_touch)
		get_tree().quit(6)
		return

	await get_tree().create_timer(0.31).timeout
	var first_position: Vector3 = player.global_position
	var first_pose: Vector4 = animator.call("get_animation_signature")
	await get_tree().create_timer(0.27).timeout
	var second_position: Vector3 = player.global_position
	var second_pose: Vector4 = animator.call("get_animation_signature")

	var total_travelled: float = _horizontal_distance(start_position, second_position)
	var moving_interval: float = _horizontal_distance(first_position, second_position)
	var pose_change: float = (second_pose - first_pose).length()
	var movement_debug: Dictionary = player.call("get_movement_debug")

	if total_travelled < 2.0 or moving_interval < 0.80:
		push_error("CI TOUCH CHECK: touchscreen joystick did not move the hero continuously; horizontal total %.4f interval %.4f start=%s first=%s second=%s debug=%s" % [total_travelled, moving_interval, start_position, first_position, second_position, movement_debug])
		_release_touch(forward_touch)
		get_tree().quit(7)
		return
	if pose_change < 0.15:
		push_error("CI TOUCH CHECK: hero moved but limbs remained frozen; pose delta %.4f" % pose_change)
		_release_touch(forward_touch)
		get_tree().quit(8)
		return

	_release_touch(forward_touch)
	await get_tree().process_frame
	var released_move: Vector2 = game.get("virtual_move")
	var release_position: Vector3 = player.global_position
	var release_debug: Dictionary = player.call("get_movement_debug")
	await get_tree().create_timer(0.32).timeout
	var stopped_position: Vector3 = player.global_position
	var stopped_debug: Dictionary = player.call("get_movement_debug")
	var stop_delta: Vector3 = stopped_position - release_position
	var horizontal_stopping_distance: float = _horizontal_distance(release_position, stopped_position)
	var vertical_stopping_distance: float = absf(stop_delta.y)

	if released_move.length() > 0.01:
		push_error("CI TOUCH CHECK: hero kept receiving input after finger release: %s" % released_move)
		get_tree().quit(9)
		return
	if horizontal_stopping_distance > 0.45:
		push_error("CI TOUCH CHECK: hero failed to stop horizontally after release; horizontal=%.4f vertical=%.4f release=%s stopped=%s release_debug=%s stopped_debug=%s" % [horizontal_stopping_distance, vertical_stopping_distance, release_position, stopped_position, release_debug, stopped_debug])
		get_tree().quit(10)
		return
	if vertical_stopping_distance > 1.25:
		push_error("CI TOUCH CHECK: hero fell or was repositioned after release; horizontal=%.4f vertical=%.4f release=%s stopped=%s release_debug=%s stopped_debug=%s" % [horizontal_stopping_distance, vertical_stopping_distance, release_position, stopped_position, release_debug, stopped_debug])
		get_tree().quit(11)
		return

	print("CI TOUCH CHECK OK: horizontal_total=%.3f interval=%.3f pose_delta=%.3f stop_horizontal=%.3f stop_vertical=%.3f" % [total_travelled, moving_interval, pose_change, horizontal_stopping_distance, vertical_stopping_distance])
	get_tree().quit()


func _horizontal_distance(from_position: Vector3, to_position: Vector3) -> float:
	return Vector2(
		to_position.x - from_position.x,
		to_position.z - from_position.z
	).length()


func _release_touch(position: Vector2) -> void:
	var release := InputEventScreenTouch.new()
	release.index = TEST_TOUCH_ID
	release.position = position
	release.pressed = false
	Input.parse_input_event(release)
