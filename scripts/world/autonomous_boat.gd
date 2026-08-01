class_name AutonomousBoat
extends CharacterBody3D

var route: Array[Vector3] = []
var route_index: int = 0
var cruise_speed: float = 4.0
var _visual: Node3D
var _base_water_height: float = -0.82
var _wake: MeshInstance3D


func setup(asset_path: String, defined_route: Array, speed: float = 4.0) -> void:
	route.clear()
	for route_point in defined_route:
		if route_point is Vector3:
			route.append(route_point)
	cruise_speed = speed
	if route.is_empty():
		return
	global_position = route[0]
	_base_water_height = route[0].y
	_build_body(asset_path)


func _physics_process(delta: float) -> void:
	if route.size() < 2:
		return
	var target = route[route_index]
	var flat_delta = target - global_position
	flat_delta.y = 0.0
	if flat_delta.length() < 3.0:
		route_index = (route_index + 1) % route.size()
		target = route[route_index]
		flat_delta = target - global_position
		flat_delta.y = 0.0
	if flat_delta.length_squared() > 0.01:
		var direction = flat_delta.normalized()
		rotation.y = lerp_angle(rotation.y, atan2(-direction.x, -direction.z), minf(1.0, delta * 1.8))
		velocity = direction * cruise_speed
		var collision = move_and_collide(velocity * delta)
		if collision != null:
			route_index = (route_index + 1) % route.size()
	var seconds = Time.get_ticks_msec() * 0.001
	global_position.y = _base_water_height + sin(seconds * 0.9 + float(get_instance_id() % 7)) * 0.07
	_visual.rotation.z = sin(seconds * 0.74) * 0.022
	_visual.rotation.x = cos(seconds * 0.61) * 0.016


func _build_body(asset_path: String) -> void:
	var collision = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(2.3, 1.0, 5.4)
	collision.shape = shape
	collision.position.y = 0.5
	add_child(collision)

	_visual = Node3D.new()
	_visual.name = "NavireVisible"
	add_child(_visual)
	if ResourceLoader.exists(asset_path):
		var packed = load(asset_path)
		if packed is PackedScene:
			var model = packed.instantiate()
			if model is Node3D:
				_visual.add_child(model)
				_build_wake()
				return
	_build_fallback()
	_build_wake()


func _build_fallback() -> void:
	var wood = _material(Color(0.25, 0.085, 0.025))
	var sail = _material(Color(0.68, 0.14, 0.08))
	_add_box("Coque", Vector3(2.3, 0.78, 5.4), Vector3(0.0, 0.48, 0.0), wood)
	_add_box("Mât", Vector3(0.14, 3.7, 0.14), Vector3(0.0, 2.65, 0.0), wood)
	_add_box("Voile", Vector3(0.06, 2.3, 2.6), Vector3(0.0, 2.9, 0.0), sail)


func _build_wake() -> void:
	_wake = MeshInstance3D.new()
	_wake.name = "Sillage"
	var mesh = BoxMesh.new()
	mesh.size = Vector3(1.5, 0.025, 4.2)
	var foam = _material(Color(0.78, 0.93, 1.0, 0.54))
	foam.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material = foam
	_wake.mesh = mesh
	_wake.position = Vector3(0.0, 0.04, 3.8)
	_visual.add_child(_wake)


func _add_box(node_name: String, size: Vector3, local_position: Vector3, material: StandardMaterial3D) -> void:
	var instance = MeshInstance3D.new()
	instance.name = node_name
	var mesh = BoxMesh.new()
	mesh.size = size
	mesh.material = material
	instance.mesh = mesh
	instance.position = local_position
	_visual.add_child(instance)


func _material(color: Color) -> StandardMaterial3D:
	var result = StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = 0.76
	return result
