class_name AdaptiveCharacterAnimator
extends ProceduralCharacterAnimator

var _native_player: AnimationPlayer
var _native_skeleton: Skeleton3D
var _native_ready: bool = false
var _native_move_ratio: float = 0.0
var _native_airborne: bool = false
var _native_swimming: bool = false
var _native_underwater: bool = false
var _native_action_timer: float = 0.0
var _native_dead: bool = false
var _last_native_clip: StringName = &""


func bind_model(model_root: Node3D) -> void:
	super.bind_model(model_root)
	_native_player = _find_animation_player(model_root)
	_native_skeleton = _find_skeleton(model_root)
	_native_ready = is_instance_valid(_native_player) and not _native_player.get_animation_list().is_empty()
	_native_action_timer = 0.0
	_native_dead = false
	_last_native_clip = &""
	if _native_ready:
		_play_native(["RESET", "Idle", "Fight_Idle", "Vol_Stationnaire_Loop"], true, 1.0, true)
		print("Animation native GLB activée : %s" % _native_player.get_animation_list())


func set_locomotion(move_ratio: float, airborne: bool = false) -> void:
	if not _native_ready:
		super.set_locomotion(move_ratio, airborne)
		return
	_native_move_ratio = clampf(move_ratio, 0.0, 1.4)
	_native_airborne = airborne


func set_swimming(swimming: bool, underwater: bool = false) -> void:
	if not _native_ready:
		super.set_swimming(swimming, underwater)
		return
	_native_swimming = swimming
	_native_underwater = underwater


func play_attack() -> void:
	if not _native_ready:
		super.play_attack()
		return
	_start_native_action(
		["Attack_Right", "Attack_Left", "Attack", "Sword_Attack", "Decollage"],
		0.50
	)


func play_dodge() -> void:
	if not _native_ready:
		super.play_dodge()
		return
	_start_native_action(["Jump", "Land", "Block", "Decollage"], 0.56)


func play_hit() -> void:
	if not _native_ready:
		super.play_hit()
		return
	if not _native_dead:
		_start_native_action(["Hit_Reaction", "Hit", "Damage", "Block", "Decollage"], 0.34)


func play_death() -> void:
	if not _native_ready:
		super.play_death()
		return
	_native_dead = true
	_start_native_action(["Death", "Die", "KO", "Land", "Decollage"], 1.0)


func reset_pose() -> void:
	if not _native_ready:
		super.reset_pose()
		return
	_native_dead = false
	_native_action_timer = 0.0
	_native_move_ratio = 0.0
	_native_airborne = false
	_native_swimming = false
	_native_underwater = false
	_play_native(["RESET", "Idle", "Fight_Idle", "Vol_Stationnaire_Loop"], true, 1.0, true)


func is_rig_ready() -> bool:
	return _native_ready or super.is_rig_ready()


func is_animation_ready() -> bool:
	return _native_ready or super.is_animation_ready()


func get_animation_signature() -> Vector4:
	if not _native_ready or not is_instance_valid(_native_player):
		return super.get_animation_signature()

	var animation_name := String(_native_player.current_animation)
	var clip_code := float(absi(hash(animation_name)) % 997) / 997.0
	var playback_position := float(_native_player.current_animation_position)

	if is_instance_valid(_native_skeleton):
		var bone_index := _find_signature_bone()
		if bone_index >= 0:
			var pose := _native_skeleton.get_bone_pose_rotation(bone_index)
			return Vector4(pose.x, pose.y, pose.z, playback_position + clip_code * 2.0)

	return Vector4(
		playback_position,
		clip_code,
		float(_native_move_ratio),
		float(_native_action_timer)
	)


func _process(delta: float) -> void:
	if not _native_ready:
		super._process(delta)
		return

	_native_action_timer = maxf(0.0, _native_action_timer - delta)
	if _native_dead:
		return
	if _native_action_timer > 0.0:
		return

	if _native_airborne:
		_play_native(["Jump", "Boat_Balance", "Vol_Stationnaire_Loop"], true, 1.0)
		return

	if _native_swimming:
		if _native_move_ratio > 0.08:
			_play_native(
				["Boat_Balance", "Run", "Walk", "Vol_Avant_RootMotion", "Vol_Stationnaire_Loop"],
				true,
				lerpf(0.9, 1.35, clampf(_native_move_ratio, 0.0, 1.0))
			)
		else:
			_play_native(["Boat_Balance", "Idle", "Vol_Stationnaire_Loop"], true, 0.9)
		return

	if _native_move_ratio > 0.68:
		_play_native(
			["Run", "Walk", "Vol_Avant_RootMotion", "Vol_Stationnaire_Loop"],
			true,
			lerpf(0.95, 1.35, clampf(_native_move_ratio, 0.0, 1.0))
		)
	elif _native_move_ratio > 0.045:
		_play_native(
			["Walk", "Run", "Vol_Avant_RootMotion", "Vol_Stationnaire_Loop"],
			true,
			lerpf(0.82, 1.12, clampf(_native_move_ratio, 0.0, 1.0))
		)
	else:
		_play_native(["Idle", "Fight_Idle", "Vol_Stationnaire_Loop", "RESET"], true, 1.0)


func _start_native_action(candidates: Array[String], fallback_duration: float) -> void:
	var played := _play_native(candidates, false, 1.0, true)
	_native_action_timer = fallback_duration
	if played and is_instance_valid(_native_player):
		var current_name := _native_player.current_animation
		if _native_player.has_animation(current_name):
			var animation := _native_player.get_animation(current_name)
			if animation != null:
				_native_action_timer = maxf(0.18, float(animation.length))


func _play_native(
	candidates: Array[String],
	loop_animation: bool,
	speed: float,
	restart: bool = false
) -> bool:
	if not _native_ready or not is_instance_valid(_native_player):
		return false

	var selected := _find_animation(candidates)
	if selected == &"":
		return false

	var animation := _native_player.get_animation(selected)
	if animation != null:
		animation.loop_mode = Animation.LOOP_LINEAR if loop_animation else Animation.LOOP_NONE

	_native_player.speed_scale = maxf(0.05, speed)
	if restart or _last_native_clip != selected or not _native_player.is_playing():
		_native_player.play(selected, 0.12, maxf(0.05, speed))
		_last_native_clip = selected
	return true


func _find_animation(candidates: Array[String]) -> StringName:
	if not is_instance_valid(_native_player):
		return &""
	var available := _native_player.get_animation_list()

	for candidate in candidates:
		for animation_name in available:
			if String(animation_name).to_lower() == candidate.to_lower():
				return animation_name

	for candidate in candidates:
		var wanted := _normalise_name(candidate)
		for animation_name in available:
			var current := _normalise_name(String(animation_name))
			if current == wanted or current.ends_with(wanted) or current.contains(wanted):
				return animation_name
	return &""


func _normalise_name(value: String) -> String:
	return value.to_lower() \
		.replace("_", "") \
		.replace("-", "") \
		.replace(" ", "") \
		.replace(".", "") \
		.replace("/", "")


func _find_animation_player(root: Node) -> AnimationPlayer:
	if root is AnimationPlayer:
		return root as AnimationPlayer
	for child in root.get_children():
		var found := _find_animation_player(child)
		if is_instance_valid(found):
			return found
	return null


func _find_skeleton(root: Node) -> Skeleton3D:
	if root is Skeleton3D:
		return root as Skeleton3D
	for child in root.get_children():
		var found := _find_skeleton(child)
		if is_instance_valid(found):
			return found
	return null


func _find_signature_bone() -> int:
	if not is_instance_valid(_native_skeleton):
		return -1
	var candidates: Array[String] = [
		"UpperArm_L", "UpperArm.L", "UpperArm_R", "UpperArm.R",
		"Spine", "Chest", "Hips", "Pelvis"
	]
	for candidate in candidates:
		var index := _native_skeleton.find_bone(candidate)
		if index >= 0:
			return index
	return -1
