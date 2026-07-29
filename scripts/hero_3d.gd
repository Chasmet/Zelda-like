class_name Hero3D
extends CharacterBody3D

signal health_changed(current: int, maximum: int)
signal stamina_changed(current: float, maximum: float)
signal attack_hit(origin: Vector3, direction: Vector3, mounted: bool)
signal interact_requested
signal defeated

const MODEL_PATH: String = "res://assets/models/hero_cheikh.glb"

@export var max_health: int = 100
@export var max_stamina: float = 100.0
@export var walk_speed: float = 3.3
@export var run_speed: float = 6.8
@export var acceleration: float = 38.0
@export var deceleration: float = 52.0
@export var air_control: float = 9.0
@export var jump_velocity: float = 7.4
@export var rotation_speed: float = 19.0

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
var _cape: Node3D

func _ready() -> void:
	_gravity = float(ProjectSettings.get_setting("physics/3d/default_gravity", 22.0))
	health = max_health
	stamina = max_stamina
	spawn_position = global_position
	floor_snap_length = 0.38
	floor_max_angle = deg_to_rad(52.0)
	safe_margin = 0.04
	_build_collision()
	_load_real_avatar()

func set_move_input(input_value: Vector2, basis: Basis) -> void:
	move_input = input_value.limit_length(1.0)
	camera_basis = basis

func request_jump() -> void:
	_requested_jump = true

func request_attack() -> void:
	if _attack_cooldown > 0.0 or _dodge_timer > 0.0 or stamina < 9.0:
		return
	_attack_timer = 0.42
	_attack_cooldown = 0.54
	_attack_emitted = false
	stamina = maxf(0.0, stamina - 9.0)
	stamina_changed.emit(stamina, max_stamina)

func request_dodge() -> void:
	if mounted or _dodge_timer > 0.0 or stamina < 18.0:
		return
	var direction: Vector3 = _camera_relative_direction()
	if direction.length_squared() < 0.01:
		direction = get_forward()
	_dodge_direction = direction.normalized()
	_dodge_timer = 0.38
	_invulnerable_timer = 0.30
	stamina = maxf(0.0, stamina - 18.0)
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
	if is_instance_valid(_model_root):
		_model_root.rotation = Vector3.ZERO

func take_damage(amount: int, from_position: Vector3 = Vector3.ZERO) -> void:
	if _invulnerable_timer > 0.0 or health <= 0:
		return
	health = maxi(0, health - amount)
	_invulnerable_timer = 0.50
	if not mounted and from_position != Vector3.ZERO:
		var knockback: Vector3 = global_position - from_position
		knockback.y = 0.18
		if knockback.length_squared() > 0.001:
			velocity += knockback.normalized() * 5.2
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
	stamina = minf(max_stamina, stamina + (18.0 if move_input.length() < 0.45 else 10.0) * delta)

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
		velocity.x = _dodge_direction.x * 12.2
		velocity.z = _dodge_direction.z * 12.2
	else:
		var target_speed: float = _analog_speed(input_strength)
		var target_velocity: Vector3 = direction * target_speed
		var accel_value: float = acceleration if is_on_floor() else air_control
		if input_strength < 0.03:
			velocity.x = move_toward(velocity.x, 0.0, deceleration * delta)
			velocity.z = move_toward(velocity.z, 0.0, deceleration * delta)
		else:
			velocity.x = move_toward(velocity.x, target_velocity.x, accel_value * delta)
			velocity.z = move_toward(velocity.z, target_velocity.z, accel_value * delta)
			var target_yaw: float = atan2(-direction.x, -direction.z)
			rotation.y = lerp_angle(rotation.y, target_yaw, 1.0 - exp(-rotation_speed * delta))

	move_and_slide()
	if global_position.y < -25.0:
		_respawn()
	_update_animation(delta)
	_update_attack()

func _analog_speed(strength: float) -> float:
	if strength <= 0.0:
		return 0.0
	if strength < 0.70:
		return walk_speed * (strength / 0.70)
	var run_blend: float = inverse_lerp(0.70, 1.0, strength)
	return lerpf(walk_speed, run_speed, run_blend)

func _camera_relative_direction() -> Vector3:
	var forward: Vector3 = -camera_basis.z
	var right: Vector3 = camera_basis.x
	forward.y = 0.0
	right.y = 0.0
	forward = forward.normalized()
	right = right.normalized()
	return (right * move_input.x + forward * move_input.y).limit_length(1.0)

func _update_attack() -> void:
	if _attack_timer <= 0.0 or not is_instance_valid(_right_arm):
		return
	var progress: float = 1.0 - (_attack_timer / 0.42)
	var swing: float = sin(progress * PI)
	_right_arm.rotation.x = deg_to_rad(-25.0) - swing * deg_to_rad(125.0)
	_right_arm.rotation.z = swing * deg_to_rad(-38.0)
	_body_root.rotation.y = swing * deg_to_rad(-18.0)
	if not _attack_emitted and progress >= 0.46:
		_attack_emitted = true
		attack_hit.emit(global_position + Vector3.UP * 1.15, get_forward(), mounted)

func _update_animation(delta: float) -> void:
	if not is_instance_valid(_body_root):
		return
	var horizontal_speed: float = Vector2(velocity.x, velocity.z).length()
	var movement_blend: float = clampf(horizontal_speed / run_speed, 0.0, 1.0)
	_anim_clock += delta * lerpf(4.2, 11.2, movement_blend)
	var stride: float = sin(_anim_clock) * movement_blend
	var opposite: float = sin(_anim_clock + PI) * movement_blend
	if _attack_timer <= 0.0:
		if is_instance_valid(_left_arm):
			_left_arm.rotation.x = stride * 0.72
		if is_instance_valid(_right_arm):
			_right_arm.rotation.x = opposite * 0.72
			_right_arm.rotation.z = 0.0
		_body_root.rotation.y = 0.0
	if is_instance_valid(_left_leg):
		_left_leg.rotation.x = opposite * 0.88
	if is_instance_valid(_right_leg):
		_right_leg.rotation.x = stride * 0.88
	_body_root.position.y = 0.28 + absf(sin(_anim_clock * 2.0)) * 0.035 * movement_blend
	_body_root.rotation.z = -stride * 0.025
	if is_instance_valid(_cape):
		_cape.rotation.x = deg_to_rad(7.0) + movement_blend * deg_to_rad(14.0) + sin(_anim_clock * 0.55) * 0.035
	if _dodge_timer > 0.0 and is_instance_valid(_model_root):
		var dodge_progress: float = 1.0 - (_dodge_timer / 0.38)
		_model_root.rotation.z = dodge_progress * TAU
		_model_root.position.y = 0.12
	elif is_instance_valid(_model_root):
		_model_root.rotation.z = lerpf(_model_root.rotation.z, 0.0, 0.35)
		_model_root.position.y = lerpf(_model_root.position.y, 0.0, 0.35)

func _update_mounted_state(delta: float) -> void:
	if not is_instance_valid(mounted_horse):
		dismount(global_position)
		return
	global_transform = mounted_horse.get_rider_transform()
	velocity = Vector3.ZERO
	_anim_clock += delta * maxf(3.0, mounted_horse.get_speed() * 0.86)
	_body_root.position.y = 0.02 + sin(_anim_clock * 2.0) * 0.018
	_body_root.rotation.x = deg_to_rad(-3.0)
	if is_instance_valid(_left_leg):
		_left_leg.rotation.x = deg_to_rad(58.0)
		_left_leg.rotation.z = deg_to_rad(-18.0)
	if is_instance_valid(_right_leg):
		_right_leg.rotation.x = deg_to_rad(58.0)
		_right_leg.rotation.z = deg_to_rad(18.0)
	if is_instance_valid(_left_arm):
		_left_arm.rotation.x = deg_to_rad(-28.0)
	if is_instance_valid(_right_arm):
		_right_arm.rotation.x = deg_to_rad(-28.0)
	if is_instance_valid(_cape):
		_cape.rotation.x = deg_to_rad(18.0) + clampf(mounted_horse.get_speed() / 14.0, 0.0, 1.0) * deg_to_rad(28.0)
	_update_attack()

func _respawn() -> void:
	health = max_health
	stamina = max_stamina
	global_position = spawn_position
	velocity = Vector3.ZERO
	health_changed.emit(health, max_health)
	stamina_changed.emit(stamina, max_stamina)

func _build_collision() -> void:
	var collision: CollisionShape3D = CollisionShape3D.new()
	collision.name = "HeroCollision"
	var capsule: CapsuleShape3D = CapsuleShape3D.new()
	capsule.radius = 0.38
	capsule.height = 1.62
	collision.shape = capsule
	collision.position.y = 0.82
	add_child(collision)

func _load_real_avatar() -> void:
	_model_root = Node3D.new()
	_model_root.name = "CheikhAvatarRoot"
	add_child(_model_root)
	_body_root = Node3D.new()
	_body_root.name = "BodyAnimationRoot"
	_body_root.position.y = 0.28
	_model_root.add_child(_body_root)
	var resource: Resource = load(MODEL_PATH)
	if not resource is PackedScene:
		push_error("Le modèle 3D de Cheikh est absent: " + MODEL_PATH)
		return
	var instance: Node3D = (resource as PackedScene).instantiate() as Node3D
	instance.name = "CheikhGLB"
	_body_root.add_child(instance)
	_left_arm = _find_node(instance, "Arm_L")
	_right_arm = _find_node(instance, "Arm_R")
	_left_leg = _find_node(instance, "Leg_L")
	_right_leg = _find_node(instance, "Leg_R")
	_cape = _find_node(instance, "Cape")
	_reparent_chain(instance, "Arm_L", ["Forearm_L", "Hand_L", "Bracer_L"])
	_reparent_chain(instance, "Arm_R", ["Forearm_R", "Hand_R", "Bracer_R", "SwordBlade", "SwordGuard", "SwordGrip"])
	_reparent_chain(instance, "Leg_L", ["Shin_L", "Boot_L", "KneeArmor_L"])
	_reparent_chain(instance, "Leg_R", ["Shin_R", "Boot_R", "KneeArmor_R"])
	_reparent_chain(instance, "Cape", ["CapeFold"])

func _find_node(root: Node, node_name: String) -> Node3D:
	var found: Node = root.find_child(node_name, true, false)
	return found as Node3D

func _reparent_chain(root: Node, parent_name: String, child_names: Array[String]) -> void:
	var new_parent: Node = root.find_child(parent_name, true, false)
	if not is_instance_valid(new_parent):
		return
	for child_name: String in child_names:
		var child: Node = root.find_child(child_name, true, false)
		if is_instance_valid(child) and child.get_parent() != new_parent:
			child.reparent(new_parent, true)

func _set_collision_enabled(enabled: bool) -> void:
	for child: Node in get_children():
		if child is CollisionShape3D:
			(child as CollisionShape3D).disabled = not enabled
