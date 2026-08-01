class_name ProceduralCharacterAnimator
extends Node3D

var _model_root: Node3D
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
var _airborne: bool = false
var _action: StringName = &""
var _action_time: float = 0.0
var _action_duration: float = 0.0
var _dead: bool = false

func bind_model(model_root: Node3D) -> void:
	_model_root = model_root
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
	var candidates: Array[Variant] = [_model_root, _torso, _head, _arm_left, _arm_right, _leg_left, _leg_right, _weapon, _cape]
	for candidate: Variant in candidates:
		if candidate is Node3D:
			var part: Node3D = candidate as Node3D
			if is_instance_valid(part) and not _parts.has(part):
				_parts.append(part)
				_base_transforms[part] = part.transform
	reset_pose()

func set_locomotion(move_ratio: float, airborne: bool = false) -> void:
	_move_ratio = clampf(move_ratio, 0.0, 1.4)
	_airborne = airborne

func play_attack() -> void:
	_start_action(&"attack", 0.46)

func play_dodge() -> void:
	_start_action(&"dodge", 0.52)

func play_hit() -> void:
	if not _dead:
		_start_action(&"hit", 0.28)

func play_death() -> void:
	_dead = true
	_start_action(&"death", 1.0)

func reset_pose() -> void:
	_dead = false
	_action = &""
	_action_time = 0.0
	_action_duration = 0.0
	_restore_base_pose()

func _process(delta: float) -> void:
	if not is_instance_valid(_model_root):
		return
	_time += delta
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
	elif _airborne:
		_animate_airborne()
	else:
		_animate_locomotion()

func _start_action(action_name: StringName, duration: float) -> void:
	_action = action_name
	_action_duration = duration
	_action_time = duration

func _action_progress() -> float:
	if _action_duration <= 0.0:
		return 1.0
	return clampf(1.0 - (_action_time / _action_duration), 0.0, 1.0)

func _animate_locomotion() -> void:
	var idle_breath: float = sin(_time * 2.2) * 0.018
	if is_instance_valid(_torso):
		_torso.position.y += idle_breath
	if is_instance_valid(_head):
		_head.rotation.z += sin(_time * 1.4) * 0.018
	if _move_ratio <= 0.05:
		if is_instance_valid(_cape):
			_cape.rotation.x += sin(_time * 1.7) * 0.035
		return
	var cadence: float = 7.0 + _move_ratio * 4.0
	var swing: float = sin(_time * cadence) * (0.45 + _move_ratio * 0.28)
	var bounce: float = abs(sin(_time * cadence)) * 0.055 * _move_ratio
	if is_instance_valid(_model_root):
		_model_root.position.y += bounce
	if is_instance_valid(_arm_left):
		_arm_left.rotation.x += swing
	if is_instance_valid(_arm_right):
		_arm_right.rotation.x -= swing
	if is_instance_valid(_leg_left):
		_leg_left.rotation.x -= swing * 0.82
	if is_instance_valid(_leg_right):
		_leg_right.rotation.x += swing * 0.82
	if is_instance_valid(_torso):
		_torso.rotation.y += sin(_time * cadence) * 0.07
	if is_instance_valid(_cape):
		_cape.rotation.x += 0.15 + abs(swing) * 0.12

func _animate_airborne() -> void:
	if is_instance_valid(_arm_left):
		_arm_left.rotation.x -= 0.55
		_arm_left.rotation.z -= 0.22
	if is_instance_valid(_arm_right):
		_arm_right.rotation.x -= 0.55
		_arm_right.rotation.z += 0.22
	if is_instance_valid(_leg_left):
		_leg_left.rotation.x += 0.30
	if is_instance_valid(_leg_right):
		_leg_right.rotation.x -= 0.18
	if is_instance_valid(_torso):
		_torso.rotation.x -= 0.08

func _animate_attack() -> void:
	var progress: float = _action_progress()
	var windup: float = clampf(progress / 0.34, 0.0, 1.0)
	var strike: float = clampf((progress - 0.34) / 0.36, 0.0, 1.0)
	var recover: float = clampf((progress - 0.70) / 0.30, 0.0, 1.0)
	var attack_curve: float = windup * (1.0 - strike) + strike * (1.0 - recover)
	if is_instance_valid(_arm_right):
		_arm_right.rotation.x += lerpf(-0.75, 1.65, strike) - recover * 0.9
		_arm_right.rotation.z += -0.65 * windup + 0.95 * strike - 0.3 * recover
	if is_instance_valid(_weapon):
		_weapon.rotation.x += 0.35 + attack_curve * 0.65
		_weapon.rotation.z += -0.25 + strike * 1.25
	if is_instance_valid(_torso):
		_torso.rotation.y += -0.35 * windup + 0.72 * strike - 0.35 * recover
	if is_instance_valid(_arm_left):
		_arm_left.rotation.z -= 0.30

func _animate_dodge() -> void:
	var progress: float = _action_progress()
	var arc: float = sin(progress * PI)
	if is_instance_valid(_model_root):
		_model_root.position.y -= arc * 0.28
		_model_root.rotation.z += sin(progress * TAU) * 0.16
	if is_instance_valid(_torso):
		_torso.rotation.x += arc * 0.48
	if is_instance_valid(_arm_left):
		_arm_left.rotation.x -= arc * 0.65
	if is_instance_valid(_arm_right):
		_arm_right.rotation.x -= arc * 0.65
	if is_instance_valid(_leg_left):
		_leg_left.rotation.x += arc * 0.55
	if is_instance_valid(_leg_right):
		_leg_right.rotation.x -= arc * 0.55

func _animate_hit() -> void:
	var progress: float = _action_progress()
	var kick: float = sin(progress * PI)
	if is_instance_valid(_torso):
		_torso.rotation.x -= kick * 0.34
		_torso.position.z += kick * 0.10
	if is_instance_valid(_head):
		_head.rotation.x -= kick * 0.22
	if is_instance_valid(_arm_left):
		_arm_left.rotation.z -= kick * 0.28
	if is_instance_valid(_arm_right):
		_arm_right.rotation.z += kick * 0.28

func _animate_death() -> void:
	var progress: float = _action_progress()
	var fall: float = progress * progress * (3.0 - 2.0 * progress)
	if is_instance_valid(_model_root):
		_model_root.rotation.x += fall * 1.42
		_model_root.position.y -= fall * 0.48
	if is_instance_valid(_arm_left):
		_arm_left.rotation.z -= fall * 0.55
	if is_instance_valid(_arm_right):
		_arm_right.rotation.z += fall * 0.55

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
