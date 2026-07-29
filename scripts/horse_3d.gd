class_name Horse3D
extends CharacterBody3D

const MODEL_PATH: String = "res://assets/models/horse_white.glb"

@export var walk_speed: float = 5.0
@export var gallop_speed: float = 13.5
@export var acceleration: float = 30.0
@export var deceleration: float = 38.0
@export var rotation_speed: float = 10.5
@export var jump_velocity: float = 7.0

var move_input: Vector2 = Vector2.ZERO
var camera_basis: Basis = Basis.IDENTITY
var controlled: bool = false
var rider: Hero3D

var _gravity: float = 22.0
var _requested_jump: bool = false
var _gait_clock: float = 0.0
var _speed: float = 0.0
var _model_root: Node3D
var _body_pivot: Node3D
var _front_left_leg: Node3D
var _front_right_leg: Node3D
var _rear_left_leg: Node3D
var _rear_right_leg: Node3D
var _neck: Node3D
var _tail: Node3D
var _rider_socket: Marker3D

func _ready() -> void:
	_gravity = float(ProjectSettings.get_setting("physics/3d/default_gravity", 22.0))
	floor_snap_length = 0.44
	floor_max_angle = deg_to_rad(48.0)
	safe_margin = 0.06
	_build_collision()
	_load_real_horse()

func set_controlled(active: bool, hero: Hero3D = null) -> void:
	controlled = active
	rider = hero
	if not active:
		move_input = Vector2.ZERO

func set_move_input(input_value: Vector2, basis: Basis) -> void:
	move_input = input_value.limit_length(1.0)
	camera_basis = basis

func request_jump() -> void:
	_requested_jump = true

func get_speed() -> float:
	return _speed

func get_rider_transform() -> Transform3D:
	if is_instance_valid(_rider_socket):
		return _rider_socket.global_transform
	return global_transform.translated(Vector3.UP * 1.75)

func get_dismount_position() -> Vector3:
	return global_position + global_transform.basis.x.normalized() * 1.55 + Vector3.UP * 0.25

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * delta
	elif _requested_jump and controlled and _speed > 2.6:
		velocity.y = jump_velocity
	_requested_jump = false

	var direction: Vector3 = _camera_relative_direction()
	var strength: float = move_input.length() if controlled else 0.0
	var target_speed: float = _analog_speed(strength)
	var target_velocity: Vector3 = direction * target_speed
	var change_rate: float = acceleration if strength > 0.03 else deceleration
	velocity.x = move_toward(velocity.x, target_velocity.x, change_rate * delta)
	velocity.z = move_toward(velocity.z, target_velocity.z, change_rate * delta)
	_speed = Vector2(velocity.x, velocity.z).length()

	if direction.length_squared() > 0.01:
		var target_yaw: float = atan2(-direction.x, -direction.z)
		rotation.y = lerp_angle(rotation.y, target_yaw, 1.0 - exp(-rotation_speed * delta))

	move_and_slide()
	_update_gait(delta)

func _analog_speed(strength: float) -> float:
	if strength < 0.04:
		return 0.0
	if strength < 0.68:
		return walk_speed * inverse_lerp(0.04, 0.68, strength)
	return lerpf(walk_speed, gallop_speed, smoothstep(0.68, 1.0, strength))

func _camera_relative_direction() -> Vector3:
	var forward: Vector3 = -camera_basis.z
	var right: Vector3 = camera_basis.x
	forward.y = 0.0
	right.y = 0.0
	forward = forward.normalized()
	right = right.normalized()
	return (right * move_input.x + forward * move_input.y).limit_length(1.0)

func _update_gait(delta: float) -> void:
	if not is_instance_valid(_body_pivot):
		return
	var movement_blend: float = clampf(_speed / gallop_speed, 0.0, 1.0)
	_gait_clock += delta * lerpf(4.5, 13.8, movement_blend)
	var front_stride: float = sin(_gait_clock) * movement_blend
	var rear_stride: float = sin(_gait_clock + PI) * movement_blend
	if is_instance_valid(_front_left_leg):
		_front_left_leg.rotation.x = front_stride * 0.72
	if is_instance_valid(_front_right_leg):
		_front_right_leg.rotation.x = -front_stride * 0.72
	if is_instance_valid(_rear_left_leg):
		_rear_left_leg.rotation.x = rear_stride * 0.68
	if is_instance_valid(_rear_right_leg):
		_rear_right_leg.rotation.x = -rear_stride * 0.68
	_body_pivot.position.y = absf(sin(_gait_clock * 2.0)) * 0.055 * movement_blend
	_body_pivot.rotation.z = sin(_gait_clock) * 0.022 * movement_blend
	if is_instance_valid(_neck):
		_neck.rotation.x = sin(_gait_clock * 2.0) * 0.045 * movement_blend
	if is_instance_valid(_tail):
		_tail.rotation.x = deg_to_rad(8.0) + sin(_gait_clock * 1.7) * 0.12
		_tail.rotation.y = sin(_gait_clock * 1.2) * 0.22

func _build_collision() -> void:
	var collision: CollisionShape3D = CollisionShape3D.new()
	collision.name = "HorseCollision"
	var capsule: CapsuleShape3D = CapsuleShape3D.new()
	capsule.radius = 0.62
	capsule.height = 2.05
	collision.shape = capsule
	collision.position = Vector3(0.0, 0.95, 0.0)
	collision.rotation.x = deg_to_rad(90.0)
	add_child(collision)

func _load_real_horse() -> void:
	_model_root = Node3D.new()
	_model_root.name = "WhiteHorseAvatarRoot"
	add_child(_model_root)
	_body_pivot = Node3D.new()
	_body_pivot.name = "HorseAnimationRoot"
	_model_root.add_child(_body_pivot)
	var resource: Resource = load(MODEL_PATH)
	if not resource is PackedScene:
		push_error("Le modèle 3D du cheval est absent: " + MODEL_PATH)
		return
	var instance: Node3D = (resource as PackedScene).instantiate() as Node3D
	instance.name = "WhiteHorseGLB"
	_body_pivot.add_child(instance)
	_front_left_leg = _find_node(instance, "HorseLeg_FL")
	_front_right_leg = _find_node(instance, "HorseLeg_FR")
	_rear_left_leg = _find_node(instance, "HorseLeg_BL")
	_rear_right_leg = _find_node(instance, "HorseLeg_BR")
	_neck = _find_node(instance, "HorseNeck")
	_tail = _find_node(instance, "Tail")
	_reparent_leg(instance, "FL")
	_reparent_leg(instance, "FR")
	_reparent_leg(instance, "BL")
	_reparent_leg(instance, "BR")
	_reparent_to(instance, "HorseNeck", ["HorseHead", "HorseMuzzle", "Ear_L", "Ear_R", "Mane"])
	_rider_socket = Marker3D.new()
	_rider_socket.name = "RiderSocket"
	_rider_socket.position = Vector3(0.0, 1.42, 0.10)
	_body_pivot.add_child(_rider_socket)

func _find_node(root: Node, node_name: String) -> Node3D:
	return root.find_child(node_name, true, false) as Node3D

func _reparent_leg(root: Node, suffix: String) -> void:
	_reparent_to(root, "HorseLeg_" + suffix, ["HorseShin_" + suffix, "Hoof_" + suffix])

func _reparent_to(root: Node, parent_name: String, child_names: Array[String]) -> void:
	var new_parent: Node = root.find_child(parent_name, true, false)
	if not is_instance_valid(new_parent):
		return
	for child_name: String in child_names:
		var child: Node = root.find_child(child_name, true, false)
		if is_instance_valid(child) and child.get_parent() != new_parent:
			child.reparent(new_parent, true)
