extends Node

const MAX_WAIT_SECONDS := 120.0


func _ready() -> void:
	if "--ci-walk-check" not in OS.get_cmdline_user_args():
		return
	call_deferred("_run_walk_check")


func _run_walk_check() -> void:
	var game := get_parent()
	var started_at := Time.get_ticks_msec()
	var player: Node = null
	var animator: Node = null

	while (Time.get_ticks_msec() - started_at) < int(MAX_WAIT_SECONDS * 1000.0):
		await get_tree().process_frame
		player = game.get("player")
		if not is_instance_valid(player):
			continue
		animator = player.get("_model_animator")
		var loading_screen = game.get("loading_screen")
		if is_instance_valid(animator) and (not is_instance_valid(loading_screen) or not loading_screen.visible):
			break

	if not is_instance_valid(player) or not is_instance_valid(animator):
		push_error("CI WALK CHECK: hero or animator was not created")
		get_tree().quit(4)
		return

	if not bool(animator.call("is_rig_ready")):
		push_error("CI WALK CHECK: Arm_L, Arm_R, Leg_L or Leg_R pivot is missing")
		get_tree().quit(5)
		return

	game.set("virtual_move", Vector2(0.0, -1.0))
	await get_tree().create_timer(0.55).timeout
	var first_position: Vector3 = player.global_position
	var first_pose: Vector4 = animator.call("get_animation_signature")

	await get_tree().create_timer(0.19).timeout
	var second_position: Vector3 = player.global_position
	var second_pose: Vector4 = animator.call("get_animation_signature")
	game.set("virtual_move", Vector2.ZERO)

	var travelled := first_position.distance_to(second_position)
	var pose_change := (second_pose - first_pose).length()
	if travelled < 0.18:
		push_error("CI WALK CHECK: the hero did not move; travelled %.4f metres" % travelled)
		get_tree().quit(6)
		return
	if pose_change < 0.20:
		push_error("CI WALK CHECK: the hero is sliding without limb animation; pose delta %.4f" % pose_change)
		get_tree().quit(7)
		return

	print("CI WALK CHECK OK: travelled=%.3f pose_delta=%.3f" % [travelled, pose_change])
	get_tree().quit()
