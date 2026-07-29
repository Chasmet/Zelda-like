extends Node3D

const HERO_SCRIPT = preload("res://scripts/hero_3d.gd")
const HORSE_SCRIPT = preload("res://scripts/horse_3d.gd")
const ENEMY_SCRIPT = preload("res://scripts/enemy_3d.gd")
const CAMERA_SCRIPT = preload("res://scripts/third_person_camera.gd")
const JOYSTICK_SCRIPT = preload("res://scripts/mobile_joystick.gd")

var hero: Hero3D
var horse: Horse3D
var camera_rig: ThirdPersonCameraRig
var joystick: MobileJoystick
var enemies: Array[Enemy3D] = []

var world_environment: WorldEnvironment
var sun: DirectionalLight3D
var water: MeshInstance3D
var day_time: float = 9.0
var defeated_count: int = 0
var current_zone: int = 9
var look_touch_id: int = -1
var mouse_look_active: bool = false

var health_bar: ProgressBar
var stamina_bar: ProgressBar
var zone_label: Label
var quest_label: Label
var message_label: Label
var mount_button: Button
var map_overlay: Control
var map_texture: Texture2D
var message_token: int = 0

var ground_portal_position: Vector3 = Vector3(0.0, 0.0, -6.0)
var sky_portal_position: Vector3 = Vector3(0.0, 34.0, -115.0)

var zone_centers: Array[Vector3] = [
	Vector3(-120.0, 0.0, -70.0),
	Vector3(-75.0, 0.0, -20.0),
	Vector3(95.0, 0.0, -70.0),
	Vector3(115.0, 0.0, 15.0),
	Vector3(100.0, 0.0, 95.0),
	Vector3(40.0, 0.0, 100.0),
	Vector3(-125.0, 0.0, 50.0),
	Vector3(-75.0, 0.0, 95.0),
	Vector3(0.0, 0.0, 20.0),
	Vector3(0.0, 34.0, -115.0)
]

var zone_names: Array[String] = [
	"1 — Montagne de Cendre",
	"2 — Forêt des Cascades",
	"3 — Pics de Givre",
	"4 — Désert du Colosse",
	"5 — Marais des Âmes",
	"6 — Ruines du Soleil",
	"7 — Arche des Navigateurs",
	"8 — Village des Falaises",
	"9 — Royaume de Skypiea",
	"10 — Citadelle Céleste"
]

func _ready() -> void:
	seed(20260729)
	_setup_input_actions()
	_build_environment()
	_build_world_from_ten_zone_map()
	_spawn_hero_and_horse()
	_spawn_enemies()
	_build_mobile_hud()
	_connect_gameplay()
	_start_music()
	_update_hud()
	_show_message("Bienvenue dans le monde de Skypiea — explore les 10 zones", 4.0)

func _process(delta: float) -> void:
	day_time = fmod(day_time + delta * 0.012, 24.0)
	_update_day_night()
	_update_current_zone()
	_update_hud()

func _physics_process(delta: float) -> void:
	if not is_instance_valid(hero) or not is_instance_valid(camera_rig):
		return
	var mobile_value: Vector2 = Vector2.ZERO
	if is_instance_valid(joystick):
		mobile_value = Vector2(joystick.value.x, -joystick.value.y)
	var keyboard_value: Vector2 = Input.get_vector("move_left", "move_right", "move_back", "move_forward")
	var combined_input: Vector2 = (mobile_value + keyboard_value).limit_length(1.0)
	var basis: Basis = camera_rig.get_camera_basis()
	if hero.mounted and is_instance_valid(horse):
		horse.set_move_input(combined_input, basis)
		hero.set_move_input(Vector2.ZERO, basis)
		camera_rig.gently_align_to(horse.rotation.y, combined_input.length(), delta)
	else:
		hero.set_move_input(combined_input, basis)
		if is_instance_valid(horse):
			horse.set_move_input(Vector2.ZERO, basis)
		camera_rig.gently_align_to(hero.rotation.y, combined_input.length(), delta)

	if Input.is_action_just_pressed("jump"):
		_on_jump_pressed()
	if Input.is_action_just_pressed("attack"):
		_on_attack_pressed()
	if Input.is_action_just_pressed("dodge"):
		_on_dodge_pressed()
	if Input.is_action_just_pressed("interact"):
		_on_interact_pressed()
	if Input.is_action_just_pressed("toggle_map"):
		_toggle_map()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event as InputEventScreenTouch
		var viewport_size: Vector2 = get_viewport().get_visible_rect().size
		if touch.pressed and touch.position.x > viewport_size.x * 0.42 and look_touch_id == -1:
			look_touch_id = touch.index
		elif not touch.pressed and touch.index == look_touch_id:
			look_touch_id = -1
	elif event is InputEventScreenDrag:
		var drag: InputEventScreenDrag = event as InputEventScreenDrag
		if drag.index == look_touch_id:
			camera_rig.add_touch_look(drag.relative)
	elif event is InputEventMouseButton:
		var mouse_button: InputEventMouseButton = event as InputEventMouseButton
		if mouse_button.button_index == MOUSE_BUTTON_RIGHT:
			mouse_look_active = mouse_button.pressed
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if mouse_look_active else Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseMotion and mouse_look_active:
		var mouse_motion: InputEventMouseMotion = event as InputEventMouseMotion
		camera_rig.add_mouse_look(mouse_motion.relative)

func _setup_input_actions() -> void:
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
	_add_key("toggle_map", KEY_M)
	var mouse_attack: InputEventMouseButton = InputEventMouseButton.new()
	mouse_attack.button_index = MOUSE_BUTTON_LEFT
	if not InputMap.has_action("attack"):
		InputMap.add_action("attack")
	InputMap.action_add_event("attack", mouse_attack)

func _add_key(action_name: StringName, key_code: Key) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
	var key_event: InputEventKey = InputEventKey.new()
	key_event.physical_keycode = key_code
	InputMap.action_add_event(action_name, key_event)

func _build_environment() -> void:
	world_environment = WorldEnvironment.new()
	world_environment.name = "WorldEnvironment"
	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky: Sky = Sky.new()
	var sky_material: ProceduralSkyMaterial = ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("#196fc0")
	sky_material.sky_horizon_color = Color("#b7dbef")
	sky_material.ground_bottom_color = Color("#182737")
	sky_material.ground_horizon_color = Color("#6b806c")
	sky.sky_material = sky_material
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.72
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.fog_enabled = true
	environment.fog_density = 0.0017
	environment.fog_light_color = Color("#a9c8d8")
	world_environment.environment = environment
	add_child(world_environment)

	sun = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-48.0, -28.0, 0.0)
	sun.light_energy = 1.35
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 105.0
	add_child(sun)

	water = MeshInstance3D.new()
	water.name = "Ocean"
	var water_mesh: PlaneMesh = PlaneMesh.new()
	water_mesh.size = Vector2(520.0, 520.0)
	var water_material: StandardMaterial3D = _material(Color(0.02, 0.30, 0.52, 0.82), 0.12, 0.24)
	water_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water_material.metallic = 0.18
	water_mesh.material = water_material
	water.mesh = water_mesh
	water.position.y = -3.2
	add_child(water)

func _update_day_night() -> void:
	if not is_instance_valid(sun) or not is_instance_valid(world_environment):
		return
	var daylight: float = clampf(sin((day_time - 6.0) / 24.0 * TAU) * 0.62 + 0.46, 0.10, 1.0)
	sun.rotation_degrees.x = -10.0 - daylight * 62.0
	sun.rotation_degrees.y = day_time * 15.0 - 180.0
	sun.light_energy = 0.25 + daylight * 1.25
	if world_environment.environment != null:
		world_environment.environment.ambient_light_energy = 0.18 + daylight * 0.62

func _build_world_from_ten_zone_map() -> void:
	_create_island(1, zone_centers[0], 38.0, 8.0, Color("#322d2d"))
	_create_island(2, zone_centers[1], 42.0, 6.0, Color("#1f693d"))
	_create_island(3, zone_centers[2], 42.0, 10.0, Color("#d8e8ee"))
	_create_island(4, zone_centers[3], 43.0, 5.0, Color("#cba35e"))
	_create_island(5, zone_centers[4], 39.0, 7.0, Color("#253c32"))
	_create_island(6, zone_centers[5], 40.0, 5.0, Color("#d2b067"))
	_create_island(7, zone_centers[6], 37.0, 6.0, Color("#55786a"))
	_create_island(8, zone_centers[7], 42.0, 5.0, Color("#4b8a4e"))
	_create_island(9, zone_centers[8], 52.0, 7.0, Color("#4f9b50"))
	_create_island(10, zone_centers[9], 34.0, 12.0, Color("#719e56"))

	_create_bridge(zone_centers[8], zone_centers[1], 11.0, Color("#8e7049"))
	_create_bridge(zone_centers[1], zone_centers[0], 9.0, Color("#5c5044"))
	_create_bridge(zone_centers[8], zone_centers[2], 11.0, Color("#9aaeb4"))
	_create_bridge(zone_centers[8], zone_centers[3], 11.0, Color("#b68f53"))
	_create_bridge(zone_centers[3], zone_centers[4], 10.0, Color("#8c7246"))
	_create_bridge(zone_centers[8], zone_centers[5], 11.0, Color("#b49559"))
	_create_bridge(zone_centers[8], zone_centers[7], 11.0, Color("#8d754d"))
	_create_bridge(zone_centers[7], zone_centers[6], 9.0, Color("#706553"))

	_build_volcano_zone()
	_build_forest_zone()
	_build_snow_zone()
	_build_desert_zone()
	_build_swamp_zone()
	_build_ruins_zone()
	_build_coast_zone()
	_build_village_zone()
	_build_capital_zone()
	_build_sky_zone()
	_create_portal(ground_portal_position, Color("#48d9ff"), "Portail vers la zone 10")
	_create_portal(sky_portal_position + Vector3(0.0, 0.0, 8.0), Color("#ffd25a"), "Retour au royaume")

func _create_island(zone_number: int, center: Vector3, radius: float, depth: float, color: Color) -> void:
	var body: StaticBody3D = StaticBody3D.new()
	body.name = "Zone_%02d_Ground" % zone_number
	body.position = center + Vector3(0.0, -depth * 0.5, 0.0)
	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	var cylinder_mesh: CylinderMesh = CylinderMesh.new()
	cylinder_mesh.top_radius = radius
	cylinder_mesh.bottom_radius = radius * 0.88
	cylinder_mesh.height = depth
	cylinder_mesh.radial_segments = 48
	cylinder_mesh.material = _material(color, 0.04, 0.92)
	mesh_instance.mesh = cylinder_mesh
	body.add_child(mesh_instance)
	var collision: CollisionShape3D = CollisionShape3D.new()
	var cylinder_shape: CylinderShape3D = CylinderShape3D.new()
	cylinder_shape.radius = radius
	cylinder_shape.height = depth
	collision.shape = cylinder_shape
	body.add_child(collision)
	add_child(body)
	_add_zone_label(zone_number, center + Vector3(0.0, 4.2, 0.0))

func _create_bridge(from_point: Vector3, to_point: Vector3, width: float, color: Color) -> void:
	var flat_from: Vector3 = Vector3(from_point.x, 0.0, from_point.z)
	var flat_to: Vector3 = Vector3(to_point.x, 0.0, to_point.z)
	var delta: Vector3 = flat_to - flat_from
	var length: float = delta.length()
	var midpoint: Vector3 = (flat_from + flat_to) * 0.5 + Vector3(0.0, -0.35, 0.0)
	var bridge: StaticBody3D = _static_box("Bridge", Vector3(width, 0.70, length), midpoint, color)
	bridge.rotation.y = atan2(delta.x, delta.z)

func _add_zone_label(zone_number: int, position_value: Vector3) -> void:
	var label: Label3D = Label3D.new()
	label.text = zone_names[zone_number - 1]
	label.position = position_value
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 42
	label.outline_size = 10
	label.modulate = Color(1.0, 0.91, 0.58)
	add_child(label)

func _build_volcano_zone() -> void:
	var center: Vector3 = zone_centers[0]
	for index: int in range(7):
		var angle: float = TAU * float(index) / 7.0
		var radius: float = 11.0 + float(index % 2) * 5.0
		_create_cone_rock(center + Vector3(cos(angle) * radius, 6.0, sin(angle) * radius), 8.0 + float(index % 3) * 2.0, 16.0, Color("#27282d"))
	_create_cone_rock(center + Vector3(0.0, 10.0, 0.0), 17.0, 28.0, Color("#202126"))
	for index: int in range(6):
		var lava_position: Vector3 = center + Vector3(-18.0 + float(index) * 7.0, 0.12, 6.0 + sin(float(index)) * 4.0)
		_create_visual_box(Vector3(8.0, 0.22, 2.4), lava_position, Color("#f04b18"), true)

func _build_forest_zone() -> void:
	var center: Vector3 = zone_centers[1]
	for index: int in range(38):
		var angle: float = randf_range(0.0, TAU)
		var radius: float = randf_range(9.0, 36.0)
		_create_tree(center + Vector3(cos(angle) * radius, 0.0, sin(angle) * radius), randf_range(0.85, 1.45), Color("#247545"))
	for index: int in range(4):
		_create_waterfall(center + Vector3(-20.0 + float(index) * 13.0, 0.2, -5.0 + float(index % 2) * 17.0))

func _build_snow_zone() -> void:
	var center: Vector3 = zone_centers[2]
	for index: int in range(11):
		var angle: float = TAU * float(index) / 11.0
		var distance: float = randf_range(8.0, 33.0)
		_create_cone_rock(center + Vector3(cos(angle) * distance, randf_range(3.0, 9.0), sin(angle) * distance), randf_range(4.0, 9.0), randf_range(10.0, 22.0), Color("#e4eef2"))
	for index: int in range(15):
		var tree_position: Vector3 = center + Vector3(randf_range(-30.0, 30.0), 0.0, randf_range(-30.0, 30.0))
		_create_tree(tree_position, randf_range(0.65, 1.1), Color("#8ca9a7"))

func _build_desert_zone() -> void:
	var center: Vector3 = zone_centers[3]
	for index: int in range(5):
		var pyramid_position: Vector3 = center + Vector3(-20.0 + float(index) * 10.0, 4.0 + float(index % 2) * 2.0, -8.0 + float(index % 3) * 11.0)
		_create_pyramid(pyramid_position, 7.0 + float(index % 2) * 3.0, 9.0 + float(index % 3) * 2.0, Color("#d5b574"))
	for index: int in range(10):
		_create_rock(center + Vector3(randf_range(-34.0, 34.0), 0.0, randf_range(-32.0, 32.0)), randf_range(0.7, 2.2), Color("#9a7548"))

func _build_swamp_zone() -> void:
	var center: Vector3 = zone_centers[4]
	for index: int in range(12):
		var pool_position: Vector3 = center + Vector3(randf_range(-28.0, 28.0), 0.08, randf_range(-28.0, 28.0))
		_create_flat_disc(pool_position, randf_range(2.0, 5.5), Color(0.08, 0.42, 0.24, 0.78))
	for index: int in range(24):
		var tree_position: Vector3 = center + Vector3(randf_range(-34.0, 34.0), 0.0, randf_range(-34.0, 34.0))
		_create_tree(tree_position, randf_range(0.65, 1.2), Color("#1b5137"))
	for index: int in range(9):
		_create_glowing_orb(center + Vector3(randf_range(-30.0, 30.0), randf_range(1.2, 3.6), randf_range(-30.0, 30.0)), Color("#46ff78"))

func _build_ruins_zone() -> void:
	var center: Vector3 = zone_centers[5]
	for x_index: int in range(-2, 3):
		for z_index: int in range(-2, 3):
			if (x_index + z_index) % 2 == 0:
				_static_box("RuinPillar", Vector3(1.4, randf_range(4.0, 8.0), 1.4), center + Vector3(float(x_index) * 8.0, randf_range(2.0, 4.0), float(z_index) * 8.0), Color("#ad9465"))
	_create_pyramid(center + Vector3(0.0, 7.0, -17.0), 13.0, 14.0, Color("#c2a36b"))

func _build_coast_zone() -> void:
	var center: Vector3 = zone_centers[6]
	_static_box("ArchLeft", Vector3(5.0, 14.0, 6.0), center + Vector3(-10.0, 7.0, 0.0), Color("#5f665f"))
	_static_box("ArchRight", Vector3(5.0, 14.0, 6.0), center + Vector3(10.0, 7.0, 0.0), Color("#5f665f"))
	_static_box("ArchTop", Vector3(25.0, 5.0, 6.0), center + Vector3(0.0, 14.0, 0.0), Color("#5f665f"))
	_create_boat(center + Vector3(0.0, 0.8, 17.0))

func _build_village_zone() -> void:
	var center: Vector3 = zone_centers[7]
	for x_index: int in range(-2, 3):
		for z_index: int in range(-1, 2):
			_create_house(center + Vector3(float(x_index) * 10.0, 0.0, float(z_index) * 13.0))
	_create_well(center + Vector3(0.0, 0.0, 0.0))

func _build_capital_zone() -> void:
	var center: Vector3 = zone_centers[8]
	_create_castle(center + Vector3(0.0, 0.0, 5.0))
	for index: int in range(22):
		var angle: float = TAU * float(index) / 22.0
		_create_tree(center + Vector3(cos(angle) * 42.0, 0.0, sin(angle) * 42.0), 0.85, Color("#3c8e4d"))
	for index: int in range(8):
		_create_house(center + Vector3(-28.0 + float(index % 4) * 18.0, 0.0, 28.0 + float(index / 4) * 15.0))

func _build_sky_zone() -> void:
	var center: Vector3 = zone_centers[9]
	_create_castle(center + Vector3(0.0, 0.0, 0.0), true)
	for index: int in range(16):
		var angle: float = TAU * float(index) / 16.0
		_create_tree(center + Vector3(cos(angle) * 25.0, 0.0, sin(angle) * 25.0), 0.72, Color("#78ad54"))
	for index: int in range(7):
		_create_rock(center + Vector3(randf_range(-27.0, 27.0), -9.0 - randf_range(0.0, 9.0), randf_range(-27.0, 27.0)), randf_range(2.0, 5.0), Color("#59635c"))

func _spawn_hero_and_horse() -> void:
	hero = HERO_SCRIPT.new() as Hero3D
	hero.name = "CheikhHero3D"
	hero.position = zone_centers[8] + Vector3(0.0, 0.3, 19.0)
	add_child(hero)
	hero.set_spawn(hero.global_position)

	horse = HORSE_SCRIPT.new() as Horse3D
	horse.name = "WhiteWarHorse3D"
	horse.position = hero.position + Vector3(4.0, 0.1, 2.0)
	add_child(horse)

	camera_rig = CAMERA_SCRIPT.new() as ThirdPersonCameraRig
	camera_rig.name = "ThirdPersonCameraRig"
	add_child(camera_rig)
	camera_rig.yaw = hero.rotation.y
	camera_rig.set_follow_target(hero, false)

func _spawn_enemies() -> void:
	var spawn_zones: Array[int] = [1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 8, 10]
	for index: int in range(spawn_zones.size()):
		var zone_number: int = spawn_zones[index]
		var center: Vector3 = zone_centers[zone_number - 1]
		var angle: float = TAU * float(index % 5) / 5.0 + float(zone_number) * 0.42
		var distance: float = 14.0 + float(index % 3) * 7.0
		var spawn_point: Vector3 = center + Vector3(cos(angle) * distance, 0.4, sin(angle) * distance)
		var enemy: Enemy3D = ENEMY_SCRIPT.new() as Enemy3D
		enemy.name = "Enemy3D_%02d" % (index + 1)
		enemy.setup(hero, index % 7, spawn_point)
		add_child(enemy)
		enemy.defeated.connect(_on_enemy_defeated)
		enemies.append(enemy)

func _connect_gameplay() -> void:
	hero.health_changed.connect(_on_health_changed)
	hero.stamina_changed.connect(_on_stamina_changed)
	hero.attack_hit.connect(_on_hero_attack_hit)
	hero.interact_requested.connect(_on_interact_pressed)

func _on_attack_pressed() -> void:
	if not is_instance_valid(hero) or map_overlay.visible:
		return
	_soft_lock_nearest_enemy()
	hero.request_attack()

func _soft_lock_nearest_enemy() -> void:
	var best_enemy: Enemy3D = null
	var best_distance: float = 7.0
	for enemy: Enemy3D in enemies:
		if not is_instance_valid(enemy) or enemy.health <= 0:
			continue
		var distance: float = hero.global_position.distance_to(enemy.global_position)
		if distance < best_distance:
			best_distance = distance
			best_enemy = enemy
	if is_instance_valid(best_enemy):
		var direction: Vector3 = best_enemy.global_position - hero.global_position
		direction.y = 0.0
		if direction.length_squared() > 0.001:
			hero.rotation.y = atan2(-direction.x, -direction.z)

func _on_hero_attack_hit(origin: Vector3, direction: Vector3, mounted_attack: bool) -> void:
	var radius: float = 4.2 if mounted_attack else 3.2
	var damage_value: int = 46 if mounted_attack else 36
	for enemy: Enemy3D in enemies:
		if not is_instance_valid(enemy) or enemy.health <= 0:
			continue
		var offset: Vector3 = enemy.global_position - origin
		var flat: Vector3 = Vector3(offset.x, 0.0, offset.z)
		if flat.length() <= radius and flat.length_squared() > 0.001:
			if direction.dot(flat.normalized()) > -0.12:
				enemy.take_damage(damage_value, origin)

func _on_dodge_pressed() -> void:
	if is_instance_valid(hero) and not map_overlay.visible:
		hero.request_dodge()

func _on_jump_pressed() -> void:
	if not is_instance_valid(hero) or map_overlay.visible:
		return
	if hero.mounted and is_instance_valid(horse):
		horse.request_jump()
	else:
		hero.request_jump()

func _on_interact_pressed() -> void:
	if not is_instance_valid(hero) or map_overlay.visible:
		return
	if hero.mounted and is_instance_valid(horse):
		var dismount_position: Vector3 = horse.get_dismount_position()
		horse.set_controlled(false)
		hero.dismount(dismount_position)
		camera_rig.set_follow_target(hero, false)
		mount_button.text = "MONTER"
		_show_message("Tu descends du cheval", 1.8)
		return
	if is_instance_valid(horse) and hero.global_position.distance_to(horse.global_position) < 3.4:
		horse.set_controlled(true, hero)
		hero.mount(horse)
		camera_rig.set_follow_target(horse, true)
		mount_button.text = "DESCENDRE"
		_show_message("Monture activée — pousse le joystick à fond pour galoper", 2.4)
		return
	if hero.global_position.distance_to(ground_portal_position) < 5.0:
		hero.global_position = sky_portal_position + Vector3(0.0, 1.0, 14.0)
		hero.set_spawn(hero.global_position)
		_show_message("Zone 10 débloquée : Citadelle Céleste", 3.0)
		return
	if hero.global_position.distance_to(sky_portal_position + Vector3(0.0, 0.0, 8.0)) < 5.0:
		hero.global_position = ground_portal_position + Vector3(0.0, 1.0, 8.0)
		hero.set_spawn(hero.global_position)
		_show_message("Retour au Royaume de Skypiea", 2.6)
		return
	_show_message("Approche-toi du cheval, d’un portail ou d’un point d’intérêt", 2.0)

func _on_enemy_defeated(enemy: Enemy3D) -> void:
	enemies.erase(enemy)
	defeated_count += 1
	_update_hud()
	if defeated_count == 5:
		_show_message("Quête avancée : cinq gardiens vaincus", 2.8)
	elif defeated_count == 10:
		_show_message("Le portail céleste réagit à ta puissance", 3.0)

func _on_health_changed(current: int, maximum: int) -> void:
	if is_instance_valid(health_bar):
		health_bar.max_value = maximum
		health_bar.value = current

func _on_stamina_changed(current: float, maximum: float) -> void:
	if is_instance_valid(stamina_bar):
		stamina_bar.max_value = maximum
		stamina_bar.value = current

func _update_current_zone() -> void:
	if not is_instance_valid(hero):
		return
	var best_zone: int = current_zone
	var best_distance: float = INF
	for index: int in range(zone_centers.size()):
		var distance: float = hero.global_position.distance_to(zone_centers[index])
		if distance < best_distance:
			best_distance = distance
			best_zone = index + 1
	current_zone = best_zone

func _update_hud() -> void:
	if not is_instance_valid(hero):
		return
	if is_instance_valid(health_bar):
		health_bar.max_value = hero.max_health
		health_bar.value = hero.health
	if is_instance_valid(stamina_bar):
		stamina_bar.max_value = hero.max_stamina
		stamina_bar.value = hero.stamina
	if is_instance_valid(zone_label):
		zone_label.text = zone_names[current_zone - 1]
	if is_instance_valid(quest_label):
		quest_label.text = "Gardiens vaincus : %d / 15   •   Monde exploré : zone %d / 10" % [defeated_count, current_zone]

func _build_mobile_hud() -> void:
	var canvas: CanvasLayer = CanvasLayer.new()
	canvas.name = "MobileHUD"
	add_child(canvas)
	var root: Control = Control.new()
	root.name = "HUDRoot"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(root)

	var top_panel: PanelContainer = PanelContainer.new()
	top_panel.anchor_left = 0.0
	top_panel.anchor_top = 0.0
	top_panel.anchor_right = 0.0
	top_panel.anchor_bottom = 0.0
	top_panel.offset_left = 24.0
	top_panel.offset_top = 20.0
	top_panel.offset_right = 430.0
	top_panel.offset_bottom = 142.0
	top_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.02, 0.04, 0.08, 0.76), 18))
	root.add_child(top_panel)
	var bars: VBoxContainer = VBoxContainer.new()
	bars.add_theme_constant_override("separation", 8)
	top_panel.add_child(bars)
	var title: Label = Label.new()
	title.text = "CHEIKH — CHEVALIER DE SKYPIEA"
	title.add_theme_font_size_override("font_size", 20)
	bars.add_child(title)
	health_bar = _make_bar(Color("#d9473f"))
	bars.add_child(health_bar)
	stamina_bar = _make_bar(Color("#41c66b"))
	bars.add_child(stamina_bar)

	zone_label = Label.new()
	zone_label.anchor_left = 0.5
	zone_label.anchor_top = 0.0
	zone_label.anchor_right = 0.5
	zone_label.anchor_bottom = 0.0
	zone_label.offset_left = -340.0
	zone_label.offset_top = 20.0
	zone_label.offset_right = 340.0
	zone_label.offset_bottom = 62.0
	zone_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	zone_label.add_theme_font_size_override("font_size", 27)
	zone_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.48))
	root.add_child(zone_label)

	quest_label = Label.new()
	quest_label.anchor_left = 0.5
	quest_label.anchor_top = 0.0
	quest_label.anchor_right = 0.5
	quest_label.anchor_bottom = 0.0
	quest_label.offset_left = -380.0
	quest_label.offset_top = 62.0
	quest_label.offset_right = 380.0
	quest_label.offset_bottom = 98.0
	quest_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	quest_label.add_theme_font_size_override("font_size", 18)
	root.add_child(quest_label)

	message_label = Label.new()
	message_label.anchor_left = 0.5
	message_label.anchor_top = 0.72
	message_label.anchor_right = 0.5
	message_label.anchor_bottom = 0.72
	message_label.offset_left = -420.0
	message_label.offset_top = -40.0
	message_label.offset_right = 420.0
	message_label.offset_bottom = 35.0
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	message_label.add_theme_font_size_override("font_size", 24)
	message_label.add_theme_color_override("font_color", Color.WHITE)
	message_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.9))
	message_label.add_theme_constant_override("outline_size", 10)
	root.add_child(message_label)

	joystick = JOYSTICK_SCRIPT.new() as MobileJoystick
	joystick.name = "MovementJoystick"
	joystick.anchor_left = 0.0
	joystick.anchor_top = 1.0
	joystick.anchor_right = 0.0
	joystick.anchor_bottom = 1.0
	joystick.offset_left = 28.0
	joystick.offset_top = -278.0
	joystick.offset_right = 278.0
	joystick.offset_bottom = -28.0
	root.add_child(joystick)

	var attack_button: Button = _make_round_button("ATQ", 118.0, Color(0.72, 0.16, 0.12, 0.88))
	_set_bottom_right_offsets(attack_button, -154.0, -168.0, 118.0)
	attack_button.button_down.connect(_on_attack_pressed)
	root.add_child(attack_button)

	var dodge_button: Button = _make_round_button("ESQ", 92.0, Color(0.12, 0.36, 0.72, 0.88))
	_set_bottom_right_offsets(dodge_button, -284.0, -105.0, 92.0)
	dodge_button.button_down.connect(_on_dodge_pressed)
	root.add_child(dodge_button)

	var jump_button: Button = _make_round_button("SAUT", 88.0, Color(0.16, 0.56, 0.38, 0.88))
	_set_bottom_right_offsets(jump_button, -244.0, -220.0, 88.0)
	jump_button.button_down.connect(_on_jump_pressed)
	root.add_child(jump_button)

	mount_button = _make_round_button("MONTER", 98.0, Color(0.62, 0.46, 0.12, 0.90))
	_set_bottom_right_offsets(mount_button, -100.0, -310.0, 98.0)
	mount_button.button_down.connect(_on_interact_pressed)
	root.add_child(mount_button)

	var map_button: Button = Button.new()
	map_button.text = "CARTE 10 ZONES"
	map_button.anchor_left = 1.0
	map_button.anchor_top = 0.0
	map_button.anchor_right = 1.0
	map_button.anchor_bottom = 0.0
	map_button.offset_left = -230.0
	map_button.offset_top = 22.0
	map_button.offset_right = -24.0
	map_button.offset_bottom = 76.0
	map_button.add_theme_font_size_override("font_size", 18)
	map_button.add_theme_stylebox_override("normal", _panel_style(Color(0.06, 0.18, 0.30, 0.88), 16))
	map_button.add_theme_stylebox_override("pressed", _panel_style(Color(0.10, 0.36, 0.58, 0.96), 16))
	map_button.pressed.connect(_toggle_map)
	root.add_child(map_button)

	_build_map_overlay(root)

func _build_map_overlay(root: Control) -> void:
	map_overlay = Control.new()
	map_overlay.name = "WorldMapOverlay"
	map_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	map_overlay.visible = false
	map_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(map_overlay)
	var backdrop: ColorRect = ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.0, 0.0, 0.0, 0.88)
	map_overlay.add_child(backdrop)
	map_texture = load("res://carte monde.png") as Texture2D
	var map_rect: TextureRect = TextureRect.new()
	map_rect.anchor_left = 0.08
	map_rect.anchor_top = 0.06
	map_rect.anchor_right = 0.92
	map_rect.anchor_bottom = 0.94
	map_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	map_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	map_rect.texture = map_texture
	map_overlay.add_child(map_rect)
	var close_button: Button = Button.new()
	close_button.text = "FERMER"
	close_button.anchor_left = 1.0
	close_button.anchor_top = 0.0
	close_button.anchor_right = 1.0
	close_button.anchor_bottom = 0.0
	close_button.offset_left = -190.0
	close_button.offset_top = 24.0
	close_button.offset_right = -28.0
	close_button.offset_bottom = 78.0
	close_button.add_theme_font_size_override("font_size", 20)
	close_button.pressed.connect(_toggle_map)
	map_overlay.add_child(close_button)

func _toggle_map() -> void:
	if not is_instance_valid(map_overlay):
		return
	map_overlay.visible = not map_overlay.visible
	get_tree().paused = map_overlay.visible
	map_overlay.process_mode = Node.PROCESS_MODE_WHEN_PAUSED

func _make_bar(fill_color: Color) -> ProgressBar:
	var bar: ProgressBar = ProgressBar.new()
	bar.custom_minimum_size = Vector2(370.0, 24.0)
	bar.show_percentage = false
	bar.add_theme_stylebox_override("background", _panel_style(Color(0.0, 0.0, 0.0, 0.55), 10))
	bar.add_theme_stylebox_override("fill", _panel_style(fill_color, 10))
	return bar

func _make_round_button(text_value: String, diameter: float, color: Color) -> Button:
	var button: Button = Button.new()
	button.text = text_value
	button.custom_minimum_size = Vector2(diameter, diameter)
	button.add_theme_font_size_override("font_size", 19)
	button.add_theme_stylebox_override("normal", _panel_style(color, int(diameter * 0.5)))
	button.add_theme_stylebox_override("hover", _panel_style(color.lightened(0.12), int(diameter * 0.5)))
	button.add_theme_stylebox_override("pressed", _panel_style(color.darkened(0.22), int(diameter * 0.5)))
	return button

func _set_bottom_right_offsets(control: Control, right_margin: float, bottom_margin: float, diameter: float) -> void:
	control.anchor_left = 1.0
	control.anchor_top = 1.0
	control.anchor_right = 1.0
	control.anchor_bottom = 1.0
	control.offset_left = right_margin - diameter
	control.offset_top = bottom_margin - diameter
	control.offset_right = right_margin
	control.offset_bottom = bottom_margin

func _panel_style(color: Color, radius: int) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.62, 0.82, 1.0, 0.35)
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	return style

func _show_message(text_value: String, duration: float) -> void:
	if not is_instance_valid(message_label):
		return
	message_token += 1
	var token: int = message_token
	message_label.text = text_value
	await get_tree().create_timer(duration).timeout
	if token == message_token and is_instance_valid(message_label):
		message_label.text = ""

func _start_music() -> void:
	var music_paths: Array[String] = ["res://music.mp3", "res://music 2.mp3", "res://music interface.mp3"]
	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	player.name = "WorldMusic"
	for path: String in music_paths:
		if ResourceLoader.exists(path):
			var stream: AudioStream = load(path) as AudioStream
			if stream != null:
				player.stream = stream
				break
	player.volume_db = -12.0
	player.finished.connect(player.play)
	add_child(player)
	if player.stream != null:
		player.play()

func _create_tree(position_value: Vector3, scale_value: float, leaf_color: Color) -> void:
	var tree: Node3D = Node3D.new()
	tree.position = position_value
	tree.scale = Vector3.ONE * scale_value
	add_child(tree)
	var trunk_material: StandardMaterial3D = _material(Color("#49301d"), 0.0, 0.92)
	var leaves_material: StandardMaterial3D = _material(leaf_color, 0.0, 0.88)
	_create_mesh(tree, _cylinder(0.22, 0.34, 3.2, 10), trunk_material, Vector3(0.0, 1.6, 0.0))
	_create_mesh(tree, _sphere(1.15, 1.95), leaves_material, Vector3(0.0, 3.35, 0.0))
	_create_mesh(tree, _sphere(0.85, 1.45), leaves_material, Vector3(-0.70, 3.05, 0.12))
	_create_mesh(tree, _sphere(0.85, 1.45), leaves_material, Vector3(0.70, 3.05, -0.12))

func _create_rock(position_value: Vector3, scale_value: float, color: Color) -> void:
	var rock: MeshInstance3D = _create_mesh(self, _sphere(0.75, 1.0), _material(color, 0.06, 0.92), position_value + Vector3(0.0, scale_value * 0.42, 0.0), Vector3(randf_range(-0.2, 0.2), randf_range(0.0, TAU), randf_range(-0.2, 0.2)), Vector3(scale_value * 1.2, scale_value * 0.72, scale_value))
	rock.name = "Rock"

func _create_cone_rock(position_value: Vector3, radius_value: float, height_value: float, color: Color) -> void:
	var mesh: CylinderMesh = _cone(radius_value, 0.0, height_value, 18)
	_create_mesh(self, mesh, _material(color, 0.04, 0.94), position_value)

func _create_pyramid(position_value: Vector3, radius_value: float, height_value: float, color: Color) -> void:
	var mesh: CylinderMesh = _cone(radius_value, 0.0, height_value, 4)
	_create_mesh(self, mesh, _material(color, 0.02, 0.92), position_value, Vector3(0.0, deg_to_rad(45.0), 0.0))

func _create_flat_disc(position_value: Vector3, radius_value: float, color: Color) -> void:
	var disc: CylinderMesh = CylinderMesh.new()
	disc.top_radius = radius_value
	disc.bottom_radius = radius_value
	disc.height = 0.10
	disc.radial_segments = 24
	var material: StandardMaterial3D = _material(color, 0.06, 0.22)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_create_mesh(self, disc, material, position_value)

func _create_glowing_orb(position_value: Vector3, color: Color) -> void:
	var material: StandardMaterial3D = _material(color, 0.10, 0.18)
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 2.2
	_create_mesh(self, _sphere(0.18, 0.34), material, position_value)

func _create_waterfall(position_value: Vector3) -> void:
	var material: StandardMaterial3D = _material(Color(0.62, 0.88, 1.0, 0.62), 0.0, 0.18)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_create_mesh(self, _box(Vector3(4.0, 0.12, 8.0)), material, position_value)

func _create_house(position_value: Vector3) -> void:
	_static_box("HouseBody", Vector3(6.4, 3.8, 5.0), position_value + Vector3(0.0, 1.9, 0.0), Color("#8e6740"))
	var roof: PrismMesh = PrismMesh.new()
	roof.size = Vector3(7.2, 2.6, 5.8)
	_create_mesh(self, roof, _material(Color("#74362c"), 0.0, 0.88), position_value + Vector3(0.0, 4.8, 0.0), Vector3(0.0, deg_to_rad(90.0), 0.0))
	_create_visual_box(Vector3(1.4, 2.3, 0.18), position_value + Vector3(0.0, 1.15, -2.58), Color("#3a2418"), false)

func _create_well(position_value: Vector3) -> void:
	var wall: CylinderMesh = CylinderMesh.new()
	wall.top_radius = 2.0
	wall.bottom_radius = 2.0
	wall.height = 1.1
	wall.radial_segments = 18
	_create_mesh(self, wall, _material(Color("#77756a"), 0.03, 0.90), position_value + Vector3(0.0, 0.55, 0.0))
	_static_box("WellBeam", Vector3(5.0, 0.35, 0.35), position_value + Vector3(0.0, 3.4, 0.0), Color("#56351f"))

func _create_castle(position_value: Vector3, celestial: bool = false) -> void:
	var wall_color: Color = Color("#e3d2a1") if celestial else Color("#b7a27a")
	_static_box("CastleKeep", Vector3(18.0, 13.0, 15.0), position_value + Vector3(0.0, 6.5, 0.0), wall_color)
	for x_value: float in [-11.0, 11.0]:
		for z_value: float in [-9.0, 9.0]:
			var tower_position: Vector3 = position_value + Vector3(x_value, 8.0, z_value)
			var tower: CylinderMesh = CylinderMesh.new()
			tower.top_radius = 3.8
			tower.bottom_radius = 4.2
			tower.height = 16.0
			tower.radial_segments = 16
			_create_mesh(self, tower, _material(wall_color, 0.04, 0.86), tower_position)
			var roof: CylinderMesh = _cone(5.0, 0.0, 6.5, 16)
			_create_mesh(self, roof, _material(Color("#165d9e"), 0.18, 0.48), tower_position + Vector3(0.0, 11.2, 0.0))
	_static_box("CastleGate", Vector3(5.0, 6.5, 1.0), position_value + Vector3(0.0, 3.25, -7.8), Color("#49301d"))

func _create_boat(position_value: Vector3) -> void:
	var boat: Node3D = Node3D.new()
	boat.position = position_value
	add_child(boat)
	_create_mesh(boat, _prism(Vector3(4.2, 2.0, 9.0)), _material(Color("#5a3420"), 0.0, 0.88), Vector3.ZERO, Vector3(0.0, 0.0, deg_to_rad(90.0)))
	_create_mesh(boat, _cylinder(0.16, 0.22, 7.0, 10), _material(Color("#4a2d1b"), 0.0, 0.90), Vector3(0.0, 4.0, 0.0))
	_create_mesh(boat, _box(Vector3(0.12, 4.6, 5.5)), _material(Color("#e9e2c9"), 0.0, 0.74), Vector3(0.0, 4.5, 0.0), Vector3(0.0, 0.0, deg_to_rad(90.0)))

func _create_portal(position_value: Vector3, color: Color, label_text: String) -> void:
	var portal_root: Node3D = Node3D.new()
	portal_root.position = position_value
	add_child(portal_root)
	var material: StandardMaterial3D = _material(color, 0.25, 0.15)
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 2.4
	var column: CylinderMesh = CylinderMesh.new()
	column.top_radius = 1.8
	column.bottom_radius = 1.8
	column.height = 4.8
	column.radial_segments = 24
	_create_mesh(portal_root, column, material, Vector3(0.0, 2.4, 0.0), Vector3.ZERO, Vector3(1.0, 1.0, 0.20))
	var label: Label3D = Label3D.new()
	label.text = label_text
	label.position = Vector3(0.0, 5.4, 0.0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 32
	label.outline_size = 8
	portal_root.add_child(label)

func _static_box(node_name: String, size_value: Vector3, position_value: Vector3, color: Color) -> StaticBody3D:
	var body: StaticBody3D = StaticBody3D.new()
	body.name = node_name
	body.position = position_value
	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size_value
	mesh.material = _material(color, 0.03, 0.88)
	mesh_instance.mesh = mesh
	body.add_child(mesh_instance)
	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = size_value
	collision.shape = shape
	body.add_child(collision)
	add_child(body)
	return body

func _create_visual_box(size_value: Vector3, position_value: Vector3, color: Color, emissive: bool) -> MeshInstance3D:
	var material: StandardMaterial3D = _material(color, 0.0, 0.82)
	if emissive:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 2.0
	return _create_mesh(self, _box(size_value), material, position_value)

func _create_mesh(parent: Node3D, mesh: Mesh, material: Material, local_position: Vector3, local_rotation: Vector3 = Vector3.ZERO, local_scale: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = local_position
	instance.rotation = local_rotation
	instance.scale = local_scale
	parent.add_child(instance)
	return instance

func _material(color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	return material

func _box(size_value: Vector3) -> BoxMesh:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size_value
	return mesh

func _sphere(radius_value: float, height_value: float) -> SphereMesh:
	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius = radius_value
	mesh.height = height_value
	mesh.radial_segments = 10
	mesh.rings = 5
	return mesh

func _cylinder(top_radius: float, bottom_radius: float, height_value: float, segments: int) -> CylinderMesh:
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = top_radius
	mesh.bottom_radius = bottom_radius
	mesh.height = height_value
	mesh.radial_segments = segments
	return mesh

func _cone(bottom_radius: float, top_radius: float, height_value: float, segments: int) -> CylinderMesh:
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.bottom_radius = bottom_radius
	mesh.top_radius = top_radius
	mesh.height = height_value
	mesh.radial_segments = segments
	return mesh

func _prism(size_value: Vector3) -> PrismMesh:
	var mesh: PrismMesh = PrismMesh.new()
	mesh.size = size_value
	return mesh
