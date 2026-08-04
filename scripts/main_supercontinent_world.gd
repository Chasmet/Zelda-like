extends "res://scripts/main_chk_player.gd"

# V10 : les dix régions forment un seul supercontinent. Chaque région couvre
# environ 150 x 130 m, soit un peu plus de dix fois la surface de l'ancien format.
const SUPER_ZONE_CENTERS = [
	Vector3(-225.0, 0.0, -150.0), # 1 Forge volcanique
	Vector3(-75.0, 0.0, -150.0),  # 2 Forêt des cascades
	Vector3(75.0, 0.0, -150.0),   # 3 Pics de glace
	Vector3(225.0, 0.0, -150.0),  # 4 Désert du colosse
	Vector3(225.0, 0.0, 0.0),     # 5 Marais des ombres
	Vector3(-75.0, 0.0, 150.0),   # 6 Ruines du soleil
	Vector3(-225.0, 0.0, 0.0),    # 7 Côte des pirates
	Vector3(-225.0, 0.0, 150.0),  # 8 Village des sources
	Vector3(-75.0, 0.0, 0.0),     # 9 Royaume central
	Vector3(150.0, 0.0, 150.0)    # 10 Hauts plateaux célestes
]

const SUPER_ZONE_NAMES = [
	"Forge Volcanique", "Forêt des Cascades", "Pics de Glace",
	"Désert du Colosse", "Marais des Ombres", "Ruines du Soleil",
	"Côte des Pirates", "Village des Sources", "Royaume Central",
	"Hauts Plateaux Célestes"
]

const REGION_SIZE := Vector2(150.0, 130.0)
const CONTINENT_HALF := Vector2(330.0, 245.0)
const CONTINENT_SIZE := Vector2(660.0, 490.0)
const TERRAIN_STEPS_X := 84
const TERRAIN_STEPS_Z := 64
const WATER_SURFACE_Y := -0.92
const WATER_BOTTOM_Y := -8.50
const SUPER_OCEAN_SIZE := Vector2(900.0, 720.0)
const SUPER_OCEAN_BOUNDS := Rect2(Vector2(-450.0, -360.0), Vector2(900.0, 720.0))

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
	world_environment.name = "SupercontinentEnvironment"
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
	environment.ambient_light_energy = 0.92
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.fog_enabled = true
	environment.fog_density = 0.00065
	environment.fog_light_color = Color(0.64, 0.76, 0.88)
	world_environment.environment = environment
	add_child(world_environment)

	var sun := DirectionalLight3D.new()
	sun.name = "SupercontinentSun"
	sun.rotation_degrees = Vector3(-52.0, -30.0, 0.0)
	sun.light_energy = 1.52
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 180.0
	add_child(sun)

	var ocean := MeshInstance3D.new()
	ocean.name = "SupercontinentOcean"
	var ocean_mesh := PlaneMesh.new()
	ocean_mesh.size = SUPER_OCEAN_SIZE
	var ocean_material := StandardMaterial3D.new()
	ocean_material.albedo_color = Color(0.012, 0.24, 0.43, 0.93)
	ocean_material.metallic = 0.18
	ocean_material.roughness = 0.16
	ocean_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ocean_mesh.material = ocean_material
	ocean.mesh = ocean_mesh
	ocean.position.y = WATER_SURFACE_Y
	add_child(ocean)

	_build_ocean_physics()

func _build_ocean_physics() -> void:
	var water_depth := WATER_SURFACE_Y - WATER_BOTTOM_Y

	ocean_swim_volume = Area3D.new()
	ocean_swim_volume.name = "OceanSwimVolume"
	ocean_swim_volume.collision_layer = 0
	ocean_swim_volume.collision_mask = 1
	ocean_swim_volume.monitoring = true
	ocean_swim_volume.monitorable = true
	ocean_swim_volume.position = Vector3(0.0, WATER_BOTTOM_Y + water_depth * 0.5, 0.0)
	var volume_collision := CollisionShape3D.new()
	volume_collision.name = "WaterVolumeCollision"
	var volume_shape := BoxShape3D.new()
	volume_shape.size = Vector3(SUPER_OCEAN_SIZE.x, water_depth, SUPER_OCEAN_SIZE.y)
	volume_collision.shape = volume_shape
	ocean_swim_volume.add_child(volume_collision)
	add_child(ocean_swim_volume)

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

	var wall_height := water_depth + 7.0
	var wall_center_y := WATER_BOTTOM_Y + wall_height * 0.5
	_add_ocean_boundary("OceanBoundaryWest", Vector3(1.0, wall_height, SUPER_OCEAN_SIZE.y), Vector3(-451.0, wall_center_y, 0.0))
	_add_ocean_boundary("OceanBoundaryEast", Vector3(1.0, wall_height, SUPER_OCEAN_SIZE.y), Vector3(451.0, wall_center_y, 0.0))
	_add_ocean_boundary("OceanBoundaryNorth", Vector3(SUPER_OCEAN_SIZE.x, wall_height, 1.0), Vector3(0.0, wall_center_y, -361.0))
	_add_ocean_boundary("OceanBoundarySouth", Vector3(SUPER_OCEAN_SIZE.x, wall_height, 1.0), Vector3(0.0, wall_center_y, 361.0))

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
	var mesh := surface.commit()
	var terrain := StaticBody3D.new()
	terrain.name = "SupercontinentTerrain"
	terrain.collision_layer = 1
	terrain.collision_mask = 1
	var visual := MeshInstance3D.new()
	visual.name = "SupercontinentVisual"
	visual.mesh = mesh
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	terrain.add_child(visual)
	var collision := CollisionShape3D.new()
	collision.name = "SupercontinentCollision"
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(mesh.get_faces())
	collision.shape = shape
	terrain.add_child(collision)
	add_child(terrain)

func _add_colored_triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	for point: Vector3 in [a, b, c]:
		surface.set_color(_super_color(point.x, point.z, point.y))
		surface.add_vertex(point)

func _super_height(world_x: float, world_z: float) -> float:
	var nx := world_x / CONTINENT_HALF.x
	var nz := world_z / CONTINENT_HALF.y
	var edge := pow(pow(absf(nx), 4.0) + pow(absf(nz), 4.0), 0.25)
	var low_wave := sin(world_x * 0.027) * 0.34 + cos(world_z * 0.031) * 0.28
	low_wave += sin((world_x + world_z) * 0.014) * 0.22
	var height := 1.75 + low_wave

	# Grandes plaines centrales et méridionales.
	var plains := _gaussian(world_x, world_z, -120.0, 80.0, 175.0)
	height = lerpf(height, 1.55 + low_wave * 0.22, plains * 0.78)

	# Massifs montagneux, falaises et hauts plateaux.
	height += _gaussian(world_x, world_z, -225.0, -150.0, 76.0) * 20.0
	height -= _gaussian(world_x, world_z, -225.0, -150.0, 20.0) * 7.0
	height += _gaussian(world_x, world_z, 55.0, -158.0, 70.0) * 13.0
	height += _gaussian(world_x, world_z, 112.0, -138.0, 48.0) * 10.0
	height += _gaussian(world_x, world_z, 150.0, 150.0, 82.0) * 21.0
	height += _gaussian(world_x, world_z, 250.0, -130.0, 74.0) * 4.0
	height -= _gaussian(world_x, world_z, 225.0, 0.0, 95.0) * 1.2

	# Deux fleuves uniquement à l'intérieur du continent.
	var river_one_x := _river_one_x(world_z)
	var river_one_distance := absf(world_x - river_one_x)
	if river_one_distance < 10.5:
		var river_one_strength := 1.0 - smoothstep(0.0, 10.5, river_one_distance)
		height = minf(height, lerpf(height, -2.05, river_one_strength))

	var river_two_z := _river_two_z(world_x)
	var river_two_distance := absf(world_z - river_two_z)
	if river_two_distance < 11.5:
		var river_two_strength := 1.0 - smoothstep(0.0, 11.5, river_two_distance)
		height = minf(height, lerpf(height, -2.25, river_two_strength))

	# Bord de mer : plages sur les côtes douces, falaises au nord et à l'est.
	if edge > 0.77:
		var coast := smoothstep(0.77, 1.0, edge)
		var cliff_sector := world_z < -105.0 or world_x > 245.0
		var coast_land := height + (6.0 * (1.0 - coast) if cliff_sector else 0.0)
		height = lerpf(coast_land, -2.6, coast)
	return height

func _gaussian(x: float, z: float, cx: float, cz: float, radius: float) -> float:
	var dx := x - cx
	var dz := z - cz
	return exp(-(dx * dx + dz * dz) / maxf(1.0, radius * radius))

func _river_one_x(world_z: float) -> float:
	return -115.0 + sin((world_z + 210.0) * 0.018) * 34.0

func _river_two_z(world_x: float) -> float:
	return 72.0 + sin((world_x + 75.0) * 0.0105) * 28.0

func _super_color(world_x: float, world_z: float, height: float) -> Color:
	if height < WATER_SURFACE_Y + 0.30:
		return Color(0.70, 0.61, 0.40)
	if height < 0.65:
		return Color(0.78, 0.68, 0.43)
	var zone_index := _nearest_super_zone(Vector3(world_x, height, world_z))
	var base: Color = SUPER_ZONE_COLORS[zone_index]
	var detail := (sin(world_x * 0.17) + cos(world_z * 0.14)) * 0.045
	if height > 15.0:
		return Color(0.82, 0.86, 0.87) if zone_index in [2, 9] else Color(0.31, 0.29, 0.27)
	return base.lightened(detail) if detail >= 0.0 else base.darkened(-detail)

func _build_two_rivers() -> void:
	_add_river_visual("FleuveNordSud", true)
	_add_river_visual("FleuveEstOuest", false)

func _add_river_visual(node_name: String, north_south: bool) -> void:
	var segments := 44
	var start_value := -225.0 if north_south else -310.0
	var end_value := 225.0 if north_south else 310.0
	var previous := Vector3.ZERO
	for index in range(segments + 1):
		var t := float(index) / float(segments)
		var axis_value := lerpf(start_value, end_value, t)
		var point := Vector3(_river_one_x(axis_value), WATER_SURFACE_Y + 0.035, axis_value) if north_south else Vector3(axis_value, WATER_SURFACE_Y + 0.04, _river_two_z(axis_value))
		if index > 0:
			var delta := point - previous
			var midpoint := (point + previous) * 0.5
			var water := _visual_box(node_name, Vector3(16.5, 0.05, delta.length() + 0.7), midpoint, Color(0.025, 0.38, 0.61, 0.86))
			water.rotation.y = atan2(delta.x, delta.z)
		previous = point

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

func _decorate_super_region(_zone_index: int) -> void:
	pass

func _add_super_zone_title(_zone_index: int) -> void:
	pass
