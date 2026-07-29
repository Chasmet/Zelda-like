class_name Horse3D
extends CharacterBody3D

@export var walk_speed: float = 6.0
@export var gallop_speed: float = 14.5
@export var acceleration: float = 18.0
@export var rotation_speed: float = 7.5
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

var _mat_white: StandardMaterial3D
var _mat_gray: StandardMaterial3D
var _mat_blue: StandardMaterial3D
var _mat_gold: StandardMaterial3D
var _mat_brown: StandardMaterial3D
var _mat_black: StandardMaterial3D

func _ready() -> void:
	_gravity = float(ProjectSettings.get_setting("physics/3d/default_gravity", 22.0))
	_build_materials()
	_build_collision()
	_build_true_3d_horse()

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
	return global_transform.translated(Vector3.UP * 2.1)

func get_dismount_position() -> Vector3:
	return global_position + global_transform.basis.x.normalized() * 1.6 + Vector3.UP * 0.2

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * delta
	elif _requested_jump and controlled and _speed > 3.0:
		velocity.y = jump_velocity
	_requested_jump = false

	var direction: Vector3 = _camera_relative_direction()
	var strength: float = move_input.length() if controlled else 0.0
	var target_speed: float = lerpf(walk_speed, gallop_speed, smoothstep(0.55, 1.0, strength)) * strength
	var target_velocity: Vector3 = direction * target_speed
	velocity.x = move_toward(velocity.x, target_velocity.x, acceleration * delta)
	velocity.z = move_toward(velocity.z, target_velocity.z, acceleration * delta)
	_speed = Vector2(velocity.x, velocity.z).length()

	if direction.length_squared() > 0.01:
		var target_yaw: float = atan2(-direction.x, -direction.z)
		rotation.y = lerp_angle(rotation.y, target_yaw, 1.0 - exp(-rotation_speed * delta))

	move_and_slide()
	_update_gait(delta)

func _camera_relative_direction() -> Vector3:
	var forward: Vector3 = -camera_basis.z
	var right: Vector3 = camera_basis.x
	forward.y = 0.0
	right.y = 0.0
	forward = forward.normalized()
	right = right.normalized()
	return (right * move_input.x + forward * move_input.y).limit_length(1.0)

func _update_gait(delta: float) -> void:
	var movement_blend: float = clampf(_speed / gallop_speed, 0.0, 1.0)
	_gait_clock += delta * lerpf(4.0, 13.5, movement_blend)
	var front_stride: float = sin(_gait_clock) * movement_blend
	var rear_stride: float = sin(_gait_clock + PI) * movement_blend
	_front_left_leg.rotation.x = front_stride * 0.72
	_front_right_leg.rotation.x = -front_stride * 0.72
	_rear_left_leg.rotation.x = rear_stride * 0.68
	_rear_right_leg.rotation.x = -rear_stride * 0.68
	_body_pivot.position.y = 1.35 + absf(sin(_gait_clock * 2.0)) * 0.08 * movement_blend
	_body_pivot.rotation.z = sin(_gait_clock) * 0.025 * movement_blend
	_neck.rotation.x = deg_to_rad(-18.0) + sin(_gait_clock * 2.0) * 0.06 * movement_blend
	_tail.rotation.x = deg_to_rad(25.0) + sin(_gait_clock * 1.7) * 0.18
	_tail.rotation.y = sin(_gait_clock * 1.2) * 0.28

func _build_materials() -> void:
	_mat_white = _material(Color("#d5d4ca"), 0.02, 0.78)
	_mat_gray = _material(Color("#92959a"), 0.04, 0.74)
	_mat_blue = _material(Color("#1459a6"), 0.32, 0.36)
	_mat_gold = _material(Color("#c9942f"), 0.72, 0.24)
	_mat_brown = _material(Color("#4b2c1b"), 0.02, 0.86)
	_mat_black = _material(Color("#111318"), 0.03, 0.80)

func _build_collision() -> void:
	var collision: CollisionShape3D = CollisionShape3D.new()
	collision.name = "HorseCollision"
	var capsule: CapsuleShape3D = CapsuleShape3D.new()
	capsule.radius = 0.72
	capsule.height = 2.4
	collision.shape = capsule
	collision.position = Vector3(0.0, 1.05, 0.0)
	collision.rotation.x = deg_to_rad(90.0)
	add_child(collision)

func _build_true_3d_horse() -> void:
	_model_root = Node3D.new()
	_model_root.name = "HorseTrue3D"
	add_child(_model_root)

	_body_pivot = Node3D.new()
	_body_pivot.name = "HorseBodyPivot"
	_body_pivot.position.y = 1.35
	_model_root.add_child(_body_pivot)

	_create_mesh(_body_pivot, "Body", _capsule(0.62, 2.05), _mat_white, Vector3.ZERO, Vector3(deg_to_rad(90.0), 0.0, 0.0), Vector3(1.10, 1.0, 1.0))
	_create_mesh(_body_pivot, "ChestArmor", _box(Vector3(1.22, 0.70, 0.62)), _mat_blue, Vector3(0.0, 0.15, -0.72))
	_create_mesh(_body_pivot, "ChestTrim", _box(Vector3(1.32, 0.10, 0.68)), _mat_gold, Vector3(0.0, 0.42, -0.73))
	_create_mesh(_body_pivot, "Saddle", _box(Vector3(0.92, 0.24, 0.86)), _mat_brown, Vector3(0.0, 0.62, 0.04))
	_create_mesh(_body_pivot, "SaddleCloth", _prism(Vector3(1.28, 1.12, 0.12)), _mat_blue, Vector3(0.0, 0.14, 0.04), Vector3(deg_to_rad(90.0), 0.0, 0.0))
	_create_mesh(_body_pivot, "SaddleGold", _box(Vector3(1.10, 0.07, 0.95)), _mat_gold, Vector3(0.0, 0.43, 0.04))

	_neck = Node3D.new()
	_neck.name = "NeckPivot"
	_neck.position = Vector3(0.0, 0.42, -0.86)
	_body_pivot.add_child(_neck)
	_neck.rotation.x = deg_to_rad(-18.0)
	_create_mesh(_neck, "Neck", _capsule(0.34, 1.10), _mat_white, Vector3(0.0, 0.34, -0.18), Vector3(deg_to_rad(-22.0), 0.0, 0.0))
	_create_mesh(_neck, "Mane", _box(Vector3(0.12, 0.78, 0.26)), _mat_gray, Vector3(0.0, 0.55, 0.08), Vector3(deg_to_rad(-22.0), 0.0, 0.0))
	_create_mesh(_neck, "Head", _capsule(0.30, 0.82), _mat_white, Vector3(0.0, 0.92, -0.42), Vector3(deg_to_rad(72.0), 0.0, 0.0), Vector3(0.92, 1.0, 0.92))
	_create_mesh(_neck, "Muzzle", _capsule(0.22, 0.54), _mat_gray, Vector3(0.0, 0.91, -0.84), Vector3(deg_to_rad(90.0), 0.0, 0.0))
	_create_mesh(_neck, "BrowArmor", _box(Vector3(0.58, 0.25, 0.34)), _mat_blue, Vector3(0.0, 1.03, -0.48), Vector3(deg_to_rad(-8.0), 0.0, 0.0))
	_create_mesh(_neck, "BrowTrim", _box(Vector3(0.64, 0.06, 0.38)), _mat_gold, Vector3(0.0, 1.13, -0.49), Vector3(deg_to_rad(-8.0), 0.0, 0.0))
	_create_mesh(_neck, "EarL", _cone(0.09, 0.0, 0.34, 8), _mat_white, Vector3(-0.17, 1.28, -0.38), Vector3(0.0, 0.0, deg_to_rad(-10.0)))
	_create_mesh(_neck, "EarR", _cone(0.09, 0.0, 0.34, 8), _mat_white, Vector3(0.17, 1.28, -0.38), Vector3(0.0, 0.0, deg_to_rad(10.0)))
	_create_mesh(_neck, "EyeL", _sphere(0.035, 0.07), _mat_black, Vector3(-0.24, 1.05, -0.65))
	_create_mesh(_neck, "EyeR", _sphere(0.035, 0.07), _mat_black, Vector3(0.24, 1.05, -0.65))

	_front_left_leg = _build_leg("FrontLeftLeg", Vector3(-0.42, -0.18, -0.63))
	_front_right_leg = _build_leg("FrontRightLeg", Vector3(0.42, -0.18, -0.63))
	_rear_left_leg = _build_leg("RearLeftLeg", Vector3(-0.42, -0.18, 0.67))
	_rear_right_leg = _build_leg("RearRightLeg", Vector3(0.42, -0.18, 0.67))

	_tail = Node3D.new()
	_tail.name = "TailPivot"
	_tail.position = Vector3(0.0, 0.28, 1.04)
	_body_pivot.add_child(_tail)
	_create_mesh(_tail, "Tail", _capsule(0.16, 1.18), _mat_gray, Vector3(0.0, -0.35, 0.38), Vector3(deg_to_rad(35.0), 0.0, 0.0), Vector3(0.75, 1.0, 0.75))

	_rider_socket = Marker3D.new()
	_rider_socket.name = "RiderSocket"
	_rider_socket.position = Vector3(0.0, 1.22, 0.02)
	_body_pivot.add_child(_rider_socket)

func _build_leg(node_name: String, local_position: Vector3) -> Node3D:
	var leg: Node3D = Node3D.new()
	leg.name = node_name
	leg.position = local_position
	_body_pivot.add_child(leg)
	_create_mesh(leg, "UpperLeg", _capsule(0.16, 0.78), _mat_white, Vector3(0.0, -0.36, 0.0))
	_create_mesh(leg, "Armor", _cylinder(0.19, 0.15, 0.38, 10), _mat_blue, Vector3(0.0, -0.52, 0.0))
	_create_mesh(leg, "ArmorTrim", _cylinder(0.20, 0.20, 0.06, 10), _mat_gold, Vector3(0.0, -0.36, 0.0))
	_create_mesh(leg, "LowerLeg", _capsule(0.12, 0.70), _mat_gray, Vector3(0.0, -0.90, 0.0))
	_create_mesh(leg, "Hoof", _box(Vector3(0.30, 0.20, 0.38)), _mat_brown, Vector3(0.0, -1.27, -0.04))
	return leg

func _create_mesh(parent: Node3D, node_name: String, mesh: Mesh, material: Material, local_position: Vector3, local_rotation: Vector3 = Vector3.ZERO, local_scale: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.material_override = material
	instance.position = local_position
	instance.rotation = local_rotation
	instance.scale = local_scale
	parent.add_child(instance)
	return instance

func _material(color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	return material

func _box(size_value: Vector3) -> BoxMesh:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size_value
	return mesh

func _capsule(radius_value: float, height_value: float) -> CapsuleMesh:
	var mesh: CapsuleMesh = CapsuleMesh.new()
	mesh.radius = radius_value
	mesh.height = height_value
	mesh.radial_segments = 12
	mesh.rings = 6
	return mesh

func _sphere(radius_value: float, height_value: float) -> SphereMesh:
	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius = radius_value
	mesh.height = height_value
	mesh.radial_segments = 12
	mesh.rings = 6
	return mesh

func _cylinder(top_radius: float, bottom_radius: float, height_value: float, segments: int) -> CylinderMesh:
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = top_radius
	mesh.bottom_radius = bottom_radius
	mesh.height = height_value
	mesh.radial_segments = segments
	return mesh

func _cone(bottom_radius: float, top_radius: float, height_value: float, segments: int) -> CylinderMesh:
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.bottom_radius = bottom_radius
	mesh.top_radius = top_radius
	mesh.height = height_value
	mesh.radial_segments = segments
	return mesh

func _prism(size_value: Vector3) -> PrismMesh:
	var mesh: PrismMesh = PrismMesh.new()
	mesh.size = size_value
	return mesh
