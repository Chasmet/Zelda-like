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

	if not animator.has_method("is_animation_ready") or not bool(animator.call("is_animation_ready")):
		push_error("CI TOUCH CHECK: CHK player animation system is not ready")
		get_tree().quit(5)
		return

	var imported_model: Node = player.get_node_or_null("Visual/ImportedHeroModel/HeroBlenderAsset")
	if not is_instance_valid(imported_model):
		push_error("CI TOUCH CHECK: joueur 1 chk.glb was not installed as the active hero")
		get_tree().quit(6)
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
		get_tree().quit(7)
		return

	await get_tree().create_timer(0.31).timeout
	var first_position: Vector3 = player.global_position
	var first_pose: Vector4 = animator.call("get_animation_signature")
	await get_tree().create_timer(0.27).timeout
	var second_position: Vector3 = player.global_position
	var second_pose: Vector4 = animator.call("get_animation_signature")

	var total_travelled: float = start_position.distance_to(second_position)
	var moving_interval: float = first_position.distance_to(second_position)
	var pose_change: float = (second_pose - first_pose).length()
	var movement_debug: Dictionary = player.call("get_movement_debug")

	if total_travelled < 2.0 or moving_interval < 0.80:
		push_error("CI TOUCH CHECK: touchscreen joystick did not move the hero continuously; total %.4f interval %.4f debug=%s" % [total_travelled, moving_interval, movement_debug])
		_release_touch(forward_touch)
		get_tree().quit(8)
		return
	if pose_change < 0.020:
		push_error("CI TOUCH CHECK: CHK hero moved but the visible model animation stayed frozen; pose delta %.4f" % pose_change)
		_release_touch(forward_touch)
		get_tree().quit(9)
		return

	_release_touch(forward_touch)
	await get_tree().process_frame
	var released_move: Vector2 = game.get("virtual_move")
	var release_position: Vector3 = player.global_position
	await get_tree().create_timer(0.32).timeout
	var stopped_position: Vector3 = player.global_position
	var stopping_distance: float = release_position.distance_to(stopped_position)

	if released_move.length() > 0.01:
		push_error("CI TOUCH CHECK: hero kept receiving input after finger release: %s" % released_move)
		get_tree().quit(10)
		return
	if stopping_distance > 0.45:
		push_error("CI TOUCH CHECK: hero failed to stop after release; travelled %.4f" % stopping_distance)
		get_tree().quit(11)
		return

	var idle_pose: Vector4 = animator.call("get_animation_signature")
	player.call("attack")
	await get_tree().create_timer(0.18).timeout
	var attack_pose: Vector4 = animator.call("get_animation_signature")
	var attack_change: float = (attack_pose - idle_pose).length()
	if attack_change < 0.06:
		push_error("CI TOUCH CHECK: CHK attack animation is not visible; delta %.4f" % attack_change)
		get_tree().quit(12)
		return

	await get_tree().create_timer(0.48).timeout
	var before_dodge: Vector4 = animator.call("get_animation_signature")
	player.call("dodge")
	await get_tree().create_timer(0.20).timeout
	var dodge_pose: Vector4 = animator.call("get_animation_signature")
	var dodge_change: float = (dodge_pose - before_dodge).length()
	if dodge_change < 0.08:
		push_error("CI TOUCH CHECK: CHK dodge animation is not visible; delta %.4f" % dodge_change)
		get_tree().quit(13)
		return

	print("CI TOUCH CHECK OK: model=joueur 1 chk.glb total=%.3f interval=%.3f walk_delta=%.3f attack_delta=%.3f dodge_delta=%.3f stop=%.3f" % [total_travelled, moving_interval, pose_change, attack_change, dodge_change, stopping_distance])
	get_tree().quit()


func _release_touch(position: Vector2) -> void:
	var release := InputEventScreenTouch.new()
	release.index = TEST_TOUCH_ID
	release.position = position
	release.pressed = false
	Input.parse_input_event(release)
