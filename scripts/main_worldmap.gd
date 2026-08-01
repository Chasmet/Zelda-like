extends Node3D

const PLAYER_SCRIPT = preload("res://scripts/player.gd")
const ENEMY_SCRIPT = preload("res://scripts/enemy.gd")

const WORLD_MAP_PATH = "res://carte monde.png"
const HERO_MODEL = "res://generated_models/hero_knight.glb"
const TREE_MODEL = "res://generated_models/world_tree.glb"
const HOUSE_MODEL = "res://generated_models/village_house.glb"
const RUIN_MODEL = "res://generated_models/ruin_gate.glb"
const BOAT_MODEL = "res://generated_models/boat.glb"
const MUSIC_WORLD_PATH = "res://music.mp3"
const MUSIC_BATTLE_PATH = "res://music 2.mp3"
const SAVE_PATH = "user://skypiea_worldmap_v2.cfg"

const ENEMY_MODELS = [
	"res://generated_models/enemy_01_armored_boar.glb",
	"res://generated_models/enemy_02_crystal_golem.glb",
	"res://generated_models/enemy_03_lava_hound.glb",
	"res://generated_models/enemy_04_anubis_knight.glb",
	"res://generated_models/enemy_05_goblin_raider.glb",
	"res://generated_models/enemy_06_ice_ogre.glb",
	"res://generated_models/enemy_07_orc_warlord.glb"
]

# Les numéros, l'emplacement et l'identité des zones suivent enfin carte monde.png.
const ZONE_NAMES = [
	"Forge Volcanique",
	"Forêt des Cascades",
	"Pics de Glace",
	"Désert du Colosse",
	"Marais des Ombres",
	"Ruines du Soleil",
	"Mer des Pirates",
	"Village des Sources",
	"Royaume Central",
	"Île Céleste"
]

const ZONE_CENTERS = [
	Vector3(-78.0, 0.0, -72.0), # 1 volcan
	Vector3(-70.0, 0.0, -20.0), # 2 forêt
	Vector3(82.0, 0.0, -65.0),  # 3 glace
	Vector3(78.0, 0.0, -10.0),  # 4 désert
	Vector3(88.0, 0.0, 48.0),   # 5 marais sombre
	Vector3(38.0, 0.0, 52.0),   # 6 ruines
	Vector3(-88.0, 0.0, 28.0),  # 7 mer pirate
	Vector3(-58.0, 0.0, 62.0),  # 8 village
	Vector3(0.0, 0.0, 15.0),    # 9 royaume central
	Vector3(0.0, 28.0, -72.0)   # 10 île céleste
]

const MAP_MARKERS = [
	Vector2(0.22, 0.16),
	Vector2(0.16, 0.38),
	Vector2(0.73, 0.15),
	Vector2(0.82, 0.39),
	Vector2(0.84, 0.70),
	Vector2(0.70, 0.69),
	Vector2(0.18, 0.64),
	Vector2(0.235, 0.82),
	Vector2(0.50, 0.45),
	Vector2(0.50, 0.085)
]

const ZONE_BASE_COLORS = [
	Color(0.16, 0.12, 0.11),
	Color(0.07, 0.28, 0.08),
	Color(0.60, 0.76, 0.86),
	Color(0.66, 0.48, 0.22),
	Color(0.08, 0.20, 0.14),
	Color(0.64, 0.50, 0.25),
	Color(0.10, 0.38, 0.42),
	Color(0.20, 0.48, 0.16),
	Color(0.24, 0.50, 0.19),
	Color(0.46, 0.58, 0.58)
]

const ZONE_ACCENT_COLORS = [
	Color(0.82, 0.12, 0.01),
	Color(0.18, 0.52, 0.12),
	Color(0.82, 0.94, 1.0),
	Color(0.88, 0.70, 0.35),
	Color(0.10, 0.48, 0.23),
	Color(0.82, 0.67, 0.34),
	Color(0.02, 0.67, 0.82),
	Color(0.46, 0.70, 0.25),
	Color(0.62, 0.72, 0.26),
	Color(0.80, 0.86, 0.82)
]

const START_ZONE = 7
const TERRAIN_SIZE = Vector2(46.0, 42.0)
const TERRAIN_STEPS = 20

var player
var enemies = []
var zone_remaining = []
var zone_total = []
var zone_completed = []
var current_zone = START_ZONE
var total_defeated = 0
var game_complete = false

var virtual_move = Vector2.ZERO
var move_touch_id = -1
var look_touch_id = -1
var move_origin = Vector2.ZERO
var joystick_knob

var health_label
var zone_label
var objective_label
var message_label
var map_panel
var map_frame
var map_player_marker
var map_zone_label
var map_status_label
var map_button
var zone_banner
var zone_banner_token = 0

var music_player
var battle_music_active = false
var zone_check_timer = 0.0
var message_token = 0
var terrain_material_cache = {}

var boot_layer
var boot_label
var boot_camera

var capital_portal_position = Vector3.ZERO
var sky_portal_position = Vector3.ZERO


func _ready():
	seed(20260801)
	if OS.has_feature("mobile"):
		DisplayServer.screen_set_orientation(DisplayServer.SCREEN_SENSOR_LANDSCAPE)

	_setup_input()
	_build_loading_screen()
	await get_tree().process_frame

	_set_loading_text("Création du ciel, de l'océan et des textures…")
	_build_environment()
	await get_tree().process_frame

	for zone_index in range(ZONE_CENTERS.size()):
		_set_loading_text("Construction du relief %d / 10\n%s" % [zone_index + 1, ZONE_NAMES[zone_index]])
		_build_zone(zone_index)
		await get_tree().process_frame

	_set_loading_text("Création des routes, ponts et repères…")
	_build_routes()
	_build_portals()
	await get_tree().process_frame

	_set_loading_text("Chargement du héros…")
	_spawn_player()
	await get_tree().process_frame

	_set_loading_text("Placement des gardiens…")
	_spawn_guardians()
	await get_tree().process_frame

	_build_hud()
	_load_progress()
	_update_hud()
	_update_map_marker()
	_play_music(MUSIC_WORLD_PATH)
	_finish_loading()
	_show_zone_banner()
	_show_message("La carte est disponible avec le bouton CARTE", 4.5)


func _process(delta):
	if not is_instance_valid(player):
		return

	player.set_virtual_move(virtual_move)
	zone_check_timer -= delta
	if zone_check_timer <= 0.0:
		zone_check_timer = 0.18
		_update_current_zone()

	if is_instance_valid(map_player_marker):
		var pulse = 1.0 + sin(Time.get_ticks_msec() * 0.006) * 0.12
		map_player_marker.scale = Vector2.ONE * pulse

	_update_battle_music()


func _notification(what):
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save_progress()


func _unhandled_input(event):
	if event is InputEventScreenTouch:
		var screen_size = get_viewport().get_visible_rect().size
		if is_instance_valid(map_panel) and map_panel.visible:
			return
		if event.pressed and event.position.x < screen_size.x * 0.43 and event.position.y > screen_size.y * 0.28 and move_touch_id < 0:
			move_touch_id = event.index
			move_origin = event.position
			_update_joystick(event.position)
		elif event.pressed and look_touch_id < 0:
			look_touch_id = event.index
		elif not event.pressed and event.index == move_touch_id:
			move_touch_id = -1
			virtual_move = Vector2.ZERO
			_reset_joystick()
		elif not event.pressed and event.index == look_touch_id:
			look_touch_id = -1
	elif event is InputEventScreenDrag:
		if is_instance_valid(map_panel) and map_panel.visible:
			return
		if event.index == move_touch_id:
			_update_joystick(event.position)
		elif event.index == look_touch_id and is_instance_valid(player):
			player.add_camera_look(event.relative * 0.0042)


func _setup_input():
	_add_key("move_forward", KEY_W)
	_add_key("move_forward", KEY_Z)
	_add_key("move_forward", KEY_UP)
	_add_key("move_back", KEY_S)
	_add_key("move_back", KEY_DOWN)
	_add_key("move_left", KEY_A)
	_add_key("move_left", KEY_Q)
	_add_key("move_left", KEY_LEFT)
	_add_key("move_right", KEY_D)
	_add_key("move_right", KEY_RIGHT)
	_add_key("jump", KEY_SPACE)
	_add_key("attack", KEY_F)
	_add_key("dodge", KEY_SHIFT)
	_add_key("interact", KEY_E)
	_add_key("sprint", KEY_CTRL)
	_add_key("world_map", KEY_M)

	if not InputMap.has_action("attack"):
		InputMap.add_action("attack")
	var mouse = InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	InputMap.action_add_event("attack", mouse)


func _add_key(action, keycode):
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var key_event = InputEventKey.new()
	key_event.physical_keycode = keycode
	InputMap.action_add_event(action, key_event)


func _build_loading_screen():
	boot_camera = Camera3D.new()
	boot_camera.position = Vector3(-55.0, 38.0, 96.0)
	add_child(boot_camera)
	boot_camera.look_at(ZONE_CENTERS[START_ZONE], Vector3.UP)
	boot_camera.current = true

	boot_layer = CanvasLayer.new()
	boot_layer.layer = 100
	add_child(boot_layer)

	var background = ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = Color(0.01, 0.025, 0.055, 1.0)
	boot_layer.add_child(background)

	if ResourceLoader.exists(WORLD_MAP_PATH):
		var map_preview = TextureRect.new()
		map_preview.texture = load(WORLD_MAP_PATH)
		map_preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		map_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		map_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		map_preview.modulate = Color(0.55, 0.62, 0.72, 0.52)
		background.add_child(map_preview)

	var shade = ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.01, 0.02, 0.045, 0.56)
	background.add_child(shade)

	var title = Label.new()
	title.text = "LES CHRONIQUES DE SKYPIEA"
	title.set_anchors_preset(Control.PRESET_CENTER)
	title.position = Vector2(-430.0, -112.0)
	title.size = Vector2(860.0, 64.0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	shade.add_child(title)

	boot_label = Label.new()
	boot_label.text = "Lecture de la carte du monde…"
	boot_label.set_anchors_preset(Control.PRESET_CENTER)
	boot_label.position = Vector2(-430.0, -20.0)
	boot_label.size = Vector2(860.0, 105.0)
	boot_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boot_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	boot_label.add_theme_font_size_override("font_size", 23)
	shade.add_child(boot_label)


func _set_loading_text(text):
	if is_instance_valid(boot_label):
		boot_label.text = text


func _finish_loading():
	if is_instance_valid(boot_layer):
		boot_layer.queue_free()
	if is_instance_valid(boot_camera):
		boot_camera.queue_free()


func _build_environment():
	var world_environment = WorldEnvironment.new()
	var environment = Environment.new()
	environment.background_mode = Environment.BG_SKY

	var sky = Sky.new()
	var sky_material = ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.02, 0.12, 0.33)
	sky_material.sky_horizon_color = Color(0.67, 0.84, 0.98)
	sky_material.ground_bottom_color = Color(0.01, 0.03, 0.055)
	sky_material.ground_horizon_color = Color(0.30, 0.43, 0.34)
	sky.sky_material = sky_material

	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.88
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.fog_enabled = true
	environment.fog_density = 0.0018
	environment.fog_light_color = Color(0.64, 0.76, 0.88)
	world_environment.environment = environment
	add_child(world_environment)

	var sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50.0, -32.0, 0.0)
	sun.light_energy = 1.5
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 105.0
	add_child(sun)

	var ocean = MeshInstance3D.new()
	var ocean_mesh = PlaneMesh.new()
	ocean_mesh.size = Vector2(260.0, 220.0)
	var ocean_material = StandardMaterial3D.new()
	ocean_material.albedo_color = Color(0.015, 0.24, 0.43, 0.94)
	ocean_material.metallic = 0.20
	ocean_material.roughness = 0.16
	ocean_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ocean_mesh.material = ocean_material
	ocean.mesh = ocean_mesh
	ocean.position.y = -0.92
	add_child(ocean)


func _build_zone(zone_index):
	_build_terrain(zone_index)
	_add_zone_title(zone_index)

	match zone_index:
		0:
			_decorate_volcano(zone_index)
		1:
			_decorate_forest(zone_index)
		2:
			_decorate_ice(zone_index)
		3:
			_decorate_desert(zone_index)
		4:
			_decorate_dark_marsh(zone_index)
		5:
			_decorate_ruins(zone_index)
		6:
			_decorate_pirate_coast(zone_index)
		7:
			_decorate_village(zone_index)
		8:
			_decorate_capital(zone_index)
		9:
			_decorate_sky_island(zone_index)


func _build_terrain(zone_index):
	var center = ZONE_CENTERS[zone_index]
	var surface = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_material(_terrain_material(zone_index))

	var step_x = TERRAIN_SIZE.x / float(TERRAIN_STEPS)
	var step_z = TERRAIN_SIZE.y / float(TERRAIN_STEPS)

	for z_index in range(TERRAIN_STEPS):
		for x_index in range(TERRAIN_STEPS):
			var x0 = -TERRAIN_SIZE.x * 0.5 + float(x_index) * step_x
			var x1 = x0 + step_x
			var z0 = -TERRAIN_SIZE.y * 0.5 + float(z_index) * step_z
			var z1 = z0 + step_z

			var p00 = Vector3(x0, _zone_height(zone_index, x0, z0), z0)
			var p10 = Vector3(x1, _zone_height(zone_index, x1, z0), z0)
			var p01 = Vector3(x0, _zone_height(zone_index, x0, z1), z1)
			var p11 = Vector3(x1, _zone_height(zone_index, x1, z1), z1)

			var uv00 = Vector2(float(x_index) / float(TERRAIN_STEPS), float(z_index) / float(TERRAIN_STEPS)) * 7.0
			var uv10 = Vector2(float(x_index + 1) / float(TERRAIN_STEPS), float(z_index) / float(TERRAIN_STEPS)) * 7.0
			var uv01 = Vector2(float(x_index) / float(TERRAIN_STEPS), float(z_index + 1) / float(TERRAIN_STEPS)) * 7.0
			var uv11 = Vector2(float(x_index + 1) / float(TERRAIN_STEPS), float(z_index + 1) / float(TERRAIN_STEPS)) * 7.0

			surface.set_uv(uv00)
			surface.add_vertex(p00)
			surface.set_uv(uv01)
			surface.add_vertex(p01)
			surface.set_uv(uv11)
			surface.add_vertex(p11)

			surface.set_uv(uv00)
			surface.add_vertex(p00)
			surface.set_uv(uv11)
			surface.add_vertex(p11)
			surface.set_uv(uv10)
			surface.add_vertex(p10)

	surface.generate_normals()
	var terrain_mesh = surface.commit()

	var body = StaticBody3D.new()
	body.name = "Zone_%02d_Terrain" % (zone_index + 1)
	body.position = center

	var visual = MeshInstance3D.new()
	visual.mesh = terrain_mesh
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	body.add_child(visual)

	var collision = CollisionShape3D.new()
	var shape = ConcavePolygonShape3D.new()
	shape.set_faces(terrain_mesh.get_faces())
	collision.shape = shape
	body.add_child(collision)
	add_child(body)


func _zone_height(zone_index, local_x, local_z):
	var nx = local_x / (TERRAIN_SIZE.x * 0.5)
	var nz = local_z / (TERRAIN_SIZE.y * 0.5)
	var edge = max(abs(nx), abs(nz))
	var island = clamp((1.0 - edge) / 0.20, 0.0, 1.0)
	island = island * island * (3.0 - 2.0 * island)

	var wave = sin(local_x * 0.21 + float(zone_index) * 0.7) * 0.35
	wave += cos(local_z * 0.24 - float(zone_index) * 0.5) * 0.30
	wave += sin((local_x + local_z) * 0.13) * 0.22
	var core = 1.1 + wave

	match zone_index:
		0:
			var radius = Vector2(nx, nz).length()
			var cone = max(0.0, 1.0 - radius) * 10.5
			var crater = exp(-pow((radius - 0.18) * 11.0, 2.0)) * 4.0
			core = 1.1 + cone - crater + wave * 0.45
		1:
			core = 1.5 + wave * 1.4 + exp(-((nx + 0.38) * (nx + 0.38) + (nz - 0.18) * (nz - 0.18)) * 5.0) * 3.0
		2:
			var peak_a = exp(-((nx + 0.28) * (nx + 0.28) + (nz + 0.12) * (nz + 0.12)) * 7.0) * 8.0
			var peak_b = exp(-((nx - 0.25) * (nx - 0.25) + (nz - 0.22) * (nz - 0.22)) * 9.0) * 6.2
			core = 1.7 + peak_a + peak_b + wave * 0.7
		3:
			core = 1.2 + sin(local_x * 0.35) * 0.55 + cos(local_z * 0.30) * 0.45 + wave * 0.55
		4:
			core = 0.75 + wave * 0.55
		5:
			var plateau = exp(-((nx + 0.08) * (nx + 0.08) + (nz + 0.08) * (nz + 0.08)) * 2.8) * 2.4
			core = 1.4 + plateau + wave * 0.50
		6:
			core = 0.55 + wave * 0.45
		7:
			core = 1.7 + wave * 0.65 + max(0.0, -nz) * 0.8
		8:
			var royal_plateau = exp(-(nx * nx + nz * nz) * 3.4) * 2.8
			core = 1.5 + royal_plateau + wave * 0.45
		9:
			var sky_hill = exp(-(nx * nx + nz * nz) * 2.6) * 3.4
			core = 1.4 + sky_hill + wave * 0.55

	var edge_height = -0.72
	if zone_index == 9:
		edge_height = -2.2
	return lerp(edge_height, core, island)


func _terrain_world_height(zone_index, world_x, world_z):
	var center = ZONE_CENTERS[zone_index]
	return center.y + _zone_height(zone_index, world_x - center.x, world_z - center.z)


func _terrain_material(zone_index):
	if terrain_material_cache.has(zone_index):
		return terrain_material_cache[zone_index]

	var material = StandardMaterial3D.new()
	material.albedo_color = Color.WHITE
	material.albedo_texture = _create_biome_texture(zone_index)
	material.roughness = 0.76
	material.metallic = 0.04 if zone_index in [0, 2, 9] else 0.0
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	terrain_material_cache[zone_index] = material
	return material


func _create_biome_texture(zone_index):
	var image = Image.create(64, 64, false, Image.FORMAT_RGBA8)
	var base = ZONE_BASE_COLORS[zone_index]
	var accent = ZONE_ACCENT_COLORS[zone_index]

	for y in range(64):
		for x in range(64):
			var seed_value = sin(float(x * 37 + y * 71 + zone_index * 193)) * 43758.5453
			var random_value = seed_value - floor(seed_value)
			var broad = (sin(float(x) * 0.24) + cos(float(y) * 0.19)) * 0.11
			var amount = clamp(random_value * 0.42 + 0.18 + broad, 0.0, 0.78)
			if zone_index == 3:
				amount += sin(float(x + y) * 0.34) * 0.12
			elif zone_index == 2:
				amount = clamp(amount + 0.18, 0.0, 0.86)
			elif zone_index == 4:
				amount *= 0.72
			image.set_pixel(x, y, base.lerp(accent, amount))

	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)


func _decorate_volcano(zone_index):
	var center = ZONE_CENTERS[zone_index]
	_add_disc(center + Vector3(0.0, 7.3, 0.0), 5.2, Color(0.98, 0.10, 0.01), Color(1.0, 0.05, 0.0))
	for index in range(13):
		var angle = TAU * float(index) / 13.0
		var radius = 12.0 + float(index % 3) * 3.0
		_add_rock(zone_index, Vector3(cos(angle) * radius, 0.0, sin(angle) * radius), Vector3(2.0, 2.6 + float(index % 4), 2.0), Color(0.075, 0.065, 0.06))
	for lane in [-1.0, 1.0]:
		var channel = _visual_box("LavaChannel", Vector3(2.2, 0.12, 19.0), center + Vector3(lane * 5.0, 2.2, 7.0), Color(0.95, 0.11, 0.01), Color(1.0, 0.05, 0.0))
		channel.rotation.y = lane * 0.32


func _decorate_forest(zone_index):
	for index in range(24):
		var x = -18.0 + float((index * 13) % 37)
		var z = -16.0 + float((index * 19) % 33)
		if abs(x) < 4.5 and abs(z) < 9.0:
			x += 8.0
		_place_model(TREE_MODEL, zone_index, Vector3(x, 0.0, z), Vector3.ONE * (0.72 + float(index % 5) * 0.08), Vector3(0.0, float(index) * 0.43, 0.0))
	_add_water_patch(zone_index, Vector3(-13.0, 0.0, 9.0), Vector2(11.0, 7.0), Color(0.02, 0.42, 0.54, 0.82))
	_add_waterfall(zone_index, Vector3(-18.5, 2.5, 10.0), Vector2(4.0, 6.5))


func _decorate_ice(zone_index):
	for index in range(18):
		var angle = TAU * float(index) / 18.0
		var radius = 9.0 + float(index % 4) * 3.0
		_add_crystal(zone_index, Vector3(cos(angle) * radius, 0.0, sin(angle) * radius), 1.1 + float(index % 4) * 0.35, Color(0.42, 0.84, 1.0))
	for offset in [Vector3(-15.0, 0.0, -13.0), Vector3(15.0, 0.0, 11.0), Vector3(0.0, 0.0, 16.0)]:
		_add_rock(zone_index, offset, Vector3(4.5, 3.2, 4.0), Color(0.54, 0.66, 0.75))


func _decorate_desert(zone_index):
	for index in range(10):
		var x = -19.0 + float((index * 11) % 39)
		var z = -15.0 + float((index * 17) % 31)
		_add_rock(zone_index, Vector3(x, 0.0, z), Vector3(2.5 + float(index % 3), 1.6 + float(index % 2), 2.2), Color(0.52, 0.31, 0.13))
	_add_colossus(zone_index, Vector3(11.0, 0.0, 3.0))
	_place_model(RUIN_MODEL, zone_index, Vector3(-10.0, 0.0, -11.0), Vector3.ONE * 1.25, Vector3.ZERO)


func _decorate_dark_marsh(zone_index):
	for offset in [Vector3(-13.0, 0.0, -10.0), Vector3(12.0, 0.0, -7.0), Vector3(-7.0, 0.0, 11.0), Vector3(13.0, 0.0, 12.0)]:
		_add_water_patch(zone_index, offset, Vector2(11.0, 7.0), Color(0.04, 0.35, 0.17, 0.82), Color(0.02, 0.85, 0.16))
	for index in range(12):
		var x = -18.0 + float((index * 15) % 37)
		var z = -16.0 + float((index * 23) % 33)
		_place_model(TREE_MODEL, zone_index, Vector3(x, 0.0, z), Vector3(0.52, 0.82, 0.52), Vector3(0.0, float(index), 0.0))
	for offset in [Vector3(-18.0, 0.0, 15.0), Vector3(17.0, 0.0, -14.0), Vector3(2.0, 0.0, -16.0)]:
		_add_crystal(zone_index, offset, 1.4, Color(0.08, 1.0, 0.34))


func _decorate_ruins(zone_index):
	_add_pyramid(zone_index, Vector3(0.0, 0.0, -7.0), 7.2)
	_add_pyramid(zone_index, Vector3(-12.0, 0.0, 8.0), 4.4)
	for offset in [Vector3(-16.0, 0.0, -12.0), Vector3(16.0, 0.0, -12.0), Vector3(-16.0, 0.0, 14.0), Vector3(16.0, 0.0, 14.0)]:
		_add_column(zone_index, offset, 5.2)
	_place_model(RUIN_MODEL, zone_index, Vector3(11.0, 0.0, 9.0), Vector3.ONE * 1.35, Vector3(0.0, -0.55, 0.0))


func _decorate_pirate_coast(zone_index):
	_add_water_patch(zone_index, Vector3(0.0, 0.0, -5.0), Vector2(38.0, 12.0), Color(0.02, 0.46, 0.68, 0.90))
	_place_model(BOAT_MODEL, zone_index, Vector3(-2.0, 0.45, -6.0), Vector3.ONE * 1.08, Vector3(0.0, -0.35, 0.0))
	for index in range(10):
		var angle = TAU * float(index) / 10.0
		_add_rock(zone_index, Vector3(cos(angle) * 18.0, 0.0, sin(angle) * 15.0), Vector3(2.4, 1.5 + float(index % 3), 2.2), Color(0.26, 0.28, 0.27))
	for offset in [Vector3(-16.0, 0.0, 13.0), Vector3(16.0, 0.0, 13.0)]:
		_place_model(TREE_MODEL, zone_index, offset, Vector3(0.60, 0.88, 0.60), Vector3.ZERO)


func _decorate_village(zone_index):
	for offset in [Vector3(-13.0, 0.0, -9.0), Vector3(0.0, 0.0, -12.0), Vector3(13.0, 0.0, -8.0), Vector3(-13.0, 0.0, 10.0), Vector3(13.0, 0.0, 10.0)]:
		_place_model(HOUSE_MODEL, zone_index, offset, Vector3.ONE * 0.92, Vector3(0.0, offset.x * 0.02, 0.0))
	for index in range(18):
		var angle = TAU * float(index) / 18.0
		var radius = 17.0 + float(index % 3) * 2.0
		_place_model(TREE_MODEL, zone_index, Vector3(cos(angle) * radius, 0.0, sin(angle) * radius), Vector3.ONE * (0.76 + float(index % 4) * 0.07), Vector3(0.0, angle, 0.0))
	_add_path(zone_index, Vector3(0.0, 0.25, 0.0), Vector3(7.0, 0.16, 35.0), 0.0)
	_add_waterfall(zone_index, Vector3(-20.0, 1.8, 8.0), Vector2(3.5, 5.0))


func _decorate_capital(zone_index):
	_add_path(zone_index, Vector3(0.0, 0.15, 5.0), Vector3(8.0, 0.16, 34.0), 0.0)
	for x_value in [-16.0, -8.0, 8.0, 16.0]:
		_add_tower(zone_index, Vector3(x_value, 0.0, -12.0), 7.5)
	_add_wall(zone_index, Vector3(0.0, 0.0, -17.0), Vector3(40.0, 5.2, 2.4))
	_place_model(RUIN_MODEL, zone_index, Vector3(0.0, 0.0, -8.0), Vector3.ONE * 1.72, Vector3.ZERO)
	for offset in [Vector3(-15.0, 0.0, 10.0), Vector3(15.0, 0.0, 10.0), Vector3(-10.0, 0.0, 17.0), Vector3(10.0, 0.0, 17.0)]:
		_place_model(HOUSE_MODEL, zone_index, offset, Vector3.ONE * 0.82, Vector3(0.0, PI, 0.0))


func _decorate_sky_island(zone_index):
	_place_model(RUIN_MODEL, zone_index, Vector3(0.0, 0.0, -7.0), Vector3.ONE * 1.65, Vector3.ZERO)
	_place_model(TREE_MODEL, zone_index, Vector3(0.0, 0.0, 9.0), Vector3.ONE * 1.45, Vector3.ZERO)
	for index in range(12):
		var angle = TAU * float(index) / 12.0
		var radius = 15.0 + float(index % 3) * 3.0
		_add_crystal(zone_index, Vector3(cos(angle) * radius, 0.0, sin(angle) * radius), 1.0 + float(index % 3) * 0.3, Color(0.75, 0.94, 1.0))
		var floating = _add_rock(zone_index, Vector3(cos(angle) * (radius + 8.0), -5.0 - float(index % 4), sin(angle) * (radius + 8.0)), Vector3(2.8, 4.0, 2.8), Color(0.43, 0.50, 0.52))
		if is_instance_valid(floating):
			floating.rotation = Vector3(float(index) * 0.11, float(index) * 0.23, float(index) * 0.09)


func _build_routes():
	_build_bridge(7, 6, 7.0, Color(0.42, 0.30, 0.17))
	_build_bridge(6, 1, 6.5, Color(0.34, 0.27, 0.18))
	_build_bridge(1, 0, 6.0, Color(0.28, 0.22, 0.17))
	_build_bridge(7, 8, 8.0, Color(0.48, 0.35, 0.20))
	_build_bridge(1, 8, 7.0, Color(0.36, 0.31, 0.19))
	_build_bridge(8, 5, 8.0, Color(0.52, 0.40, 0.22))
	_build_bridge(5, 4, 7.0, Color(0.48, 0.38, 0.22))
	_build_bridge(5, 3, 7.0, Color(0.52, 0.41, 0.23))
	_build_bridge(3, 2, 6.5, Color(0.58, 0.50, 0.36))


func _build_bridge(zone_a, zone_b, width, color):
	var start = ZONE_CENTERS[zone_a]
	var finish = ZONE_CENTERS[zone_b]
	var delta = finish - start
	var horizontal = Vector3(delta.x, 0.0, delta.z)
	var length = horizontal.length()
	if length < 1.0:
		return

	var midpoint = (start + finish) * 0.5
	midpoint.y = 1.35
	var bridge = _static_box("Route_%02d_%02d" % [zone_a + 1, zone_b + 1], Vector3(width, 0.55, length), midpoint, color)
	bridge.rotation.y = atan2(horizontal.x, horizontal.z)

	var left_rail = _visual_box("Rail", Vector3(0.20, 0.65, length), midpoint + Vector3(-width * 0.48, 0.55, 0.0), Color(0.24, 0.16, 0.08))
	left_rail.rotation.y = bridge.rotation.y
	var right_rail = _visual_box("Rail", Vector3(0.20, 0.65, length), midpoint + Vector3(width * 0.48, 0.55, 0.0), Color(0.24, 0.16, 0.08))
	right_rail.rotation.y = bridge.rotation.y


func _build_portals():
	var capital = ZONE_CENTERS[8]
	capital_portal_position = Vector3(capital.x, _terrain_world_height(8, capital.x, capital.z - 12.0) + 0.4, capital.z - 12.0)
	_add_portal(capital_portal_position, Color(0.30, 0.72, 1.0), "PORTAIL VERS L'ÎLE CÉLESTE")

	var sky = ZONE_CENTERS[9]
	sky_portal_position = Vector3(sky.x, _terrain_world_height(9, sky.x, sky.z + 11.0) + 0.4, sky.z + 11.0)
	_add_portal(sky_portal_position, Color(1.0, 0.78, 0.24), "RETOUR AU ROYAUME")


func _add_portal(position, color, text):
	var anchor = Node3D.new()
	anchor.position = position
	add_child(anchor)

	var ring = MeshInstance3D.new()
	var torus = TorusMesh.new()
	torus.inner_radius = 1.35
	torus.outer_radius = 1.72
	var portal_material = StandardMaterial3D.new()
	portal_material.albedo_color = color
	portal_material.emission_enabled = true
	portal_material.emission = color
	portal_material.emission_energy_multiplier = 3.0
	torus.material = portal_material
	ring.mesh = torus
	ring.rotation.x = PI * 0.5
	ring.position.y = 1.8
	anchor.add_child(ring)

	var light = OmniLight3D.new()
	light.light_color = color
	light.light_energy = 3.2
	light.omni_range = 8.0
	light.position.y = 1.8
	anchor.add_child(light)
	_add_world_label(anchor, text, Vector3(0.0, 4.0, 0.0), color)


func _spawn_player():
	player = PLAYER_SCRIPT.new()
	player.name = "CheikhHero"
	var center = ZONE_CENTERS[START_ZONE]
	var spawn_x = center.x
	var spawn_z = center.z + 4.0
	player.position = Vector3(spawn_x, _terrain_world_height(START_ZONE, spawn_x, spawn_z) + 0.45, spawn_z)
	add_child(player)
	player.set_spawn(player.global_position)
	if ResourceLoader.exists(HERO_MODEL):
		player.apply_asset(HERO_MODEL)
	player.health_changed.connect(_on_health_changed)
	player.attack_requested.connect(_on_player_attack)
	player.interact_requested.connect(_on_interact)


func _spawn_guardians():
	zone_remaining.resize(ZONE_CENTERS.size())
	zone_total.resize(ZONE_CENTERS.size())
	zone_completed.resize(ZONE_CENTERS.size())

	for zone_index in range(ZONE_CENTERS.size()):
		zone_remaining[zone_index] = 0
		zone_total[zone_index] = 0
		zone_completed[zone_index] = false

	zone_completed[START_ZONE] = true

	for zone_index in range(ZONE_CENTERS.size()):
		if zone_index == START_ZONE:
			continue
		var count = 3 if zone_index in [8, 9] else 2
		zone_remaining[zone_index] = count
		zone_total[zone_index] = count

		for enemy_index in range(count):
			var enemy = ENEMY_SCRIPT.new()
			enemy.name = "Zone_%02d_Gardien_%02d" % [zone_index + 1, enemy_index + 1]
			var angle = TAU * float(enemy_index) / float(max(1, count)) + 0.8
			var radius = 7.0 + float(enemy_index % 2) * 3.5
			var world_x = ZONE_CENTERS[zone_index].x + cos(angle) * radius
			var world_z = ZONE_CENTERS[zone_index].z + sin(angle) * radius
			enemy.position = Vector3(world_x, _terrain_world_height(zone_index, world_x, world_z) + 0.45, world_z)
			enemy.set_meta("zone_index", zone_index)
			add_child(enemy)

			var model_index = (zone_index + enemy_index) % ENEMY_MODELS.size()
			enemy.setup(player, model_index, ENEMY_MODELS[model_index])
			enemy.defeated.connect(_on_enemy_defeated)
			enemies.append(enemy)


func _on_player_attack():
	if not is_instance_valid(player):
		return
	var forward = player.get_forward()
	for enemy in enemies.duplicate():
		if not is_instance_valid(enemy) or enemy.health <= 0:
			continue
		var offset = enemy.global_position - player.global_position
		var flat_offset = Vector3(offset.x, 0.0, offset.z)
		if flat_offset.length() <= 3.15 and flat_offset.length() > 0.01:
			if forward.dot(flat_offset.normalized()) > -0.08:
				enemy.take_damage(34, player.global_position)


func _on_interact():
	if not is_instance_valid(player):
		return

	if player.global_position.distance_to(capital_portal_position) < 4.0:
		var sky = ZONE_CENTERS[9]
		var target_z = sky.z + 7.0
		player.global_position = Vector3(sky.x, _terrain_world_height(9, sky.x, target_z) + 0.65, target_z)
		player.set_spawn(player.global_position)
		_show_message("Bienvenue dans la Zone 10 — Île Céleste", 4.0)
		return

	if player.global_position.distance_to(sky_portal_position) < 4.0:
		var capital = ZONE_CENTERS[8]
		var target_z = capital.z + 7.0
		player.global_position = Vector3(capital.x, _terrain_world_height(8, capital.x, target_z) + 0.65, target_z)
		player.set_spawn(player.global_position)
		_show_message("Retour au Royaume Central", 3.0)
		return

	if current_zone == START_ZONE:
		_show_message("Ouvre CARTE pour choisir ta destination.", 3.0)
	elif zone_remaining[current_zone] > 0:
		_show_message("Zone %d : il reste %d gardien(s)." % [current_zone + 1, zone_remaining[current_zone]], 2.8)
	else:
		_show_message("Zone %d libérée." % (current_zone + 1), 2.5)


func _on_enemy_defeated(enemy):
	enemies.erase(enemy)
	var zone_index = int(enemy.get_meta("zone_index", -1))
	if zone_index < 0 or zone_index >= zone_remaining.size():
		return

	zone_remaining[zone_index] = max(0, int(zone_remaining[zone_index]) - 1)
	total_defeated += 1
	if zone_remaining[zone_index] == 0:
		zone_completed[zone_index] = true
		_show_message("ZONE %d LIBÉRÉE — %s" % [zone_index + 1, ZONE_NAMES[zone_index]], 5.0)

	game_complete = _all_hostile_zones_complete()
	if game_complete:
		_show_message("VICTOIRE — toutes les régions de la carte sont libérées !", 8.0)

	_update_hud()
	_update_map_marker()
	_save_progress()


func _all_hostile_zones_complete():
	for zone_index in range(ZONE_CENTERS.size()):
		if zone_index == START_ZONE:
			continue
		if not bool(zone_completed[zone_index]):
			return false
	return true


func _update_current_zone():
	var nearest_zone = current_zone
	var nearest_distance = INF

	for zone_index in range(ZONE_CENTERS.size()):
		var center = ZONE_CENTERS[zone_index]
		var dx = player.global_position.x - center.x
		var dz = player.global_position.z - center.z
		var dy = player.global_position.y - center.y
		var distance = dx * dx + dz * dz + dy * dy * 4.0
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_zone = zone_index

	if nearest_zone != current_zone:
		current_zone = nearest_zone
		_update_hud()
		_update_map_marker()
		_show_zone_banner()


func _build_hud():
	var canvas = CanvasLayer.new()
	canvas.layer = 20
	add_child(canvas)

	var root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(root)

	var bar = ColorRect.new()
	bar.color = Color(0.012, 0.025, 0.055, 0.88)
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar.offset_bottom = 78.0
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bar)

	health_label = Label.new()
	health_label.position = Vector2(18.0, 8.0)
	health_label.size = Vector2(250.0, 30.0)
	health_label.add_theme_font_size_override("font_size", 21)
	bar.add_child(health_label)

	zone_label = Label.new()
	zone_label.position = Vector2(18.0, 39.0)
	zone_label.size = Vector2(480.0, 30.0)
	zone_label.add_theme_font_size_override("font_size", 18)
	bar.add_child(zone_label)

	objective_label = Label.new()
	objective_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	objective_label.position = Vector2(-500.0, 10.0)
	objective_label.size = Vector2(390.0, 55.0)
	objective_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	objective_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	objective_label.add_theme_font_size_override("font_size", 16)
	bar.add_child(objective_label)

	map_button = Button.new()
	map_button.text = "CARTE"
	map_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	map_button.position = Vector2(-102.0, 10.0)
	map_button.size = Vector2(88.0, 54.0)
	map_button.add_theme_font_size_override("font_size", 17)
	map_button.pressed.connect(_toggle_map)
	bar.add_child(map_button)

	message_label = Label.new()
	message_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	message_label.position = Vector2(-410.0, 86.0)
	message_label.size = Vector2(820.0, 52.0)
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	message_label.add_theme_font_size_override("font_size", 23)
	message_label.add_theme_constant_override("outline_size", 7)
	root.add_child(message_label)

	zone_banner = Label.new()
	zone_banner.set_anchors_preset(Control.PRESET_CENTER)
	zone_banner.position = Vector2(-470.0, -92.0)
	zone_banner.size = Vector2(940.0, 90.0)
	zone_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	zone_banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	zone_banner.add_theme_font_size_override("font_size", 32)
	zone_banner.add_theme_constant_override("outline_size", 10)
	zone_banner.visible = false
	root.add_child(zone_banner)

	_build_joystick(root)
	_build_action_buttons(root)
	_build_map_panel(root)


func _build_joystick(root):
	var joystick = ColorRect.new()
	joystick.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	joystick.position = Vector2(28.0, -190.0)
	joystick.size = Vector2(160.0, 160.0)
	joystick.color = Color(0.10, 0.26, 0.48, 0.54)
	joystick.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(joystick)

	joystick_knob = ColorRect.new()
	joystick_knob.position = Vector2(54.0, 54.0)
	joystick_knob.size = Vector2(52.0, 52.0)
	joystick_knob.color = Color(0.64, 0.84, 1.0, 0.84)
	joystick_knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	joystick.add_child(joystick_knob)


func _build_action_buttons(root):
	var attack_button = _make_button(root, "ATTAQUE", Vector2(-126.0, -116.0), Vector2(108.0, 54.0))
	attack_button.pressed.connect(_attack_button_pressed)

	var jump_button = _make_button(root, "SAUT", Vector2(-244.0, -116.0), Vector2(108.0, 54.0))
	jump_button.pressed.connect(_jump_button_pressed)

	var dodge_button = _make_button(root, "ESQUIVE", Vector2(-244.0, -58.0), Vector2(108.0, 48.0))
	dodge_button.pressed.connect(_dodge_button_pressed)

	var action_button = _make_button(root, "ACTION", Vector2(-126.0, -58.0), Vector2(108.0, 48.0))
	action_button.pressed.connect(_action_button_pressed)


func _make_button(parent, text, position, size):
	var button = Button.new()
	button.text = text
	button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	button.position = position
	button.size = size
	button.add_theme_font_size_override("font_size", 14)
	parent.add_child(button)
	return button


func _build_map_panel(root):
	map_panel = ColorRect.new()
	map_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	map_panel.color = Color(0.005, 0.012, 0.03, 0.96)
	map_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	map_panel.visible = false
	root.add_child(map_panel)

	var title = Label.new()
	title.text = "CARTE DU MONDE — 10 ZONES"
	title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title.position = Vector2(-300.0, 6.0)
	title.size = Vector2(600.0, 40.0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	map_panel.add_child(title)

	map_frame = Control.new()
	map_frame.set_anchors_preset(Control.PRESET_CENTER)
	map_frame.position = Vector2(-225.0, -128.0)
	map_frame.size = Vector2(450.0, 300.0)
	map_panel.add_child(map_frame)

	var map_texture = TextureRect.new()
	map_texture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if ResourceLoader.exists(WORLD_MAP_PATH):
		map_texture.texture = load(WORLD_MAP_PATH)
	map_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	map_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	map_frame.add_child(map_texture)

	map_player_marker = Label.new()
	map_player_marker.text = "●\nVOUS"
	map_player_marker.size = Vector2(76.0, 44.0)
	map_player_marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	map_player_marker.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	map_player_marker.modulate = Color(1.0, 0.18, 0.12)
	map_player_marker.add_theme_font_size_override("font_size", 15)
	map_player_marker.add_theme_constant_override("outline_size", 7)
	map_frame.add_child(map_player_marker)

	map_zone_label = Label.new()
	map_zone_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	map_zone_label.position = Vector2(-260.0, 134.0)
	map_zone_label.size = Vector2(520.0, 36.0)
	map_zone_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	map_zone_label.add_theme_font_size_override("font_size", 18)
	map_panel.add_child(map_zone_label)

	map_status_label = Label.new()
	map_status_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	map_status_label.position = Vector2(-300.0, 167.0)
	map_status_label.size = Vector2(600.0, 34.0)
	map_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	map_status_label.add_theme_font_size_override("font_size", 15)
	map_panel.add_child(map_status_label)

	var close_button = Button.new()
	close_button.text = "FERMER"
	close_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	close_button.position = Vector2(-112.0, 9.0)
	close_button.size = Vector2(98.0, 42.0)
	close_button.pressed.connect(_toggle_map)
	map_panel.add_child(close_button)


func _toggle_map():
	if not is_instance_valid(map_panel):
		return
	map_panel.visible = not map_panel.visible
	virtual_move = Vector2.ZERO
	move_touch_id = -1
	look_touch_id = -1
	_reset_joystick()
	if is_instance_valid(player):
		player.can_control = not map_panel.visible
	_update_map_marker()


func _update_map_marker():
	if not is_instance_valid(map_player_marker) or not is_instance_valid(map_frame):
		return

	var marker = MAP_MARKERS[current_zone]
	map_player_marker.position = Vector2(marker.x * map_frame.size.x - 38.0, marker.y * map_frame.size.y - 22.0)
	map_zone_label.text = "VOUS ÊTES EN ZONE %d — %s" % [current_zone + 1, ZONE_NAMES[current_zone]]

	var completed_count = 0
	for zone_index in range(zone_completed.size()):
		if bool(zone_completed[zone_index]):
			completed_count += 1
	map_status_label.text = "Régions libérées : %d / 10 — Touchez FERMER pour reprendre" % completed_count


func _show_zone_banner():
	if not is_instance_valid(zone_banner):
		return
	zone_banner_token += 1
	var token = zone_banner_token
	zone_banner.text = "ZONE %d\n%s" % [current_zone + 1, ZONE_NAMES[current_zone]]
	zone_banner.modulate = ZONE_ACCENT_COLORS[current_zone]
	zone_banner.visible = true
	await get_tree().create_timer(2.8).timeout
	if token == zone_banner_token and is_instance_valid(zone_banner):
		zone_banner.visible = false


func _attack_button_pressed():
	if is_instance_valid(player):
		player.attack()


func _jump_button_pressed():
	if is_instance_valid(player) and player.is_on_floor():
		player.velocity.y = player.jump_velocity


func _dodge_button_pressed():
	if is_instance_valid(player):
		player.dodge()


func _action_button_pressed():
	if is_instance_valid(player):
		player.interact()


func _update_joystick(position):
	var offset = (position - move_origin).limit_length(64.0)
	virtual_move = offset / 64.0
	if is_instance_valid(joystick_knob):
		joystick_knob.position = Vector2(54.0, 54.0) + offset


func _reset_joystick():
	if is_instance_valid(joystick_knob):
		joystick_knob.position = Vector2(54.0, 54.0)


func _on_health_changed(current, maximum):
	if is_instance_valid(health_label):
		health_label.text = "PV %d / %d" % [current, maximum]


func _update_hud():
	if is_instance_valid(player) and is_instance_valid(health_label):
		health_label.text = "PV %d / %d" % [player.health, player.max_health]

	if is_instance_valid(zone_label):
		zone_label.text = "ZONE %d / 10 — %s" % [current_zone + 1, ZONE_NAMES[current_zone]]
		zone_label.modulate = ZONE_ACCENT_COLORS[current_zone]

	if is_instance_valid(objective_label):
		if game_complete:
			objective_label.text = "MONDE LIBÉRÉ\n%d gardiens vaincus" % total_defeated
		elif current_zone == START_ZONE:
			objective_label.text = "Objectif : ouvre CARTE\net choisis ta destination"
		elif int(zone_remaining[current_zone]) > 0:
			objective_label.text = "Gardiens : %d / %d\nCarte disponible" % [zone_remaining[current_zone], zone_total[current_zone]]
		else:
			objective_label.text = "ZONE LIBÉRÉE\nExplore une autre région"


func _show_message(text, duration):
	if not is_instance_valid(message_label):
		return
	message_token += 1
	var token = message_token
	message_label.text = text
	await get_tree().create_timer(duration).timeout
	if token == message_token and is_instance_valid(message_label):
		message_label.text = ""


func _play_music(path):
	if not ResourceLoader.exists(path):
		return
	if not is_instance_valid(music_player):
		music_player = AudioStreamPlayer.new()
		music_player.volume_db = -9.0
		music_player.finished.connect(_replay_music)
		add_child(music_player)
	music_player.stream = load(path)
	music_player.play()


func _replay_music():
	if is_instance_valid(music_player):
		music_player.play()


func _update_battle_music():
	var nearby = false
	for enemy in enemies:
		if is_instance_valid(enemy) and enemy.health > 0:
			if enemy.global_position.distance_to(player.global_position) < 14.0:
				nearby = true
				break

	if nearby != battle_music_active:
		battle_music_active = nearby
		_play_music(MUSIC_BATTLE_PATH if nearby else MUSIC_WORLD_PATH)


func _add_zone_title(zone_index):
	var center = ZONE_CENTERS[zone_index]
	var local_z = -TERRAIN_SIZE.y * 0.36
	var world_y = _terrain_world_height(zone_index, center.x, center.z + local_z) + 4.2
	var anchor = Node3D.new()
	anchor.position = Vector3(center.x, world_y, center.z + local_z)
	add_child(anchor)
	_add_world_label(anchor, "ZONE %d — %s" % [zone_index + 1, ZONE_NAMES[zone_index]], Vector3.ZERO, ZONE_ACCENT_COLORS[zone_index])


func _add_world_label(parent, text, position, color):
	var label = Label3D.new()
	label.text = text
	label.position = position
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 38
	label.outline_size = 9
	label.modulate = color
	parent.add_child(label)


func _place_model(path, zone_index, offset, scale, rotation):
	if not ResourceLoader.exists(path):
		return null
	var resource = load(path)
	if not (resource is PackedScene):
		return null

	var instance = resource.instantiate()
	if not (instance is Node3D):
		instance.queue_free()
		return null

	var center = ZONE_CENTERS[zone_index]
	var world_x = center.x + offset.x
	var world_z = center.z + offset.z
	instance.position = Vector3(world_x, _terrain_world_height(zone_index, world_x, world_z) + offset.y, world_z)
	instance.scale = scale
	instance.rotation = rotation
	add_child(instance)
	return instance


func _add_rock(zone_index, offset, scale_value, color):
	var center = ZONE_CENTERS[zone_index]
	var world_x = center.x + offset.x
	var world_z = center.z + offset.z
	var rock = MeshInstance3D.new()
	var mesh = SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 1.7
	mesh.material = _material(color)
	rock.mesh = mesh
	rock.position = Vector3(world_x, _terrain_world_height(zone_index, world_x, world_z) + offset.y + scale_value.y * 0.42, world_z)
	rock.scale = scale_value
	rock.rotation = Vector3(offset.z * 0.04, offset.x * 0.08, offset.x * 0.03)
	add_child(rock)
	return rock


func _add_crystal(zone_index, offset, size_value, color):
	var center = ZONE_CENTERS[zone_index]
	var world_x = center.x + offset.x
	var world_z = center.z + offset.z
	var crystal = MeshInstance3D.new()
	var mesh = PrismMesh.new()
	mesh.size = Vector3(size_value * 0.55, size_value * 2.2, size_value * 0.55)
	mesh.material = _material(color, color)
	crystal.mesh = mesh
	crystal.position = Vector3(world_x, _terrain_world_height(zone_index, world_x, world_z) + offset.y + size_value, world_z)
	crystal.rotation.y = offset.x * 0.11
	add_child(crystal)
	return crystal


func _add_water_patch(zone_index, offset, patch_size, color, emission = Color(0.0, 0.0, 0.0, 1.0)):
	var center = ZONE_CENTERS[zone_index]
	var world_x = center.x + offset.x
	var world_z = center.z + offset.z
	var y_value = _terrain_world_height(zone_index, world_x, world_z) + offset.y + 0.10
	return _visual_box("WaterPatch", Vector3(patch_size.x, 0.08, patch_size.y), Vector3(world_x, y_value, world_z), color, emission)


func _add_waterfall(zone_index, offset, waterfall_size):
	var center = ZONE_CENTERS[zone_index]
	var world_x = center.x + offset.x
	var world_z = center.z + offset.z
	var waterfall = _visual_box("Waterfall", Vector3(waterfall_size.x, waterfall_size.y, 0.12), Vector3(world_x, center.y + offset.y, world_z), Color(0.46, 0.82, 0.98, 0.72), Color(0.08, 0.30, 0.48))
	waterfall.rotation.y = PI * 0.5


func _add_disc(position, radius, color, emission):
	var mesh_instance = MeshInstance3D.new()
	var mesh = CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = 0.14
	mesh.material = _material(color, emission)
	mesh_instance.mesh = mesh
	mesh_instance.position = position
	add_child(mesh_instance)
	return mesh_instance


func _add_colossus(zone_index, offset):
	var center = ZONE_CENTERS[zone_index]
	var world_x = center.x + offset.x
	var world_z = center.z + offset.z
	var ground_y = _terrain_world_height(zone_index, world_x, world_z)
	var anchor = Node3D.new()
	anchor.position = Vector3(world_x, ground_y, world_z)
	add_child(anchor)

	var stone = Color(0.42, 0.34, 0.23)
	var torso = _mesh_box(Vector3(2.8, 4.8, 1.9), stone)
	torso.position.y = 4.0
	anchor.add_child(torso)

	var head = MeshInstance3D.new()
	var head_mesh = SphereMesh.new()
	head_mesh.radius = 1.15
	head_mesh.height = 2.2
	head_mesh.material = _material(stone)
	head.mesh = head_mesh
	head.position.y = 7.1
	anchor.add_child(head)

	for side in [-1.0, 1.0]:
		var arm = _mesh_box(Vector3(1.0, 4.6, 1.0), stone)
		arm.position = Vector3(side * 2.1, 4.1, 0.0)
		arm.rotation.z = side * 0.12
		anchor.add_child(arm)

		var leg = _mesh_box(Vector3(1.1, 3.7, 1.2), stone)
		leg.position = Vector3(side * 0.8, 1.85, 0.0)
		anchor.add_child(leg)


func _add_pyramid(zone_index, offset, size_value):
	var center = ZONE_CENTERS[zone_index]
	var world_x = center.x + offset.x
	var world_z = center.z + offset.z
	var pyramid = MeshInstance3D.new()
	var mesh = PrismMesh.new()
	mesh.size = Vector3(size_value, size_value * 0.82, size_value)
	mesh.material = _material(Color(0.72, 0.56, 0.30))
	pyramid.mesh = mesh
	pyramid.position = Vector3(world_x, _terrain_world_height(zone_index, world_x, world_z) + size_value * 0.41, world_z)
	pyramid.rotation.x = PI * 0.5
	add_child(pyramid)


func _add_column(zone_index, offset, height_value):
	var center = ZONE_CENTERS[zone_index]
	var world_x = center.x + offset.x
	var world_z = center.z + offset.z
	var column = MeshInstance3D.new()
	var mesh = CylinderMesh.new()
	mesh.top_radius = 0.65
	mesh.bottom_radius = 0.78
	mesh.height = height_value
	mesh.material = _material(Color(0.68, 0.58, 0.38))
	column.mesh = mesh
	column.position = Vector3(world_x, _terrain_world_height(zone_index, world_x, world_z) + height_value * 0.5, world_z)
	add_child(column)


func _add_tower(zone_index, offset, height_value):
	var center = ZONE_CENTERS[zone_index]
	var world_x = center.x + offset.x
	var world_z = center.z + offset.z
	var y_value = _terrain_world_height(zone_index, world_x, world_z) + height_value * 0.5
	return _static_box("CapitalTower", Vector3(4.5, height_value, 4.5), Vector3(world_x, y_value, world_z), Color(0.20, 0.19, 0.22))


func _add_wall(zone_index, offset, size_value):
	var center = ZONE_CENTERS[zone_index]
	var world_x = center.x + offset.x
	var world_z = center.z + offset.z
	var y_value = _terrain_world_height(zone_index, world_x, world_z) + size_value.y * 0.5
	return _static_box("CapitalWall", size_value, Vector3(world_x, y_value, world_z), Color(0.18, 0.17, 0.20))


func _add_path(zone_index, offset, size_value, rotation_y):
	var center = ZONE_CENTERS[zone_index]
	var world_x = center.x + offset.x
	var world_z = center.z + offset.z
	var y_value = _terrain_world_height(zone_index, world_x, world_z) + offset.y
	var path = _visual_box("ZonePath", size_value, Vector3(world_x, y_value, world_z), Color(0.48, 0.34, 0.20))
	path.rotation.y = rotation_y
	return path


func _static_box(name, size_value, position, color, emission = Color(0.0, 0.0, 0.0, 1.0)):
	var body = StaticBody3D.new()
	body.name = name
	body.position = position

	var visual = MeshInstance3D.new()
	var mesh = BoxMesh.new()
	mesh.size = size_value
	mesh.material = _material(color, emission)
	visual.mesh = mesh
	body.add_child(visual)

	var collision = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = size_value
	collision.shape = shape
	body.add_child(collision)
	add_child(body)
	return body


func _visual_box(name, size_value, position, color, emission = Color(0.0, 0.0, 0.0, 1.0)):
	var visual = MeshInstance3D.new()
	visual.name = name
	var mesh = BoxMesh.new()
	mesh.size = size_value
	mesh.material = _material(color, emission)
	visual.mesh = mesh
	visual.position = position
	add_child(visual)
	return visual


func _mesh_box(size_value, color):
	var visual = MeshInstance3D.new()
	var mesh = BoxMesh.new()
	mesh.size = size_value
	mesh.material = _material(color)
	visual.mesh = mesh
	return visual


func _material(color, emission = Color(0.0, 0.0, 0.0, 1.0)):
	var material = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.68
	if color.a < 0.99:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if emission.r + emission.g + emission.b > 0.01:
		material.emission_enabled = true
		material.emission = emission
		material.emission_energy_multiplier = 2.4
	return material


func _save_progress():
	if not is_instance_valid(player):
		return

	var config = ConfigFile.new()
	config.set_value("world", "remaining", zone_remaining)
	config.set_value("world", "completed", zone_completed)
	config.set_value("world", "total_defeated", total_defeated)
	config.set_value("world", "complete", game_complete)
	config.set_value("player", "position", player.global_position)
	config.set_value("player", "health", player.health)
	config.save(SAVE_PATH)


func _load_progress():
	var config = ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return

	total_defeated = int(config.get_value("world", "total_defeated", 0))
	game_complete = bool(config.get_value("world", "complete", false))

	var saved_remaining = config.get_value("world", "remaining", zone_remaining)
	if saved_remaining is Array and saved_remaining.size() == zone_remaining.size():
		for zone_index in range(zone_remaining.size()):
			zone_remaining[zone_index] = int(saved_remaining[zone_index])

	var saved_completed = config.get_value("world", "completed", zone_completed)
	if saved_completed is Array and saved_completed.size() == zone_completed.size():
		for zone_index in range(zone_completed.size()):
			zone_completed[zone_index] = bool(saved_completed[zone_index])

	for enemy in enemies.duplicate():
		if not is_instance_valid(enemy):
			continue
		var enemy_zone = int(enemy.get_meta("zone_index", -1))
		if enemy_zone >= 0 and enemy_zone < zone_completed.size() and bool(zone_completed[enemy_zone]):
			enemies.erase(enemy)
			enemy.queue_free()

	var saved_position = config.get_value("player", "position", player.global_position)
	if saved_position is Vector3:
		player.global_position = saved_position
		player.set_spawn(saved_position)
	player.health = clamp(int(config.get_value("player", "health", player.max_health)), 1, player.max_health)
	player.health_changed.emit(player.health, player.max_health)
