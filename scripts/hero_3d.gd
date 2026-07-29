class_name Hero3D
extends CharacterBody3D

signal health_changed(current: int, maximum: int)
signal stamina_changed(current: float, maximum: float)
signal attack_hit(origin: Vector3, direction: Vector3, mounted: bool)
signal interact_requested
signal defeated

@export var max_health: int = 100
@export var max_stamina: float = 100.0
@export var walk_speed: float = 4.6
@export var run_speed: float = 8.2
@export var acceleration: float = 24.0
@export var air_control: float = 7.0
@export var jump_velocity: float = 8.4
@export var rotation_speed: float = 14.0

var health: int = 100
var stamina: float = 100.0
var move_input: Vector2 = Vector2.ZERO
var camera_basis: Basis = Basis.IDENTITY
var mounted: bool = false
var mounted_horse: Horse3D
var spawn_position: Vector3 = Vector3.ZERO

var _gravity: float = 22.0
var _anim_clock: float = 0.0
var _attack_timer: float = 0.0
var _attack_cooldown: float = 0.0
var _attack_emitted: bool = false
var _dodge_timer: float = 0.0
var _dodge_direction: Vector3 = Vector3.ZERO
var _invulnerable_timer: float = 0.0
var _requested_jump: bool = false

var _model_root: Node3D
var _body_root: Node3D
var _left_arm: Node3D
var _right_arm: Node3D
var _left_leg: Node3D
var _right_leg: Node3D
var _sword_arm: Node3D
var _cape: Node3D

var _mat_blue: StandardMaterial3D
var _mat_blue_dark: StandardMaterial3D
var _mat_gold: StandardMaterial3D
var _mat_white: StandardMaterial3D
var _mat_green: StandardMaterial3D
var _mat_brown: StandardMaterial3D
var _mat_skin: StandardMaterial3D
var _mat_black: StandardMaterial3D

func _ready() -> void:
	_gravity = float(ProjectSettings.get_setting("physics/3d/default_gravity", 22.0))
	health = max_health
	stamina = max_stamina
	spawn_position = global_position
	_build_materials()
	_build_collision()
	_build_true_3d_model()

func set_move_input(input_value: Vector2, basis: Basis) -> void:
	move_input = input_value.limit_length(1.0)
	camera_basis = basis

func request_jump() -> void:
	_requested_jump = true

func request_attack() -> void:
	if _attack_cooldown > 0.0 or _dodge_timer > 0.0 or stamina < 10.0:
		return
	_attack_timer = 0.44
	_attack_cooldown = 0.58
	_attack_emitted = false
	stamina = maxf(0.0, stamina - 10.0)
	stamina_changed.emit(stamina, max_stamina)

func request_dodge() -> void:
	if mounted or _dodge_timer > 0.0 or stamina < 22.0:
		return
	var direction: Vector3 = _camera_relative_direction()
	if direction.length_squared() < 0.01:
		direction = get_forward()
	_dodge_direction = direction.normalized()
	_dodge_timer = 0.46
	_invulnerable_timer = 0.34
	stamina = maxf(0.0, stamina - 22.0)
	stamina_changed.emit(stamina, max_stamina)

func request_interact() -> void:
	interact_requested.emit()

func mount(horse: Horse3D) -> void:
	if not is_instance_valid(horse):
		return
	mounted = true
	mounted_horse = horse
	velocity = Vector3.ZERO
	_set_collision_enabled(false)

func dismount(dismount_position: Vector3) -> void:
	mounted = false
	mounted_horse = null
	global_position = dismount_position
	velocity = Vector3.ZERO
	_set_collision_enabled(true)
	_model_root.rotation = Vector3.ZERO

func take_damage(amount: int, from_position: Vector3 = Vector3.ZERO) -> void:
	if _invulnerable_timer > 0.0 or health <= 0:
		return
	health = maxi(0, health - amount)
	_invulnerable_timer = 0.55
	if not mounted and from_position != Vector3.ZERO:
		var knockback: Vector3 = global_position - from_position
		knockback.y = 0.2
		if knockback.length_squared() > 0.001:
			velocity += knockback.normalized() * 6.0
	health_changed.emit(health, max_health)
	if health <= 0:
		defeated.emit()
		_respawn()

func heal(amount: int) -> void:
	health = mini(max_health, health + amount)
	health_changed.emit(health, max_health)

func get_forward() -> Vector3:
	return -global_transform.basis.z.normalized()

func get_model_root() -> Node3D:
	return _model_root

func set_spawn(point: Vector3) -> void:
	spawn_position = point

func _physics_process(delta: float) -> void:
	_attack_cooldown = maxf(0.0, _attack_cooldown - delta)
	_attack_timer = maxf(0.0, _attack_timer - delta)
	_dodge_timer = maxf(0.0, _dodge_timer - delta)
	_invulnerable_timer = maxf(0.0, _invulnerable_timer - delta)
	stamina = minf(max_stamina, stamina + (15.0 if move_input.length() < 0.75 else 8.0) * delta)

	if mounted:
		_update_mounted_state(delta)
		_requested_jump = false
		return

	if not is_on_floor():
		velocity.y -= _gravity * delta
	elif _requested_jump and _dodge_timer <= 0.0:
		velocity.y = jump_velocity
	_requested_jump = false

	var direction: Vector3 = _camera_relative_direction()
	var input_strength: float = move_input.length()
	if _dodge_timer > 0.0:
		velocity.x = _dodge_direction.x * 13.0
		velocity.z = _dodge_direction.z * 13.0
	else:
		var target_speed: float = lerpf(walk_speed, run_speed, smoothstep(0.55, 1.0, input_strength))
		var target_velocity: Vector3 = direction * target_speed * input_strength
		var current_acceleration: float = acceleration if is_on_floor() else air_control
		velocity.x = move_toward(velocity.x, target_velocity.x, current_acceleration * delta)
		velocity.z = move_toward(velocity.z, target_velocity.z, current_acceleration * delta)
		if direction.length_squared() > 0.01:
			var target_yaw: float = atan2(-direction.x, -direction.z)
			rotation.y = lerp_angle(rotation.y, target_yaw, 1.0 - exp(-rotation_speed * delta))

	move_and_slide()
	if global_position.y < -25.0:
		_respawn()
	_update_animation(delta, input_strength)
	_update_attack(delta)

func _camera_relative_direction() -> Vector3:
	var forward: Vector3 = -camera_basis.z
	var right: Vector3 = camera_basis.x
	forward.y = 0.0
	right.y = 0.0
	forward = forward.normalized()
	right = right.normalized()
	var direction: Vector3 = right * move_input.x + forward * move_input.y
	return direction.limit_length(1.0)

func _update_attack(_delta: float) -> void:
	if _attack_timer <= 0.0:
		return
	var progress: float = 1.0 - (_attack_timer / 0.44)
	var swing: float = sin(progress * PI)
	_right_arm.rotation.x = deg_to_rad(-35.0) - swing * deg_to_rad(100.0)
	_right_arm.rotation.z = swing * deg_to_rad(-52.0)
	_body_root.rotation.y = swing * deg_to_rad(-24.0)
	if not _attack_emitted and progress >= 0.48:
		_attack_emitted = true
		attack_hit.emit(global_position + Vector3.UP * 1.2, get_forward(), mounted)

func _update_animation(delta: float, input_strength: float) -> void:
	_anim_clock += delta * lerpf(4.0, 10.5, input_strength)
	var horizontal_speed: float = Vector2(velocity.x, velocity.z).length()
	var movement_blend: float = clampf(horizontal_speed / run_speed, 0.0, 1.0)
	var stride: float = sin(_anim_clock) * movement_blend
	var opposite: float = sin(_anim_clock + PI) * movement_blend

	if _attack_timer <= 0.0:
		_left_arm.rotation.x = stride * 0.65
		_right_arm.rotation.x = opposite * 0.65
		_right_arm.rotation.z = 0.0
		_body_root.rotation.y = 0.0
	_left_leg.rotation.x = opposite * 0.82
	_right_leg.rotation.x = stride * 0.82
	_body_root.position.y = 0.03 + absf(sin(_anim_clock * 2.0)) * 0.045 * movement_blend
	_body_root.rotation.z = -stride * 0.035
	_cape.rotation.x = deg_to_rad(7.0) + movement_blend * deg_to_rad(12.0) + sin(_anim_clock * 0.55) * 0.04

	if _dodge_timer > 0.0:
		var dodge_progress: float = 1.0 - (_dodge_timer / 0.46)
		_model_root.rotation.z = dodge_progress * TAU
		_model_root.position.y = 0.15
	else:
		_model_root.rotation.z = lerpf(_model_root.rotation.z, 0.0, 0.28)
		_model_root.position.y = lerpf(_model_root.position.y, 0.0, 0.25)

func _update_mounted_state(delta: float) -> void:
	if not is_instance_valid(mounted_horse):
		dismount(global_position)
		return
	var saddle_transform: Transform3D = mounted_horse.get_rider_transform()
	global_transform = saddle_transform
	velocity = Vector3.ZERO
	_anim_clock += delta * maxf(3.0, mounted_horse.get_speed() * 0.9)
	_body_root.position.y = -0.08 + sin(_anim_clock * 2.0) * 0.025
	_body_root.rotation.x = deg_to_rad(-4.0)
	_left_leg.rotation.x = deg_to_rad(58.0)
	_right_leg.rotation.x = deg_to_rad(58.0)
	_left_leg.rotation.z = deg_to_rad(-18.0)
	_right_leg.rotation.z = deg_to_rad(18.0)
	_left_arm.rotation.x = deg_to_rad(-35.0)
	_right_arm.rotation.x = deg_to_rad(-35.0)
	_cape.rotation.x = deg_to_rad(22.0) + clampf(mounted_horse.get_speed() / 14.0, 0.0, 1.0) * deg_to_rad(24.0)
	_update_attack(delta)

func _respawn() -> void:
	health = max_health
	stamina = max_stamina
	global_position = spawn_position
	velocity = Vector3.ZERO
	health_changed.emit(health, max_health)
	stamina_changed.emit(stamina, max_stamina)

func _build_materials() -> void:
	_mat_blue = _material(Color("#1459a6"), 0.35, 0.34)
	_mat_blue_dark = _material(Color("#082b59"), 0.15, 0.52)
	_mat_gold = _material(Color("#c9942f"), 0.72, 0.24)
	_mat_white = _material(Color("#d8d7cb"), 0.05, 0.62)
	_mat_green = _material(Color("#245c48"), 0.08, 0.70)
	_mat_brown = _material(Color("#4a2c1c"), 0.05, 0.84)
	_mat_skin = _material(Color("#6e402c"), 0.02, 0.78)
	_mat_black = _material(Color("#0b0c10"), 0.08, 0.70)

func _build_collision() -> void:
	var collision: CollisionShape3D = CollisionShape3D.new()
	collision.name = "BodyCollision"
	var capsule: CapsuleShape3D = CapsuleShape3D.new()
	capsule.radius = 0.43
	capsule.height = 1.75
	collision.shape = capsule
	collision.position.y = 0.92
	add_child(collision)

func _build_true_3d_model() -> void:
	_model_root = Node3D.new()
	_model_root.name = "HeroTrue3D"
	add_child(_model_root)

	_body_root = Node3D.new()
	_body_root.name = "BodyRoot"
	_model_root.add_child(_body_root)

	_create_mesh(_body_root, "Pelvis", _box(Vector3(0.58, 0.34, 0.38)), _mat_brown, Vector3(0.0, 0.92, 0.0))
	_create_mesh(_body_root, "Belt", _box(Vector3(0.70, 0.16, 0.46)), _mat_gold, Vector3(0.0, 1.10, 0.0))
	_create_mesh(_body_root, "Torso", _capsule(0.39, 0.88), _mat_white, Vector3(0.0, 1.53, 0.0))
	_create_mesh(_body_root, "ChestArmor", _box(Vector3(0.76, 0.46, 0.24)), _mat_blue, Vector3(0.0, 1.63, -0.22))
	_create_mesh(_body_root, "ChestGold", _box(Vector3(0.50, 0.09, 0.28)), _mat_gold, Vector3(0.0, 1.69, -0.34))
	_create_mesh(_body_root, "Neck", _cylinder(0.14, 0.14, 0.22, 12), _mat_skin, Vector3(0.0, 2.04, 0.0))
	_create_mesh(_body_root, "Head", _sphere(0.27, 0.52), _mat_skin, Vector3(0.0, 2.29, 0.0))
	_create_mesh(_body_root, "Hair", _sphere(0.275, 0.20), _mat_black, Vector3(0.0, 2.47, 0.015), Vector3.ZERO, Vector3(1.0, 0.58, 1.0))
	_create_mesh(_body_root, "Nose", _box(Vector3(0.055, 0.10, 0.08)), _mat_skin, Vector3(0.0, 2.29, -0.265))
	_create_mesh(_body_root, "EyeL", _sphere(0.022, 0.04), _mat_black, Vector3(-0.085, 2.34, -0.253))
	_create_mesh(_body_root, "EyeR", _sphere(0.022, 0.04), _mat_black, Vector3(0.085, 2.34, -0.253))

	_left_arm = _build_arm("LeftArm", -0.48, false)
	_right_arm = _build_arm("RightArm", 0.48, true)
	_left_leg = _build_leg("LeftLeg", -0.20)
	_right_leg = _build_leg("RightLeg", 0.20)

	_create_mesh(_body_root, "TabardFront", _prism(Vector3(0.66, 0.86, 0.10)), _mat_green, Vector3(0.0, 0.70, -0.25), Vector3(deg_to_rad(90.0), 0.0, 0.0))
	_create_mesh(_body_root, "TabardGold", _box(Vector3(0.16, 0.72, 0.05)), _mat_gold, Vector3(0.0, 0.68, -0.34))

	_cape = Node3D.new()
	_cape.name = "CapePivot"
	_cape.position = Vector3(0.0, 1.95, 0.27)
	_body_root.add_child(_cape)
	_create_mesh(_cape, "Cape", _prism(Vector3(1.18, 1.70, 0.10)), _mat_blue, Vector3(0.0, -0.74, 0.11), Vector3(deg_to_rad(90.0), 0.0, 0.0))
	_create_mesh(_cape, "CapeTrim", _box(Vector3(1.05, 0.07, 0.13)), _mat_gold, Vector3(0.0, -1.54, 0.12))

func _build_arm(node_name: String, x_position: float, sword_side: bool) -> Node3D:
	var shoulder: Node3D = Node3D.new()
	shoulder.name = node_name
	shoulder.position = Vector3(x_position, 1.82, 0.0)
	_body_root.add_child(shoulder)
	_create_mesh(shoulder, "ShoulderArmor", _sphere(0.25, 0.28), _mat_blue, Vector3.ZERO, Vector3.ZERO, Vector3(1.15, 0.72, 1.0))
	_create_mesh(shoulder, "ShoulderTrim", _box(Vector3(0.36, 0.10, 0.34)), _mat_gold, Vector3(0.0, -0.05, 0.0))
	_create_mesh(shoulder, "UpperArm", _capsule(0.12, 0.56), _mat_brown, Vector3(0.0, -0.33, 0.0))
	_create_mesh(shoulder, "Bracer", _cylinder(0.15, 0.11, 0.36, 10), _mat_blue, Vector3(0.0, -0.69, 0.0))
	_create_mesh(shoulder, "Hand", _sphere(0.13, 0.23), _mat_skin, Vector3(0.0, -0.93, 0.0))
	if sword_side:
		_sword_arm = shoulder
		_create_mesh(shoulder, "SwordGrip", _cylinder(0.045, 0.045, 0.30, 8), _mat_brown, Vector3(0.0, -1.06, -0.05), Vector3(deg_to_rad(90.0), 0.0, 0.0))
		_create_mesh(shoulder, "SwordGuard", _box(Vector3(0.34, 0.05, 0.08)), _mat_gold, Vector3(0.0, -1.12, -0.18))
		_create_mesh(shoulder, "SwordBlade", _box(Vector3(0.10, 0.88, 0.035)), _mat_white, Vector3(0.0, -1.58, -0.20), Vector3(deg_to_rad(-8.0), 0.0, 0.0))
	return shoulder

func _build_leg(node_name: String, x_position: float) -> Node3D:
	var hip: Node3D = Node3D.new()
	hip.name = node_name
	hip.position = Vector3(x_position, 0.93, 0.0)
	_body_root.add_child(hip)
	_create_mesh(hip, "Thigh", _capsule(0.16, 0.62), _mat_green, Vector3(0.0, -0.34, 0.0))
	_create_mesh(hip, "KneeArmor", _sphere(0.18, 0.24), _mat_blue, Vector3(0.0, -0.70, -0.08), Vector3.ZERO, Vector3(1.0, 0.82, 1.0))
	_create_mesh(hip, "Shin", _capsule(0.14, 0.56), _mat_brown, Vector3(0.0, -1.02, 0.0))
	_create_mesh(hip, "Boot", _box(Vector3(0.30, 0.22, 0.48)), _mat_brown, Vector3(0.0, -1.37, -0.10))
	return hip

func _set_collision_enabled(enabled: bool) -> void:
	var collision: CollisionShape3D = get_node_or_null("BodyCollision") as CollisionShape3D
	if collision != null:
		collision.disabled = not enabled

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

func _prism(size_value: Vector3) -> PrismMesh:
	var mesh: PrismMesh = PrismMesh.new()
	mesh.size = size_value
	return mesh
