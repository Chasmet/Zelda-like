extends "res://scripts/player_water.gd"

const V8_MODEL_ANIMATOR = preload("res://scripts/procedural_animator_v8.gd")

signal water_flight_changed(active: bool, remaining: float)

@export var water_flight_duration: float = 5.0
@export var water_flight_speed: float = 9.2
@export var water_flight_acceleration: float = 18.0
@export var water_flight_height: float = 3.2

var water_flight_active: bool = false
var water_flight_remaining: float = 0.0
var water_flight_used_since_land: bool = false
var _flight_target_y: float = 0.0


func apply_asset(path: String) -> void:
	if path.is_empty() or not is_instance_valid(_visual) or not ResourceLoader.exists(path):
		return

	var loaded: Resource = load(path)
	if not loaded is PackedScene:
		super.apply_asset(path)
		return

	var packed: PackedScene = loaded as PackedScene
	var scene_instance: Node = packed.instantiate()
	if not scene_instance is Node3D:
		return

	_clear_generated_visual(true)
	var animator: ProceduralCharacterAnimator = V8_MODEL_ANIMATOR.new() as ProceduralCharacterAnimator
	animator.name = "ImportedHeroModel"
	_visual.add_child(animator)

	var node_3d: Node3D = scene_instance as Node3D
	node_3d.name = "HeroBlenderAsset"
	node_3d.rotation.y = PI
	animator.add_child(node_3d)
	animator.bind_model(node_3d)
	_model_animator = animator


func request_water_flight() -> bool:
	if water_flight_active or water_flight_used_since_land or not in_water or _respawning:
		return false

	water_flight_active = true
	water_flight_remaining = water_flight_duration
	water_flight_used_since_land = true
	_flight_target_y = water_surface_y + water_flight_height
	in_water = false
	underwater = false
	_open_water_column = false
	_swim_vertical_timer = 0.0
	velocity.y = maxf(velocity.y, 6.4)
	water_state_changed.emit(false, false)
	water_flight_changed.emit(true, water_flight_remaining)
	return true


func get_water_debug() -> Dictionary:
	var result: Dictionary = super.get_water_debug()
	result["flight_active"] = water_flight_active
	result["flight_remaining"] = water_flight_remaining
	result["flight_duration"] = water_flight_duration
	result["flight_used_since_land"] = water_flight_used_since_land
	return result


func set_virtual_move(value: Vector2) -> void:
	super.set_virtual_move(value)
	# Sur mobile, relâcher le joystick doit arrêter immédiatement l'impulsion
	# horizontale. Cela évite la glissade résiduelle sur les grands terrains.
	if virtual_move.length() <= 0.08:
		velocity.x = 0.0
		velocity.z = 0.0


func _physics_process(delta: float) -> void:
	if water_flight_active:
		_process_water_flight(delta)
		return

	super._physics_process(delta)

	if not in_water and is_on_floor() and global_position.y > water_surface_y + 0.45:
		water_flight_used_since_land = false


func _process_water_flight(delta: float) -> void:
	if _respawning:
		_finish_water_flight()
		return

	_physics_tick_count += 1
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	dodge_cooldown = maxf(0.0, dodge_cooldown - delta)
	invulnerability = maxf(0.0, invulnerability - delta)
	water_flight_remaining = maxf(0.0, water_flight_remaining - delta)

	var input_vector: Vector2 = Input.get_vector(
		"move_left",
		"move_right",
		"move_forward",
		"move_back"
	)
	if virtual_move.length() > 0.08:
		input_vector = virtual_move.limit_length(1.0)

	var forward: Vector3 = Vector3.FORWARD
	var right: Vector3 = Vector3.RIGHT
	if is_instance_valid(_camera):
		forward = -_camera.global_transform.basis.z
		right = _camera.global_transform.basis.x
	forward.y = 0.0
	right.y = 0.0
	forward = (
		forward.normalized()
		if forward.length_squared() > 0.0001
		else Vector3.FORWARD
	)
	right = (
		right.normalized()
		if right.length_squared() > 0.0001
		else Vector3.RIGHT
	)

	var direction: Vector3 = right * input_vector.x + forward * -input_vector.y
	if direction.length_squared() > 0.0001:
		direction = direction.normalized()

	var target_horizontal: Vector3 = direction * water_flight_speed
	velocity.x = move_toward(
		velocity.x,
		target_horizontal.x,
		water_flight_acceleration * delta
	)
	velocity.z = move_toward(
		velocity.z,
		target_horizontal.z,
		water_flight_acceleration * delta
	)

	var height_error: float = _flight_target_y - global_position.y
	var target_vertical: float = clampf(height_error * 2.2, -2.2, 6.8)
	velocity.y = move_toward(
		velocity.y,
		target_vertical,
		water_flight_acceleration * delta
	)

	if is_instance_valid(_visual) and direction.length_squared() > 0.01:
		_visual.rotation.y = lerp_angle(
			_visual.rotation.y,
			atan2(-direction.x, -direction.z),
			minf(1.0, 9.0 * delta)
		)

	if Input.is_action_just_pressed("attack"):
		attack()
	if Input.is_action_just_pressed("interact"):
		interact()

	_last_position_before_slide = global_position
	move_and_slide()
	_last_position_after_slide = global_position
	_last_slide_count = get_slide_collision_count()

	if (
		is_on_floor()
		and global_position.y > water_surface_y + 0.45
		and water_flight_remaining < water_flight_duration - 0.25
	):
		last_safe_ground_position = global_position
		_finish_water_flight()
		return

	if water_flight_remaining <= 0.0:
		_finish_water_flight()
		return

	if global_position.y < water_bottom_y - 0.35:
		_finish_water_flight()
		_respawn()
		return

	if is_instance_valid(_model_animator):
		var horizontal_speed: float = Vector2(velocity.x, velocity.z).length()
		_model_animator.set_locomotion(
			horizontal_speed / maxf(water_flight_speed, 0.01),
			true
		)

	water_flight_changed.emit(true, water_flight_remaining)


func _finish_water_flight() -> void:
	if not water_flight_active:
		return
	water_flight_active = false
	water_flight_remaining = 0.0
	water_flight_changed.emit(false, 0.0)
