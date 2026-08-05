extends "res://scripts/player_yvane.gd"

# V6.1 : assistance physique de sortie d'eau. Le héros grimpe sur une berge
# lorsqu'il nage vers elle près de la surface, au lieu de rester bloqué contre
# le collider du terrain.
@export var shore_probe_distance: float = 6.5
@export var shore_max_step_height: float = 3.6
@export var shore_exit_forward_speed: float = 3.2
@export var shore_exit_up_speed: float = 3.6

var _shore_exit_cooldown: float = 0.0


func _physics_process(delta: float) -> void:
	_shore_exit_cooldown = maxf(0.0, _shore_exit_cooldown - delta)
	super._physics_process(delta)
	if _shore_exit_cooldown > 0.0 or not in_water or not can_control:
		return
	if global_position.y < water_surface_y - 1.05:
		return

	var input_vector: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if virtual_move.length() > 0.08:
		input_vector = virtual_move.limit_length(1.0)
	if input_vector.length() <= 0.10:
		return

	var direction := _camera_relative_direction(input_vector)
	if direction.length_squared() <= 0.01:
		return

	# Le rayon central et deux rayons latéraux permettent de sortir même lorsque
	# la berge n'est pas parfaitement perpendiculaire au joueur.
	for angle: float in [0.0, -0.36, 0.36, -0.68, 0.68]:
		var candidate := direction.rotated(Vector3.UP, angle)
		if _try_exit_water(candidate):
			return


func _camera_relative_direction(input_vector: Vector2) -> Vector3:
	var forward: Vector3 = Vector3.FORWARD
	var right: Vector3 = Vector3.RIGHT
	if is_instance_valid(_camera):
		forward = -_camera.global_transform.basis.z
		right = _camera.global_transform.basis.x
	forward.y = 0.0
	right.y = 0.0
	forward = forward.normalized() if forward.length_squared() > 0.0001 else Vector3.FORWARD
	right = right.normalized() if right.length_squared() > 0.0001 else Vector3.RIGHT
	var direction := right * input_vector.x + forward * -input_vector.y
	return direction.normalized() if direction.length_squared() > 0.0001 else Vector3.ZERO


func _try_exit_water(direction: Vector3) -> bool:
	if get_world_3d() == null:
		return false
	for distance: float in [1.50, 3.00, 4.80, shore_probe_distance]:
		var target := global_position + direction * distance
		var ray_from := Vector3(target.x, water_surface_y + shore_max_step_height + 1.2, target.z)
		var ray_to := Vector3(target.x, water_surface_y - 1.15, target.z)
		var query := PhysicsRayQueryParameters3D.create(ray_from, ray_to, 1)
		query.exclude = [get_rid()]
		query.collide_with_areas = false
		query.collide_with_bodies = true
		var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty():
			continue
		var hit_position: Vector3 = hit.get("position", ray_to)
		if hit_position.y < water_surface_y - 0.08:
			continue
		if hit_position.y > water_surface_y + shore_max_step_height:
			continue
		_finish_shore_exit(hit_position, direction)
		return true
	return false


func _finish_shore_exit(hit_position: Vector3, direction: Vector3) -> void:
	var was_underwater := underwater
	global_position = hit_position + Vector3.UP * 0.10
	velocity = direction * shore_exit_forward_speed
	velocity.y = shore_exit_up_speed
	in_water = false
	underwater = false
	_open_water_column = false
	_water_probe_timer = 0.16
	_swim_vertical_timer = 0.0
	_swim_vertical_override = 0.0
	_shore_exit_cooldown = 0.35
	last_safe_ground_position = global_position
	water_state_changed.emit(false, false)
	if was_underwater:
		oxygen = minf(max_oxygen, oxygen + 0.75)
		_emit_oxygen_if_needed(true)


func get_water_debug() -> Dictionary:
	var result: Dictionary = super.get_water_debug()
	result["shore_exit_cooldown"] = _shore_exit_cooldown
	result["shore_probe_distance"] = shore_probe_distance
	result["shore_max_step_height"] = shore_max_step_height
	return result
