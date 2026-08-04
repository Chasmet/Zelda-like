extends "res://scripts/main_supercontinent_world.gd"

func _decorate_super_region(zone_index: int) -> void:
	match zone_index:
		0: _decorate_super_volcano(zone_index)
		1: _decorate_super_forest(zone_index)
		2: _decorate_super_ice(zone_index)
		3: _decorate_super_desert(zone_index)
		4: _decorate_super_marsh(zone_index)
		5: _decorate_super_ruins(zone_index)
		6: _decorate_super_pirate_coast(zone_index)
		7: _decorate_super_village(zone_index)
		8: _decorate_super_capital(zone_index)
		9: _decorate_super_highlands(zone_index)

func _decorate_super_volcano(zone_index: int) -> void:
	var center: Vector3 = SUPER_ZONE_CENTERS[zone_index]
	_add_disc(Vector3(center.x, _super_height(center.x, center.z) + 0.4, center.z), 8.0, Color(0.96, 0.09, 0.01), Color(1.0, 0.03, 0.0))
	for index in range(30):
		var angle := TAU * float(index) / 30.0
		var radius := 28.0 + float(index % 5) * 7.0
		_super_add_rock(Vector3(center.x + cos(angle) * radius, 0.0, center.z + sin(angle) * radius), Vector3(2.4, 3.0 + float(index % 4), 2.3), Color(0.10, 0.08, 0.07))

func _decorate_super_forest(zone_index: int) -> void:
	var center: Vector3 = SUPER_ZONE_CENTERS[zone_index]
	for index in range(72):
		var x := center.x - 66.0 + float((index * 37) % 133)
		var z := center.z - 55.0 + float((index * 53) % 111)
		var path_z := center.z + sin((x - center.x) * 0.045) * 15.0
		if absf(z - path_z) < 7.5:
			continue
		_spawn_super_model(TREE_MODEL, Vector3(x, _super_height(x, z), z), Vector3.ONE * (0.72 + float(index % 6) * 0.065), Vector3(0.0, float(index) * 0.49, 0.0))

func _decorate_super_ice(zone_index: int) -> void:
	var center: Vector3 = SUPER_ZONE_CENTERS[zone_index]
	for index in range(32):
		var angle := TAU * float(index) / 32.0
		var radius := 18.0 + float(index % 7) * 7.0
		_super_add_crystal(Vector3(center.x + cos(angle) * radius, 0.0, center.z + sin(angle) * radius), 1.4 + float(index % 5) * 0.32, Color(0.48, 0.86, 1.0))

func _decorate_super_desert(zone_index: int) -> void:
	var center: Vector3 = SUPER_ZONE_CENTERS[zone_index]
	for index in range(24):
		var x := center.x - 64.0 + float((index * 41) % 129)
		var z := center.z - 52.0 + float((index * 29) % 105)
		_super_add_rock(Vector3(x, 0.0, z), Vector3(2.5 + float(index % 4), 1.6 + float(index % 3), 2.4), Color(0.52, 0.31, 0.14))
	_spawn_super_model(RUIN_MODEL, _ground_point(center + Vector3(-26.0, 0.0, 14.0)), Vector3.ONE * 1.7, Vector3(0.0, -0.5, 0.0))

func _decorate_super_marsh(zone_index: int) -> void:
	var center: Vector3 = SUPER_ZONE_CENTERS[zone_index]
	for index in range(40):
		var x := center.x - 64.0 + float((index * 43) % 129)
		var z := center.z - 52.0 + float((index * 31) % 105)
		_spawn_super_model(TREE_MODEL, Vector3(x, _super_height(x, z), z), Vector3(0.50, 0.78 + float(index % 4) * 0.08, 0.50), Vector3(0.0, float(index) * 0.67, 0.0))

func _decorate_super_ruins(zone_index: int) -> void:
	var center: Vector3 = SUPER_ZONE_CENTERS[zone_index]
	_spawn_super_model(RUIN_MODEL, _ground_point(center + Vector3(0.0, 0.0, -18.0)), Vector3.ONE * 2.0, Vector3.ZERO)
	for offset in [Vector3(-44.0, 0.0, -30.0), Vector3(44.0, 0.0, -30.0), Vector3(-44.0, 0.0, 30.0), Vector3(44.0, 0.0, 30.0)]:
		_super_add_column(center + offset, 7.0)

func _decorate_super_pirate_coast(zone_index: int) -> void:
	var center: Vector3 = SUPER_ZONE_CENTERS[zone_index]
	_spawn_super_model(BOAT_MODEL, Vector3(-318.0, WATER_SURFACE_Y + 0.42, center.z - 8.0), Vector3.ONE * 1.5, Vector3(0.0, -0.35, 0.0))
	for index in range(24):
		var z := center.z - 58.0 + float(index) * 5.0
		_super_add_rock(Vector3(-292.0 + float(index % 3) * 4.0, 0.0, z), Vector3(2.2, 1.4 + float(index % 4), 2.0), Color(0.27, 0.28, 0.26))

func _decorate_super_village(zone_index: int) -> void:
	var center: Vector3 = SUPER_ZONE_CENTERS[zone_index]
	for offset in [Vector3(-42.0, 0.0, -25.0), Vector3(0.0, 0.0, -31.0), Vector3(42.0, 0.0, -24.0), Vector3(-36.0, 0.0, 27.0), Vector3(36.0, 0.0, 27.0)]:
		_spawn_super_model(HOUSE_MODEL, _ground_point(center + offset), Vector3.ONE * 1.12, Vector3(0.0, offset.x * 0.015, 0.0))
	for index in range(28):
		var angle := TAU * float(index) / 28.0
		var radius := 48.0 + float(index % 4) * 5.0
		var x := center.x + cos(angle) * radius
		var z := center.z + sin(angle) * radius
		_spawn_super_model(TREE_MODEL, Vector3(x, _super_height(x, z), z), Vector3.ONE * 0.86, Vector3(0.0, angle, 0.0))

func _decorate_super_capital(zone_index: int) -> void:
	var center: Vector3 = SUPER_ZONE_CENTERS[zone_index]
	_spawn_super_model(RUIN_MODEL, _ground_point(center + Vector3(0.0, 0.0, -21.0)), Vector3.ONE * 2.15, Vector3.ZERO)
	for x_offset in [-50.0, -25.0, 25.0, 50.0]:
		_super_add_tower(center + Vector3(x_offset, 0.0, -42.0), 9.0)
	for offset in [Vector3(-45.0, 0.0, 27.0), Vector3(45.0, 0.0, 27.0), Vector3(-18.0, 0.0, 42.0), Vector3(18.0, 0.0, 42.0)]:
		_spawn_super_model(HOUSE_MODEL, _ground_point(center + offset), Vector3.ONE, Vector3(0.0, PI, 0.0))

func _decorate_super_highlands(zone_index: int) -> void:
	var center: Vector3 = SUPER_ZONE_CENTERS[zone_index]
	_spawn_super_model(RUIN_MODEL, _ground_point(center + Vector3(0.0, 0.0, -24.0)), Vector3.ONE * 2.2, Vector3.ZERO)
	for index in range(36):
		var angle := TAU * float(index) / 36.0
		var radius := 22.0 + float(index % 6) * 7.0
		_super_add_crystal(Vector3(center.x + cos(angle) * radius, 0.0, center.z + sin(angle) * radius), 1.2 + float(index % 5) * 0.32, Color(0.76, 0.94, 1.0))

func _build_routes() -> void:
	var links = [
		[7, 6], [6, 8], [8, 4], [7, 5], [5, 9],
		[6, 1], [1, 0], [1, 2], [2, 3], [3, 4], [8, 9], [5, 8]
	]
	for link in links:
		_add_ground_route(int(link[0]), int(link[1]), 7.0)
	_add_forest_path()

func _add_ground_route(zone_a: int, zone_b: int, width: float) -> void:
	var start: Vector3 = SUPER_ZONE_CENTERS[zone_a]
	var finish: Vector3 = SUPER_ZONE_CENTERS[zone_b]
	var distance := Vector2(finish.x - start.x, finish.z - start.z).length()
	var segment_count := maxi(2, int(ceil(distance / 12.0)))
	var previous := start
	for index in range(1, segment_count + 1):
		var point := start.lerp(finish, float(index) / float(segment_count))
		var midpoint := (previous + point) * 0.5
		var delta := point - previous
		var ground_y := _super_height(midpoint.x, midpoint.z)
		var road_y := ground_y + 0.10
		var is_bridge := ground_y < WATER_SURFACE_Y + 0.15
		if is_bridge:
			road_y = WATER_SURFACE_Y + 0.34
		var size := Vector3(width, 0.28 if is_bridge else 0.08, delta.length() + 0.75)
		var road = _static_box("ContinentBridge", size, Vector3(midpoint.x, road_y, midpoint.z), Color(0.43, 0.32, 0.20)) if is_bridge else _visual_box("ContinentRoad", size, Vector3(midpoint.x, road_y, midpoint.z), Color(0.46, 0.34, 0.21))
		road.rotation.y = atan2(delta.x, delta.z)
		previous = point

func _add_forest_path() -> void:
	var center: Vector3 = SUPER_ZONE_CENTERS[1]
	var previous := Vector3(center.x - 65.0, 0.0, center.z)
	for index in range(1, 15):
		var x := center.x - 65.0 + float(index) * 9.3
		var z := center.z + sin((x - center.x) * 0.045) * 15.0
		var point := Vector3(x, 0.0, z)
		var midpoint := (previous + point) * 0.5
		var delta := point - previous
		var path := _visual_box("ForestPath", Vector3(4.2, 0.07, delta.length() + 0.6), Vector3(midpoint.x, _super_height(midpoint.x, midpoint.z) + 0.09, midpoint.z), Color(0.38, 0.27, 0.16))
		path.rotation.y = atan2(delta.x, delta.z)
		previous = point

func _add_super_zone_title(zone_index: int) -> void:
	var center: Vector3 = SUPER_ZONE_CENTERS[zone_index]
	var title_z := center.z - REGION_SIZE.y * 0.38
	var anchor := Node3D.new()
	anchor.name = "SuperZoneTitle%02d" % (zone_index + 1)
	anchor.position = Vector3(center.x, _super_height(center.x, title_z) + 5.0, title_z)
	add_child(anchor)
	_add_world_label(anchor, "ZONE %d — %s" % [zone_index + 1, SUPER_ZONE_NAMES[zone_index]], Vector3.ZERO, ZONE_ACCENT_COLORS[zone_index])

func _spawn_super_model(path: String, position: Vector3, scale_value: Vector3, rotation_value: Vector3) -> Node3D:
	if not ResourceLoader.exists(path):
		return null
	var resource := load(path)
	if not resource is PackedScene:
		return null
	var instance := (resource as PackedScene).instantiate()
	if not instance is Node3D:
		instance.queue_free()
		return null
	var model := instance as Node3D
	model.position = position
	model.scale = scale_value
	model.rotation = rotation_value
	add_child(model)
	return model

func _ground_point(point: Vector3) -> Vector3:
	return Vector3(point.x, _super_height(point.x, point.z) + point.y, point.z)

func _super_add_rock(point: Vector3, scale_value: Vector3, color: Color) -> void:
	var rock := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 1.7
	mesh.material = _material(color)
	rock.mesh = mesh
	rock.position = Vector3(point.x, _super_height(point.x, point.z) + scale_value.y * 0.42, point.z)
	rock.scale = scale_value
	rock.rotation = Vector3(point.z * 0.015, point.x * 0.02, point.x * 0.01)
	add_child(rock)

func _super_add_crystal(point: Vector3, size_value: float, color: Color) -> void:
	var crystal := MeshInstance3D.new()
	var mesh := PrismMesh.new()
	mesh.size = Vector3(size_value, size_value * 3.0, size_value)
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 1.7
	mesh.material = material
	crystal.mesh = mesh
	crystal.position = Vector3(point.x, _super_height(point.x, point.z) + size_value * 1.5, point.z)
	crystal.rotation = Vector3(0.0, point.x * 0.02, 0.08)
	add_child(crystal)

func _super_add_column(point: Vector3, height_value: float) -> void:
	var column := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.75
	mesh.bottom_radius = 0.95
	mesh.height = height_value
	mesh.material = _material(Color(0.68, 0.58, 0.38))
	column.mesh = mesh
	column.position = Vector3(point.x, _super_height(point.x, point.z) + height_value * 0.5, point.z)
	add_child(column)

func _super_add_tower(point: Vector3, height_value: float) -> void:
	_static_box("CapitalTower", Vector3(5.5, height_value, 5.5), Vector3(point.x, _super_height(point.x, point.z) + height_value * 0.5, point.z), Color(0.20, 0.19, 0.22))
