extends "res://scripts/main_chk_player.gd"

# V6.1 : grand supercontinent construit à partir de formes et de coordonnées
# déterministes. Les dix régions sont beaucoup plus vastes et ne sont plus
# remplies par une génération pseudo-aléatoire.
const SUPER_ZONE_CENTERS = [
	Vector3(-600.0, 0.0, -360.0), # 1 Forge volcanique
	Vector3(-200.0, 0.0, -360.0), # 2 Forêt des cascades
	Vector3(200.0, 0.0, -360.0),  # 3 Pics de glace
	Vector3(600.0, 0.0, -360.0),  # 4 Désert du colosse
	Vector3(600.0, 0.0, 0.0),     # 5 Marais des ombres
	Vector3(-200.0, 0.0, 360.0),  # 6 Ruines du soleil
	Vector3(-600.0, 0.0, 0.0),    # 7 Côte des pirates
	Vector3(-600.0, 0.0, 360.0),  # 8 Village des sources
	Vector3(-200.0, 0.0, 0.0),    # 9 Royaume central
	Vector3(360.0, 0.0, 360.0)    # 10 Hauts plateaux célestes
]

const SUPER_ZONE_NAMES = [
	"Forge Volcanique", "Forêt des Cascades", "Pics de Glace",
	"Désert du Colosse", "Marais des Ombres", "Ruines du Soleil",
	"Côte des Pirates", "Village des Sources", "Royaume Central",
	"Hauts Plateaux Célestes"
]

# Une région mesure maintenant 400 x 320 mètres, soit plus de six fois la
# surface de la V6. Le continent entier mesure 1,8 x 1,12 km.
const REGION_SIZE := Vector2(400.0, 320.0)
const CONTINENT_HALF := Vector2(900.0, 560.0)
const CONTINENT_SIZE := Vector2(1800.0, 1120.0)
const TERRAIN_STEPS_X := 180
const TERRAIN_STEPS_Z := 112

const WATER_SURFACE_Y := -1.50
const WATER_BOTTOM_Y := -11.00
const SUPER_OCEAN_SIZE := Vector2(2400.0, 1720.0)
const SUPER_OCEAN_BOUNDS := Rect2(Vector2(-1200.0, -860.0), Vector2(2400.0, 1720.0))

# Tracés manuels des deux seuls fleuves intérieurs.
const RIVER_NS_PATH = [
	Vector2(-135.0, -520.0),
	Vector2(-118.0, -360.0),
	Vector2(-86.0, -190.0),
	Vector2(-112.0, -20.0),
	Vector2(-70.0, 170.0),
	Vector2(-52.0, 350.0),
	Vector2(-8.0, 520.0)
]
const RIVER_EW_PATH = [
	Vector2(-850.0, 176.0),
	Vector2(-620.0, 164.0),
	Vector2(-380.0, 138.0),
	Vector2(-120.0, 154.0),
	Vector2(140.0, 128.0),
	Vector2(430.0, 162.0),
	Vector2(850.0, 148.0)
]
const RIVER_NS_HALF_WIDTH := 16.0
const RIVER_EW_HALF_WIDTH := 18.0

const YVANE_SCRIPT = preload("res://scripts/player_yvane.gd")
const GENERIC_ENEMY_SCRIPT = preload("res://scripts/enemy.gd")
const IMPORTED_ENEMY_SCRIPT = preload("res://scripts/uploaded_enemy.gd")
const YVANE_MODEL_PATH := "res://scenes/characters/yvane_player_2_model.tscn"

const BOSS_SPECS = {
	0: {
		"node": "BaggyBoss",
		"title": "Baggy — Boss de la Forge",
		"asset": "res://asset_payloads/yvane/baggy boss .glb",
		"health": 210,
		"damage": 18,
		"speed": 3.05,
		"height": 3.2,
		"color": Color(0.95, 0.22, 0.08)
	},
	3: {
		"node": "BossIle4",
		"title": "Boss de l'île 4",
		"asset": "res://asset_payloads/yvane/boss ile 4.glb",
		"health": 225,
		"damage": 20,
		"speed": 3.15,
		"height": 3.35,
		"color": Color(0.95, 0.70, 0.18)
	},
	4: {
		"node": "BossSorciere",
		"title": "Boss sorcière",
		"asset": "res://asset_payloads/yvane/boss sorcière.glb",
		"health": 235,
		"damage": 21,
		"speed": 3.25,
		"height": 3.45,
		"color": Color(0.54, 0.22, 0.95)
	},
	9: {
		"node": "GrandeBossSorciereCauchemars",
		"title": "Grande boss sorcière des cauchemars",
		"asset": "res://asset_payloads/yvane/grande boss sorcière des cauchemars.glb",
		"health": 260,
		"damage": 24,
		"speed": 3.30,
		"height": 4.2,
		"color": Color(0.82, 0.12, 0.92)
	}
}

const SUPER_ZONE_COLORS = [
	Color(0.30, 0.12, 0.08), Color(0.08, 0.34, 0.10),
	Color(0.72, 0.84, 0.90), Color(0.72, 0.52, 0.25),
	Color(0.10, 0.27, 0.15), Color(0.62, 0.48, 0.25),
	Color(0.72, 0.63, 0.39), Color(0.24, 0.50, 0.18),
	Color(0.31, 0.55, 0.20), Color(0.50, 0.63, 0.54)
]

var _supercontinent_built := false


func _build_environment() -> void:
	var world_environment := WorldEnvironment.new()
	world_environment.name = "SupercontinentEnvironmentV61"
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.018, 0.10, 0.30)
	sky_material.sky_horizon_color = Color(0.65, 0.82, 0.96)
	sky_material.ground_bottom_color = Color(0.015, 0.03, 0.045)
	sky_material.ground_horizon_color = Color(0.30, 0.43, 0.31)
	sky.sky_material = sky_material
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.96
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.fog_enabled = true
	environment.fog_density = 0.00028
	environment.fog_light_color = Color(0.64, 0.76, 0.88)
	world_environment.environment = environment
	add_child(world_environment)

	var sun := DirectionalLight3D.new()
	sun.name = "SupercontinentSun"
	sun.rotation_degrees = Vector3(-52.0, -30.0, 0.0)
	sun.light_energy = 1.56
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 260.0
	add_child(sun)

	# L'océan est dessiné uniquement autour du continent. Il n'existe plus de
	# grande dalle bleue traversant toutes les régions.
	var ocean_margin_x := (SUPER_OCEAN_SIZE.x - CONTINENT_SIZE.x) * 0.5
	var ocean_margin_z := (SUPER_OCEAN_SIZE.y - CONTINENT_SIZE.y) * 0.5
	_add_ocean_surface(
		"OceanNorth",
		Vector2(SUPER_OCEAN_SIZE.x, ocean_margin_z),
		Vector3(0.0, WATER_SURFACE_Y, -CONTINENT_HALF.y - ocean_margin_z * 0.5)
	)
	_add_ocean_surface(
		"OceanSouth",
		Vector2(SUPER_OCEAN_SIZE.x, ocean_margin_z),
		Vector3(0.0, WATER_SURFACE_Y, CONTINENT_HALF.y + ocean_margin_z * 0.5)
	)
	_add_ocean_surface(
		"OceanWest",
		Vector2(ocean_margin_x, CONTINENT_SIZE.y),
		Vector3(-CONTINENT_HALF.x - ocean_margin_x * 0.5, WATER_SURFACE_Y, 0.0)
	)
	_add_ocean_surface(
		"OceanEast",
		Vector2(ocean_margin_x, CONTINENT_SIZE.y),
		Vector3(CONTINENT_HALF.x + ocean_margin_x * 0.5, WATER_SURFACE_Y, 0.0)
	)
	_build_ocean_physics()


func _add_ocean_surface(node_name: String, size_value: Vector2, position_value: Vector3) -> void:
	var water := MeshInstance3D.new()
	water.name = node_name
	var mesh := PlaneMesh.new()
	mesh.size = size_value
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.012, 0.24, 0.43, 0.94)
	material.metallic = 0.16
	material.roughness = 0.18
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material = material
	water.mesh = mesh
	water.position = position_value
	add_child(water)


func _build_ocean_physics() -> void:
	var water_depth := WATER_SURFACE_Y - WATER_BOTTOM_Y
	var ocean_margin_x := (SUPER_OCEAN_SIZE.x - CONTINENT_SIZE.x) * 0.5
	var ocean_margin_z := (SUPER_OCEAN_SIZE.y - CONTINENT_SIZE.y) * 0.5

	ocean_swim_volume = Area3D.new()
	ocean_swim_volume.name = "OceanSwimVolume"
	ocean_swim_volume.collision_layer = 0
	ocean_swim_volume.collision_mask = 1
	ocean_swim_volume.monitoring = true
	ocean_swim_volume.monitorable = true
	add_child(ocean_swim_volume)

	_add_ocean_volume_shape(
		"WaterVolumeCollision",
		Vector3(SUPER_OCEAN_SIZE.x, water_depth, ocean_margin_z),
		Vector3(0.0, WATER_BOTTOM_Y + water_depth * 0.5, -CONTINENT_HALF.y - ocean_margin_z * 0.5)
	)
	_add_ocean_volume_shape(
		"WaterVolumeSouth",
		Vector3(SUPER_OCEAN_SIZE.x, water_depth, ocean_margin_z),
		Vector3(0.0, WATER_BOTTOM_Y + water_depth * 0.5, CONTINENT_HALF.y + ocean_margin_z * 0.5)
	)
	_add_ocean_volume_shape(
		"WaterVolumeWest",
		Vector3(ocean_margin_x, water_depth, CONTINENT_SIZE.y),
		Vector3(-CONTINENT_HALF.x - ocean_margin_x * 0.5, WATER_BOTTOM_Y + water_depth * 0.5, 0.0)
	)
	_add_ocean_volume_shape(
		"WaterVolumeEast",
		Vector3(ocean_margin_x, water_depth, CONTINENT_SIZE.y),
		Vector3(CONTINENT_HALF.x + ocean_margin_x * 0.5, WATER_BOTTOM_Y + water_depth * 0.5, 0.0)
	)

	ocean_floor = StaticBody3D.new()
	ocean_floor.name = "OceanSeabed"
	ocean_floor.collision_layer = 1
	ocean_floor.collision_mask = 1
	ocean_floor.position = Vector3(0.0, WATER_BOTTOM_Y - 0.40, 0.0)
	var floor_collision := CollisionShape3D.new()
	floor_collision.name = "SeabedCollision"
	var floor_shape := BoxShape3D.new()
	floor_shape.size = Vector3(SUPER_OCEAN_SIZE.x - 2.0, 0.80, SUPER_OCEAN_SIZE.y - 2.0)
	floor_collision.shape = floor_shape
	ocean_floor.add_child(floor_collision)
	add_child(ocean_floor)

	var wall_height := water_depth + 9.0
	var wall_center_y := WATER_BOTTOM_Y + wall_height * 0.5
	_add_ocean_boundary("OceanBoundaryWest", Vector3(1.0, wall_height, SUPER_OCEAN_SIZE.y), Vector3(-1201.0, wall_center_y, 0.0))
	_add_ocean_boundary("OceanBoundaryEast", Vector3(1.0, wall_height, SUPER_OCEAN_SIZE.y), Vector3(1201.0, wall_center_y, 0.0))
	_add_ocean_boundary("OceanBoundaryNorth", Vector3(SUPER_OCEAN_SIZE.x, wall_height, 1.0), Vector3(0.0, wall_center_y, -861.0))
	_add_ocean_boundary("OceanBoundarySouth", Vector3(SUPER_OCEAN_SIZE.x, wall_height, 1.0), Vector3(0.0, wall_center_y, 861.0))


func _add_ocean_volume_shape(node_name: String, size_value: Vector3, position_value: Vector3) -> void:
	var collision := CollisionShape3D.new()
	collision.name = node_name
	collision.position = position_value
	var shape := BoxShape3D.new()
	shape.size = size_value
	collision.shape = shape
	ocean_swim_volume.add_child(collision)


func _build_zone(zone_index) -> void:
	if not _supercontinent_built:
		_build_supercontinent_terrain()
		_build_two_rivers()
		_supercontinent_built = true
	_add_super_zone_title(zone_index)
	_decorate_super_region(zone_index)


func _build_supercontinent_terrain() -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.94
	material.metallic = 0.0
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
	terrain.name = "SupercontinentTerrainV61"
	terrain.collision_layer = 1
	terrain.collision_mask = 1

	var visual := MeshInstance3D.new()
	visual.name = "SupercontinentVisual"
	visual.mesh = mesh
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	terrain.add_child(visual)

	# Collider HeightMap continu : aucun trou ni dalle concave traversable.
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
			heights[data_index] = _super_height(world_x, world_z)
			data_index += 1

	var height_shape := HeightMapShape3D.new()
	height_shape.map_width = collision_width
	height_shape.map_depth = collision_depth
	height_shape.map_data = heights
	var collision := CollisionShape3D.new()
	collision.name = "SupercontinentHeightMap"
	collision.shape = height_shape
	collision.scale = Vector3(COLLISION_STEP, 1.0, COLLISION_STEP)
	terrain.add_child(collision)
	add_child(terrain)


func _add_colored_triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	for point: Vector3 in [a, b, c]:
		surface.set_color(_super_color(point.x, point.z, point.y))
		surface.add_vertex(point)


func _super_height(world_x: float, world_z: float) -> float:
	# Plaine continentale stable. Le relief vient uniquement de massifs dessinés
	# à des emplacements précis, pas d'un bruit ou d'un tirage aléatoire.
	var height := 4.20

	# Région 1 : volcan et caldeira.
	height += _gaussian(world_x, world_z, -600.0, -360.0, 128.0) * 31.0
	height -= _gaussian(world_x, world_z, -600.0, -360.0, 38.0) * 13.0
	height += _gaussian(world_x, world_z, -730.0, -430.0, 72.0) * 8.0

	# Région 2 : collines boisées et bassin de cascade.
	height += _gaussian(world_x, world_z, -290.0, -440.0, 96.0) * 7.0
	height += _gaussian(world_x, world_z, -90.0, -430.0, 84.0) * 5.0
	height -= _gaussian(world_x, world_z, -205.0, -292.0, 64.0) * 2.0

	# Région 3 : chaîne de glace.
	height += _gaussian(world_x, world_z, 125.0, -425.0, 94.0) * 17.0
	height += _gaussian(world_x, world_z, 270.0, -405.0, 84.0) * 21.0
	height += _gaussian(world_x, world_z, 210.0, -275.0, 72.0) * 10.0

	# Région 4 : plateau désertique et mesa.
	height += _gaussian(world_x, world_z, 610.0, -370.0, 150.0) * 5.5
	height += _gaussian(world_x, world_z, 700.0, -445.0, 58.0) * 8.0

	# Région 5 : marais bas, toujours au-dessus du niveau de l'eau.
	height -= _gaussian(world_x, world_z, 600.0, 0.0, 170.0) * 1.65

	# Région 6 : ruines sur terrasse.
	height += _gaussian(world_x, world_z, -200.0, 360.0, 150.0) * 2.5

	# Région 7 : collines côtières protégeant le port.
	height += _gaussian(world_x, world_z, -680.0, -40.0, 92.0) * 5.0

	# Région 8 : grande plaine du village volontairement plane.
	height = lerpf(height, 4.35, _gaussian(world_x, world_z, -600.0, 360.0, 150.0) * 0.96)

	# Région 9 : capitale sur plateau doux.
	height += _gaussian(world_x, world_z, -200.0, 0.0, 180.0) * 2.2

	# Région 10 : hauts plateaux.
	height += _gaussian(world_x, world_z, 360.0, 360.0, 170.0) * 22.0
	height += _gaussian(world_x, world_z, 500.0, 410.0, 82.0) * 9.0

	# Deux fleuves, et seulement ces deux fleuves, creusent l'intérieur.
	var river_one_distance := absf(world_x - _river_one_x(world_z))
	if river_one_distance < RIVER_NS_HALF_WIDTH:
		var strength_one := 1.0 - smoothstep(0.0, RIVER_NS_HALF_WIDTH, river_one_distance)
		height = lerpf(height, -2.85, strength_one)

	var river_two_distance := absf(world_z - _river_two_z(world_x))
	if river_two_distance < RIVER_EW_HALF_WIDTH:
		var strength_two := 1.0 - smoothstep(0.0, RIVER_EW_HALF_WIDTH, river_two_distance)
		height = lerpf(height, -3.00, strength_two)

	# La côte ne commence qu'aux limites extérieures du supercontinent.
	var rectangular_edge := maxf(absf(world_x) / CONTINENT_HALF.x, absf(world_z) / CONTINENT_HALF.y)
	if rectangular_edge > 0.87:
		var coast := smoothstep(0.87, 1.0, rectangular_edge)
		var beach_height := lerpf(height, 0.15, smoothstep(0.87, 0.955, rectangular_edge))
		height = lerpf(beach_height, -4.20, coast)
	return height


func _gaussian(x: float, z: float, cx: float, cz: float, radius: float) -> float:
	var dx := x - cx
	var dz := z - cz
	return exp(-(dx * dx + dz * dz) / maxf(1.0, radius * radius))


func _river_one_x(world_z: float) -> float:
	return _sample_path_x_for_z(RIVER_NS_PATH, world_z)


func _river_two_z(world_x: float) -> float:
	return _sample_path_z_for_x(RIVER_EW_PATH, world_x)


func _sample_path_x_for_z(path_points: Array, world_z: float) -> float:
	if path_points.is_empty():
		return 0.0
	if world_z <= path_points[0].y:
		return path_points[0].x
	for index in range(path_points.size() - 1):
		var a: Vector2 = path_points[index]
		var b: Vector2 = path_points[index + 1]
		if world_z <= b.y:
			var t := inverse_lerp(a.y, b.y, world_z)
			return lerpf(a.x, b.x, t)
	return path_points[path_points.size() - 1].x


func _sample_path_z_for_x(path_points: Array, world_x: float) -> float:
	if path_points.is_empty():
		return 0.0
	if world_x <= path_points[0].x:
		return path_points[0].y
	for index in range(path_points.size() - 1):
		var a: Vector2 = path_points[index]
		var b: Vector2 = path_points[index + 1]
		if world_x <= b.x:
			var t := inverse_lerp(a.x, b.x, world_x)
			return lerpf(a.y, b.y, t)
	return path_points[path_points.size() - 1].y


func _super_color(world_x: float, world_z: float, height: float) -> Color:
	if height < WATER_SURFACE_Y + 0.25:
		return Color(0.73, 0.64, 0.43)
	if height < 1.0:
		return Color(0.80, 0.71, 0.48)
	var zone_index := _nearest_super_zone(Vector3(world_x, height, world_z))
	if height > 20.0:
		return Color(0.82, 0.87, 0.90) if zone_index in [2, 9] else Color(0.30, 0.28, 0.26)
	return SUPER_ZONE_COLORS[zone_index]


func _build_two_rivers() -> void:
	_add_river_visual("FleuveNordSud", RIVER_NS_PATH, 29.0)
	_add_river_visual("FleuveEstOuest", RIVER_EW_PATH, 33.0)


func _add_river_visual(node_name: String, path_points: Array, width: float) -> void:
	for index in range(path_points.size() - 1):
		var start_2d: Vector2 = path_points[index]
		var end_2d: Vector2 = path_points[index + 1]
		var start := Vector3(start_2d.x, WATER_SURFACE_Y + 0.035, start_2d.y)
		var finish := Vector3(end_2d.x, WATER_SURFACE_Y + 0.035, end_2d.y)
		var delta := finish - start
		var midpoint := (start + finish) * 0.5
		var water: Node3D = _visual_box(
			node_name,
			Vector3(width, 0.05, delta.length() + 1.0),
			midpoint,
			Color(0.025, 0.38, 0.61, 0.88)
		)
		water.rotation.y = atan2(delta.x, delta.z)


func _nearest_super_zone(world_position: Vector3) -> int:
	var nearest_zone := START_ZONE
	var nearest_distance := INF
	for zone_index in range(SUPER_ZONE_CENTERS.size()):
		var center: Vector3 = SUPER_ZONE_CENTERS[zone_index]
		var dx := world_position.x - center.x
		var dz := world_position.z - center.z
		var distance := dx * dx + dz * dz
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_zone = zone_index
	return nearest_zone


func get_v61_world_metrics() -> Dictionary:
	return {
		"centers": SUPER_ZONE_CENTERS,
		"region_size": REGION_SIZE,
		"continent_size": CONTINENT_SIZE,
		"continent_half": CONTINENT_HALF,
		"water_surface_y": WATER_SURFACE_Y,
		"water_bottom_y": WATER_BOTTOM_Y,
		"ocean_bounds": SUPER_OCEAN_BOUNDS
	}


func _decorate_super_region(_zone_index: int) -> void:
	pass


func _add_super_zone_title(_zone_index: int) -> void:
	pass
