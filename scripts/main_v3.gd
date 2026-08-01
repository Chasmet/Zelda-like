extends Node3D

const PLAYER_SCRIPT = preload("res://scripts/player.gd")
const ENEMY_SCRIPT = preload("res://scripts/enemy.gd")
const HERO_PORTRAIT: Texture2D = preload("res://pack player 1 2eme pack.png")
const WORLD_MAP: Texture2D = preload("res://carte monde.png")
const MUSIC_WORLD: AudioStream = preload("res://music.mp3")
const MUSIC_BATTLE: AudioStream = preload("res://music 2.mp3")

const HERO_MODEL := "res://generated_models/hero_knight.glb"
const HERO_FALLBACK := "res://pack player 1.png"
const ENEMY_MODELS: Array[String] = [
	"res://generated_models/enemy_01_armored_boar.glb",
	"res://generated_models/enemy_02_crystal_golem.glb",
	"res://generated_models/enemy_03_lava_hound.glb",
	"res://generated_models/enemy_04_anubis_knight.glb",
	"res://generated_models/enemy_05_goblin_raider.glb",
	"res://generated_models/enemy_06_ice_ogre.glb",
	"res://generated_models/enemy_07_orc_warlord.glb"
]
const ENEMY_FALLBACKS: Array[String] = [
	"res://pack ennemis.png", "res://pack ennemis 2.png",
	"res://pack ennemis 3.png", "res://pack ennemis 4.png",
	"res://pack ennemis 5.png", "res://pack ennemis 6.png",
	"res://pack ennemis 7.png"
]
const TREE_MODEL := "res://generated_models/world_tree.glb"
const HOUSE_MODEL := "res://generated_models/village_house.glb"
const RUIN_MODEL := "res://generated_models/ruin_gate.glb"
const BOAT_MODEL := "res://generated_models/boat.glb"

var player: PlayerController
var enemies: Array[EnemyController] = []
var virtual_move := Vector2.ZERO
var move_touch_id := -1
var look_touch_id := -1
var move_origin := Vector2.ZERO
var joystick_knob: ColorRect
var health_label: Label
var quest_label: Label
var message_label: Label
var music_player: AudioStreamPlayer
var defeated_count := 0
var battle_music_active := false

func _ready() -> void:
	if OS.has_feature("mobile"):
		DisplayServer.screen_set_orientation(DisplayServer.SCREEN_SENSOR_LANDSCAPE)
	_setup_input()
	_build_environment()
	_build_world()
	_spawn_player()
	_spawn_enemies()
	_build_hud()
	_play_music(MUSIC_WORLD)
	_update_hud()
	_show_message("Modèles 3D Blender et animations actifs", 3.5)

func _process(_delta: float) -> void:
	if is_instance_valid(player):
		player.set_virtual_move(virtual_move)
		_update_battle_music()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		var size := get_viewport().get_visible_rect().size
		if touch.pressed and touch.position.x < size.x * 0.42 and touch.position.y > size.y * 0.35 and move_touch_id < 0:
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
	sky_material.sky_top_color = Color(0.035, 0.17, 0.48)
	sky_material.sky_horizon_color = Color(0.74, 0.86, 1.0)
	sky_material.ground_bottom_color = Color(0.02, 0.05, 0.035)
	sky_material.ground_horizon_color = Color(0.28, 0.42, 0.28)
	sky.sky_material = sky_material
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.92
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.fog_enabled = true
	environment.fog_density = 0.0022
	world_env.environment = environment
	add_child(world_env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50.0, -35.0, 0.0)
	sun.light_energy = 1.5
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 80.0
	add_child(sun)

func _build_world() -> void:
	_static_box("Island", Vector3(86.0, 1.2, 86.0), Vector3(0.0, -0.6, 0.0), Color(0.12, 0.42, 0.16))
	_visual_box("Path", Vector3(7.0, 0.12, 66.0), Vector3(0.0, 0.06, -2.0), Color(0.47, 0.33, 0.18))
	_visual_box("Village", Vector3(27.0, 0.18, 21.0), Vector3(0.0, 0.09, 24.0), Color(0.38, 0.29, 0.18))
	_visual_box("Ruins", Vector3(25.0, 0.28, 23.0), Vector3(0.0, 0.14, -30.0), Color(0.32, 0.34, 0.39))
	var ocean := MeshInstance3D.new()
	var ocean_mesh := PlaneMesh.new()
	ocean_mesh.size = Vector2(220.0, 220.0)
	var ocean_material := _material(Color(0.015, 0.25, 0.48, 0.82))
	ocean_material.metallic = 0.18
	ocean_material.roughness = 0.18
	ocean_mesh.material = ocean_material
	ocean.mesh = ocean_mesh
	ocean.position.y = -0.85
	add_child(ocean)
	for house_position: Vector3 in [Vector3(-10, 0, 20), Vector3(10, 0, 20), Vector3(-10, 0, 30), Vector3(10, 0, 30)]:
		_spawn_model(HOUSE_MODEL, house_position, Vector3.ONE)
	for index in range(30):
		var angle := TAU * float(index) / 30.0
		var radius := 30.0 + float(index % 4) * 1.9
		_spawn_model(TREE_MODEL, Vector3(cos(angle) * radius, 0.0, sin(angle) * radius), Vector3.ONE * (0.82 + float(index % 3) * 0.12), Vector3(0.0, angle, 0.0))
	_spawn_model(RUIN_MODEL, Vector3(0.0, 0.0, -22.0), Vector3.ONE * 1.15)
	_spawn_model(BOAT_MODEL, Vector3(34.0, -0.42, 22.0), Vector3.ONE * 0.85, Vector3(0.0, -0.65, 0.0))

func _spawn_player() -> void:
	player = PLAYER_SCRIPT.new()
	player.name = "Hero"
	player.position = Vector3(0.0, 0.3, 14.0)
	add_child(player)
	player.set_spawn(player.global_position)
	player.apply_asset(_preferred(HERO_MODEL, HERO_FALLBACK))
	player.health_changed.connect(_on_health_changed)
	player.attack_requested.connect(_on_player_attack)
	player.interact_requested.connect(_on_interact)

func _spawn_enemies() -> void:
	var positions: Array[Vector3] = [
		Vector3(-13, 0.3, 7), Vector3(13, 0.3, 6), Vector3(-19, 0.3, -4), Vector3(19, 0.3, -7),
		Vector3(-15, 0.3, -18), Vector3(15, 0.3, -20), Vector3(-8, 0.3, -31), Vector3(8, 0.3, -32),
		Vector3(-25, 0.3, 18), Vector3(25, 0.3, 17), Vector3(-28, 0.3, -13), Vector3(28, 0.3, -15),
		Vector3(0, 0.3, -36), Vector3(0, 0.3, 34)
	]
	for index in range(positions.size()):
		var enemy: EnemyController = ENEMY_SCRIPT.new()
		enemy.name = "Enemy_%02d" % (index + 1)
		enemy.position = positions[index]
		add_child(enemy)
		var kind := index % ENEMY_MODELS.size()
		enemy.setup(player, kind, _preferred(ENEMY_MODELS[kind], ENEMY_FALLBACKS[kind]))
		enemy.defeated.connect(_on_enemy_defeated)
		enemies.append(enemy)

func _preferred(model_path: String, fallback_path: String) -> String:
	return model_path if ResourceLoader.exists(model_path) else fallback_path

func _on_player_attack() -> void:
	var forward := player.get_forward()
	for enemy: EnemyController in enemies.duplicate():
		if not is_instance_valid(enemy) or enemy.health <= 0:
			continue
		var offset := enemy.global_position - player.global_position
		var flat := Vector3(offset.x, 0.0, offset.z)
		if flat.length() <= 3.0 and forward.dot(flat.normalized()) > -0.05:
			enemy.take_damage(34, player.global_position)

func _on_interact() -> void:
	_show_message("Explore le village, les ruines et les sept familles d’ennemis", 3.0)

func _on_enemy_defeated(enemy: EnemyController) -> void:
	enemies.erase(enemy)
	defeated_count += 1
	_update_hud()
	if defeated_count >= 14:
		_show_message("VICTOIRE — royaume libéré", 6.0)

func _on_health_changed(current: int, maximum: int) -> void:
	if is_instance_valid(health_label):
		health_label.text = "PV %d / %d" % [current, maximum]

func _build_hud() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(root)
	var bar := ColorRect.new()
	bar.color = Color(0.015, 0.025, 0.05, 0.82)
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar.offset_bottom = 88.0
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bar)
	var portrait := TextureRect.new()
	portrait.texture = _atlas(HERO_PORTRAIT, 2, 3, 0)
	portrait.position = Vector2(14, 8)
	portrait.size = Vector2(72, 72)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	bar.add_child(portrait)
	health_label = Label.new()
	health_label.position = Vector2(96, 10)
	health_label.add_theme_font_size_override("font_size", 24)
	bar.add_child(health_label)
	quest_label = Label.new()
	quest_label.position = Vector2(96, 44)
	quest_label.add_theme_font_size_override("font_size", 19)
	bar.add_child(quest_label)
	var map := TextureRect.new()
	map.texture = WORLD_MAP
	map.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	map.position = Vector2(-205, 102)
	map.size = Vector2(185, 125)
	map.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	map.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	map.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(map)
	message_label = Label.new()
	message_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	message_label.position = Vector2(-360, 105)
	message_label.size = Vector2(720, 60)
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	message_label.add_theme_font_size_override("font_size", 26)
	message_label.add_theme_constant_override("outline_size", 8)
	root.add_child(message_label)
	var joystick := ColorRect.new()
	joystick.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	joystick.position = Vector2(35, -215)
	joystick.size = Vector2(180, 180)
	joystick.color = Color(0.14, 0.30, 0.52, 0.55)
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
	if player.is_on_floor():
		player.velocity.y = player.jump_velocity

func _update_joystick(position: Vector2) -> void:
	var offset := (position - move_origin).limit_length(72.0)
	virtual_move = offset / 72.0
	if is_instance_valid(joystick_knob):
		joystick_knob.position = Vector2(59, 59) + offset

func _reset_joystick() -> void:
	if is_instance_valid(joystick_knob):
		joystick_knob.position = Vector2(59, 59)

func _update_hud() -> void:
	if is_instance_valid(player) and is_instance_valid(health_label):
		health_label.text = "PV %d / %d" % [player.health, player.max_health]
	if is_instance_valid(quest_label):
		quest_label.text = "Gardiens vaincus : %d / 14" % defeated_count

func _show_message(text: String, duration: float) -> void:
	if not is_instance_valid(message_label):
		return
	message_label.text = text
	await get_tree().create_timer(duration).timeout
	if is_instance_valid(message_label) and message_label.text == text:
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
	for enemy: EnemyController in enemies:
		if is_instance_valid(enemy) and enemy.global_position.distance_to(player.global_position) < 13.0:
			nearby = true
			break
	if nearby != battle_music_active:
		battle_music_active = nearby
		_play_music(MUSIC_BATTLE if nearby else MUSIC_WORLD)

func _atlas(texture: Texture2D, columns: int, rows: int, index: int) -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = texture
	var width := float(texture.get_width()) / columns
	var height := float(texture.get_height()) / rows
	atlas.region = Rect2(float(index % columns) * width, float(index / columns) * height, width, height)
	return atlas

func _static_box(name: String, size: Vector3, position: Vector3, color: Color) -> void:
	var body := StaticBody3D.new()
	body.name = name
	body.position = position
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = _material(color)
	visual.mesh = mesh
	body.add_child(visual)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	add_child(body)

func _visual_box(name: String, size: Vector3, position: Vector3, color: Color) -> void:
	var visual := MeshInstance3D.new()
	visual.name = name
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = _material(color)
	visual.mesh = mesh
	visual.position = position
	add_child(visual)

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

func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.62
	if color.a < 0.99:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return material
