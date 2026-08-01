extends Node3D

const PLAYER_SCRIPT = preload("res://scripts/player.gd")
const ENEMY_SCRIPT = preload("res://scripts/enemy.gd")

const HERO_MODEL = "res://generated_models/hero_knight.glb"
const TREE_MODEL = "res://generated_models/world_tree.glb"
const HOUSE_MODEL = "res://generated_models/village_house.glb"
const RUIN_MODEL = "res://generated_models/ruin_gate.glb"
const BOAT_MODEL = "res://generated_models/boat.glb"
const MUSIC_WORLD_PATH = "res://music.mp3"
const MUSIC_BATTLE_PATH = "res://music 2.mp3"
const SAVE_PATH = "user://skypiea_stable_v1.cfg"

const ENEMY_MODELS = [
	"res://generated_models/enemy_01_armored_boar.glb",
	"res://generated_models/enemy_02_crystal_golem.glb",
	"res://generated_models/enemy_03_lava_hound.glb",
	"res://generated_models/enemy_04_anubis_knight.glb",
	"res://generated_models/enemy_05_goblin_raider.glb",
	"res://generated_models/enemy_06_ice_ogre.glb",
	"res://generated_models/enemy_07_orc_warlord.glb"
]

const ZONE_NAMES = [
	"Village des Sources",
	"Forêt d'Émeraude",
	"Marais des Brumes",
	"Canyon Rouge",
	"Désert Solaire",
	"Côte des Pirates",
	"Monts de Glace",
	"Terres Volcaniques",
	"Îles Célestes",
	"Citadelle Noire"
]

const ZONE_CENTERS = [
	Vector3(-108.0, 0.0, 34.0),
	Vector3(-54.0, 0.0, 34.0),
	Vector3(0.0, 0.0, 34.0),
	Vector3(54.0, 0.0, 34.0),
	Vector3(108.0, 0.0, 34.0),
	Vector3(108.0, 0.0, -34.0),
	Vector3(54.0, 0.0, -34.0),
	Vector3(0.0, 0.0, -34.0),
	Vector3(-54.0, 0.0, -34.0),
	Vector3(-108.0, 0.0, -34.0)
]

const ZONE_COLORS = [
	Color(0.18, 0.46, 0.18),
	Color(0.055, 0.31, 0.095),
	Color(0.13, 0.24, 0.17),
	Color(0.44, 0.18, 0.08),
	Color(0.64, 0.47, 0.20),
	Color(0.16, 0.42, 0.38),
	Color(0.56, 0.72, 0.82),
	Color(0.17, 0.12, 0.11),
	Color(0.42, 0.55, 0.64),
	Color(0.12, 0.10, 0.18)
]

var player
var enemies = []
var zone_remaining = []
var zone_total = []
var zone_gates = {}
var unlocked_zone = 1
var current_zone = 0
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
var music_player
var battle_music_active = false
var zone_check_timer = 0.0
var message_token = 0

var boot_layer
var boot_label
var boot_camera

func _ready():
	seed(20260801)
	if OS.has_feature("mobile"):
		DisplayServer.screen_set_orientation(DisplayServer.SCREEN_SENSOR_LANDSCAPE)
	_setup_input()
	_build_loading_screen()
	await get_tree().process_frame

	_set_loading_text("Création du ciel et de l'océan…")
	_build_environment()
	await get_tree().process_frame

	for zone_index in range(ZONE_CENTERS.size()):
		_set_loading_text("Chargement zone %d / 10\n%s" % [zone_index + 1, ZONE_NAMES[zone_index]])
		_build_zone(zone_index)
		await get_tree().process_frame

	_set_loading_text("Connexion des dix zones…")
	_build_connectors()
	_build_gates()
	await get_tree().process_frame

	_set_loading_text("Chargement du héros…")
	_spawn_player()
	await get_tree().process_frame

	_set_loading_text("Chargement des gardiens…")
	_spawn_guardians()
	await get_tree().process_frame

	_build_hud()
	_load_progress()
	_update_hud()
	_play_music(MUSIC_WORLD_PATH)
	_finish_loading()
	_show_message("Monde chargé — traverse les 10 zones", 4.0)

func _process(delta):
	if not is_instance_valid(player):
		return
	player.set_virtual_move(virtual_move)
	zone_check_timer -= delta
	if zone_check_timer <= 0.0:
		zone_check_timer = 0.2
		_update_current_zone()
	_update_battle_music()

func _notification(what):
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save_progress()

func _unhandled_input(event):
	if event is InputEventScreenTouch:
		var screen_size = get_viewport().get_visible_rect().size
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
	boot_camera.position = Vector3(-108.0, 28.0, 68.0)
	add_child(boot_camera)
	boot_camera.look_at(ZONE_CENTERS[0], Vector3.UP)
	boot_camera.current = true

	boot_layer = CanvasLayer.new()
	boot_layer.layer = 100
	add_child(boot_layer)
	var background = ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = Color(0.015, 0.032, 0.075, 1.0)
	boot_layer.add_child(background)

	var title = Label.new()
	title.text = "LES CHRONIQUES DE SKYPIEA"
	title.set_anchors_preset(Control.PRESET_CENTER)
	title.position = Vector2(-400.0, -105.0)
	title.size = Vector2(800.0, 60.0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	background.add_child(title)

	boot_label = Label.new()
	boot_label.text = "Initialisation du moteur 3D…"
	boot_label.set_anchors_preset(Control.PRESET_CENTER)
	boot_label.position = Vector2(-400.0, -20.0)
	boot_label.size = Vector2(800.0, 100.0)
	boot_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boot_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	boot_label.add_theme_font_size_override("font_size", 23)
	background.add_child(boot_label)

	var hint = Label.new()
	hint.text = "Chargement optimisé pour Android"
	hint.set_anchors_preset(Control.PRESET_CENTER)
	hint.position = Vector2(-400.0, 90.0)
	hint.size = Vector2(800.0, 40.0)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.modulate = Color(0.68, 0.80, 0.95)
	hint.add_theme_font_size_override("font_size", 17)
	background.add_child(hint)

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
	sky_material.sky_top_color = Color(0.025, 0.11, 0.32)
	sky_material.sky_horizon_color = Color(0.66, 0.82, 0.96)
	sky_material.ground_bottom_color = Color(0.018, 0.035, 0.045)
	sky_material.ground_horizon_color = Color(0.30, 0.41, 0.31)
	sky.sky_material = sky_material
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.84
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.fog_enabled = true
	environment.fog_density = 0.0015
	world_environment.environment = environment
	add_child(world_environment)

	var sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52.0, -28.0, 0.0)
	sun.light_energy = 1.45
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 85.0
	add_child(sun)

	var ocean = MeshInstance3D.new()
	var ocean_mesh = PlaneMesh.new()
	ocean_mesh.size = Vector2(390.0, 230.0)
	ocean_mesh.material = _material(Color(0.012, 0.19, 0.36, 0.86))
	ocean.mesh = ocean_mesh
	ocean.position.y = -1.15
	add_child(ocean)

func _build_zone(zone_index):
	var center = ZONE_CENTERS[zone_index]
	_static_box("Zone_%02d_Ground" % (zone_index + 1), Vector3(50.0, 1.2, 46.0), center + Vector3(0.0, -0.6, 0.0), ZONE_COLORS[zone_index])
	_add_zone_title(zone_index, center + Vector3(0.0, 4.8, -18.5))

	match zone_index:
		0:
			for offset in [Vector3(-11, 0, -8), Vector3(11, 0, -8), Vector3(-11, 0, 10), Vector3(11, 0, 10)]:
				_spawn_model(HOUSE_MODEL, center + offset, Vector3.ONE * 0.88)
			for offset in [Vector3(-19, 0, -16), Vector3(19, 0, -16), Vector3(-19, 0, 16), Vector3(19, 0, 16)]:
				_spawn_model(TREE_MODEL, center + offset, Vector3.ONE * 0.84)
			_visual_box("VillagePath", Vector3(7.0, 0.10, 34.0), center + Vector3(0, 0.06, 0), Color(0.48, 0.34, 0.20))
		1:
			for index in range(10):
				var x = -20.0 + float(index % 5) * 10.0
				var z = -14.0 + float(index / 5) * 27.0
				_spawn_model(TREE_MODEL, center + Vector3(x, 0, z), Vector3.ONE * (0.82 + float(index % 3) * 0.08), Vector3(0, float(index) * 0.4, 0))
		2:
			_visual_box("SwampPoolA", Vector3(14.0, 0.05, 9.0), center + Vector3(-11, 0.06, -8), Color(0.06, 0.26, 0.20, 0.78))
			_visual_box("SwampPoolB", Vector3(14.0, 0.05, 9.0), center + Vector3(11, 0.06, 9), Color(0.06, 0.26, 0.20, 0.78))
			for offset in [Vector3(-19, 0, -16), Vector3(19, 0, -16), Vector3(-19, 0, 16), Vector3(19, 0, 16)]:
				_spawn_model(TREE_MODEL, center + offset, Vector3(0.65, 0.88, 0.65))
		3:
			for side in [-1.0, 1.0]:
				for index in range(5):
					_static_box("CanyonWall", Vector3(5.0, 5.0, 5.0), center + Vector3(side * 18.0, 2.5, -16.0 + float(index) * 8.0), Color(0.42, 0.16, 0.07))
		4:
			for index in range(7):
				var dune_x = -18.0 + float(index % 4) * 12.0
				var dune_z = -12.0 + float(index / 4) * 24.0
				_dune(center + Vector3(dune_x, 0.35, dune_z), 2.0 + float(index % 3) * 0.4)
			_spawn_model(RUIN_MODEL, center + Vector3(0, 0, -12), Vector3.ONE * 1.08)
		5:
			_visual_box("Lagoon", Vector3(44.0, 0.06, 14.0), center + Vector3(0, 0.08, -14), Color(0.02, 0.40, 0.61, 0.82))
			_spawn_model(BOAT_MODEL, center + Vector3(0, 0.12, -13), Vector3.ONE * 0.88, Vector3(0, -0.35, 0))
			for tree_x in [-18.0, -6.0, 6.0, 18.0]:
				_spawn_model(TREE_MODEL, center + Vector3(tree_x, 0, 13), Vector3(0.56, 0.88, 0.56))
		6:
			for index in range(8):
				var angle = TAU * float(index) / 8.0
				_ice_crystal(center + Vector3(cos(angle) * 16.0, 0, sin(angle) * 14.0), 1.3 + float(index % 2) * 0.35)
		7:
			_visual_box("LavaPoolA", Vector3(13.0, 0.08, 8.0), center + Vector3(-11, 0.09, -8), Color(0.92, 0.11, 0.01), Color(1.0, 0.04, 0.0))
			_visual_box("LavaPoolB", Vector3(13.0, 0.08, 8.0), center + Vector3(11, 0.09, 9), Color(0.92, 0.11, 0.01), Color(1.0, 0.04, 0.0))
			for offset in [Vector3(-19, 1, -16), Vector3(19, 1, -16), Vector3(-19, 1, 16), Vector3(19, 1, 16)]:
				_rock(center + offset, Vector3(3.0, 2.0, 2.6), Color(0.10, 0.08, 0.075))
		8:
			for index in range(5):
				var platform_x = -18.0 + float(index) * 9.0
				_visual_box("SkyPlatform", Vector3(11.0, 0.8, 9.0), center + Vector3(platform_x, 0.4 + float(index % 2) * 0.4, 0), Color(0.56, 0.66, 0.74))
			_spawn_model(RUIN_MODEL, center + Vector3(0, 0, -13), Vector3.ONE * 1.1)
		9:
			_spawn_model(RUIN_MODEL, center + Vector3(0, 0, 8), Vector3.ONE * 1.5)
			for tower_x in [-18.0, -8.0, 8.0, 18.0]:
				_static_box("CitadelTower", Vector3(5.0, 9.0, 5.0), center + Vector3(tower_x, 4.5, -10.0), Color(0.08, 0.07, 0.11))

func _build_connectors():
	for index in range(ZONE_CENTERS.size() - 1):
		var start = ZONE_CENTERS[index]
		var finish = ZONE_CENTERS[index + 1]
		var midpoint = (start + finish) * 0.5
		if absf(start.x - finish.x) > absf(start.z - finish.z):
			_static_box("Bridge_%02d" % index, Vector3(absf(start.x - finish.x), 0.5, 8.0), midpoint + Vector3(0, -0.25, 0), Color(0.34, 0.27, 0.18))
		else:
			_static_box("Bridge_%02d" % index, Vector3(8.0, 0.5, absf(start.z - finish.z)), midpoint + Vector3(0, -0.25, 0), Color(0.34, 0.27, 0.18))

func _build_gates():
	for target_zone in range(2, ZONE_CENTERS.size()):
		var previous = ZONE_CENTERS[target_zone - 1]
		var target = ZONE_CENTERS[target_zone]
		var midpoint = (previous + target) * 0.5
		var horizontal = absf(previous.x - target.x) > absf(previous.z - target.z)
		var gate_size = Vector3(0.8, 5.0, 8.0) if horizontal else Vector3(8.0, 5.0, 0.8)
		var gate = _static_box("Gate_to_%02d" % (target_zone + 1), gate_size, midpoint + Vector3(0, 2.5, 0), Color(0.08, 0.52, 0.82, 0.60), Color(0.02, 0.42, 1.0))
		zone_gates[target_zone] = gate

func _spawn_player():
	player = PLAYER_SCRIPT.new()
	player.name = "CheikhHero"
	player.position = ZONE_CENTERS[0] + Vector3(0.0, 0.35, 7.0)
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
	zone_remaining.fill(0)
	zone_total.fill(0)
	for zone_index in range(1, ZONE_CENTERS.size()):
		var count = 2 if zone_index == 9 else 1
		zone_remaining[zone_index] = count
		zone_total[zone_index] = count
		for enemy_index in range(count):
			var enemy = ENEMY_SCRIPT.new()
			enemy.name = "Zone_%02d_Guardian_%02d" % [zone_index + 1, enemy_index + 1]
			enemy.position = ZONE_CENTERS[zone_index] + Vector3(-5.0 + float(enemy_index) * 10.0, 0.35, 3.0)
			enemy.set_meta("zone_index", zone_index)
			add_child(enemy)
			var model_index = (zone_index + enemy_index - 1) % ENEMY_MODELS.size()
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
		var flat = Vector3(offset.x, 0.0, offset.z)
		if flat.length() <= 3.0 and flat.length() > 0.01 and forward.dot(flat.normalized()) > -0.05:
			enemy.take_damage(34, player.global_position)

func _on_enemy_defeated(enemy):
	enemies.erase(enemy)
	var zone_index = int(enemy.get_meta("zone_index", 0))
	if zone_index <= 0 or zone_index >= zone_remaining.size():
		return
	zone_remaining[zone_index] = maxi(0, int(zone_remaining[zone_index]) - 1)
	total_defeated += 1
	if zone_remaining[zone_index] == 0:
		if zone_index == 9:
			game_complete = true
			_show_message("VICTOIRE — les 10 zones sont libérées !", 7.0)
		else:
			_unlock_zone(zone_index + 1)
	_update_hud()
	_save_progress()

func _unlock_zone(zone_index):
	if zone_index <= unlocked_zone or zone_index >= ZONE_CENTERS.size():
		return
	unlocked_zone = zone_index
	if zone_gates.has(zone_index):
		var gate = zone_gates[zone_index]
		if is_instance_valid(gate):
			gate.queue_free()
		zone_gates.erase(zone_index)
	_show_message("Zone %d ouverte : %s" % [zone_index + 1, ZONE_NAMES[zone_index]], 4.0)

func _on_interact():
	if current_zone == 0:
		_show_message("Entre dans la Forêt d'Émeraude et bats son gardien.", 3.0)
	elif current_zone > unlocked_zone:
		_show_message("Cette zone est verrouillée.", 2.5)
	elif int(zone_remaining[current_zone]) > 0:
		_show_message("Il reste %d gardien(s)." % int(zone_remaining[current_zone]), 2.5)
	else:
		_show_message("Zone sécurisée.", 2.5)

func _update_current_zone():
	var nearest = 0
	var nearest_distance = INF
	for index in range(ZONE_CENTERS.size()):
		var delta = player.global_position - ZONE_CENTERS[index]
		var distance = Vector2(delta.x, delta.z).length_squared()
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = index
	if nearest != current_zone:
		current_zone = nearest
		_update_hud()
		_show_message("Zone %d / 10 — %s" % [current_zone + 1, ZONE_NAMES[current_zone]], 2.5)

func _build_hud():
	var canvas = CanvasLayer.new()
	add_child(canvas)
	var root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(root)

	var top_bar = ColorRect.new()
	top_bar.color = Color(0.012, 0.022, 0.045, 0.86)
	top_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_bar.offset_bottom = 102.0
	top_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(top_bar)

	health_label = Label.new()
	health_label.position = Vector2(22, 10)
	health_label.size = Vector2(310, 34)
	health_label.add_theme_font_size_override("font_size", 24)
	top_bar.add_child(health_label)

	zone_label = Label.new()
	zone_label.position = Vector2(22, 46)
	zone_label.size = Vector2(610, 38)
	zone_label.add_theme_font_size_override("font_size", 20)
	top_bar.add_child(zone_label)

	objective_label = Label.new()
	objective_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	objective_label.position = Vector2(-520, 18)
	objective_label.size = Vector2(490, 64)
	objective_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	objective_label.add_theme_font_size_override("font_size", 18)
	top_bar.add_child(objective_label)

	message_label = Label.new()
	message_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	message_label.position = Vector2(-400, 112)
	message_label.size = Vector2(800, 62)
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	message_label.add_theme_font_size_override("font_size", 25)
	message_label.add_theme_constant_override("outline_size", 8)
	root.add_child(message_label)

	var joystick = ColorRect.new()
	joystick.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	joystick.position = Vector2(35, -215)
	joystick.size = Vector2(180, 180)
	joystick.color = Color(0.14, 0.30, 0.52, 0.52)
	joystick.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(joystick)

	joystick_knob = ColorRect.new()
	joystick_knob.position = Vector2(59, 59)
	joystick_knob.size = Vector2(62, 62)
	joystick_knob.color = Color(0.60, 0.84, 1.0, 0.86)
	joystick_knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	joystick.add_child(joystick_knob)

	_make_button(root, "ATTAQUE", Vector2(-185, -155), Vector2(150, 70), player.attack)
	_make_button(root, "ESQUIVE", Vector2(-350, -105), Vector2(140, 62), player.dodge)
	_make_button(root, "SAUT", Vector2(-350, -180), Vector2(140, 62), _mobile_jump)
	_make_button(root, "ACTION", Vector2(-185, -78), Vector2(150, 58), player.interact)

func _make_button(parent, text, position, button_size, callback):
	var button = Button.new()
	button.text = text
	button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	button.position = position
	button.size = button_size
	button.add_theme_font_size_override("font_size", 19)
	button.button_down.connect(callback)
	parent.add_child(button)

func _mobile_jump():
	if is_instance_valid(player) and player.is_on_floor():
		player.velocity.y = player.jump_velocity

func _update_joystick(position):
	var offset = (position - move_origin).limit_length(66.0)
	virtual_move = offset / 66.0
	if is_instance_valid(joystick_knob):
		joystick_knob.position = Vector2(59, 59) + offset

func _reset_joystick():
	if is_instance_valid(joystick_knob):
		joystick_knob.position = Vector2(59, 59)

func _on_health_changed(current, maximum):
	if is_instance_valid(health_label):
		health_label.text = "PV %d / %d" % [current, maximum]

func _update_hud():
	if is_instance_valid(player) and is_instance_valid(health_label):
		health_label.text = "PV %d / %d" % [player.health, player.max_health]
	if is_instance_valid(zone_label):
		zone_label.text = "Zone %d / 10 — %s" % [current_zone + 1, ZONE_NAMES[current_zone]]
	if is_instance_valid(objective_label):
		if game_complete:
			objective_label.text = "MONDE LIBÉRÉ — %d gardiens vaincus" % total_defeated
		elif current_zone == 0:
			objective_label.text = "Objectif : entre dans la Forêt d'Émeraude"
		elif current_zone > unlocked_zone:
			objective_label.text = "Zone verrouillée — termine la précédente"
		else:
			objective_label.text = "Gardiens : %d / %d | Zone max : %d / 10" % [int(zone_remaining[current_zone]), int(zone_total[current_zone]), unlocked_zone + 1]

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
		if is_instance_valid(enemy) and enemy.global_position.distance_to(player.global_position) < 14.0:
			nearby = true
			break
	if nearby != battle_music_active:
		battle_music_active = nearby
		_play_music(MUSIC_BATTLE_PATH if nearby else MUSIC_WORLD_PATH)

func _add_zone_title(zone_index, position):
	var anchor = Node3D.new()
	anchor.position = position
	add_child(anchor)
	var label = Label3D.new()
	label.text = "ZONE %d — %s" % [zone_index + 1, ZONE_NAMES[zone_index]]
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 40
	label.outline_size = 9
	label.modulate = Color(1.0, 0.88, 0.45)
	anchor.add_child(label)

func _static_box(node_name, box_size, box_position, color, emission = Color(0, 0, 0, 1)):
	var body = StaticBody3D.new()
	body.name = node_name
	body.position = box_position
	var visual = MeshInstance3D.new()
	var mesh = BoxMesh.new()
	mesh.size = box_size
	mesh.material = _material(color, emission)
	visual.mesh = mesh
	body.add_child(visual)
	var collision = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = box_size
	collision.shape = shape
	body.add_child(collision)
	add_child(body)
	return body

func _visual_box(node_name, box_size, box_position, color, emission = Color(0, 0, 0, 1)):
	var visual = MeshInstance3D.new()
	visual.name = node_name
	var mesh = BoxMesh.new()
	mesh.size = box_size
	mesh.material = _material(color, emission)
	visual.mesh = mesh
	visual.position = box_position
	add_child(visual)
	return visual

func _rock(position, rock_scale, color):
	var rock = MeshInstance3D.new()
	var mesh = SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 1.7
	mesh.material = _material(color)
	rock.mesh = mesh
	rock.position = position
	rock.scale = rock_scale
	add_child(rock)

func _dune(position, dune_size):
	var dune = MeshInstance3D.new()
	var mesh = SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 1.4
	mesh.material = _material(Color(0.75, 0.56, 0.26))
	dune.mesh = mesh
	dune.position = position
	dune.scale = Vector3(dune_size * 1.8, dune_size * 0.38, dune_size)
	add_child(dune)

func _ice_crystal(position, crystal_size):
	var crystal = MeshInstance3D.new()
	var mesh = PrismMesh.new()
	mesh.size = Vector3(crystal_size * 0.55, crystal_size * 2.0, crystal_size * 0.55)
	mesh.material = _material(Color(0.42, 0.82, 0.98, 0.78), Color(0.05, 0.38, 0.75))
	crystal.mesh = mesh
	crystal.position = position + Vector3(0, crystal_size, 0)
	add_child(crystal)

func _spawn_model(path, position, model_scale, rotation = Vector3.ZERO):
	if not ResourceLoader.exists(path):
		return null
	var resource = load(path)
	if not resource is PackedScene:
		return null
	var model = resource.instantiate()
	if not model is Node3D:
		model.queue_free()
		return null
	model.position = position
	model.scale = model_scale
	model.rotation = rotation
	add_child(model)
	return model

func _material(color, emission = Color(0, 0, 0, 1)):
	var material = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.62
	if color.a < 0.99:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if emission.r + emission.g + emission.b > 0.01:
		material.emission_enabled = true
		material.emission = emission
		material.emission_energy_multiplier = 2.0
	return material

func _save_progress():
	if not is_instance_valid(player):
		return
	var config = ConfigFile.new()
	config.set_value("world", "unlocked_zone", unlocked_zone)
	config.set_value("world", "total_defeated", total_defeated)
	config.set_value("world", "complete", game_complete)
	config.set_value("player", "position", player.global_position)
	config.set_value("player", "health", player.health)
	config.save(SAVE_PATH)

func _load_progress():
	var config = ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return
	unlocked_zone = clampi(int(config.get_value("world", "unlocked_zone", 1)), 1, 9)
	total_defeated = int(config.get_value("world", "total_defeated", 0))
	game_complete = bool(config.get_value("world", "complete", false))
	for gate_zone in zone_gates.keys():
		if int(gate_zone) <= unlocked_zone:
			var gate = zone_gates[gate_zone]
			if is_instance_valid(gate):
				gate.queue_free()
	var saved_position = config.get_value("player", "position", player.global_position)
	if saved_position is Vector3:
		player.global_position = saved_position
	player.health = clampi(int(config.get_value("player", "health", player.max_health)), 1, player.max_health)
	player.health_changed.emit(player.health, player.max_health)
