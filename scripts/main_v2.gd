extends Node3D

const PLAYER_SCRIPT = preload("res://scripts/player.gd")
const ENEMY_SCRIPT = preload("res://scripts/enemy.gd")

# Références explicites : Godot doit importer et emballer ces fichiers dans l'APK.
const HERO_SHEET_1: Texture2D = preload("res://pack player 1.png")
const HERO_SHEET_2: Texture2D = preload("res://pack player 1 2eme pack.png")
const ENEMY_SHEET_1: Texture2D = preload("res://pack ennemis.png")
const ENEMY_SHEET_2: Texture2D = preload("res://pack ennemis 2.png")
const ENEMY_SHEET_3: Texture2D = preload("res://pack ennemis 3.png")
const ENEMY_SHEET_4: Texture2D = preload("res://pack ennemis 4.png")
const ENEMY_SHEET_5: Texture2D = preload("res://pack ennemis 5.png")
const ENEMY_SHEET_6: Texture2D = preload("res://pack ennemis 6.png")
const ENEMY_SHEET_7: Texture2D = preload("res://pack ennemis 7.png")
const WORLD_MAP: Texture2D = preload("res://carte monde.png")
const WORLD_ASSETS: Texture2D = preload("res://file_00000000bf5081f4b6651ba786c924f3.png")
const MUSIC_WORLD: AudioStream = preload("res://music.mp3")
const MUSIC_BATTLE: AudioStream = preload("res://music 2.mp3")
const MUSIC_INTERFACE: AudioStream = preload("res://music interface.mp3")

const HERO_PATH := "res://pack player 1.png"
const HERO_PATH_2 := "res://pack player 1 2eme pack.png"
const ENEMY_PATHS: Array[String] = [
	"res://pack ennemis.png",
	"res://pack ennemis 2.png",
	"res://pack ennemis 3.png",
	"res://pack ennemis 4.png",
	"res://pack ennemis 5.png",
	"res://pack ennemis 6.png",
	"res://pack ennemis 7.png"
]

var player: PlayerController
var enemies: Array[EnemyController] = []
var defeated_count := 0
var virtual_move := Vector2.ZERO
var move_touch_id := -1
var look_touch_id := -1
var move_origin := Vector2.ZERO
var joystick_knob: ColorRect
var health_label: Label
var quest_label: Label
var message_label: Label
var music_player: AudioStreamPlayer
var battle_music_active := false
var day_time := 9.0
var sun: DirectionalLight3D
var world_environment: WorldEnvironment
var rain: GPUParticles3D
var rain_enabled := false
var rain_timer := 32.0

func _ready() -> void:
	if OS.has_feature("mobile"):
		DisplayServer.screen_set_orientation(DisplayServer.SCREEN_SENSOR_LANDSCAPE)
	seed(20260729)
	_setup_input()
	_build_environment()
	_build_world()
	_spawn_player()
	_spawn_enemies()
	_build_hud()
	_start_music(MUSIC_WORLD)
	_update_hud()
	_show_message("Les assets du dépôt sont chargés — explore le royaume", 3.5)

func _process(delta: float) -> void:
	day_time = fmod(day_time + delta * 0.025, 24.0)
	_update_day_night()
	rain_timer -= delta
	if rain_timer <= 0.0:
		rain_timer = randf_range(35.0, 65.0)
		_set_rain(not rain_enabled and randf() > 0.48)
	if is_instance_valid(player):
		player.set_virtual_move(virtual_move)
		if is_instance_valid(rain):
			rain.global_position = player.global_position + Vector3(0, 10, 0)
		_update_battle_music()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		var size := get_viewport().get_visible_rect().size
		if touch.pressed and touch.position.x < size.x * 0.42 and touch.position.y > size.y * 0.35 and move_touch_id == -1:
			move_touch_id = touch.index
			move_origin = touch.position
			_update_joystick(touch.position)
		elif touch.pressed and look_touch_id == -1:
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
	world_environment = WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.04, 0.20, 0.55)
	sky_material.sky_horizon_color = Color(0.78, 0.88, 1.0)
	sky_material.ground_bottom_color = Color(0.025, 0.06, 0.05)
	sky_material.ground_horizon_color = Color(0.32, 0.48, 0.32)
	sky.sky_material = sky_material
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.85
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.fog_enabled = true
	environment.fog_density = 0.0025
	environment.fog_light_color = Color(0.68, 0.78, 0.88)
	world_environment.environment = environment
	add_child(world_environment)

	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -32, 0)
	sun.light_energy = 1.45
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 75.0
	add_child(sun)

	rain = GPUParticles3D.new()
	rain.amount = 320
	rain.lifetime = 1.2
	rain.visibility_aabb = AABB(Vector3(-25, -14, -25), Vector3(50, 28, 50))
	var rain_process := ParticleProcessMaterial.new()
	rain_process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	rain_process.emission_box_extents = Vector3(22, 1, 22)
	rain_process.direction = Vector3(0, -1, 0)
	rain_process.initial_velocity_min = 21.0
	rain_process.initial_velocity_max = 28.0
	rain_process.gravity = Vector3(1.0, -8.0, 0.5)
	rain.process_material = rain_process
	var drop := QuadMesh.new()
	drop.size = Vector2(0.03, 0.65)
	var drop_material := StandardMaterial3D.new()
	drop_material.albedo_color = Color(0.6, 0.82, 1.0, 0.58)
	drop_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	drop_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	drop_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	drop.material = drop_material
	rain.draw_pass_1 = drop
	rain.emitting = false
	add_child(rain)

func _build_world() -> void:
	_create_static_box("MainIsland", Vector3(84, 1.2, 84), Vector3(0, -0.6, 0), Color(0.12, 0.42, 0.16))
	_create_visual_box("MainPath", Vector3(7, 0.12, 64), Vector3(0, 0.06, -2), Color(0.47, 0.33, 0.18))
	_create_visual_box("VillageSquare", Vector3(26, 0.18, 20), Vector3(0, 0.09, 23), Color(0.38, 0.29, 0.18))
	_create_visual_box("RuinsFloor", Vector3(24, 0.26, 22), Vector3(0, 0.13, -29), Color(0.32, 0.34, 0.39))

	var ocean := MeshInstance3D.new()
	var ocean_mesh := PlaneMesh.new()
	ocean_mesh.size = Vector2(220, 220)
	var ocean_material := StandardMaterial3D.new()
	ocean_material.albedo_color = Color(0.015, 0.25, 0.48, 0.82)
	ocean_material.metallic = 0.18
	ocean_material.roughness = 0.18
	ocean_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ocean_mesh.material = ocean_material
	ocean.mesh = ocean_mesh
	ocean.position.y = -0.85
	add_child(ocean)

	for index in range(38):
		var angle := TAU * float(index) / 38.0 + randf_range(-0.11, 0.11)
		var radius := randf_range(28.0, 38.0)
		_create_tree(Vector3(cos(angle) * radius, 0, sin(angle) * radius), randf_range(0.75, 1.35))
	for index in range(24):
		var rock_position := Vector3(randf_range(-34, 34), 0, randf_range(-34, 34))
		if absf(rock_position.x) < 5.0:
			rock_position.x += 9.0
		_create_rock(rock_position, randf_range(0.4, 1.35))

	_build_village()
	_build_ruins()
	_build_asset_monument()

func _build_village() -> void:
	var house_positions: Array[Vector3] = [
		Vector3(-10, 0, 19), Vector3(10, 0, 19),
		Vector3(-10, 0, 29), Vector3(10, 0, 29)
	]
	for house_position in house_positions:
		_create_house(house_position)
	_create_static_box("Bridge", Vector3(5, 0.35, 10), Vector3(0, 0.18, 9), Color(0.36, 0.19, 0.07))

func _build_ruins() -> void:
	for x in [-9.0, 9.0]:
		for z in [-38.0, -22.0]:
			_create_static_box("RuinsPillar", Vector3(1.5, 7, 1.5), Vector3(x, 3.5, z), Color(0.40, 0.42, 0.47))
	_create_static_box("RuinsWall", Vector3(20, 5, 1.3), Vector3(0, 2.5, -40), Color(0.34, 0.36, 0.42))
	_create_static_box("RuinsStep", Vector3(10, 0.7, 3), Vector3(0, 0.35, -18), Color(0.42, 0.43, 0.46))

func _build_asset_monument() -> void:
	var frame := StaticBody3D.new()
	frame.position = Vector3(18, 0, 12)
	add_child(frame)
	var sprite := Sprite3D.new()
	sprite.texture = WORLD_ASSETS
	sprite.pixel_size = 0.00115
	sprite.position.y = 3.0
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	frame.add_child(sprite)
	var base := MeshInstance3D.new()
	var base_mesh := BoxMesh.new()
	base_mesh.size = Vector3(5.5, 0.7, 1.0)
	base_mesh.material = _material(Color(0.18, 0.20, 0.24))
	base.mesh = base_mesh
	base.position.y = 0.35
	frame.add_child(base)

func _spawn_player() -> void:
	player = PLAYER_SCRIPT.new()
	player.name = "HeroAsset"
	player.position = Vector3(0, 0.3, 14)
	add_child(player)
	player.set_spawn(player.global_position)
	player.apply_asset(HERO_PATH)
	player.health_changed.connect(_on_health_changed)
	player.attack_requested.connect(_on_player_attack)
	player.interact_requested.connect(_on_interact)
	var camera := player.get_node_or_null("CameraPivot/SpringArm/Camera") as Camera3D
	if camera != null:
		camera.current = true

func _spawn_enemies() -> void:
	var positions: Array[Vector3] = [
		Vector3(-13, 0.3, 7), Vector3(13, 0.3, 6),
		Vector3(-19, 0.3, -4), Vector3(19, 0.3, -7),
		Vector3(-15, 0.3, -18), Vector3(15, 0.3, -20),
		Vector3(-8, 0.3, -31), Vector3(8, 0.3, -32),
		Vector3(-25, 0.3, 18), Vector3(25, 0.3, 17),
		Vector3(-28, 0.3, -13), Vector3(28, 0.3, -15),
		Vector3(0, 0.3, -36), Vector3(0, 0.3, 33)
	]
	for index in range(positions.size()):
		var enemy: EnemyController = ENEMY_SCRIPT.new()
		enemy.name = "EnemyAsset_%02d" % (index + 1)
		enemy.position = positions[index]
		add_child(enemy)
		var pack_index := index % ENEMY_PATHS.size()
		enemy.setup(player, index % 4, ENEMY_PATHS[pack_index])
		enemy.defeated.connect(_on_enemy_defeated)
		enemies.append(enemy)

func _on_player_attack() -> void:
	var forward := player.get_forward()
	for enemy in enemies.duplicate():
		if not is_instance_valid(enemy) or enemy.health <= 0:
			continue
		var offset := enemy.global_position - player.global_position
		var flat := Vector3(offset.x, 0, offset.z)
		if flat.length() <= 3.0 and forward.dot(flat.normalized()) > -0.05:
			enemy.take_damage(34, player.global_position)

func _on_interact() -> void:
	if player.global_position.distance_to(Vector3(18, 0, 12)) < 5.0:
		_show_message("Planche d'assets du monde : intégrée au jeu", 2.8)
	else:
		_show_message("Explore, combats les ennemis et découvre les ruines", 2.8)

func _on_enemy_defeated(enemy: EnemyController) -> void:
	enemies.erase(enemy)
	defeated_count += 1
	_update_hud()
	if defeated_count == 7:
		_show_message("La moitié des gardiens est vaincue !", 3.0)
	elif defeated_count >= 14:
		_show_message("VICTOIRE — le royaume est libéré", 6.0)

func _on_health_changed(current: int, maximum: int) -> void:
	if is_instance_valid(health_label):
		health_label.text = "PV  %d / %d" % [current, maximum]

func _build_hud() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "LandscapeHUD"
	add_child(canvas)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(root)

	var top_bar := ColorRect.new()
	top_bar.color = Color(0.015, 0.025, 0.05, 0.80)
	top_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_bar.offset_bottom = 88
	top_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(top_bar)

	var portrait := TextureRect.new()
	portrait.texture = _atlas(HERO_SHEET_2, 3, 2, 0)
	portrait.position = Vector2(14, 8)
	portrait.size = Vector2(72, 72)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	top_bar.add_child(portrait)

	health_label = Label.new()
	health_label.position = Vector2(96, 10)
	health_label.size = Vector2(320, 32)
	health_label.add_theme_font_size_override("font_size", 24)
	top_bar.add_child(health_label)

	quest_label = Label.new()
	quest_label.position = Vector2(96, 44)
	quest_label.size = Vector2(580, 32)
	quest_label.add_theme_font_size_override("font_size", 19)
	top_bar.add_child(quest_label)

	var asset_status := Label.new()
	asset_status.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	asset_status.position = Vector2(-420, 13)
	asset_status.size = Vector2(400, 56)
	asset_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	asset_status.add_theme_font_size_override("font_size", 16)
	asset_status.text = "INTÉGRÉS : 2 héros | 7 packs ennemis | carte | textures | 3 musiques"
	top_bar.add_child(asset_status)

	var map_frame := ColorRect.new()
	map_frame.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	map_frame.position = Vector2(-205, 102)
	map_frame.size = Vector2(185, 125)
	map_frame.color = Color(0.01, 0.02, 0.04, 0.78)
	map_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(map_frame)
	var map := TextureRect.new()
	map.texture = WORLD_MAP
	map.position = Vector2(5, 5)
	map.size = Vector2(175, 115)
	map.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	map.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	map.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_frame.add_child(map)

	message_label = Label.new()
	message_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	message_label.position = Vector2(-360, 105)
	message_label.size = Vector2(720, 60)
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	message_label.add_theme_font_size_override("font_size", 26)
	message_label.add_theme_color_override("font_color", Color(1, 0.9, 0.45))
	message_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	message_label.add_theme_constant_override("outline_size", 8)
	root.add_child(message_label)

	var joystick_base := ColorRect.new()
	joystick_base.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	joystick_base.position = Vector2(35, -215)
	joystick_base.size = Vector2(180, 180)
	joystick_base.color = Color(0.14, 0.30, 0.52, 0.55)
	joystick_base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(joystick_base)
	joystick_knob = ColorRect.new()
	joystick_knob.position = Vector2(59, 59)
	joystick_knob.size = Vector2(62, 62)
	joystick_knob.color = Color(0.60, 0.84, 1.0, 0.86)
	joystick_knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	joystick_base.add_child(joystick_knob)

	var attack_button := _make_button(root, "ATTAQUE", Vector2(-185, -155), Vector2(150, 70))
	attack_button.button_down.connect(player.attack)
	var dodge_button := _make_button(root, "ESQUIVE", Vector2(-350, -105), Vector2(140, 62))
	dodge_button.button_down.connect(player.dodge)
	var jump_button := _make_button(root, "SAUT", Vector2(-350, -180), Vector2(140, 62))
	jump_button.button_down.connect(_mobile_jump)
	var action_button := _make_button(root, "ACTION", Vector2(-185, -78), Vector2(150, 58))
	action_button.button_down.connect(player.interact)

func _make_button(parent: Control, text: String, button_position: Vector2, button_size: Vector2) -> Button:
	var button := Button.new()
	button.text = text
	button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	button.position = button_position
	button.size = button_size
	button.modulate = Color(0.12, 0.30, 0.60, 0.92)
	button.add_theme_font_size_override("font_size", 19)
	parent.add_child(button)
	return button

func _mobile_jump() -> void:
	if player.is_on_floor():
		player.velocity.y = player.jump_velocity

func _update_joystick(position: Vector2) -> void:
	var radius := 72.0
	var offset := (position - move_origin).limit_length(radius)
	virtual_move = offset / radius
	if is_instance_valid(joystick_knob):
		joystick_knob.position = Vector2(59, 59) + offset

func _reset_joystick() -> void:
	if is_instance_valid(joystick_knob):
		joystick_knob.position = Vector2(59, 59)

func _update_hud() -> void:
	if is_instance_valid(health_label) and is_instance_valid(player):
		health_label.text = "PV  %d / %d" % [player.health, player.max_health]
	if is_instance_valid(quest_label):
		quest_label.text = "Quête : gardiens vaincus %d / 14" % defeated_count

func _show_message(text: String, duration: float) -> void:
	if not is_instance_valid(message_label):
		return
	message_label.text = text
	var expected := text
	await get_tree().create_timer(duration).timeout
	if is_instance_valid(message_label) and message_label.text == expected:
		message_label.text = ""

func _start_music(stream: AudioStream) -> void:
	if not is_instance_valid(music_player):
		music_player = AudioStreamPlayer.new()
		music_player.name = "GameMusic"
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
		if is_instance_valid(enemy) and enemy.global_position.distance_to(player.global_position) < 13.0:
			nearby = true
			break
	if nearby != battle_music_active:
		battle_music_active = nearby
		_start_music(MUSIC_BATTLE if nearby else MUSIC_WORLD)

func _update_day_night() -> void:
	if not is_instance_valid(sun) or not is_instance_valid(world_environment):
		return
	var daylight := clampf(sin((day_time - 6.0) / 24.0 * TAU) * 0.65 + 0.45, 0.10, 1.0)
	sun.rotation_degrees.x = -8.0 - daylight * 62.0
	sun.rotation_degrees.y = day_time * 15.0 - 180.0
	sun.light_energy = daylight * (0.92 if rain_enabled else 1.45)
	world_environment.environment.ambient_light_energy = 0.25 + daylight * 0.62

func _set_rain(enabled: bool) -> void:
	rain_enabled = enabled
	if is_instance_valid(rain):
		rain.emitting = enabled
	if is_instance_valid(world_environment):
		world_environment.environment.fog_density = 0.010 if enabled else 0.0025
	_show_message("La pluie commence" if enabled else "Le ciel s'éclaircit", 2.2)

func _atlas(texture: Texture2D, columns: int, rows: int, index: int) -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = texture
	var cell_width := float(texture.get_width()) / float(columns)
	var cell_height := float(texture.get_height()) / float(rows)
	var column := index % columns
	var row := index / columns
	atlas.region = Rect2(column * cell_width, row * cell_height, cell_width, cell_height)
	return atlas

func _create_static_box(node_name: String, box_size: Vector3, box_position: Vector3, color: Color) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = box_position
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = box_size
	mesh.material = _material(color)
	mesh_instance.mesh = mesh
	body.add_child(mesh_instance)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = box_size
	collision.shape = shape
	body.add_child(collision)
	add_child(body)
	return body

func _create_visual_box(node_name: String, box_size: Vector3, box_position: Vector3, color: Color) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = box_size
	mesh.material = _material(color)
	instance.mesh = mesh
	instance.position = box_position
	add_child(instance)
	return instance

func _create_tree(tree_position: Vector3, tree_scale: float) -> void:
	var tree := Node3D.new()
	tree.position = tree_position
	tree.scale = Vector3.ONE * tree_scale
	add_child(tree)
	var trunk := MeshInstance3D.new()
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.20
	trunk_mesh.bottom_radius = 0.34
	trunk_mesh.height = 2.8
	trunk_mesh.material = _material(Color(0.23, 0.10, 0.04))
	trunk.mesh = trunk_mesh
	trunk.position.y = 1.4
	tree.add_child(trunk)
	var crown_positions: Array[Vector3] = [Vector3(0, 3.0, 0), Vector3(-0.65, 2.65, 0), Vector3(0.65, 2.65, 0.2)]
	for crown_position in crown_positions:
		var crown := MeshInstance3D.new()
		var crown_mesh := SphereMesh.new()
		crown_mesh.radius = 1.15
		crown_mesh.height = 2.1
		crown_mesh.material = _material(Color(0.06, 0.35 + randf_range(-0.04, 0.05), 0.10))
		crown.mesh = crown_mesh
		crown.position = crown_position
		tree.add_child(crown)

func _create_rock(rock_position: Vector3, rock_scale: float) -> void:
	var rock := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = rock_scale
	mesh.height = rock_scale * 1.3
	mesh.material = _material(Color(0.28, 0.31, 0.34))
	rock.mesh = mesh
	rock.position = rock_position + Vector3(0, rock_scale * 0.45, 0)
	rock.scale = Vector3(1.2, 0.72, 0.95)
	rock.rotation.y = randf_range(0, TAU)
	add_child(rock)

func _create_house(house_position: Vector3) -> void:
	var house := Node3D.new()
	house.position = house_position
	add_child(house)
	var wall := MeshInstance3D.new()
	var wall_mesh := BoxMesh.new()
	wall_mesh.size = Vector3(4.5, 2.8, 3.7)
	wall_mesh.material = _material(Color(0.57, 0.42, 0.23))
	wall.mesh = wall_mesh
	wall.position.y = 1.4
	house.add_child(wall)
	var roof := MeshInstance3D.new()
	var roof_mesh := PrismMesh.new()
	roof_mesh.size = Vector3(5.1, 1.9, 4.3)
	roof_mesh.material = _material(Color(0.34, 0.08, 0.05))
	roof.mesh = roof_mesh
	roof.position.y = 3.35
	roof.rotation.y = PI * 0.5
	house.add_child(roof)

func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.62
	if color.a < 0.99:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return material
