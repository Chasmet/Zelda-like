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
	print("CI MOVEMENT DEBUG BEFORE: ", player.call("get_movement_debug"))

	var press := InputEventScreenTouch.new()
	press.index = TEST_TOUCH_ID
	press.position = forward_touch
	press.pressed = true
	Input.parse_input_event(press)
	await get_tree().process_frame

	var applied_move: Vector2 = game.get("virtual_move")
	print("CI MOVEMENT DEBUG AFTER PRESS: game_move=", applied_move, " player=", player.call("get_movement_debug"))
	if applied_move.length() < 0.45 or applied_move.y > -0.35:
		push_error("CI TOUCH CHECK: touching above the joystick did not create forward movement: %s" % applied_move)
		_release_touch(forward_touch)
		get_tree().quit(6)
		return

	await get_tree().create_timer(0.20).timeout
	print("CI MOVEMENT DEBUG 200MS: ", player.call("get_movement_debug"))
	await get_tree().create_timer(0.38).timeout
	var first_position: Vector3 = player.global_position
	var first_pose: Vector4 = animator.call("get_animation_signature")
	print("CI MOVEMENT DEBUG 580MS: ", player.call("get_movement_debug"))

	var drag := InputEventScreenDrag.new()
	drag.index = TEST_TOUCH_ID
	drag.position = joystick_center + Vector2(34.0, -54.0)
	drag.relative = Vector2(34.0, 6.0)
	Input.parse_input_event(drag)
	await get_tree().create_timer(0.21).timeout

	var second_position: Vector3 = player.global_position
	var second_pose: Vector4 = animator.call("get_animation_signature")
	print("CI MOVEMENT DEBUG AFTER DRAG: ", player.call("get_movement_debug"))
	_release_touch(drag.position)
	await get_tree().process_frame

	var total_travelled: float = start_position.distance_to(second_position)
	var interval_travelled: float = first_position.distance_to(second_position)
	var pose_change: float = (second_pose - first_pose).length()
	var released_move: Vector2 = game.get("virtual_move")

	if total_travelled < 1.2 or interval_travelled < 0.25:
		push_error("CI TOUCH CHECK: touchscreen joystick did not move the hero; total %.4f interval %.4f debug=%s" % [total_travelled, interval_travelled, player.call("get_movement_debug")])
		get_tree().quit(7)
		return
	if pose_change < 0.20:
		push_error("CI TOUCH CHECK: hero moved but limbs remained frozen; pose delta %.4f" % pose_change)
		get_tree().quit(8)
		return
	if released_move.length() > 0.01:
		push_error("CI TOUCH CHECK: hero kept moving after finger release: %s" % released_move)
		get_tree().quit(9)
		return

	print("CI TOUCH CHECK OK: total=%.3f interval=%.3f pose_delta=%.3f" % [total_travelled, interval_travelled, pose_change])
	get_tree().quit()


func _release_touch(position: Vector2) -> void:
	var release := InputEventScreenTouch.new()
	release.index = TEST_TOUCH_ID
	release.position = position
	release.pressed = false
	Input.parse_input_event(release)
