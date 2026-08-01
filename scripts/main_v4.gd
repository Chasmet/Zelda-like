extends Node3D

const PLAYER_SCRIPT = preload("res://scripts/player.gd")
const ENEMY_SCRIPT = preload("res://scripts/enemy.gd")
const MUSIC_WORLD: AudioStream = preload("res://music.mp3")
const MUSIC_BATTLE: AudioStream = preload("res://music 2.mp3")

const HERO_MODEL := "res://generated_models/hero_knight.glb"
const ENEMY_MODELS: Array[String] = [
	"res://generated_models/enemy_01_armored_boar.glb",
	"res://generated_models/enemy_02_crystal_golem.glb",
	"res://generated_models/enemy_03_lava_hound.glb",
	"res://generated_models/enemy_04_anubis_knight.glb",
	"res://generated_models/enemy_05_goblin_raider.glb",
	"res://generated_models/enemy_06_ice_ogre.glb",
	"res://generated_models/enemy_07_orc_warlord.glb"
]
const TREE_MODEL := "res://generated_models/world_tree.glb"
const HOUSE_MODEL := "res://generated_models/village_house.glb"
const RUIN_MODEL := "res://generated_models/ruin_gate.glb"
const BOAT_MODEL := "res://generated_models/boat.glb"

const ZONE_NAMES: Array[String] = [
	"Village des Sources", "Forêt d'Émeraude", "Marais des Brumes",
	"Canyon Rouge", "Désert Solaire", "Côte des Pirates",
	"Monts de Glace", "Terres Volcaniques", "Îles Célestes", "Citadelle Noire"
]
const ZONE_CENTERS: Array[Vector3] = [
	Vector3(-108.0, 0.0, 34.0), Vector3(-54.0, 0.0, 34.0), Vector3(0.0, 0.0, 34.0),
	Vector3(54.0, 0.0, 34.0), Vector3(108.0, 0.0, 34.0), Vector3(108.0, 0.0, -34.0),
	Vector3(54.0, 0.0, -34.0), Vector3(0.0, 0.0, -34.0), Vector3(-54.0, 0.0, -34.0),
	Vector3(-108.0, 0.0, -34.0)
]
const ZONE_COLORS: Array[Color] = [
	Color(0.18, 0.46, 0.18), Color(0.055, 0.31, 0.095), Color(0.13, 0.24, 0.17),
	Color(0.44, 0.18, 0.08), Color(0.64, 0.47, 0.20), Color(0.16, 0.42, 0.38),
	Color(0.56, 0.72, 0.82), Color(0.17, 0.12, 0.11), Color(0.42, 0.55, 0.64),
	Color(0.12, 0.10, 0.18)
]
const SAVE_PATH := "user://skypiea_world_v4.cfg"

var player: PlayerController
var enemies: Array[EnemyController] = []
var zone_enemies_remaining: Array[int] = []
var zone_enemies_total: Array[int] = []
var zone_gates: Dictionary = {}
var unlocked_zone: int = 1
var current_zone: int = 0
var total_defeated: int = 0
var game_complete: bool = false
var virtual_move := Vector2.ZERO
var move_touch_id := -1
var look_touch_id := -1
var move_origin := Vector2.ZERO
var joystick_knob: ColorRect
var health_label: Label
var zone_label: Label
var objective_label: Label
var message_label: Label
var music_player: AudioStreamPlayer
var battle_music_active := false
var zone_check_timer := 0.0
var message_token := 0

func _ready() -> void:
	seed(20260801)
	if OS.has_feature("mobile"):
		DisplayServer.screen_set_orientation(DisplayServer.SCREEN_SENSOR_LANDSCAPE)
	_setup_input()
	_build_environment()
	_build_ten_zone_world()
	_spawn_player()
	_spawn_zone_enemies()
	_build_hud()
	_play_music(MUSIC_WORLD)
	_load_progress()
	_update_hud()
	_show_message("Monde ouvert : 10 zones reliées", 3.5)

func _process(delta: float) -> void:
	if not is_instance_valid(player):
		return
	player.set_virtual_move(virtual_move)
	zone_check_timer -= delta
	if zone_check_timer <= 0.0:
		zone_check_timer = 0.20
		_update_current_zone()
	_update_battle_music()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save_progress()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		var size := get_viewport().get_visible_rect().size
		if touch.pressed and touch.position.x < size.x * 0.42 and touch.position.y > size.y * 0.30 and move_touch_id < 0:
			move_touch_id = touch.index
			move_origin = touch.position
			_update_joystick(touch.position)
		elif touch.pressed and look_touch_id < 0:
			look_touch_id = touch.index
		elif not touch.pressed and touch.index == move_touch_id:
			move_touch_id = -1
			virtual_move = Vector2.ZERO
			_reset_joystick()
		elif not touch.pressed and touch.index == look_touch_id:
			look_touch_id = -1
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index == move_touch_id:
			_update_joystick(drag.position)
		elif drag.index == look_touch_id and is_instance_valid(player):
			player.add_camera_look(drag.relative * 0.0042)

func _setup_input() -> void:
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
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	InputMap.action_add_event("attack", mouse)

func _add_key(action: StringName, keycode: int) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	InputMap.action_add_event(action, event)

func _build_environment() -> void:
	var world_env := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
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
	world_env.environment = environment
	add_child(world_env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52.0, -28.0, 0.0)
	sun.light_energy = 1.45
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 85.0
	add_child(sun)
	var ocean := MeshInstance3D.new()
	var ocean_mesh := PlaneMesh.new()
	ocean_mesh.size = Vector2(390.0, 230.0)
	var ocean_material := _material(Color(0.012, 0.19, 0.36, 0.86))
	ocean_material.metallic = 0.18
	ocean_material.roughness = 0.20
	ocean_mesh.material = ocean_material
	ocean.mesh = ocean_mesh
	ocean.position.y = -1.15
	add_child(ocean)

func _build_ten_zone_world() -> void:
	for zone_index in range(ZONE_CENTERS.size()):
		_build_zone(zone_index)
	_build_connectors()
	_build_progression_gates()

func _build_zone(zone_index: int) -> void:
	var center := ZONE_CENTERS[zone_index]
	_static_box("Zone_%02d_Ground" % (zone_index + 1), Vector3(50.0, 1.2, 46.0), center + Vector3(0.0, -0.6, 0.0), ZONE_COLORS[zone_index])
	_add_zone_title(zone_index, center + Vector3(0.0, 4.8, -18.5))
	match zone_index:
		0: _decorate_village(center)
		1: _decorate_forest(center)
		2: _decorate_swamp(center)
		3: _decorate_canyon(center)
		4: _decorate_desert(center)
		5: _decorate_coast(center)
		6: _decorate_ice(center)
		7: _decorate_volcano(center)
		8: _decorate_sky(center)
		9: _decorate_citadel(center)

func _build_connectors() -> void:
	for index in range(ZONE_CENTERS.size() - 1):
		var start := ZONE_CENTERS[index]
		var finish := ZONE_CENTERS[index + 1]
		var midpoint := (start + finish) * 0.5
		if absf(start.x - finish.x) > absf(start.z - finish.z):
			_static_box("Bridge_%02d" % index, Vector3(absf(start.x - finish.x), 0.5, 8.0), midpoint + Vector3(0, -0.25, 0), Color(0.34, 0.27, 0.18))
		else:
			_static_box("Bridge_%02d" % index, Vector3(8.0, 0.5, absf(start.z - finish.z)), midpoint + Vector3(0, -0.25, 0), Color(0.34, 0.27, 0.18))

func _build_progression_gates() -> void:
	for target_zone in range(2, ZONE_CENTERS.size()):
		var previous := ZONE_CENTERS[target_zone - 1]
		var target := ZONE_CENTERS[target_zone]
		var midpoint := (previous + target) * 0.5
		var horizontal := absf(previous.x - target.x) > absf(previous.z - target.z)
		var size := Vector3(0.8, 5.0, 8.0) if horizontal else Vector3(8.0, 5.0, 0.8)
		var gate := _static_box("Gate_to_zone_%02d" % (target_zone + 1), size, midpoint + Vector3(0.0, 2.5, 0.0), Color(0.08, 0.52, 0.82, 0.58), Color(0.02, 0.42, 1.0))
		zone_gates[target_zone] = gate
		_add_world_label(gate, "Zone %d verrouillée" % (target_zone + 1), Vector3(0, 3.1, 0), Color(0.55, 0.88, 1.0))

func _decorate_village(center: Vector3) -> void:
	for offset in [Vector3(-13, 0, -10), Vector3(13, 0, -10), Vector3(-13, 0, 10), Vector3(13, 0, 10)]:
		_spawn_model(HOUSE_MODEL, center + offset, Vector3.ONE * 0.92)
	for index in range(12):
		var angle := TAU * float(index) / 12.0
		_spawn_model(TREE_MODEL, center + Vector3(cos(angle) * 20.0, 0, sin(angle) * 18.0), Vector3.ONE * (0.80 + float(index % 3) * 0.10))
	_visual_box("VillagePath", Vector3(8.0, 0.10, 34.0), center + Vector3(0, 0.06, 0), Color(0.48, 0.34, 0.20))

func _decorate_forest(center: Vector3) -> void:
	for index in range(28):
		var x := float((index * 17) % 43) - 21.0
		var z := float((index * 29) % 39) - 19.0
		if absf(z) < 4.0:
			z += 7.0 if z >= 0.0 else -7.0
		_spawn_model(TREE_MODEL, center + Vector3(x, 0, z), Vector3.ONE * (0.78 + float(index % 5) * 0.08), Vector3(0, float(index) * 0.31, 0))
	for offset in [Vector3(-16, 0.5, -13), Vector3(17, 0.7, 10), Vector3(-18, 0.45, 15)]:
		_rock(center + offset, Vector3(2.8, 1.4, 2.4), Color(0.21, 0.25, 0.22))

func _decorate_swamp(center: Vector3) -> void:
	for offset in [Vector3(-13, 0.05, -11), Vector3(12, 0.05, -8), Vector3(-8, 0.05, 12), Vector3(14, 0.05, 13)]:
		_visual_box("SwampPool", Vector3(13.0, 0.05, 8.0), center + offset, Color(0.08, 0.28, 0.22, 0.74), Color(0.02, 0.18, 0.12))
	for index in range(14):
		var angle := TAU * float(index) / 14.0
		_spawn_model(TREE_MODEL, center + Vector3(cos(angle) * 20.0, 0, sin(angle) * 18.0), Vector3(0.65, 0.92, 0.65), Vector3(0, angle, 0))

func _decorate_canyon(center: Vector3) -> void:
	for side in [-1.0, 1.0]:
		for index in range(7):
			_static_box("CanyonWall", Vector3(5.0, 5.0 + float(index % 3) * 1.2, 5.0), center + Vector3(side * (17.0 + float(index % 2) * 3.0), 2.5, -18.0 + float(index) * 6.0), Color(0.40, 0.15, 0.065))
	for offset in [Vector3(-8, 0.6, -12), Vector3(9, 0.7, -2), Vector3(-7, 0.5, 12)]:
		_rock(center + offset, Vector3(3.6, 1.8, 2.8), Color(0.50, 0.20, 0.08))

func _decorate_desert(center: Vector3) -> void:
	for index in range(13):
		var x := float((index * 19) % 41) - 20.0
		var z := float((index * 23) % 37) - 18.0
		_dune(center + Vector3(x, 0.35, z), 2.0 + float(index % 4) * 0.55)
	_spawn_model(RUIN_MODEL, center + Vector3(0, 0, -13), Vector3.ONE * 1.18)

func _decorate_coast(center: Vector3) -> void:
	_visual_box("Lagoon", Vector3(45.0, 0.06, 15.0), center + Vector3(0, 0.08, -14), Color(0.02, 0.42, 0.60, 0.80), Color(0.01, 0.18, 0.36))
	_spawn_model(BOAT_MODEL, center + Vector3(2, 0.10, -13), Vector3.ONE * 0.92, Vector3(0, -0.35, 0))
	for index in range(12):
		var x := -20.0 + float(index) * 3.6
		_spawn_model(TREE_MODEL, center + Vector3(x, 0, 12.0 + float(index % 3) * 2.0), Vector3(0.55, 0.88, 0.55), Vector3(0, float(index), 0))

func _decorate_ice(center: Vector3) -> void:
	for index in range(18):
		var angle := TAU * float(index) / 18.0
		var radius := 11.0 + float(index % 4) * 3.0
		_ice_crystal(center + Vector3(cos(angle) * radius, 0, sin(angle) * radius), 1.2 + float(index % 3) * 0.35)
	for offset in [Vector3(-15, 1.3, -13), Vector3(15, 1.5, 10)]:
		_rock(center + offset, Vector3(6.0, 3.0, 5.0), Color(0.50, 0.62, 0.70))

func _decorate_volcano(center: Vector3) -> void:
	for offset in [Vector3(-14, 0.08, -10), Vector3(12, 0.08, -8), Vector3(-6, 0.08, 13), Vector3(15, 0.08, 12)]:
		_visual_box("LavaPool", Vector3(12.0, 0.08, 7.0), center + offset, Color(0.92, 0.12, 0.015), Color(1.0, 0.05, 0.0))
	for index in range(16):
		var angle := TAU * float(index) / 16.0
		_rock(center + Vector3(cos(angle) * 20.0, 0.8, sin(angle) * 18.0), Vector3(3.2, 2.0, 2.8), Color(0.10, 0.085, 0.08))

func _decorate_sky(center: Vector3) -> void:
	for index in range(9):
		var x := -18.0 + float(index % 3) * 18.0
		var z := -14.0 + float(index / 3) * 14.0
		var platform := _visual_box("SkyPlatform", Vector3(13.0, 1.0, 9.0), center + Vector3(x, 0.35 + float(index % 2) * 0.35, z), Color(0.56, 0.66, 0.72))
		platform.rotation.y = float(index) * 0.18
	_spawn_model(RUIN_MODEL, center + Vector3(0, 0, -12), Vector3.ONE * 1.25)

func _decorate_citadel(center: Vector3) -> void:
	_spawn_model(RUIN_MODEL, center + Vector3(0, 0, 8), Vector3.ONE * 1.65)
	for x in [-18.0, -9.0, 9.0, 18.0]:
		_static_box("CitadelTower", Vector3(5.0, 10.0, 5.0), center + Vector3(x, 5.0, -10.0), Color(0.08, 0.07, 0.11))
	_static_box("CitadelWall", Vector3(42.0, 6.0, 2.0), center + Vector3(0, 3.0, -18.0), Color(0.10, 0.085, 0.13))

func _spawn_player() -> void:
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

func _spawn_zone_enemies() -> void:
	zone_enemies_remaining.resize(ZONE_CENTERS.size())
	zone_enemies_total.resize(ZONE_CENTERS.size())
	zone_enemies_remaining.fill(0)
	zone_enemies_total.fill(0)
	for zone_index in range(1, ZONE_CENTERS.size()):
		var count := 3 if zone_index == ZONE_CENTERS.size() - 1 else 2
		zone_enemies_remaining[zone_index] = count
		zone_enemies_total[zone_index] = count
		for enemy_index in range(count):
			var enemy := ENEMY_SCRIPT.new() as EnemyController
			enemy.name = "Zone_%02d_Guardian_%02d" % [zone_index + 1, enemy_index + 1]
			var offset := Vector3(-7.0 + float(enemy_index) * 14.0, 0.35, 2.0 + float(enemy_index % 2) * 7.0)
			enemy.position = ZONE_CENTERS[zone_index] + offset
			enemy.set_meta("zone_index", zone_index)
			add_child(enemy)
			var model_index := (zone_index + enemy_index - 1) % ENEMY_MODELS.size()
			enemy.setup(player, model_index, ENEMY_MODELS[model_index])
			enemy.defeated.connect(_on_enemy_defeated)
			enemies.append(enemy)

func _on_player_attack() -> void:
	var forward := player.get_forward()
	for enemy in enemies.duplicate():
		if not is_instance_valid(enemy) or enemy.health <= 0:
			continue
		var offset := enemy.global_position - player.global_position
		var flat := Vector3(offset.x, 0.0, offset.z)
		if flat.length() <= 3.0 and flat.length() > 0.01 and forward.dot(flat.normalized()) > -0.05:
			enemy.take_damage(34, player.global_position)

func _on_interact() -> void:
	if current_zone > unlocked_zone:
		_show_message("Cette zone est encore verrouillée.", 2.4)
	elif current_zone == 0:
		_show_message("Traverse les dix zones et bats leurs gardiens.", 3.0)
	elif zone_enemies_remaining[current_zone] > 0:
		_show_message("Il reste %d gardien(s) dans cette zone." % zone_enemies_remaining[current_zone], 2.6)
	elif current_zone == 9 and game_complete:
		_show_message("Les dix zones sont libérées.", 3.0)
	else:
		_show_message("Zone sécurisée. La suivante est ouverte.", 2.6)

func _on_enemy_defeated(enemy: EnemyController) -> void:
	enemies.erase(enemy)
	var zone_index := int(enemy.get_meta("zone_index", 0))
	if zone_index <= 0 or zone_index >= zone_enemies_remaining.size():
		return
	zone_enemies_remaining[zone_index] = maxi(0, zone_enemies_remaining[zone_index] - 1)
	total_defeated += 1
	if zone_enemies_remaining[zone_index] == 0:
		if zone_index == 9:
			game_complete = true
			_show_message("VICTOIRE — les 10 zones sont libérées !", 7.0)
		elif zone_index >= unlocked_zone:
			_unlock_zone(zone_index + 1)
	_update_hud()
	_save_progress()

func _unlock_zone(zone_index: int) -> void:
	if zone_index <= unlocked_zone or zone_index >= ZONE_CENTERS.size():
		return
	unlocked_zone = zone_index
	if zone_gates.has(zone_index):
		var gate := zone_gates[zone_index] as Node
		if is_instance_valid(gate):
			gate.queue_free()
		zone_gates.erase(zone_index)
	_show_message("Zone %d ouverte : %s" % [zone_index + 1, ZONE_NAMES[zone_index]], 4.0)

func _update_current_zone() -> void:
	var nearest := 0
	var nearest_distance := INF
	for index in range(ZONE_CENTERS.size()):
		var distance := Vector2(player.global_position.x - ZONE_CENTERS[index].x, player.global_position.z - ZONE_CENTERS[index].z).length_squared()
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = index
	if nearest != current_zone:
		current_zone = nearest
		_update_hud()
		_show_message("Zone %d/10 — %s" % [current_zone + 1, ZONE_NAMES[current_zone]], 2.5)

func _build_hud() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(root)
	var bar := ColorRect.new()
	bar.color = Color(0.012, 0.022, 0.045, 0.86)
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar.offset_bottom = 102.0
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bar)
	health_label = Label.new()
	health_label.position = Vector2(22, 10)
	health_label.size = Vector2(310, 34)
	health_label.add_theme_font_size_override("font_size", 24)
	bar.add_child(health_label)
	zone_label = Label.new()
	zone_label.position = Vector2(22, 46)
	zone_label.size = Vector2(600, 38)
	zone_label.add_theme_font_size_override("font_size", 20)
	bar.add_child(zone_label)
	objective_label = Label.new()
	objective_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	objective_label.position = Vector2(-520, 18)
	objective_label.size = Vector2(490, 64)
	objective_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	objective_label.add_theme_font_size_override("font_size", 18)
	bar.add_child(objective_label)
	message_label = Label.new()
	message_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	message_label.position = Vector2(-400, 112)
	message_label.size = Vector2(800, 62)
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	message_label.add_theme_font_size_override("font_size", 25)
	message_label.add_theme_constant_override("outline_size", 8)
	root.add_child(message_label)
	var joystick := ColorRect.new()
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
	_button(root, "ATTAQUE", Vector2(-185, -155), Vector2(150, 70), player.attack)
	_button(root, "ESQUIVE", Vector2(-350, -105), Vector2(140, 62), player.dodge)
	_button(root, "SAUT", Vector2(-350, -180), Vector2(140, 62), _mobile_jump)
	_button(root, "ACTION", Vector2(-185, -78), Vector2(150, 58), player.interact)

func _button(parent: Control, label: String, position: Vector2, size: Vector2, callback: Callable) -> void:
	var button := Button.new()
	button.text = label
	button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	button.position = position
	button.size = size
	button.add_theme_font_size_override("font_size", 19)
	button.button_down.connect(callback)
	parent.add_child(button)

func _mobile_jump() -> void:
	if is_instance_valid(player) and player.is_on_floor():
		player.velocity.y = player.jump_velocity

func _update_joystick(position: Vector2) -> void:
	var offset := (position - move_origin).limit_length(66.0)
	virtual_move = offset / 66.0
	if is_instance_valid(joystick_knob):
		joystick_knob.position = Vector2(59, 59) + offset

func _reset_joystick() -> void:
	if is_instance_valid(joystick_knob):
		joystick_knob.position = Vector2(59, 59)

func _on_health_changed(current: int, maximum: int) -> void:
	if is_instance_valid(health_label):
		health_label.text = "PV %d / %d" % [current, maximum]

func _update_hud() -> void:
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
			objective_label.text = "Gardiens : %d / %d | Zone max : %d / 10" % [zone_enemies_remaining[current_zone], zone_enemies_total[current_zone], unlocked_zone + 1]

func _show_message(text: String, duration: float) -> void:
	if not is_instance_valid(message_label):
		return
	message_token += 1
	var token := message_token
	message_label.text = text
	await get_tree().create_timer(duration).timeout
	if token == message_token and is_instance_valid(message_label):
		message_label.text = ""

func _play_music(stream: AudioStream) -> void:
	if not is_instance_valid(music_player):
		music_player = AudioStreamPlayer.new()
		music_player.volume_db = -9.0
		music_player.finished.connect(_replay_music)
		add_child(music_player)
	music_player.stream = stream
	music_player.play()

func _replay_music() -> void:
	if is_instance_valid(music_player):
		music_player.play()

func _update_battle_music() -> void:
	var nearby := false
	for enemy in enemies:
		if is_instance_valid(enemy) and enemy.global_position.distance_to(player.global_position) < 14.0:
			nearby = true
			break
	if nearby != battle_music_active:
		battle_music_active = nearby
		_play_music(MUSIC_BATTLE if nearby else MUSIC_WORLD)

func _add_zone_title(zone_index: int, position: Vector3) -> void:
	var anchor := Node3D.new()
	anchor.position = position
	add_child(anchor)
	_add_world_label(anchor, "ZONE %d — %s" % [zone_index + 1, ZONE_NAMES[zone_index]], Vector3.ZERO, Color(1.0, 0.88, 0.45))

func _add_world_label(parent: Node3D, text: String, position: Vector3, color: Color) -> void:
	var label := Label3D.new()
	label.text = text
	label.position = position
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 40
	label.outline_size = 9
	label.modulate = color
	parent.add_child(label)

func _static_box(name: String, size: Vector3, position: Vector3, color: Color, emission: Color = Color(0, 0, 0, 1)) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = name
	body.position = position
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = _material(color, emission)
	visual.mesh = mesh
	body.add_child(visual)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	add_child(body)
	return body

func _visual_box(name: String, size: Vector3, position: Vector3, color: Color, emission: Color = Color(0, 0, 0, 1)) -> MeshInstance3D:
	var visual := MeshInstance3D.new()
	visual.name = name
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = _material(color, emission)
	visual.mesh = mesh
	visual.position = position
	add_child(visual)
	return visual

func _rock(position: Vector3, scale: Vector3, color: Color) -> void:
	var rock := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 1.7
	mesh.material = _material(color)
	rock.mesh = mesh
	rock.position = position
	rock.scale = scale
	rock.rotation.y = position.x * 0.11
	add_child(rock)

func _dune(position: Vector3, size: float) -> void:
	var dune := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 1.4
	mesh.material = _material(Color(0.75, 0.56, 0.26))
	dune.mesh = mesh
	dune.position = position
	dune.scale = Vector3(size * 1.8, size * 0.38, size)
	add_child(dune)

func _ice_crystal(position: Vector3, size: float) -> void:
	var crystal := MeshInstance3D.new()
	var mesh := PrismMesh.new()
	mesh.size = Vector3(size * 0.55, size * 2.0, size * 0.55)
	mesh.material = _material(Color(0.42, 0.82, 0.98, 0.78), Color(0.05, 0.38, 0.75))
	crystal.mesh = mesh
	crystal.position = position + Vector3(0, size, 0)
	crystal.rotation.y = position.z * 0.08
	add_child(crystal)

func _spawn_model(path: String, position: Vector3, scale: Vector3, rotation: Vector3 = Vector3.ZERO) -> Node3D:
	if not ResourceLoader.exists(path):
		return null
	var resource := load(path)
	if not (resource is PackedScene):
		return null
	var instance := (resource as PackedScene).instantiate()
	if not (instance is Node3D):
		instance.queue_free()
		return null
	var model := instance as Node3D
	model.position = position
	model.scale = scale
	model.rotation = rotation
	add_child(model)
	return model

func _material(color: Color, emission: Color = Color(0, 0, 0, 1)) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.62
	if color.a < 0.99:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if emission.r + emission.g + emission.b > 0.01:
		material.emission_enabled = true
		material.emission = emission
		material.emission_energy_multiplier = 2.0
	return material

func _save_progress() -> void:
	if not is_instance_valid(player):
		return
	var config := ConfigFile.new()
	config.set_value("world", "unlocked_zone", unlocked_zone)
	config.set_value("world", "remaining", zone_enemies_remaining)
	config.set_value("world", "total_defeated", total_defeated)
	config.set_value("world", "complete", game_complete)
	config.set_value("player", "position", player.global_position)
	config.set_value("player", "health", player.health)
	config.save(SAVE_PATH)

func _load_progress() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return
	unlocked_zone = clampi(int(config.get_value("world", "unlocked_zone", 1)), 1, 9)
	total_defeated = int(config.get_value("world", "total_defeated", 0))
	game_complete = bool(config.get_value("world", "complete", false))
	var saved_remaining: Variant = config.get_value("world", "remaining", zone_enemies_remaining)
	if saved_remaining is Array and (saved_remaining as Array).size() == zone_enemies_remaining.size():
		for index in range(zone_enemies_remaining.size()):
			zone_enemies_remaining[index] = int((saved_remaining as Array)[index])
	for gate_zone in zone_gates.keys():
		if int(gate_zone) <= unlocked_zone:
			var gate := zone_gates[gate_zone] as Node
			if is_instance_valid(gate):
				gate.queue_free()
	var saved_position: Vector3 = config.get_value("player", "position", player.global_position)
	player.global_position = saved_position
	player.health = clampi(int(config.get_value("player", "health", player.max_health)), 1, player.max_health)
	player.health_changed.emit(player.health, player.max_health)
