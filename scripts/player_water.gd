class_name PlayerWaterController
extends "res://scripts/player.gd"

signal water_state_changed(in_water: bool, underwater: bool)
signal oxygen_changed(current: float, maximum: float)

@export var swim_speed: float = 4.8
@export var swim_sprint_speed: float = 6.2
@export var swim_acceleration: float = 11.0
@export var swim_vertical_speed: float = 3.8
@export var max_oxygen: float = 12.0

var oxygen: float = 12.0
var in_water: bool = false
var underwater: bool = false
var water_surface_y: float = -0.92
var water_bottom_y: float = -8.5
var water_bounds: Rect2 = Rect2()
var last_safe_ground_position: Vector3 = Vector3.ZERO

var _water_enabled: bool = false
var _swim_vertical_override: float = 0.0
var _swim_vertical_timer: float = 0.0
var _drown_tick_timer: float = 1.0
var _last_oxygen_report: int = -1


func _ready() -> void:
	super._ready()
	oxygen = max_oxygen
	last_safe_ground_position = global_position
	_emit_oxygen_if_needed(true)


func set_water_profile(surface_y: float, bottom_y: float, bounds: Rect2) -> void:
	water_surface_y = surface_y
	water_bottom_y = bottom_y
	water_bounds = bounds
	_water_enabled = true
	_refresh_water_flags()


func set_spawn(point: Vector3) -> void:
	super.set_spawn(point)
	if point.is_finite():
		last_safe_ground_position = point


func request_swim_vertical(direction: float, duration: float = 0.42) -> void:
	if not in_water:
		return
	_swim_vertical_override = clampf(direction, -1.0, 1.0)
	_swim_vertical_timer = maxf(_swim_vertical_timer, duration)


func get_safe_save_position() -> Vector3:
	if last_safe_ground_position.is_finite():
		return last_safe_ground_position
	return spawn_position


func get_water_debug() -> Dictionary:
	return {
		"enabled": _water_enabled,
		"in_water": in_water,
		"underwater": underwater,
		"oxygen": oxygen,
		"max_oxygen": max_oxygen,
		"surface_y": water_surface_y,
		"bottom_y": water_bottom_y,
		"bounds": water_bounds,
		"safe_position": last_safe_ground_position,
		"vertical_override": _swim_vertical_override,
		"vertical_timer": _swim_vertical_timer
	}


func get_movement_debug() -> Dictionary:
	var result: Dictionary = super.get_movement_debug()
	result.merge(get_water_debug(), true)
	return result


func _physics_process(delta: float) -> void:
	_refresh_water_flags()
	if not in_water:
		super._physics_process(delta)
		_refresh_water_flags()
		if not in_water and is_on_floor() and global_position.is_finite():
			last_safe_ground_position = global_position
		return

	_physics_tick_count += 1
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	dodge_cooldown = maxf(0.0, dodge_cooldown - delta)
	invulnerability = maxf(0.0, invulnerability - delta)
	_swim_vertical_timer = maxf(0.0, _swim_vertical_timer - delta)

	var input_vector: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if virtual_move.length() > 0.08:
		input_vector = virtual_move.limit_length(1.0)
	_last_input_vector = input_vector
	_last_direction = Vector3.ZERO
	_last_target_velocity = Vector3.ZERO

	var forward: Vector3 = Vector3.FORWARD
	var right: Vector3 = Vector3.RIGHT
	if is_instance_valid(_camera):
		forward = -_camera.global_transform.basis.z
		right = _camera.global_transform.basis.x
	forward.y = 0.0
	right.y = 0.0
	forward = forward.normalized() if forward.length_squared() > 0.0001 else Vector3.FORWARD
	right = right.normalized() if right.length_squared() > 0.0001 else Vector3.RIGHT

	var direction: Vector3 = right * input_vector.x + forward * -input_vector.y
	if direction.length_squared() > 0.0001:
		direction = direction.normalized()
	_last_direction = direction

	var speed: float = swim_sprint_speed if Input.is_action_pressed("sprint") else swim_speed
	var target_horizontal := Vector3(direction.x * speed, 0.0, direction.z * speed)
	_last_target_velocity = Vector3(target_horizontal.x, velocity.y, target_horizontal.z)

	if can_control and direction.length_squared() > 0.01:
		velocity.x = move_toward(velocity.x, target_horizontal.x, swim_acceleration * delta)
		velocity.z = move_toward(velocity.z, target_horizontal.z, swim_acceleration * delta)
		if is_instance_valid(_visual):
			_visual.rotation.y = lerp_angle(_visual.rotation.y, atan2(-direction.x, -direction.z), minf(1.0, 8.0 * delta))
	else:
		velocity.x = move_toward(velocity.x, 0.0, swim_acceleration * 0.75 * delta)
		velocity.z = move_toward(velocity.z, 0.0, swim_acceleration * 0.75 * delta)

	var vertical_input: float = 0.0
	if can_control:
		if Input.is_action_pressed("jump"):
			vertical_input += 1.0
		if Input.is_action_pressed("dodge"):
			vertical_input -= 1.0
		if _swim_vertical_timer > 0.0:
			vertical_input = _swim_vertical_override

	var surface_target: float = water_surface_y - 1.15
	var target_vertical: float
	if absf(vertical_input) > 0.01:
		target_vertical = vertical_input * swim_vertical_speed
	elif underwater:
		target_vertical = 1.15
	else:
		target_vertical = clampf((surface_target - global_position.y) * 1.8, -1.6, 1.6)
	velocity.y = move_toward(velocity.y, target_vertical, swim_acceleration * delta)

	if can_control:
		if Input.is_action_just_pressed("attack"):
			attack()
		if Input.is_action_just_pressed("interact"):
			interact()

	_last_position_before_slide = global_position
	move_and_slide()
	_last_position_after_slide = global_position
	_last_slide_count = get_slide_collision_count()

	if global_position.y > water_surface_y - 0.58:
		global_position.y = water_surface_y - 0.58
		velocity.y = minf(velocity.y, 0.0)
	if global_position.y < water_bottom_y - 0.35:
		_respawn()
		return

	_refresh_water_flags()
	_update_oxygen(delta)
	_update_model_animation()


func dodge() -> void:
	if in_water:
		if dodge_cooldown > 0.0 or not can_control:
			return
		dodge_cooldown = 0.28
		request_swim_vertical(-1.0, 0.52)
		return
	super.dodge()


func _refresh_water_flags() -> void:
	var previous_in_water := in_water
	var previous_underwater := underwater
	var inside_horizontal := false
	if _water_enabled and water_bounds.size.x > 0.0 and water_bounds.size.y > 0.0:
		inside_horizontal = water_bounds.has_point(Vector2(global_position.x, global_position.z))
	in_water = _water_enabled and inside_horizontal and global_position.y <= water_surface_y + 0.35 and global_position.y >= water_bottom_y - 1.0
	underwater = in_water and global_position.y + 1.58 < water_surface_y - 0.10
	if previous_in_water != in_water or previous_underwater != underwater:
		water_state_changed.emit(in_water, underwater)


func _update_oxygen(delta: float) -> void:
	if underwater:
		oxygen = maxf(0.0, oxygen - delta)
	else:
		oxygen = minf(max_oxygen, oxygen + delta * 3.5)

	if oxygen <= 0.0:
		_drown_tick_timer -= delta
		if _drown_tick_timer <= 0.0:
			_drown_tick_timer = 1.0
			take_damage(12)
	else:
		_drown_tick_timer = 1.0
	_emit_oxygen_if_needed()


func _emit_oxygen_if_needed(force: bool = false) -> void:
	var report := int(round(oxygen * 10.0))
	if force or report != _last_oxygen_report:
		_last_oxygen_report = report
		oxygen_changed.emit(oxygen, max_oxygen)


func _respawn() -> void:
	can_control = false
	velocity = Vector3.ZERO
	var respawn_position := last_safe_ground_position if last_safe_ground_position.is_finite() else spawn_position
	global_position = respawn_position
	spawn_position = respawn_position
	health = max_health
	oxygen = max_oxygen
	in_water = false
	underwater = false
	_swim_vertical_timer = 0.0
	_swim_vertical_override = 0.0
	health_changed.emit(health, max_health)
	_emit_oxygen_if_needed(true)
	if is_instance_valid(_model_animator):
		_model_animator.reset_pose()
	await get_tree().create_timer(0.35).timeout
	can_control = true


func _update_model_animation() -> void:
	if not is_instance_valid(_model_animator):
		return
	var horizontal_speed: float = Vector2(velocity.x, velocity.z).length()
	if in_water:
		_model_animator.set_locomotion(horizontal_speed / maxf(swim_speed, 0.01), false)
	else:
		_model_animator.set_locomotion(horizontal_speed / maxf(move_speed, 0.01), not is_on_floor())
