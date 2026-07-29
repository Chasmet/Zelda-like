class_name ThirdPersonCameraRig
extends Node3D

@export var mouse_sensitivity: float = 0.0035
@export var touch_sensitivity: float = 0.0045
@export var min_pitch: float = deg_to_rad(-55.0)
@export var max_pitch: float = deg_to_rad(48.0)
@export var normal_distance: float = 6.4
@export var mounted_distance: float = 8.4
@export var normal_height: float = 1.65
@export var mounted_height: float = 2.35
@export var follow_smoothing: float = 14.0

var follow_target: Node3D
var yaw: float = 0.0
var pitch: float = deg_to_rad(-12.0)
var _desired_distance: float = 6.4
var _desired_height: float = 1.65
var _look_cooldown: float = 0.0

var _pitch_node: Node3D
var _spring_arm: SpringArm3D
var _camera: Camera3D

func _ready() -> void:
	_pitch_node = Node3D.new()
	_pitch_node.name = "Pitch"
	add_child(_pitch_node)

	_spring_arm = SpringArm3D.new()
	_spring_arm.name = "SpringArm"
	_spring_arm.spring_length = normal_distance
	_spring_arm.margin = 0.18
	_spring_arm.collision_mask = 1
	_pitch_node.add_child(_spring_arm)

	_camera = Camera3D.new()
	_camera.name = "Camera3D"
	_camera.current = true
	_camera.fov = 70.0
	_camera.near = 0.08
	_camera.far = 650.0
	_spring_arm.add_child(_camera)

func set_follow_target(target: Node3D, mounted: bool = false) -> void:
	follow_target = target
	set_mounted_view(mounted)
	if is_instance_valid(target):
		global_position = target.global_position + Vector3.UP * _desired_height

func set_mounted_view(mounted: bool) -> void:
	_desired_distance = mounted_distance if mounted else normal_distance
	_desired_height = mounted_height if mounted else normal_height

func add_touch_look(relative: Vector2) -> void:
	yaw -= relative.x * touch_sensitivity
	pitch = clampf(pitch - relative.y * touch_sensitivity, min_pitch, max_pitch)
	_look_cooldown = 1.5

func add_mouse_look(relative: Vector2) -> void:
	yaw -= relative.x * mouse_sensitivity
	pitch = clampf(pitch - relative.y * mouse_sensitivity, min_pitch, max_pitch)
	_look_cooldown = 1.5

func get_camera_basis() -> Basis:
	if is_instance_valid(_camera):
		return _camera.global_transform.basis
	return global_transform.basis

func get_camera() -> Camera3D:
	return _camera

func _physics_process(delta: float) -> void:
	_look_cooldown = maxf(0.0, _look_cooldown - delta)
	if not is_instance_valid(follow_target):
		return

	var target_position: Vector3 = follow_target.global_position + Vector3.UP * _desired_height
	global_position = global_position.lerp(target_position, 1.0 - exp(-follow_smoothing * delta))
	rotation.y = yaw
	_pitch_node.rotation.x = pitch
	_spring_arm.spring_length = lerpf(_spring_arm.spring_length, _desired_distance, 1.0 - exp(-10.0 * delta))

func gently_align_to(target_yaw: float, movement_strength: float, delta: float) -> void:
	if _look_cooldown > 0.0 or movement_strength < 0.35:
		return
	yaw = lerp_angle(yaw, target_yaw, 1.0 - exp(-1.7 * delta))
