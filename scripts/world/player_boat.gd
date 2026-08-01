class_name PlayerBoat
extends CharacterBody3D

signal boarding_changed(boarded: bool, boat: PlayerBoat)

@export var max_speed: float = 12.0
@export var acceleration: float = 7.0
@export var turn_speed: float = 1.35

var player: PlayerController
var water_height: float = -0.82
var boarded: bool = false
var virtual_move: Vector2 = Vector2.ZERO

var _visual: Node3D
var _wake_left: MeshInstance3D
var _wake_right: MeshInstance3D
var _forward_speed: float = 0.0
var _base_water_height: float = -0.82
var _saved_collision_layer: int = 1
var _saved_collision_mask: int = 1


func setup(player_node: PlayerController, asset_path: String, initial_water_height: float) -> void:
	player = player_node
	water_height = initial_water_height
	_base_water_height = initial_water_height
	_build_body(asset_path)
	position.y = water_height


func _physics_process(delta: float) -> void:
	var seconds = Time.get_ticks_msec() * 0.001
	water_height = _base_water_height + sin(seconds * 1.15 + float(get_instance_id() % 11)) * 0.07
	position.y = lerpf(position.y, water_height, minf(1.0, delta * 3.0))
	_visual.rotation.z = sin(seconds * 0.82) * 0.025
	_visual.rotation.x = cos(seconds * 0.63) * 0.018

	if boarded:
		var throttle = clampf(-virtual_move.y, -0.55, 1.0)
		var steering = virtual_move.x
		_forward_speed = move_toward(_forward_speed, throttle * max_speed, acceleration * delta)
		var steering_strength = 0.35 + minf(absf(_forward_speed) / max_speed, 1.0)
		rotation.y -= steering * turn_speed * steering_strength * delta
		var forward = -global_transform.basis.z
		velocity.x = forward.x * _forward_speed
		velocity.z = forward.z * _forward_speed
		velocity.y = 0.0
		move_and_slide()
		global_position.x = clampf(global_position.x, -442.0, 442.0)
		global_position.z = clampf(global_position.z, -317.0, 317.0)
		_sync_player_on_deck()
	else:
		_forward_speed = move_toward(_forward_speed, 0.0, acceleration * 0.55 * delta)
		velocity.x = move_toward(velocity.x, 0.0, acceleration * delta)
		velocity.z = move_toward(velocity.z, 0.0, acceleration * delta)

	_update_wake()


func set_virtual_move(value: Vector2) -> void:
	virtual_move = value.limit_length(1.0)


func can_board(player_position: Vector3, max_distance: float = 5.5) -> bool:
	return not boarded and global_position.distance_to(player_position) <= max_distance


func board() -> bool:
	if boarded or not is_instance_valid(player):
		return false
	boarded = true
	_saved_collision_layer = player.collision_layer
	_saved_collision_mask = player.collision_mask
	player.collision_layer = 0
	player.collision_mask = 0
	player.can_control = false
	player.velocity = Vector3.ZERO
	player.set_physics_process(false)
	_sync_player_on_deck()
	boarding_changed.emit(true, self)
	return true


func disembark() -> bool:
	if not boarded or not is_instance_valid(player):
		return false
	boarded = false
	virtual_move = Vector2.ZERO
	player.global_position = global_position + global_transform.basis.x * 2.6 + Vector3(0.0, 0.45, 0.0)
	player.rotation.y = rotation.y
	player.collision_layer = _saved_collision_layer
	player.collision_mask = _saved_collision_mask
	player.set_physics_process(true)
	player.can_control = true
	player.velocity = Vector3.ZERO
	boarding_changed.emit(false, self)
	return true


func _sync_player_on_deck() -> void:
	if not boarded or not is_instance_valid(player):
		return
	player.global_position = global_position + Vector3(0.0, 1.18, 0.0)
	player.rotation.y = rotation.y


func _build_body(asset_path: String) -> void:
	var collider = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(2.5, 1.1, 5.8)
	collider.shape = shape
	collider.position.y = 0.55
	add_child(collider)

	_visual = Node3D.new()
	_visual.name = "BateauVisible"
	add_child(_visual)

	if ResourceLoader.exists(asset_path):
		var resource = load(asset_path)
		if resource is PackedScene:
			var model = resource.instantiate()
			if model is Node3D:
				_visual.add_child(model)
				return

	_build_fallback_boat()


func _build_fallback_boat() -> void:
	var wood = _material(Color(0.24, 0.075, 0.018))
	var trim = _material(Color(0.48, 0.20, 0.055))
	var sail = _material(Color(0.78, 0.72, 0.56))
	_add_box(_visual, "Coque", Vector3(2.5, 0.85, 5.8), Vector3(0.0, 0.55, 0.0), wood)
	_add_box(_visual, "Pont", Vector3(2.25, 0.18, 5.25), Vector3(0.0, 1.02, 0.0), trim)
	_add_box(_visual, "Mât", Vector3(0.16, 4.2, 0.16), Vector3(0.0, 3.15, 0.0), trim)
	_add_box(_visual, "Voile", Vector3(0.08, 2.7, 2.9), Vector3(0.0, 3.45, -0.05), sail)


func _update_wake() -> void:
	var wake_visible = boarded and absf(_forward_speed) > 1.0
	if not is_instance_valid(_wake_left):
		_wake_left = _create_wake("SillageGauche", -0.78)
		_wake_right = _create_wake("SillageDroit", 0.78)
	_wake_left.visible = wake_visible
	_wake_right.visible = wake_visible
	if wake_visible:
		var wake_length = 2.0 + absf(_forward_speed) * 0.38
		_wake_left.scale.z = wake_length
		_wake_right.scale.z = wake_length


func _create_wake(node_name: String, x_position: float) -> MeshInstance3D:
	var wake = MeshInstance3D.new()
	wake.name = node_name
	var mesh = BoxMesh.new()
	mesh.size = Vector3(0.14, 0.035, 1.0)
	var wake_material = _material(Color(0.82, 0.94, 1.0, 0.68))
	wake_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material = wake_material
	wake.mesh = mesh
	wake.position = Vector3(x_position, 0.10, 3.4)
	_visual.add_child(wake)
	return wake


func _add_box(parent: Node3D, node_name: String, size: Vector3, local_position: Vector3, material: StandardMaterial3D) -> void:
	var mesh_instance = MeshInstance3D.new()
	mesh_instance.name = node_name
	var mesh = BoxMesh.new()
	mesh.size = size
	mesh.material = material
	mesh_instance.mesh = mesh
	mesh_instance.position = local_position
	parent.add_child(mesh_instance)


func _material(color: Color) -> StandardMaterial3D:
	var result = StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = 0.76
	return result
