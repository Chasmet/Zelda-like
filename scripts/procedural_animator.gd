class_name ProceduralCharacterAnimator
extends Node3D

var _model_root: Node3D
var _hips: Node3D
var _torso: Node3D
var _head: Node3D
var _arm_left: Node3D
var _arm_right: Node3D
var _leg_left: Node3D
var _leg_right: Node3D
var _weapon: Node3D
var _cape: Node3D
var _parts: Array[Node3D] = []
var _base_transforms: Dictionary = {}

var _time: float = 0.0
var _move_ratio: float = 0.0
var _target_move_ratio: float = 0.0
var _airborne: bool = false
var _swimming: bool = false
var _underwater: bool = false
var _action: StringName = &""
var _action_time: float = 0.0
var _action_duration: float = 0.0
var _dead: bool = false
var _rig_ready: bool = false
var _single_mesh_mode: bool = false


func bind_model(model_root: Node3D) -> void:
	_model_root = model_root
	_hips = _find_part(["Hips", "Pelvis"])
	_torso = _find_part(["Torso", "Body", "Chest"])
	_head = _find_part(["Head"])
	_arm_left = _find_part(["Arm_L", "ArmLeft", "LeftArm"])
	_arm_right = _find_part(["Arm_R", "ArmRight", "RightArm"])
	_leg_left = _find_part(["Leg_L", "LegLeft", "LeftLeg"])
	_leg_right = _find_part(["Leg_R", "LegRight", "RightLeg"])
	_weapon = _find_part(["Weapon", "Sword", "Club"])
	_cape = _find_part(["Cape"])

	_parts.clear()
	_base_transforms.clear()
	var candidates: Array[Variant] = [
		_model_root, _hips, _torso, _head,
		_arm_left, _arm_right, _leg_left, _leg_right,
		_weapon, _cape
	]
	for candidate: Variant in candidates:
		if candidate is Node3D:
			var part: Node3D = candidate as Node3D
			if is_instance_valid(part) and not _parts.has(part):
				_parts.append(part)
				_base_transforms[part] = part.transform

	_rig_ready = (
		is_instance_valid(_arm_left)
		and is_instance_valid(_arm_right)
		and is_instance_valid(_leg_left)
		and is_instance_valid(_leg_right)
	)
	_single_mesh_mode = not _rig_ready
	if _single_mesh_mode:
		print("CHK joueur 1 : animation procédurale du modèle complet activée")
	reset_pose()


func set_locomotion(move_ratio: float, airborne: bool = false) -> void:
	_target_move_ratio = clampf(move_ratio, 0.0, 1.4)
	_airborne = airborne


func set_swimming(swimming: bool, underwater: bool = false) -> void:
	_swimming = swimming
	_underwater = underwater


func is_rig_ready() -> bool:
	return _rig_ready


func is_animation_ready() -> bool:
	return is_instance_valid(_model_root)


func get_animation_signature() -> Vector4:
	if _rig_ready:
		return Vector4(
			_arm_left.rotation.x if is_instance_valid(_arm_left) else 0.0,
			_arm_right.rotation.x if is_instance_valid(_arm_right) else 0.0,
			_leg_left.rotation.x if is_instance_valid(_leg_left) else 0.0,
			_leg_right.rotation.x if is_instance_valid(_leg_right) else 0.0
		)
	if not is_instance_valid(_model_root):
		return Vector4.ZERO
	return Vector4(
		_model_root.rotation.x,
		_model_root.rotation.z,
		_model_root.position.y,
		_model_root.scale.y
	)


func play_attack() -> void:
	_start_action(&"attack", 0.50)


func play_dodge() -> void:
	_start_action(&"dodge", 0.56)


func play_hit() -> void:
	if not _dead:
		_start_action(&"hit", 0.30)


func play_death() -> void:
	_dead = true
	_start_action(&"death", 1.0)


func reset_pose() -> void:
	_dead = false
	_action = &""
	_action_time = 0.0
	_action_duration = 0.0
	_move_ratio = 0.0
	_target_move_ratio = 0.0
	_airborne = false
	_swimming = false
	_underwater = false
	_restore_base_pose()


func _process(delta: float) -> void:
	if not is_instance_valid(_model_root):
		return

	_time += delta
	_move_ratio = move_toward(_move_ratio, _target_move_ratio, delta * 5.2)
	if _action_time > 0.0:
		_action_time = maxf(0.0, _action_time - delta)
		if _action_time <= 0.0 and not _dead:
			_action = &""

	_restore_base_pose()
	if _dead or _action == &"death":
		_animate_death()
	elif _action == &"attack":
		_animate_attack()
	elif _action == &"dodge":
		_animate_dodge()
	elif _action == &"hit":
		_animate_hit()
	elif _swimming:
		_animate_swimming()
	elif _airborne:
		_animate_airborne()
	elif _rig_ready:
		_animate_rigged_locomotion()
	else:
		_animate_single_mesh_locomotion()


func _start_action(action_name: StringName, duration: float) -> void:
	_action = action_name
	_action_duration = duration
	_action_time = duration


func _action_progress() -> float:
	if _action_duration <= 0.0:
		return 1.0
	return clampf(1.0 - (_action_time / _action_duration), 0.0, 1.0)


func _animate_single_mesh_locomotion() -> void:
	var breathing: float = sin(_time * 2.15)
	if _move_ratio <= 0.045:
		_model_root.position.y += breathing * 0.012
		_model_root.rotation.z += sin(_time * 1.22) * 0.010
		_model_root.rotation.y += sin(_time * 0.72) * 0.008
		_model_root.scale = _model_root.scale * Vector3(
			1.0 - breathing * 0.0035,
			1.0 + breathing * 0.007,
			1.0 - breathing * 0.0035
		)
		if is_instance_valid(_weapon):
			_weapon.rotation.z += sin(_time * 1.35) * 0.014
		return

	var run_blend: float = clampf((_move_ratio - 0.52) / 0.48, 0.0, 1.0)
	var cadence: float = lerpf(7.2, 12.0, run_blend)
	var phase: float = _time * cadence
	var stride: float = sin(phase)
	var impact: float = absf(sin(phase))
	var bounce: float = impact * lerpf(0.045, 0.085, run_blend)
	var sway: float = stride * lerpf(0.045, 0.085, run_blend)
	var lateral: float = sin(phase * 0.5) * lerpf(0.015, 0.033, run_blend)

	_model_root.position.y += bounce
	_model_root.position.x += lateral
	_model_root.rotation.x += lerpf(-0.025, -0.085, run_blend)
	_model_root.rotation.z += sway
	_model_root.rotation.y += sin(phase * 0.5) * lerpf(0.018, 0.035, run_blend)
	_model_root.scale = _model_root.scale * Vector3(
		1.0 + impact * lerpf(0.010, 0.020, run_blend),
		1.0 - impact * lerpf(0.014, 0.028, run_blend),
		1.0 + impact * lerpf(0.008, 0.016, run_blend)
	)
	if is_instance_valid(_weapon):
		_weapon.rotation.x += -stride * lerpf(0.18, 0.30, run_blend)
		_weapon.rotation.z += stride * lerpf(0.10, 0.18, run_blend)


func _animate_rigged_locomotion() -> void:
	var breathing: float = sin(_time * 2.25)
	if is_instance_valid(_torso):
		_torso.position.y += breathing * 0.018
		_torso.rotation.x += breathing * 0.010
		_torso.rotation.z += sin(_time * 1.15) * 0.007
	if is_instance_valid(_head):
		_head.rotation.z += sin(_time * 1.45) * 0.018

	if _move_ratio <= 0.045:
		if is_instance_valid(_cape):
			_cape.rotation.x += sin(_time * 1.8) * 0.045
		return

	var run_blend: float = clampf((_move_ratio - 0.58) / 0.42, 0.0, 1.0)
	var cadence: float = lerpf(7.4, 12.2, run_blend)
	var phase: float = _time * cadence
	var stride: float = sin(phase)
	var opposite: float = sin(phase + PI)
	var impact: float = absf(sin(phase))
	var swing_amount: float = lerpf(0.62, 1.02, run_blend) * clampf(_move_ratio + 0.20, 0.0, 1.2)
	var leg_amount: float = swing_amount * 0.92
	var bounce: float = impact * lerpf(0.050, 0.095, run_blend)

	_model_root.position.y += bounce
	_model_root.rotation.x += lerpf(-0.035, -0.12, run_blend)
	_model_root.rotation.z += sin(phase * 0.5) * lerpf(0.018, 0.045, run_blend)

	if is_instance_valid(_hips):
		_hips.rotation.y += sin(phase) * lerpf(0.075, 0.13, run_blend)
	if is_instance_valid(_torso):
		_torso.rotation.y -= sin(phase) * lerpf(0.085, 0.15, run_blend)
		_torso.position.y += bounce * 0.26
	if is_instance_valid(_head):
		_head.rotation.y += sin(phase) * 0.035
	if is_instance_valid(_arm_left):
		_arm_left.rotation.x += stride * swing_amount
	if is_instance_valid(_arm_right):
		_arm_right.rotation.x += opposite * swing_amount
	if is_instance_valid(_leg_left):
		_leg_left.rotation.x += opposite * leg_amount
	if is_instance_valid(_leg_right):
		_leg_right.rotation.x += stride * leg_amount
	if is_instance_valid(_cape):
		_cape.rotation.x += 0.12 + run_blend * 0.18 + impact * 0.10


func _animate_airborne() -> void:
	_model_root.position.y += 0.045
	_model_root.rotation.x -= 0.12
	_model_root.scale = _model_root.scale * Vector3(0.985, 1.045, 0.985)
	if is_instance_valid(_arm_left):
		_arm_left.rotation.x -= 0.72
		_arm_left.rotation.z -= 0.28
	if is_instance_valid(_arm_right):
		_arm_right.rotation.x -= 0.72
		_arm_right.rotation.z += 0.28
	if is_instance_valid(_leg_left):
		_leg_left.rotation.x += 0.42
	if is_instance_valid(_leg_right):
		_leg_right.rotation.x -= 0.28
	if is_instance_valid(_weapon):
		_weapon.rotation.x -= 0.28


func _animate_swimming() -> void:
	var speed_blend: float = clampf(_move_ratio, 0.0, 1.0)
	var phase: float = _time * lerpf(3.8, 7.5, speed_blend)
	var wave: float = sin(phase)
	var dive_tilt: float = -0.42 if _underwater else -0.22
	_model_root.rotation.x += dive_tilt - speed_blend * 0.12
	_model_root.rotation.z += wave * lerpf(0.025, 0.065, speed_blend)
	_model_root.position.y += sin(phase * 0.72) * 0.045
	_model_root.position.x += sin(phase * 0.5) * 0.022
	_model_root.scale = _model_root.scale * Vector3(
		1.0 + absf(wave) * 0.008,
		1.0 - absf(wave) * 0.012,
		1.0 + absf(wave) * 0.010
	)
	if is_instance_valid(_arm_left):
		_arm_left.rotation.x += wave * 0.82
	if is_instance_valid(_arm_right):
		_arm_right.rotation.x -= wave * 0.82
	if is_instance_valid(_leg_left):
		_leg_left.rotation.x -= wave * 0.48
	if is_instance_valid(_leg_right):
		_leg_right.rotation.x += wave * 0.48
	if is_instance_valid(_weapon):
		_weapon.rotation.z += 0.25 + wave * 0.10


func _animate_attack() -> void:
	var progress: float = _action_progress()
	var windup: float = clampf(progress / 0.28, 0.0, 1.0)
	var strike: float = clampf((progress - 0.28) / 0.34, 0.0, 1.0)
	var recover: float = clampf((progress - 0.62) / 0.38, 0.0, 1.0)
	var arc: float = sin(progress * PI)

	_model_root.position.z -= arc * 0.16
	_model_root.position.y += arc * 0.035
	_model_root.rotation.y += -0.28 * windup + 0.58 * strike - 0.30 * recover
	_model_root.rotation.z += -0.10 * windup + 0.16 * strike - 0.08 * recover
	_model_root.scale = _model_root.scale * Vector3(
		1.0 + arc * 0.025,
		1.0 - arc * 0.015,
		1.0 + arc * 0.035
	)
	if is_instance_valid(_arm_right):
		_arm_right.rotation.x += lerpf(-1.05, 1.85, strike) - recover * 0.85
		_arm_right.rotation.z += -0.78 * windup + 1.05 * strike - 0.35 * recover
	if is_instance_valid(_arm_left):
		_arm_left.rotation.z -= 0.42
	if is_instance_valid(_torso):
		_torso.rotation.y += -0.48 * windup + 0.88 * strike - 0.42 * recover
	if is_instance_valid(_weapon):
		_weapon.rotation.x += 0.18 + strike * 0.86
		_weapon.rotation.z += -0.55 * windup + 1.78 * strike - 0.70 * recover


func _animate_dodge() -> void:
	var progress: float = _action_progress()
	var arc: float = sin(progress * PI)
	_model_root.position.y -= arc * 0.30
	_model_root.position.z -= arc * 0.10
	_model_root.rotation.z += sin(progress * TAU) * 0.34
	_model_root.rotation.x += arc * 0.36
	_model_root.scale = _model_root.scale * Vector3(
		1.0 + arc * 0.10,
		1.0 - arc * 0.18,
		1.0 + arc * 0.10
	)
	if is_instance_valid(_weapon):
		_weapon.rotation.z += arc * 0.55
	if is_instance_valid(_cape):
		_cape.rotation.x += arc * 0.60


func _animate_hit() -> void:
	var progress: float = _action_progress()
	var kick: float = sin(progress * PI)
	_model_root.position.z += kick * 0.13
	_model_root.rotation.x -= kick * 0.32
	_model_root.rotation.z += sin(progress * TAU) * 0.06
	_model_root.scale = _model_root.scale * Vector3(
		1.0 + kick * 0.08,
		1.0 - kick * 0.10,
		1.0 + kick * 0.08
	)
	if is_instance_valid(_head):
		_head.rotation.x -= kick * 0.28
	if is_instance_valid(_arm_left):
		_arm_left.rotation.z -= kick * 0.34
	if is_instance_valid(_arm_right):
		_arm_right.rotation.z += kick * 0.34


func _animate_death() -> void:
	var progress: float = _action_progress()
	var fall: float = progress * progress * (3.0 - 2.0 * progress)
	_model_root.rotation.x += fall * 1.46
	_model_root.rotation.z += fall * 0.16
	_model_root.position.y -= fall * 0.48
	_model_root.position.z += fall * 0.18
	_model_root.scale = _model_root.scale * Vector3(
		1.0 + fall * 0.10,
		1.0 - fall * 0.12,
		1.0 + fall * 0.08
	)
	if is_instance_valid(_arm_left):
		_arm_left.rotation.z -= fall * 0.62
	if is_instance_valid(_arm_right):
		_arm_right.rotation.z += fall * 0.62
	if is_instance_valid(_weapon):
		_weapon.rotation.z += fall * 0.95


func _restore_base_pose() -> void:
	for part: Node3D in _parts:
		if is_instance_valid(part) and _base_transforms.has(part):
			part.transform = _base_transforms[part]


func _find_part(prefixes: Array[String]) -> Node3D:
	if not is_instance_valid(_model_root):
		return null
	return _find_part_recursive(_model_root, prefixes)


func _find_part_recursive(node: Node, prefixes: Array[String]) -> Node3D:
	if node is Node3D:
		var node_name: String = String(node.name).to_lower()
		for prefix: String in prefixes:
			if node_name.begins_with(prefix.to_lower()):
				return node as Node3D
	for child: Node in node.get_children():
		var found: Node3D = _find_part_recursive(child, prefixes)
		if found != null:
			return found
	return null
