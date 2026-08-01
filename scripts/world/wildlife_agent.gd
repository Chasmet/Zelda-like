class_name WildlifeAgent
extends CharacterBody3D

var species: String
var habitat: String
var player: Node3D
var habitat_center: Vector3
var habitat_radius: float
var terrain_height: Callable
var region_index: int
var current_weather: String = "clair"
var nocturnal: bool = false

var _target: Vector3
var _decision_timer: float = 0.0
var _speed: float = 2.6
var _visual: Node3D
var _tail_or_wings: Node3D
var _phase: float = 0.0
var _attack_timer: float = 0.0


func setup(species_name: String, habitat_type: String, player_node: Node3D, center: Vector3, radius: float, region: int, height_callable: Callable, spawn_index: int) -> void:
	species = species_name
	habitat = habitat_type
	player = player_node
	habitat_center = center
	habitat_radius = radius
	region_index = region
	terrain_height = height_callable
	nocturnal = species in ["hibou", "chauve-souris", "poisson abyssal"]
	_speed = 2.0 + float(spawn_index % 4) * 0.45
	var angle = TAU * float(spawn_index) / 17.0
	var distance = 7.0 + float(spawn_index % 6) * 4.2
	global_position = center + Vector3(cos(angle) * distance, 0.0, sin(angle) * distance)
	if habitat == "marin":
		global_position.y = -2.5 - float(spawn_index % 7) * 2.8
	elif habitat == "aérien":
		global_position.y = center.y + 7.0 + float(spawn_index % 4) * 2.0
	else:
		global_position.y = _ground_height(global_position.x, global_position.z) + 0.38
	_build_visual()
	_choose_target()


func _physics_process(delta: float) -> void:
	_decision_timer -= delta
	_attack_timer = maxf(0.0, _attack_timer - delta)
	_phase += delta * (4.0 + _speed)
	if _decision_timer <= 0.0:
		_choose_target()

	var distance_to_player = INF
	if is_instance_valid(player):
		distance_to_player = global_position.distance_to(player.global_position)
	var predator = species in ["loup", "ours", "requin"]
	if distance_to_player < 7.0 and not predator:
		var away = global_position - player.global_position
		away.y = 0.0 if habitat == "terrestre" else away.y
		if away.length_squared() > 0.01:
			_target = global_position + away.normalized() * 14.0
	elif predator and distance_to_player < 10.0:
		_target = player.global_position
		if distance_to_player < 1.65 and _attack_timer <= 0.0 and player.has_method("take_damage"):
			_attack_timer = 1.45
			player.call("take_damage", 7, global_position)

	if habitat == "marin":
		_move_marine(delta)
	elif habitat == "aérien":
		_move_flying(delta)
	else:
		_move_land(delta)
	_animate_visual(delta)


func set_weather(weather_id: String) -> void:
	current_weather = weather_id
	if weather_id in ["orage", "blizzard", "cendres", "forte_pluie"]:
		_decision_timer = 0.0


func _move_land(delta: float) -> void:
	var delta_target = _target - global_position
	delta_target.y = 0.0
	if delta_target.length() < 0.8:
		velocity.x = move_toward(velocity.x, 0.0, delta * 8.0)
		velocity.z = move_toward(velocity.z, 0.0, delta * 8.0)
	else:
		var direction = delta_target.normalized()
		var run_factor = 1.7 if is_instance_valid(player) and global_position.distance_to(player.global_position) < 7.0 else 1.0
		velocity.x = direction.x * _speed * run_factor
		velocity.z = direction.z * _speed * run_factor
		_visual.rotation.y = lerp_angle(_visual.rotation.y, atan2(-direction.x, -direction.z), minf(1.0, delta * 7.0))
	if not is_on_floor():
		velocity.y -= 18.0 * delta
	move_and_slide()
	if get_slide_collision_count() > 0:
		_decision_timer = 0.0


func _move_marine(delta: float) -> void:
	var direction = _target - global_position
	if direction.length() < 1.2:
		_choose_target()
		direction = _target - global_position
	if direction.length_squared() > 0.01:
		direction = direction.normalized()
		velocity = direction * _speed
		var collision = move_and_collide(velocity * delta)
		if collision != null:
			var tangent = direction.slide(collision.get_normal()).normalized()
			_target = global_position + tangent * 12.0 + Vector3(0.0, 1.0, 0.0)
			_decision_timer = 2.0
		_visual.look_at(global_position + direction, Vector3.UP)
	global_position.y = clampf(global_position.y, -24.0, -1.8)


func _move_flying(delta: float) -> void:
	var direction = _target - global_position
	if direction.length() < 1.2:
		_choose_target()
		direction = _target - global_position
	if direction.length_squared() > 0.01:
		direction = direction.normalized()
		global_position += direction * _speed * 1.25 * delta
		_visual.look_at(global_position + direction, Vector3.UP)
	global_position.y = maxf(global_position.y, habitat_center.y + 5.0)


func _choose_target() -> void:
	var identity = float(int(get_instance_id()) % 97)
	var time_value = Time.get_ticks_msec() * 0.001
	var angle = fmod(identity * 1.73 + time_value * 0.21, TAU)
	var radius = habitat_radius * (0.35 + fmod(identity * 0.071 + time_value * 0.013, 0.58))
	_target = habitat_center + Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
	if habitat == "marin":
		_target.y = -2.2 - fmod(identity * 1.9 + time_value * 0.17, 20.5)
	elif habitat == "aérien":
		_target.y = habitat_center.y + 6.0 + fmod(identity + time_value * 0.19, 9.0)
	else:
		_target.y = _ground_height(_target.x, _target.z) + 0.35
	_decision_timer = 4.0 + fmod(identity, 5.0)


func _build_visual() -> void:
	var collider = CollisionShape3D.new()
	var collider_shape = SphereShape3D.new()
	collider_shape.radius = 0.42 if habitat == "terrestre" else 0.28
	collider.shape = collider_shape
	collider.position.y = 0.52 if habitat == "terrestre" else 0.0
	add_child(collider)

	_visual = Node3D.new()
	_visual.name = "AnimalVisible"
	add_child(_visual)
	var colors = _species_colors()
	var body_material = _material(colors[0])
	var accent_material = _material(colors[1])

	if habitat == "marin":
		var fish = _sphere("Corps", Vector3.ZERO, Vector3(0.55, 0.24, 0.28), body_material)
		_visual.add_child(fish)
		_tail_or_wings = Node3D.new()
		_tail_or_wings.position = Vector3(0.0, 0.0, 0.48)
		_visual.add_child(_tail_or_wings)
		var tail = _box("Queue", Vector3(0.06, 0.45, 0.42), Vector3.ZERO, accent_material)
		_tail_or_wings.add_child(tail)
	elif habitat == "aérien":
		_visual.add_child(_sphere("Corps", Vector3.ZERO, Vector3(0.34, 0.22, 0.40), body_material))
		_tail_or_wings = Node3D.new()
		_visual.add_child(_tail_or_wings)
		_tail_or_wings.add_child(_box("AileGauche", Vector3(0.72, 0.05, 0.32), Vector3(-0.42, 0.0, 0.0), accent_material))
		_tail_or_wings.add_child(_box("AileDroite", Vector3(0.72, 0.05, 0.32), Vector3(0.42, 0.0, 0.0), accent_material))
	else:
		_visual.add_child(_sphere("Corps", Vector3(0.0, 0.55, 0.0), Vector3(0.54, 0.32, 0.38), body_material))
		_visual.add_child(_sphere("Tête", Vector3(0.0, 0.75, -0.48), Vector3(0.28, 0.24, 0.28), accent_material))
		for leg_x in [-0.33, 0.33]:
			for leg_z in [-0.26, 0.28]:
				_visual.add_child(_box("Patte", Vector3(0.12, 0.48, 0.12), Vector3(leg_x, 0.25, leg_z), body_material))

	var label = Label3D.new()
	label.text = species.capitalize()
	label.position = Vector3(0.0, 1.35 if habitat == "terrestre" else 0.75, 0.0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 18
	label.outline_size = 5
	_visual.add_child(label)


func _animate_visual(delta: float) -> void:
	if habitat == "marin" and is_instance_valid(_tail_or_wings):
		_tail_or_wings.rotation.y = sin(_phase * 1.7) * 0.52
	elif habitat == "aérien" and is_instance_valid(_tail_or_wings):
		_tail_or_wings.scale.y = 0.45 + absf(sin(_phase * 1.4)) * 0.75
	else:
		_visual.position.y = absf(sin(_phase)) * 0.06


func _ground_height(world_x: float, world_z: float) -> float:
	if terrain_height.is_valid():
		return float(terrain_height.call(region_index, world_x, world_z))
	return habitat_center.y


func _species_colors() -> Array[Color]:
	if species in ["cerf", "lapin", "renard", "sanglier", "cheval", "vache", "mouton", "chèvre"]:
		return [Color(0.34, 0.18, 0.07), Color(0.62, 0.42, 0.20)]
	if species in ["loup", "ours", "corbeau", "requin", "poisson abyssal"]:
		return [Color(0.10, 0.12, 0.14), Color(0.27, 0.31, 0.34)]
	if habitat == "marin":
		return [Color(0.04, 0.42, 0.66), Color(0.12, 0.78, 0.72)]
	if habitat == "aérien":
		return [Color(0.58, 0.60, 0.62), Color(0.84, 0.80, 0.64)]
	return [Color(0.18, 0.46, 0.16), Color(0.52, 0.66, 0.22)]


func _sphere(node_name: String, local_position: Vector3, scale_value: Vector3, material: StandardMaterial3D) -> MeshInstance3D:
	var instance = MeshInstance3D.new()
	instance.name = node_name
	var mesh = SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.material = material
	instance.mesh = mesh
	instance.position = local_position
	instance.scale = scale_value
	return instance


func _box(node_name: String, size: Vector3, local_position: Vector3, material: StandardMaterial3D) -> MeshInstance3D:
	var instance = MeshInstance3D.new()
	instance.name = node_name
	var mesh = BoxMesh.new()
	mesh.size = size
	mesh.material = material
	instance.mesh = mesh
	instance.position = local_position
	return instance


func _material(color: Color) -> StandardMaterial3D:
	var result = StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = 0.72
	return result
