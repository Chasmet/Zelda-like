extends "res://scripts/main_water_final.gd"

const FLIGHT_PLAYER_SCRIPT = preload("res://scripts/player_water_flight.gd")
const POPULATION_SCRIPT = preload("res://scripts/world_population_v8.gd")
const WEATHER_SCRIPT = preload("res://scripts/world_weather_v8.gd")

const REGION_LINEAR_SCALE := 3.16227766
const EXP_OCEAN_SURFACE_Y := -0.92
const EXP_OCEAN_BOTTOM_Y := -10.0
const EXP_OCEAN_SIZE := Vector2(920.0, 620.0)
const EXP_OCEAN_BOUNDS := Rect2(Vector2(-460.0, -310.0), Vector2(920.0, 620.0))
const EXP_START_REGION := 0
const SAVE_LAYOUT_VERSION := 8

const REGION_NAMES = [
	"Village côtier",
	"Forêt dense",
	"Montagnes rocheuses",
	"Plaines agricoles",
	"Zone volcanique",
	"Marais brumeux",
	"Désert de cendres",
	"Port commercial",
	"Ruines anciennes",
	"Sommet enneigé"
]

# Permutation entre le nouvel ordre demandé et les biomes déjà codés.
# On conserve ainsi les modèles, textures et gardiens du projet existant.
const USER_TO_SOURCE = [7, 1, 2, 8, 0, 4, 3, 6, 5, 9]

const REGION_CENTERS = [
	Vector3(-300.0, 0.0, -170.0),
	Vector3(-150.0, 0.0, -170.0),
	Vector3(0.0, 0.0, -170.0),
	Vector3(150.0, 0.0, -170.0),
	Vector3(300.0, 0.0, -170.0),
	Vector3(-300.0, 0.0, 105.0),
	Vector3(-150.0, 0.0, 105.0),
	Vector3(0.0, 0.0, 105.0),
	Vector3(150.0, 0.0, 105.0),
	Vector3(300.0, 0.0, 105.0)
]

const REGION_MAP_MARKERS = [
	Vector2(0.12, 0.28),
	Vector2(0.31, 0.28),
	Vector2(0.50, 0.28),
	Vector2(0.69, 0.28),
	Vector2(0.88, 0.28),
	Vector2(0.12, 0.72),
	Vector2(0.31, 0.72),
	Vector2(0.50, 0.72),
	Vector2(0.69, 0.72),
	Vector2(0.88, 0.72)
]

const REGION_BASE_COLORS = [
	Color(0.48, 0.38, 0.20),
	Color(0.06, 0.27, 0.09),
	Color(0.30, 0.34, 0.37),
	Color(0.38, 0.52, 0.18),
	Color(0.17, 0.08, 0.05),
	Color(0.08, 0.19, 0.13),
	Color(0.28, 0.24, 0.20),
	Color(0.17, 0.32, 0.38),
	Color(0.45, 0.35, 0.18),
	Color(0.68, 0.79, 0.86)
]

const REGION_ACCENT_COLORS = [
	Color(0.93, 0.74, 0.36),
	Color(0.20, 0.62, 0.17),
	Color(0.64, 0.70, 0.74),
	Color(0.78, 0.67, 0.25),
	Color(1.00, 0.18, 0.02),
	Color(0.12, 0.55, 0.30),
	Color(0.65, 0.58, 0.50),
	Color(0.04, 0.68, 0.83),
	Color(0.83, 0.67, 0.31),
	Color(0.86, 0.95, 1.00)
]

var expansion_environment: WorldEnvironment
var expansion_sun: DirectionalLight3D
var population_manager
var weather_manager

var pause_layer: CanvasLayer
var pause_panel: ColorRect
var pause_button: Button
var weather_label: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await super._ready()

	population_manager = POPULATION_SCRIPT.new()
	population_manager.name = "LivingPopulationV8"
	add_child(population_manager)
	population_manager.setup(
		self,
		player,
		REGION_CENTERS,
		REGION_NAMES,
		REGION_ACCENT_COLORS
	)

	weather_manager = WEATHER_SCRIPT.new()
	weather_manager.name = "DynamicWeatherV8"
	add_child(weather_manager)
	weather_manager.setup(self, player, expansion_environment, expansion_sun)

	_restore_expansion_progress()
	_show_message(
		"Tutoriel : explore les régions, parle aux habitants et ramasse les cristaux.",
		6.0
	)


func _process(delta: float) -> void:
	super._process(delta)

	if get_tree().paused:
		return

	if is_instance_valid(population_manager):
		population_manager.update_simulation(delta, current_zone)

	if is_instance_valid(weather_manager):
		weather_manager.update_system(delta, current_zone)

	_refresh_expansion_hud()


func _build_environment() -> void:
	super._build_environment()
	_build_large_ocean_visual()
	_build_expansion_environment()


func _build_ocean_physics() -> void:
	var water_depth := EXP_OCEAN_SURFACE_Y - EXP_OCEAN_BOTTOM_Y

	ocean_swim_volume = Area3D.new()
	ocean_swim_volume.name = "OceanSwimVolume"
	ocean_swim_volume.collision_layer = 0
	ocean_swim_volume.collision_mask = 1
	ocean_swim_volume.monitoring = true
	ocean_swim_volume.monitorable = true
	ocean_swim_volume.position = Vector3(
		0.0,
		EXP_OCEAN_BOTTOM_Y + water_depth * 0.5,
		0.0
	)

	var volume_collision := CollisionShape3D.new()
	var volume_shape := BoxShape3D.new()
	volume_shape.size = Vector3(EXP_OCEAN_SIZE.x, water_depth, EXP_OCEAN_SIZE.y)
	volume_collision.shape = volume_shape
	ocean_swim_volume.add_child(volume_collision)
	add_child(ocean_swim_volume)

	ocean_floor = StaticBody3D.new()
	ocean_floor.name = "OceanSeabed"
	ocean_floor.collision_layer = 1
	ocean_floor.collision_mask = 1
	ocean_floor.position = Vector3(0.0, EXP_OCEAN_BOTTOM_Y - 0.45, 0.0)

	var floor_collision := CollisionShape3D.new()
	var floor_shape := BoxShape3D.new()
	floor_shape.size = Vector3(EXP_OCEAN_SIZE.x - 4.0, 0.9, EXP_OCEAN_SIZE.y - 4.0)
	floor_collision.shape = floor_shape
	ocean_floor.add_child(floor_collision)

	var floor_visual := MeshInstance3D.new()
	var floor_mesh := BoxMesh.new()
	floor_mesh.size = floor_shape.size
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color(0.035, 0.075, 0.08)
	floor_material.roughness = 0.98
	floor_mesh.material = floor_material
	floor_visual.mesh = floor_mesh
	ocean_floor.add_child(floor_visual)
	add_child(ocean_floor)

	var wall_height := water_depth + 12.0
	var wall_center_y := EXP_OCEAN_BOTTOM_Y + wall_height * 0.5
	_add_ocean_boundary(
		"OceanBoundaryWest",
		Vector3(1.0, wall_height, EXP_OCEAN_SIZE.y),
		Vector3(-461.0, wall_center_y, 0.0)
	)
	_add_ocean_boundary(
		"OceanBoundaryEast",
		Vector3(1.0, wall_height, EXP_OCEAN_SIZE.y),
		Vector3(461.0, wall_center_y, 0.0)
	)
	_add_ocean_boundary(
		"OceanBoundaryNorth",
		Vector3(EXP_OCEAN_SIZE.x, wall_height, 1.0),
		Vector3(0.0, wall_center_y, -311.0)
	)
	_add_ocean_boundary(
		"OceanBoundarySouth",
		Vector3(EXP_OCEAN_SIZE.x, wall_height, 1.0),
		Vector3(0.0, wall_center_y, 311.0)
	)


func _build_large_ocean_visual() -> void:
	var ocean := MeshInstance3D.new()
	ocean.name = "ExpandedOceanVisual"

	var mesh := PlaneMesh.new()
	mesh.size = EXP_OCEAN_SIZE
	mesh.subdivide_width = 12
	mesh.subdivide_depth = 8

	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.015, 0.28, 0.43, 0.82)
	material.metallic = 0.18
	material.roughness = 0.22
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material = material

	ocean.mesh = mesh
	ocean.position.y = EXP_OCEAN_SURFACE_Y - 0.03
	add_child(ocean)


func _build_expansion_environment() -> void:
	expansion_environment = WorldEnvironment.new()
	expansion_environment.name = "ExpansionWorldEnvironment"

	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.40, 0.66, 0.88)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.62, 0.72, 0.82)
	environment.ambient_light_energy = 0.92
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.55, 0.65, 0.72)
	environment.fog_density = 0.0018

	expansion_environment.environment = environment
	add_child(expansion_environment)

	expansion_sun = DirectionalLight3D.new()
	expansion_sun.name = "ExpansionSun"
	expansion_sun.shadow_enabled = true
	expansion_sun.directional_shadow_max_distance = 180.0
	expansion_sun.light_energy = 1.35
	expansion_sun.rotation_degrees = Vector3(-48.0, -28.0, 0.0)
	add_child(expansion_sun)


func _build_zone(region_index) -> void:
	var source_index: int = USER_TO_SOURCE[region_index]
	var existing_ids := {}

	for child in get_children():
		existing_ids[child.get_instance_id()] = true

	super._build_zone(source_index)

	var source_center: Vector3 = ZONE_CENTERS[source_index]
	var destination_center: Vector3 = REGION_CENTERS[region_index]

	for child in get_children():
		if existing_ids.has(child.get_instance_id()):
			continue
		if child is Node3D:
			_relocate_zone_node(child, source_center, destination_center)

	_add_region_identity(region_index)
	_add_region_detail_clusters(region_index)


func _relocate_zone_node(
	node: Node3D,
	source_center: Vector3,
	destination_center: Vector3
) -> void:
	var offset := node.position - source_center
	node.position = destination_center + Vector3(
		offset.x * REGION_LINEAR_SCALE,
		offset.y,
		offset.z * REGION_LINEAR_SCALE
	)

	var node_name := String(node.name)
	if node_name.contains("Terrain"):
		node.scale.x *= REGION_LINEAR_SCALE
		node.scale.z *= REGION_LINEAR_SCALE
	elif _is_large_footprint(node_name):
		node.scale.x *= 1.35
		node.scale.z *= 1.35


func _is_large_footprint(node_name: String) -> bool:
	return (
		node_name.contains("Path")
		or node_name.contains("Water")
		or node_name.contains("Wall")
		or node_name.contains("Lava")
		or node_name.contains("Channel")
	)


func _add_region_identity(region_index: int) -> void:
	var center: Vector3 = REGION_CENTERS[region_index]

	var label := Label3D.new()
	label.name = "RegionName_%02d" % (region_index + 1)
	label.text = "%d — %s" % [region_index + 1, REGION_NAMES[region_index]]
	label.font_size = 86
	label.outline_size = 18
	label.modulate = REGION_ACCENT_COLORS[region_index]
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = center + Vector3(0.0, 9.0, -52.0)
	label.visibility_range_end = 180.0
	add_child(label)

	for corner in [
		Vector3(-67.0, 0.0, -59.0),
		Vector3(67.0, 0.0, -59.0),
		Vector3(-67.0, 0.0, 59.0),
		Vector3(67.0, 0.0, 59.0)
	]:
		var world_position: Vector3 = center + corner
		world_position.y = _expanded_height(
			region_index,
			world_position.x,
			world_position.z
		) + 3.0
		_make_static_box(
			"Frontiere_%02d" % (region_index + 1),
			Vector3(1.3, 6.0, 1.3),
			world_position,
			REGION_ACCENT_COLORS[region_index].darkened(0.28)
		)


func _add_region_detail_clusters(region_index: int) -> void:
	for variant in range(3):
		var count := 18
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = _create_region_detail_mesh(region_index, variant)
		multimesh.instance_count = count
		multimesh.visible_instance_count = count

		for item_index in range(count):
			var angle := float(item_index) * 2.399963 + float(variant) * 0.71
			var radius := 14.0 + float((item_index * 17 + variant * 9) % 49)
			var x: float = REGION_CENTERS[region_index].x + cos(angle) * radius
			var z: float = (
				REGION_CENTERS[region_index].z
				+ sin(angle) * radius * 0.88
			)
			var y := _expanded_height(region_index, x, z)
			var size_factor := 0.70 + float((item_index + variant) % 5) * 0.12
			var basis := Basis(Vector3.UP, angle).scaled(
				_detail_scale(region_index, variant, size_factor)
			)
			multimesh.set_instance_transform(
				item_index,
				Transform3D(basis, Vector3(x, y, z))
			)

		var cluster := MultiMeshInstance3D.new()
		cluster.name = "Details_%02d_%02d" % [region_index + 1, variant + 1]
		cluster.multimesh = multimesh
		cluster.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		cluster.visibility_range_end = 210.0
		add_child(cluster)


func _create_region_detail_mesh(region_index: int, variant: int) -> PrimitiveMesh:
	var mesh: PrimitiveMesh

	match region_index:
		0:
			mesh = BoxMesh.new() if variant == 0 else CylinderMesh.new()
		1:
			mesh = CylinderMesh.new() if variant < 2 else SphereMesh.new()
		2:
			mesh = BoxMesh.new() if variant == 0 else CylinderMesh.new()
		3:
			mesh = BoxMesh.new() if variant != 1 else CylinderMesh.new()
		4:
			mesh = CylinderMesh.new() if variant == 0 else SphereMesh.new()
		5:
			mesh = CylinderMesh.new() if variant != 2 else SphereMesh.new()
		6:
			mesh = SphereMesh.new() if variant == 0 else BoxMesh.new()
		7:
			mesh = BoxMesh.new() if variant != 2 else CylinderMesh.new()
		8:
			mesh = CylinderMesh.new() if variant < 2 else BoxMesh.new()
		_:
			mesh = CylinderMesh.new() if variant != 1 else SphereMesh.new()

	var material := StandardMaterial3D.new()
	material.albedo_color = Color.WHITE
	material.albedo_texture = _create_region_texture(region_index, variant)
	material.roughness = 0.78
	material.metallic = 0.12 if region_index in [2, 4, 8, 9] else 0.0
	mesh.material = material

	if mesh is BoxMesh:
		mesh.size = Vector3(1.8, 2.2, 1.8)
	elif mesh is CylinderMesh:
		mesh.top_radius = 0.48
		mesh.bottom_radius = 0.70
		mesh.height = 3.6
	elif mesh is SphereMesh:
		mesh.radius = 1.05
		mesh.height = 2.0

	return mesh


func _detail_scale(
	region_index: int,
	variant: int,
	factor: float
) -> Vector3:
	if region_index == 1:
		return Vector3(1.0, 2.1 + variant * 0.45, 1.0) * factor
	if region_index == 3:
		return Vector3(0.75, 1.45, 0.75) * factor
	if region_index == 7:
		return Vector3(1.35, 1.0 + variant * 0.45, 1.15) * factor
	if region_index == 8:
		return Vector3(0.9, 2.0 + variant * 0.50, 0.9) * factor
	return Vector3.ONE * factor


func _create_region_texture(region_index: int, variant: int) -> ImageTexture:
	var image := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	var base: Color = REGION_BASE_COLORS[region_index]
	var accent: Color = REGION_ACCENT_COLORS[region_index]

	for y in range(32):
		for x in range(32):
			var wave := sin(float(x * (variant + 2)) * 0.34) * 0.12
			var grain_seed := sin(
				float(
					x * 41
					+ y * 67
					+ region_index * 127
					+ variant * 211
				)
			) * 15437.31
			var grain: float = grain_seed - floor(grain_seed)
			var amount := clampf(0.16 + grain * 0.48 + wave, 0.0, 0.82)

			if region_index == 9:
				amount = clampf(amount + 0.24, 0.0, 0.94)
			elif region_index == 4:
				amount = clampf(
					amount + sin(float(x + y) * 0.55) * 0.22,
					0.0,
					0.92
				)

			image.set_pixel(x, y, base.lerp(accent, amount))

	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)


func _build_routes() -> void:
	var pairs := [
		Vector2i(0, 1),
		Vector2i(1, 2),
		Vector2i(2, 3),
		Vector2i(3, 4),
		Vector2i(5, 6),
		Vector2i(6, 7),
		Vector2i(7, 8),
		Vector2i(8, 9),
		Vector2i(0, 5),
		Vector2i(1, 6),
		Vector2i(2, 7),
		Vector2i(3, 8),
		Vector2i(4, 9)
	]

	for pair in pairs:
		_build_expanded_route(pair.x, pair.y)


func _build_expanded_route(region_a: int, region_b: int) -> void:
	var start: Vector3 = REGION_CENTERS[region_a]
	var finish: Vector3 = REGION_CENTERS[region_b]
	var horizontal := Vector3(finish.x - start.x, 0.0, finish.z - start.z)
	var length := horizontal.length()

	if length < 1.0:
		return

	var midpoint := (start + finish) * 0.5
	midpoint.y = 0.30

	var route := _make_static_box(
		"Route_%02d_%02d" % [region_a + 1, region_b + 1],
		Vector3(8.5, 0.55, length),
		midpoint,
		Color(0.36, 0.28, 0.18)
	)
	route.rotation.y = atan2(horizontal.x, horizontal.z)


func _build_portals() -> void:
	capital_portal_position = REGION_CENTERS[8] + Vector3(0.0, 2.0, 0.0)
	sky_portal_position = REGION_CENTERS[9] + Vector3(0.0, 2.0, 0.0)


func _spawn_player() -> void:
	player = FLIGHT_PLAYER_SCRIPT.new()
	player.name = "CheikhHero"

	var center: Vector3 = REGION_CENTERS[EXP_START_REGION]
	var spawn_x := center.x
	var spawn_z := center.z + 10.0
	player.position = Vector3(
		spawn_x,
		_expanded_height(EXP_START_REGION, spawn_x, spawn_z) + 0.55,
		spawn_z
	)

	add_child(player)
	player.set_spawn(player.global_position)
	player.set_water_profile(
		EXP_OCEAN_SURFACE_Y,
		EXP_OCEAN_BOTTOM_Y,
		EXP_OCEAN_BOUNDS
	)

	# Le modèle Cheikh chevalier est forcé ici et reste aussi utilisé
	# par le portrait du HUD hérité.
	if ResourceLoader.exists(HERO_MODEL):
		player.apply_asset(HERO_MODEL)

	player.health_changed.connect(_on_health_changed)
	player.attack_requested.connect(_on_player_attack)
	player.interact_requested.connect(_on_interact)
	current_zone = EXP_START_REGION


func _spawn_guardians() -> void:
	super._spawn_guardians()

	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue

		var source_index := _nearest_source_zone(enemy.global_position)
		var region_index := _source_to_region(source_index)
		enemy.global_position = _map_source_position_to_region(
			enemy.global_position,
			source_index,
			region_index
		)


func _nearest_source_zone(world_position: Vector3) -> int:
	var best_index := 0
	var best_distance := INF

	for source_index in range(ZONE_CENTERS.size()):
		var distance := Vector2(
			world_position.x - ZONE_CENTERS[source_index].x,
			world_position.z - ZONE_CENTERS[source_index].z
		).length_squared()

		if distance < best_distance:
			best_distance = distance
			best_index = source_index

	return best_index


func _source_to_region(source_index: int) -> int:
	for region_index in range(USER_TO_SOURCE.size()):
		if USER_TO_SOURCE[region_index] == source_index:
			return region_index
	return 0


func _map_source_position_to_region(
	world_position: Vector3,
	source_index: int,
	region_index: int
) -> Vector3:
	var offset: Vector3 = world_position - ZONE_CENTERS[source_index]
	return REGION_CENTERS[region_index] + Vector3(
		offset.x * REGION_LINEAR_SCALE,
		offset.y,
		offset.z * REGION_LINEAR_SCALE
	)


func _expanded_height(
	region_index: int,
	world_x: float,
	world_z: float
) -> float:
	var source_index: int = USER_TO_SOURCE[region_index]
	var center: Vector3 = REGION_CENTERS[region_index]
	var local_x := (world_x - center.x) / REGION_LINEAR_SCALE
	var local_z := (world_z - center.z) / REGION_LINEAR_SCALE
	return center.y + _zone_height(source_index, local_x, local_z)


func _update_current_zone() -> void:
	if not is_instance_valid(player):
		return

	var previous: int = current_zone
	var best_distance := INF

	for region_index in range(REGION_CENTERS.size()):
		var distance := Vector2(
			player.global_position.x - REGION_CENTERS[region_index].x,
			player.global_position.z - REGION_CENTERS[region_index].z
		).length_squared()

		if distance < best_distance:
			best_distance = distance
			current_zone = region_index

	if current_zone != previous:
		_show_zone_banner()
		_update_hud()


func _update_hud() -> void:
	if not is_instance_valid(player):
		return

	var source_index: int = USER_TO_SOURCE[current_zone]
	var collected := 0
	if is_instance_valid(population_manager):
		collected = population_manager.get_collected_count()

	if is_instance_valid(health_label):
		health_label.text = "VIE %d / %d" % [player.health, player.max_health]

	if is_instance_valid(zone_label):
		zone_label.text = "RÉGION %d / 10 — %s" % [
			current_zone + 1,
			REGION_NAMES[current_zone]
		]

	if is_instance_valid(objective_label):
		var remaining := (
			int(zone_remaining[source_index])
			if source_index < zone_remaining.size()
			else 0
		)
		objective_label.text = (
			"Gardiens restants : %d  •  Cristaux : %d / 30"
			% [remaining, collected]
		)


func _show_zone_banner() -> void:
	if not is_instance_valid(zone_banner):
		return

	zone_banner_token += 1
	var token: int = zone_banner_token
	zone_banner.text = "RÉGION %d\n%s" % [
		current_zone + 1,
		REGION_NAMES[current_zone]
	]
	zone_banner.modulate = REGION_ACCENT_COLORS[current_zone]
	zone_banner.visible = true

	await get_tree().create_timer(2.4).timeout
	if token == zone_banner_token and is_instance_valid(zone_banner):
		zone_banner.visible = false


func _add_zone_numbers(frame, font_size, show_names) -> void:
	for region_index in range(REGION_MAP_MARKERS.size()):
		var label := Label.new()
		label.text = str(region_index + 1)

		if show_names:
			label.tooltip_text = REGION_NAMES[region_index]

		label.size = Vector2(34.0, 28.0)
		label.position = Vector2(
			REGION_MAP_MARKERS[region_index].x * frame.size.x - 17.0,
			REGION_MAP_MARKERS[region_index].y * frame.size.y - 14.0
		)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.modulate = REGION_ACCENT_COLORS[region_index]
		label.add_theme_font_size_override("font_size", font_size)
		label.add_theme_constant_override("outline_size", 5)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.add_child(label)


func _calculate_live_marker() -> Vector2:
	if not is_instance_valid(player):
		return REGION_MAP_MARKERS[EXP_START_REGION]

	var region_index: int = current_zone
	var center: Vector3 = REGION_CENTERS[region_index]
	var local := Vector2(
		(player.global_position.x - center.x) / 150.0,
		(player.global_position.z - center.z) / 135.0
	)
	return REGION_MAP_MARKERS[region_index] + local.limit_length(0.055)


func _build_hud() -> void:
	super._build_hud()
	_build_pause_menu()


func _build_controls_help(root) -> void:
	super._build_controls_help(root)

	if is_instance_valid(controls_help_label):
		controls_help_label.text = (
			"JOYSTICK : BOUGER  •  SAUT SUR L'EAU : VOL 5 s"
			+ "  •  INTERAGIR : PARLER / EXPLORER"
		)


func _jump_button_pressed() -> void:
	if (
		is_instance_valid(player)
		and bool(player.get("in_water"))
		and player.has_method("request_water_flight")
	):
		if player.request_water_flight():
			_show_message(
				"Vol aquatique activé : 5 secondes pour rejoindre la terre.",
				3.0
			)
			return

	super._jump_button_pressed()


func _update_water_hud() -> void:
	super._update_water_hud()

	if not is_instance_valid(player) or not player.has_method("get_water_debug"):
		return

	var water: Dictionary = player.get_water_debug()
	if (
		bool(water.get("flight_active", false))
		and is_instance_valid(water_status_label)
	):
		var remaining := float(water.get("flight_remaining", 0.0))
		water_status_label.text = (
			"VOL AQUATIQUE  •  %.1f s  •  REJOINS LA TERRE"
			% remaining
		)
		water_status_label.modulate = Color(1.0, 0.86, 0.32)


func _on_interact() -> void:
	if (
		is_instance_valid(population_manager)
		and population_manager.try_interact(current_zone)
	):
		return

	super._on_interact()


func _build_pause_menu() -> void:
	pause_layer = CanvasLayer.new()
	pause_layer.name = "PauseLayer"
	pause_layer.layer = 40
	pause_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(pause_layer)

	pause_button = Button.new()
	pause_button.text = "PAUSE"
	pause_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	pause_button.position = Vector2(-292.0, 12.0)
	pause_button.size = Vector2(110.0, 56.0)
	pause_button.process_mode = Node.PROCESS_MODE_ALWAYS
	pause_button.pressed.connect(_toggle_pause)
	pause_layer.add_child(pause_button)

	weather_label = Label.new()
	weather_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	weather_label.position = Vector2(-430.0, 92.0)
	weather_label.size = Vector2(250.0, 38.0)
	weather_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	weather_label.add_theme_font_size_override("font_size", 17)
	weather_label.add_theme_constant_override("outline_size", 5)
	weather_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pause_layer.add_child(weather_label)

	pause_panel = ColorRect.new()
	pause_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pause_panel.color = Color(0.01, 0.02, 0.05, 0.94)
	pause_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	pause_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	pause_panel.visible = false
	pause_layer.add_child(pause_panel)

	var title := Label.new()
	title.text = "JEU EN PAUSE"
	title.set_anchors_preset(Control.PRESET_CENTER)
	title.position = Vector2(-260.0, -120.0)
	title.size = Vector2(520.0, 70.0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 38)
	title.add_theme_constant_override("outline_size", 8)
	pause_panel.add_child(title)

	var resume := Button.new()
	resume.text = "REPRENDRE"
	resume.set_anchors_preset(Control.PRESET_CENTER)
	resume.position = Vector2(-160.0, -20.0)
	resume.size = Vector2(320.0, 64.0)
	resume.process_mode = Node.PROCESS_MODE_ALWAYS
	resume.pressed.connect(_toggle_pause)
	pause_panel.add_child(resume)


func _toggle_pause() -> void:
	var new_paused := not get_tree().paused
	get_tree().paused = new_paused

	if is_instance_valid(pause_panel):
		pause_panel.visible = new_paused

	if is_instance_valid(pause_button):
		pause_button.visible = not new_paused


func _refresh_expansion_hud() -> void:
	if is_instance_valid(weather_label) and is_instance_valid(weather_manager):
		weather_label.text = weather_manager.get_status_text()

	if is_instance_valid(map_zone_label):
		map_zone_label.text = "Région %d — %s" % [
			current_zone + 1,
			REGION_NAMES[current_zone]
		]

	if is_instance_valid(map_status_label):
		var collected := 0
		if is_instance_valid(population_manager):
			collected = population_manager.get_collected_count()
		map_status_label.text = (
			"200 habitants actifs  •  %d / 30 cristaux  •  météo dynamique"
			% collected
		)


func _make_static_box(
	node_name: String,
	size_value: Vector3,
	position_value: Vector3,
	color: Color
) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.collision_layer = 1
	body.collision_mask = 1
	body.position = position_value

	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size_value
	collision.shape = shape
	body.add_child(collision)

	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size_value
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.82
	mesh.material = material
	visual.mesh = mesh
	body.add_child(visual)

	add_child(body)
	return body


func _load_progress() -> void:
	var version_config := ConfigFile.new()
	var layout_version := 0

	if version_config.load(SAVE_PATH) == OK:
		layout_version = int(
			version_config.get_value("world", "layout_version", 0)
		)

	super._load_progress()

	if layout_version < SAVE_LAYOUT_VERSION and is_instance_valid(player):
		var source_index := _nearest_source_zone(player.global_position)
		var region_index: int = _source_to_region(source_index)
		player.global_position = _map_source_position_to_region(
			player.global_position,
			source_index,
			region_index
		)
		player.set_spawn(player.global_position)
		current_zone = region_index


func _restore_expansion_progress() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return

	if is_instance_valid(population_manager):
		population_manager.set_collected_count(
			int(config.get_value("world", "collected_count", 0))
		)


func _save_progress() -> void:
	super._save_progress()

	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return

	config.set_value("world", "layout_version", SAVE_LAYOUT_VERSION)

	if is_instance_valid(population_manager):
		config.set_value(
			"world",
			"collected_count",
			population_manager.get_collected_count()
		)

	config.save(SAVE_PATH)
