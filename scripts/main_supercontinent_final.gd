extends "res://scripts/main_supercontinent_v10.gd"

# Grande plaine stable autour du village de départ. Le rayon a été adapté à la
# nouvelle région de 500 x 430 m afin que le village, les maisons et les routes
# ne soient plus posés sur une petite bosse côtière.
func _super_height(world_x: float, world_z: float) -> float:
	var base_height: float = super._super_height(world_x, world_z)
	var village_center: Vector3 = SUPER_ZONE_CENTERS[START_ZONE]
	var distance: float = Vector2(world_x - village_center.x, world_z - village_center.z).length()
	if distance >= 165.0:
		return base_height
	var flat_height := 2.10
	var blend := 1.0 - smoothstep(82.0, 165.0, distance)
	return lerpf(base_height, flat_height, blend)


# HeightMap Android optimisé : cellules de 4 m sur le continent de 2,2 x 1,7 km.
# Le relief visuel reste détaillé, mais le nombre d'échantillons physiques est
# divisé par quatre par rapport à une grille de 2 m.
func _build_supercontinent_terrain() -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.90
	material.metallic = 0.01
	surface.set_material(material)

	var step_x := CONTINENT_SIZE.x / float(TERRAIN_STEPS_X)
	var step_z := CONTINENT_SIZE.y / float(TERRAIN_STEPS_Z)
	for z_index in range(TERRAIN_STEPS_Z):
		for x_index in range(TERRAIN_STEPS_X):
			var x0 := -CONTINENT_HALF.x + float(x_index) * step_x
			var x1 := x0 + step_x
			var z0 := -CONTINENT_HALF.y + float(z_index) * step_z
			var z1 := z0 + step_z
			var p00 := Vector3(x0, _super_height(x0, z0), z0)
			var p10 := Vector3(x1, _super_height(x1, z0), z0)
			var p01 := Vector3(x0, _super_height(x0, z1), z1)
			var p11 := Vector3(x1, _super_height(x1, z1), z1)
			_add_colored_triangle(surface, p00, p01, p11)
			_add_colored_triangle(surface, p00, p11, p10)

	surface.generate_normals()
	var mesh: ArrayMesh = surface.commit()
	var terrain := StaticBody3D.new()
	terrain.name = "SupercontinentTerrain"
	terrain.collision_layer = 1
	terrain.collision_mask = 1

	var visual := MeshInstance3D.new()
	visual.name = "SupercontinentVisual"
	visual.mesh = mesh
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	terrain.add_child(visual)

	const COLLISION_STEP := 4.0
	var collision_width := int(round(CONTINENT_SIZE.x / COLLISION_STEP)) + 1
	var collision_depth := int(round(CONTINENT_SIZE.y / COLLISION_STEP)) + 1
	var half_width := float(collision_width - 1) * COLLISION_STEP * 0.5
	var half_depth := float(collision_depth - 1) * COLLISION_STEP * 0.5
	var heights := PackedFloat32Array()
	heights.resize(collision_width * collision_depth)
	var data_index := 0
	for depth_index in range(collision_depth):
		var world_z := -half_depth + float(depth_index) * COLLISION_STEP
		for width_index in range(collision_width):
			var world_x := -half_width + float(width_index) * COLLISION_STEP
			heights[data_index] = _super_height(world_x, world_z) / COLLISION_STEP
			data_index += 1

	var height_shape := HeightMapShape3D.new()
	height_shape.map_width = collision_width
	height_shape.map_depth = collision_depth
	height_shape.map_data = heights
	var collision := CollisionShape3D.new()
	collision.name = "SupercontinentHeightMap"
	collision.shape = height_shape
	collision.scale = Vector3.ONE * COLLISION_STEP
	terrain.add_child(collision)
	add_child(terrain)


# Les quatre GLB exacts sont répartis dans quatre régions différentes et posés
# sur le relief. Ils gardent leurs matériaux, proportions et détails d'origine.
func _spawn_imported_boss(zone_index: int, spec: Dictionary) -> void:
	var enemy = IMPORTED_ENEMY_SCRIPT.new()
	var boss_id := String(spec["node"])
	var boss_asset := String(spec["asset"])
	enemy.name = boss_id
	enemy.set("visual_height", float(spec["height"]))
	var center: Vector3 = SUPER_ZONE_CENTERS[zone_index]
	var angle := 0.72 + float(zone_index) * 0.61
	var radius := 92.0 + float(zone_index % 3) * 16.0
	var world_x := center.x + cos(angle) * radius
	var world_z := center.z + sin(angle) * radius
	enemy.position = Vector3(world_x, _super_height(world_x, world_z) + 1.10, world_z)
	enemy.set_meta("zone_index", zone_index)
	enemy.set_meta("boss_id", boss_id)
	enemy.set_meta("boss_asset", boss_asset)
	enemy.set_meta("uses_original_glb", true)
	enemy.set_meta("animation_enabled", true)
	add_child(enemy)
	spawned_bosses[boss_id] = enemy
	enemy.setup(player, zone_index + 2, boss_asset)
	enemy.max_health = int(spec["health"])
	enemy.health = enemy.max_health
	enemy.damage = int(spec["damage"])
	enemy.move_speed = float(spec["speed"])
	enemy.aggro_range = 46.0
	enemy.attack_range = 2.55
	enemy.spawn_position = enemy.global_position
	enemy.defeated.connect(_on_enemy_defeated)
	enemies.append(enemy)
	if enemy.has_method("_update_health_label"):
		enemy.call("_update_health_label")
	_add_character_name_label(enemy, String(spec["title"]), float(spec["height"]) + 0.65)
	var aura_color: Color = spec["color"]
	_add_boss_aura(enemy, aura_color)


func _spawn_generic_guardian(zone_index: int, enemy_index: int) -> void:
	var enemy = GENERIC_ENEMY_SCRIPT.new()
	enemy.name = "Zone_%02d_Gardien_%02d" % [zone_index + 1, enemy_index + 1]
	var center: Vector3 = SUPER_ZONE_CENTERS[zone_index]
	var angle := TAU * float(enemy_index + 1) / 3.0 + 0.8 + float(zone_index) * 0.19
	var radius := 72.0 + float(enemy_index % 2) * 46.0
	var world_x := center.x + cos(angle) * radius
	var world_z := center.z + sin(angle) * radius
	enemy.position = Vector3(world_x, _super_height(world_x, world_z) + 0.55, world_z)
	enemy.set_meta("zone_index", zone_index)
	add_child(enemy)
	var model_index := (zone_index + enemy_index) % ENEMY_MODELS.size()
	enemy.setup(player, model_index, ENEMY_MODELS[model_index])
	enemy.spawn_position = enemy.global_position
	enemy.defeated.connect(_on_enemy_defeated)
	enemies.append(enemy)


# Réseau principal reliant les dix régions, plus routes secondaires et chemins
# forestiers. Les segments sont espacés pour rester légers sur Android.
func _build_routes() -> void:
	var links = [
		[7, 6], [6, 8], [8, 4], [7, 5], [5, 9],
		[6, 1], [1, 0], [1, 2], [2, 3], [3, 4], [8, 9], [5, 8]
	]
	for link in links:
		var zone_a := int(link[0])
		var zone_b := int(link[1])
		var curve := 36.0 if (zone_a + zone_b) % 2 == 0 else -36.0
		_add_massive_route(SUPER_ZONE_CENTERS[zone_a], SUPER_ZONE_CENTERS[zone_b], 12.0, 34.0, curve)

	for zone_index in range(SUPER_ZONE_CENTERS.size()):
		_add_region_loop(zone_index, 112.0 + float(zone_index % 3) * 18.0)
	_add_forest_path()


func _add_massive_route(start: Vector3, finish: Vector3, width: float, segment_length: float, curve: float = 0.0) -> void:
	var planar_delta := Vector2(finish.x - start.x, finish.z - start.z)
	var distance := planar_delta.length()
	var segment_count := maxi(2, int(ceil(distance / maxf(18.0, segment_length))))
	var perpendicular := Vector2(-planar_delta.y, planar_delta.x).normalized()
	var previous := start
	for index in range(1, segment_count + 1):
		var t := float(index) / float(segment_count)
		var point := start.lerp(finish, t)
		var bend := sin(t * PI) * curve
		point.x += perpendicular.x * bend
		point.z += perpendicular.y * bend
		var midpoint := (previous + point) * 0.5
		var delta := point - previous
		var ground_y := _super_height(midpoint.x, midpoint.z)
		var is_bridge := ground_y < WATER_SURFACE_Y + 0.25
		var road_y := WATER_SURFACE_Y + 0.48 if is_bridge else ground_y + 0.12
		var size := Vector3(width, 0.42 if is_bridge else 0.10, delta.length() + 1.2)
		var road: Node3D
		if is_bridge:
			road = _static_box("ContinentBridge", size, Vector3(midpoint.x, road_y, midpoint.z), Color(0.43, 0.32, 0.20))
		else:
			road = _visual_box("ContinentRoad", size, Vector3(midpoint.x, road_y, midpoint.z), Color(0.46, 0.34, 0.21))
		road.rotation.y = atan2(delta.x, delta.z)
		previous = point


func _add_region_loop(zone_index: int, radius: float) -> void:
	var center: Vector3 = SUPER_ZONE_CENTERS[zone_index]
	var segment_count := 18
	var previous := center + Vector3(radius, 0.0, 0.0)
	for index in range(1, segment_count + 1):
		var angle := TAU * float(index) / float(segment_count)
		var squash := 0.66 + float(zone_index % 2) * 0.08
		var point := center + Vector3(cos(angle) * radius, 0.0, sin(angle) * radius * squash)
		_add_massive_route(previous, point, 6.2, 26.0, 0.0)
		previous = point


func _add_forest_path() -> void:
	var center: Vector3 = SUPER_ZONE_CENTERS[1]
	var previous := Vector3(center.x - 225.0, 0.0, center.z - 36.0)
	for index in range(1, 27):
		var x := center.x - 225.0 + float(index) * 18.0
		var z := center.z + sin((x - center.x) * 0.014) * 62.0
		var point := Vector3(x, 0.0, z)
		_add_massive_route(previous, point, 5.2, 22.0, 0.0)
		previous = point


func _decorate_super_region(zone_index: int) -> void:
	match zone_index:
		0: _decorate_massive_volcano(zone_index)
		1: _decorate_massive_forest(zone_index)
		2: _decorate_massive_ice(zone_index)
		3: _decorate_massive_desert(zone_index)
		4: _decorate_massive_marsh(zone_index)
		5: _decorate_massive_ruins(zone_index)
		6: _decorate_massive_pirate_coast(zone_index)
		7: _decorate_massive_village(zone_index)
		8: _decorate_massive_capital(zone_index)
		9: _decorate_massive_highlands(zone_index)


func _decorate_massive_volcano(zone_index: int) -> void:
	var center: Vector3 = SUPER_ZONE_CENTERS[zone_index]
	_add_disc(Vector3(center.x, _super_height(center.x, center.z) + 0.45, center.z), 18.0, Color(0.96, 0.09, 0.01), Color(1.0, 0.03, 0.0))
	_scatter_rocks(zone_index, 64, 220, 180, Color(0.10, 0.08, 0.07), 2.8)


func _decorate_massive_forest(zone_index: int) -> void:
	_scatter_trees(zone_index, 165, 235, 190, 0.72, 0.065)
	var center: Vector3 = SUPER_ZONE_CENTERS[zone_index]
	for offset in [Vector3(-145.0, 0.0, 90.0), Vector3(135.0, 0.0, -105.0), Vector3(45.0, 0.0, 145.0)]:
		_super_add_rock(center + offset, Vector3(4.0, 3.2, 4.0), Color(0.24, 0.28, 0.20))


func _decorate_massive_ice(zone_index: int) -> void:
	var center: Vector3 = SUPER_ZONE_CENTERS[zone_index]
	for index in range(74):
		var angle := TAU * float(index) / 74.0
		var radius := 48.0 + float((index * 37) % 185)
		_super_add_crystal(Vector3(center.x + cos(angle) * radius, 0.0, center.z + sin(angle) * radius * 0.72), 1.4 + float(index % 6) * 0.34, Color(0.48, 0.86, 1.0))
	_scatter_rocks(zone_index, 32, 230, 180, Color(0.56, 0.64, 0.68), 2.1)


func _decorate_massive_desert(zone_index: int) -> void:
	_scatter_rocks(zone_index, 58, 235, 190, Color(0.52, 0.31, 0.14), 3.0)
	var center: Vector3 = SUPER_ZONE_CENTERS[zone_index]
	_spawn_super_model(RUIN_MODEL, _ground_point(center + Vector3(-90.0, 0.0, 55.0)), Vector3.ONE * 2.4, Vector3(0.0, -0.5, 0.0))


func _decorate_massive_marsh(zone_index: int) -> void:
	_scatter_trees(zone_index, 108, 235, 190, 0.48, 0.055)
	var center: Vector3 = SUPER_ZONE_CENTERS[zone_index]
	for index in range(8):
		var x := center.x - 170.0 + float((index * 71) % 340)
		var z := center.z - 130.0 + float((index * 53) % 260)
		var pool: Node3D = _visual_box("MarshPool", Vector3(34.0 + float(index % 3) * 9.0, 0.04, 22.0 + float(index % 2) * 11.0), Vector3(x, _super_height(x, z) + 0.08, z), Color(0.03, 0.28, 0.23, 0.82))
		pool.rotation.y = float(index) * 0.43


func _decorate_massive_ruins(zone_index: int) -> void:
	var center: Vector3 = SUPER_ZONE_CENTERS[zone_index]
	_spawn_super_model(RUIN_MODEL, _ground_point(center + Vector3(0.0, 0.0, -54.0)), Vector3.ONE * 2.8, Vector3.ZERO)
	for x_offset in [-170.0, -85.0, 85.0, 170.0]:
		var height_variant := int(int(absf(x_offset)) / 85.0) % 3
		for z_offset in [-118.0, 118.0]:
			_super_add_column(center + Vector3(x_offset, 0.0, z_offset), 8.0 + float(height_variant))
	_scatter_rocks(zone_index, 36, 220, 175, Color(0.48, 0.42, 0.30), 2.2)


func _decorate_massive_pirate_coast(zone_index: int) -> void:
	var center: Vector3 = SUPER_ZONE_CENTERS[zone_index]
	_spawn_super_model(BOAT_MODEL, Vector3(-1090.0, WATER_SURFACE_Y + 0.42, center.z - 35.0), Vector3.ONE * 2.1, Vector3(0.0, -0.35, 0.0))
	for index in range(42):
		var z := center.z - 205.0 + float(index) * 10.0
		_super_add_rock(Vector3(-1010.0 + float(index % 4) * 9.0, 0.0, z), Vector3(2.5, 1.8 + float(index % 5), 2.4), Color(0.27, 0.28, 0.26))
	_scatter_trees(zone_index, 42, 210, 175, 0.62, 0.05)


func _decorate_massive_village(zone_index: int) -> void:
	var center: Vector3 = SUPER_ZONE_CENTERS[zone_index]
	var house_offsets = [
		Vector3(-118.0, 0.0, -62.0), Vector3(-58.0, 0.0, -88.0), Vector3(0.0, 0.0, -102.0), Vector3(62.0, 0.0, -84.0), Vector3(124.0, 0.0, -55.0),
		Vector3(-135.0, 0.0, 44.0), Vector3(-72.0, 0.0, 78.0), Vector3(0.0, 0.0, 92.0), Vector3(74.0, 0.0, 76.0), Vector3(138.0, 0.0, 40.0)
	]
	for offset in house_offsets:
		_spawn_super_model(HOUSE_MODEL, _ground_point(center + offset), Vector3.ONE * 1.18, Vector3(0.0, offset.x * 0.008, 0.0))
	_scatter_trees(zone_index, 62, 225, 185, 0.72, 0.055)


func _decorate_massive_capital(zone_index: int) -> void:
	var center: Vector3 = SUPER_ZONE_CENTERS[zone_index]
	_spawn_super_model(RUIN_MODEL, _ground_point(center + Vector3(0.0, 0.0, -72.0)), Vector3.ONE * 3.0, Vector3.ZERO)
	for x_offset in [-150.0, -90.0, -30.0, 30.0, 90.0, 150.0]:
		_super_add_tower(center + Vector3(x_offset, 0.0, -145.0), 10.0 + float(int(absf(x_offset)) % 4))
	for row in range(3):
		for column in range(6):
			var offset := Vector3(-150.0 + float(column) * 60.0, 0.0, 25.0 + float(row) * 62.0)
			_spawn_super_model(HOUSE_MODEL, _ground_point(center + offset), Vector3.ONE * 1.05, Vector3(0.0, PI, 0.0))
	_scatter_trees(zone_index, 38, 225, 185, 0.66, 0.045)


func _decorate_massive_highlands(zone_index: int) -> void:
	var center: Vector3 = SUPER_ZONE_CENTERS[zone_index]
	_spawn_super_model(RUIN_MODEL, _ground_point(center + Vector3(0.0, 0.0, -88.0)), Vector3.ONE * 3.0, Vector3.ZERO)
	for index in range(82):
		var angle := TAU * float(index) / 82.0
		var radius := 52.0 + float((index * 43) % 205)
		_super_add_crystal(Vector3(center.x + cos(angle) * radius, 0.0, center.z + sin(angle) * radius * 0.72), 1.2 + float(index % 6) * 0.34, Color(0.76, 0.94, 1.0))
	_scatter_rocks(zone_index, 42, 225, 180, Color(0.40, 0.43, 0.44), 2.4)


func _scatter_trees(zone_index: int, count: int, span_x: int, span_z: int, scale_min: float, scale_step: float) -> void:
	var center: Vector3 = SUPER_ZONE_CENTERS[zone_index]
	for index in range(count):
		var x_offset := -float(span_x) + float((index * 137 + zone_index * 53) % (span_x * 2 + 1))
		var z_offset := -float(span_z) + float((index * 191 + zone_index * 71) % (span_z * 2 + 1))
		var x := center.x + x_offset
		var z := center.z + z_offset
		if _near_internal_river(x, z, 43.0):
			continue
		if Vector2(x_offset, z_offset).length() < 48.0:
			continue
		var scale_value := scale_min + float(index % 7) * scale_step
		_spawn_super_model(TREE_MODEL, Vector3(x, _super_height(x, z), z), Vector3.ONE * scale_value, Vector3(0.0, float(index) * 0.47, 0.0))


func _scatter_rocks(zone_index: int, count: int, span_x: int, span_z: int, color: Color, base_size: float) -> void:
	var center: Vector3 = SUPER_ZONE_CENTERS[zone_index]
	for index in range(count):
		var x_offset := -float(span_x) + float((index * 149 + zone_index * 47) % (span_x * 2 + 1))
		var z_offset := -float(span_z) + float((index * 173 + zone_index * 83) % (span_z * 2 + 1))
		var x := center.x + x_offset
		var z := center.z + z_offset
		if _near_internal_river(x, z, 34.0):
			continue
		var size := base_size + float(index % 4) * 0.65
		_super_add_rock(Vector3(x, 0.0, z), Vector3(size, size * (0.75 + float(index % 3) * 0.18), size * 0.88), color)


func _near_internal_river(world_x: float, world_z: float, margin: float) -> bool:
	return absf(world_x - _river_one_x(world_z)) < margin or absf(world_z - _river_two_z(world_x)) < margin


func _add_map_river(north_south: bool) -> void:
	var line := Line2D.new()
	line.width = 5.0
	line.default_color = Color(0.20, 0.70, 0.96)
	var points := PackedVector2Array()
	for index in range(41):
		var t := float(index) / 40.0
		if north_south:
			var z := lerpf(-CONTINENT_HALF.y + 95.0, CONTINENT_HALF.y - 95.0, t)
			points.append(_world_to_map(Vector3(_river_one_x(z), 0.0, z)))
		else:
			var x := lerpf(-CONTINENT_HALF.x + 110.0, CONTINENT_HALF.x - 110.0, t)
			points.append(_world_to_map(Vector3(x, 0.0, _river_two_z(x))))
	line.points = points
	map_frame.add_child(line)


func get_ci_water_points() -> Dictionary:
	var shore_land := Vector3(-980.0, 0.0, 240.0)
	shore_land.y = _super_height(shore_land.x, shore_land.z) + 0.75
	var shore_water := Vector3(-1190.0, WATER_SURFACE_Y - 1.15, 240.0)
	var river_x := 0.0
	var river_z := _river_two_z(river_x)
	var river_water := Vector3(river_x, WATER_SURFACE_Y - 1.15, river_z)
	var deep_water := Vector3(0.0, WATER_SURFACE_Y - 1.15, 970.0)
	return {
		"shore_land": shore_land,
		"shore_water": shore_water,
		"river_water": river_water,
		"deep_water": deep_water
	}


func _process(delta: float) -> void:
	super._process(delta)
	if not is_instance_valid(player):
		return
	if move_touch_id >= 0 or virtual_move.length() > 0.08:
		return
	if Input.is_action_pressed("move_forward") or Input.is_action_pressed("move_back"):
		return
	if Input.is_action_pressed("move_left") or Input.is_action_pressed("move_right"):
		return
	if float(player.get("dodge_cooldown")) > 0.02 or float(player.get("invulnerability")) > 0.02:
		return
	player.velocity.x = 0.0
	player.velocity.z = 0.0


func _release_movement_touch() -> void:
	super._release_movement_touch()
	if not is_instance_valid(player):
		return
	player.velocity.x = 0.0
	player.velocity.z = 0.0
