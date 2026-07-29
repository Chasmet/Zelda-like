extends Node3D

const PLAYER_SCRIPT = preload("res://scripts/player.gd")
const ENEMY_SCRIPT = preload("res://scripts/enemy.gd")
const SAVE_PATH := "user://zelda_like_save.cfg"

var player: PlayerController
var enemies: Array[EnemyController] = []
var image_assets: Array[String] = []
var model_assets: Array[String] = []
var audio_assets: Array[String] = []

var kills: int = 0
var relic_collected: bool = false
var quest_complete: bool = false
var game_time: float = 9.0
var weather_timer: float = 45.0
var rain_enabled: bool = false

var world_environment: WorldEnvironment
var sun: DirectionalLight3D
var rain: GPUParticles3D
var relic: Node3D
var portal: Node3D
var elder: Node3D
var campfire: Node3D

var health_label: Label
var quest_label: Label
var message_label: Label
var assets_label: Label
var joystick_knob: ColorRect
var move_touch_id: int = -1
var look_touch_id: int = -1
var move_origin: Vector2 = Vector2.ZERO
var virtual_move: Vector2 = Vector2.ZERO
var message_token: int = 0

func _ready() -> void:
	seed(20260729)
	_setup_input()
	_scan_assets("res://")
	_build_environment()
	_build_world()
	_spawn_player()
	_spawn_quest_objects()
	_spawn_enemies()
	_build_hud()
	_connect_gameplay()
	_start_music()
	_load_game()
	_update_hud()
	_show_message("Bienvenue dans Les Chroniques de Skypiea", 3.5)

func _process(delta: float) -> void:
	game_time = fmod(game_time + delta * 0.018, 24.0)
	_update_day_night()
	weather_timer -= delta
	if weather_timer <= 0.0:
		weather_timer = randf_range(35.0, 75.0)
		_set_rain(not rain_enabled and randf() > 0.42)
	if is_instance_valid(relic) and relic.visible:
		relic.rotate_y(delta * 1.5)
	if is_instance_valid(player):
		player.set_virtual_move(virtual_move)
		if is_instance_valid(rain):
			rain.global_position = player.global_position + Vector3(0, 11, 0)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save_game()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event as InputEventScreenTouch
		var screen_width: float = get_viewport().get_visible_rect().size.x
		if touch.pressed and touch.position.x < screen_width * 0.46 and move_touch_id == -1:
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
		var drag: InputEventScreenDrag = event as InputEventScreenDrag
		if drag.index == move_touch_id:
			_update_joystick(drag.position)
		elif drag.index == look_touch_id and is_instance_valid(player):
			player.add_camera_look(drag.relative * 0.004)

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
	var mouse: InputEventMouseButton = InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	InputMap.action_add_event("attack", mouse)

func _add_key(action: StringName, keycode: int) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = keycode
	InputMap.action_add_event(action, event)

func _scan_assets(path: String) -> void:
	var directory: DirAccess = DirAccess.open(path)
	if directory == null:
		return
	for file_name: String in directory.get_files():
		if file_name.ends_with(".import"):
			continue
		var full_path: String = path.path_join(file_name)
		var extension: String = file_name.get_extension().to_lower()
		if extension in ["png", "jpg", "jpeg", "webp", "svg"]:
			image_assets.append(full_path)
		elif extension in ["glb", "gltf", "fbx", "obj", "dae", "tscn", "scn"] and not full_path.ends_with("scenes/main.tscn"):
			model_assets.append(full_path)
		elif extension in ["ogg", "wav", "mp3"]:
			audio_assets.append(full_path)
	for folder: String in directory.get_directories():
		if folder in [".git", ".godot", ".github", "scripts", "scenes", "build"]:
			continue
		_scan_assets(path.path_join(folder))

func _build_environment() -> void:
	world_environment = WorldEnvironment.new()
	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky: Sky = Sky.new()
	var sky_material: ProceduralSkyMaterial = ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.045, 0.15, 0.34)
	sky_material.sky_horizon_color = Color(0.66, 0.78, 0.9)
	sky_material.ground_bottom_color = Color(0.025, 0.04, 0.07)
	sky_material.ground_horizon_color = Color(0.4, 0.48, 0.42)
	sky.sky_material = sky_material
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.72
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.fog_enabled = true
	environment.fog_density = 0.004
	environment.fog_light_color = Color(0.62, 0.72, 0.82)
	world_environment.environment = environment
	add_child(world_environment)

	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -35, 0)
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 72.0
	add_child(sun)

	rain = GPUParticles3D.new()
	rain.amount = 350
	rain.lifetime = 1.2
	rain.visibility_aabb = AABB(Vector3(-25, -16, -25), Vector3(50, 30, 50))
	var particle_process: ParticleProcessMaterial = ParticleProcessMaterial.new()
	particle_process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	particle_process.emission_box_extents = Vector3(22, 1, 22)
	particle_process.direction = Vector3(0, -1, 0)
	particle_process.initial_velocity_min = 20.0
	particle_process.initial_velocity_max = 28.0
	particle_process.gravity = Vector3(1.2, -7.0, 0.6)
	rain.process_material = particle_process
	var drop: QuadMesh = QuadMesh.new()
	drop.size = Vector2(0.035, 0.68)
	drop.material = _material(Color(0.55, 0.8, 1.0, 0.58), Color(0.08, 0.2, 0.35))
	rain.draw_pass_1 = drop
	rain.emitting = false
	add_child(rain)

func _build_world() -> void:
	_create_static_box("Island", Vector3(72, 1, 72), Vector3(0, -0.5, 0), Color(0.14, 0.38, 0.14))
	_create_visual_box("Path", Vector3(7, 0.08, 55), Vector3(0, 0.04, 0), Color(0.46, 0.34, 0.19))
	_create_visual_box("VillageSquare", Vector3(23, 0.18, 18), Vector3(0, 0.09, 23), Color(0.32, 0.27, 0.18))
	_create_visual_box("TempleFloor", Vector3(19, 0.32, 18), Vector3(0, 0.16, -26), Color(0.28, 0.29, 0.34))
	var water: MeshInstance3D = MeshInstance3D.new()
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(190, 190)
	plane.material = _material(Color(0.02, 0.23, 0.42, 0.76))
	water.mesh = plane
	water.position.y = -0.72
	add_child(water)
	for index: int in range(30):
		var angle: float = TAU * float(index) / 30.0 + randf_range(-0.13, 0.13)
		var radius: float = randf_range(24.0, 32.0)
		_create_tree(Vector3(cos(angle) * radius, 0, sin(angle) * radius), randf_range(0.8, 1.25))
	for index: int in range(18):
		var rock_position: Vector3 = Vector3(randf_range(-29, 29), 0, randf_range(-29, 29))
		if absf(rock_position.x) < 5.0:
			rock_position.x += 8.0
		_create_rock(rock_position, randf_range(0.45, 1.3))
	_build_village()
	_build_ruins()
	_place_asset_previews()

func _build_village() -> void:
	var positions: Array[Vector3] = [
		Vector3(-8, 0, 20), Vector3(8, 0, 20),
		Vector3(-8, 0, 28), Vector3(8, 0, 28)
	]
	for house_position: Vector3 in positions:
		_create_house(house_position)

func _build_ruins() -> void:
	for x: float in [-7.0, 7.0]:
		for z: float in [-32.0, -20.0]:
			_create_static_box("Pillar", Vector3(1.4, 6, 1.4), Vector3(x, 3, z), Color(0.34, 0.36, 0.4))
	_create_static_box("TempleBack", Vector3(16, 4, 1.2), Vector3(0, 2, -34), Color(0.3, 0.32, 0.37))
	_create_static_box("Step1", Vector3(8, 0.6, 3), Vector3(0, 0.3, -17), Color(0.36, 0.36, 0.38))
	_create_static_box("Step2", Vector3(6, 0.6, 2.2), Vector3(0, 0.9, -18.4), Color(0.4, 0.4, 0.42))

func _spawn_player() -> void:
	player = PLAYER_SCRIPT.new()
	player.name = "Hero"
	player.position = Vector3(0, 0.2, 13)
	add_child(player)
	player.set_spawn(player.global_position)
	var hero_asset: String = _find_best_asset(
		["cheikh", "yvane", "nelvin", "nelvyn", "hero", "player", "personnage", "chevalier", "knight"],
		true
	)
	if not hero_asset.is_empty():
		player.apply_asset(hero_asset)

func _spawn_enemies() -> void:
	var enemy_assets: Array[String] = _matching_assets(
		["enemy", "ennemi", "monster", "monstre", "goblin", "tortue", "lievre", "wolf", "bandit"]
	)
	var positions: Array[Vector3] = [
		Vector3(-12, 0.2, 7), Vector3(12, 0.2, 5),
		Vector3(-16, 0.2, -6), Vector3(16, 0.2, -9),
		Vector3(-11, 0.2, -21), Vector3(11, 0.2, -23),
		Vector3(0, 0.2, -29), Vector3(22, 0.2, 15)
	]
	for index: int in range(positions.size()):
		var enemy: EnemyController = ENEMY_SCRIPT.new()
		enemy.name = "Enemy_%02d" % (index + 1)
		enemy.position = positions[index]
		add_child(enemy)
		var asset_path: String = ""
		if not enemy_assets.is_empty():
			asset_path = enemy_assets[index % enemy_assets.size()]
		enemy.setup(player, index % 6, asset_path)
		enemy.defeated.connect(_on_enemy_defeated)
		enemies.append(enemy)

func _spawn_quest_objects() -> void:
	elder = _character_marker("Ancien du village", Vector3(0, 0, 25), Color(0.46, 0.18, 0.52))
	campfire = Node3D.new()
	campfire.position = Vector3(-4, 0, 15)
	add_child(campfire)
	var flame: MeshInstance3D = MeshInstance3D.new()
	var flame_mesh: SphereMesh = SphereMesh.new()
	flame_mesh.radius = 0.38
	flame_mesh.height = 0.8
	flame_mesh.material = _material(Color(1, 0.32, 0.03), Color(1, 0.1, 0.01))
	flame.mesh = flame_mesh
	flame.position.y = 0.55
	campfire.add_child(flame)
	_add_label(campfire, "Feu de repos", Vector3(0, 1.4, 0), Color(1, 0.68, 0.22))

	relic = Node3D.new()
	relic.position = Vector3(0, 1.2, -28)
	relic.visible = false
	add_child(relic)
	var relic_mesh_instance: MeshInstance3D = MeshInstance3D.new()
	var relic_mesh: PrismMesh = PrismMesh.new()
	relic_mesh.size = Vector3(0.8, 1.5, 0.8)
	relic_mesh.material = _material(Color(0.22, 0.84, 1), Color(0.05, 0.6, 1))
	relic_mesh_instance.mesh = relic_mesh
	relic.add_child(relic_mesh_instance)
	_add_label(relic, "Relique céleste", Vector3(0, 1.3, 0), Color(0.35, 0.9, 1))

	portal = Node3D.new()
	portal.position = Vector3(0, 0, -32.8)
	add_child(portal)
	for x: float in [-2.0, 2.0]:
		var pillar: MeshInstance3D = MeshInstance3D.new()
		var pillar_mesh: BoxMesh = BoxMesh.new()
		pillar_mesh.size = Vector3(0.55, 4, 0.55)
		pillar_mesh.material = _material(Color(0.25, 0.08, 0.08), Color(0.16, 0.01, 0.01))
		pillar.mesh = pillar_mesh
		pillar.position = Vector3(x, 2, 0)
		portal.add_child(pillar)
	var portal_surface: MeshInstance3D = MeshInstance3D.new()
	portal_surface.name = "PortalSurface"
	var portal_mesh: QuadMesh = QuadMesh.new()
	portal_mesh.size = Vector2(3.6, 3.4)
	portal_mesh.material = _material(Color(0.34, 0.02, 0.05, 0.78), Color(0.42, 0.01, 0.03))
	portal_surface.mesh = portal_mesh
	portal_surface.position.y = 2
	portal.add_child(portal_surface)
	_add_label(portal, "Portail scellé", Vector3(0, 4.25, 0), Color(1, 0.25, 0.2))

func _build_hud() -> void:
	var canvas: CanvasLayer = CanvasLayer.new()
	add_child(canvas)
	var root: Control = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(root)
	var top_panel: ColorRect = ColorRect.new()
	top_panel.color = Color(0.015, 0.025, 0.05, 0.78)
	top_panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_panel.offset_bottom = 102
	top_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(top_panel)

	health_label = Label.new()
	health_label.position = Vector2(24, 12)
	health_label.size = Vector2(420, 36)
	health_label.add_theme_font_size_override("font_size", 25)
	top_panel.add_child(health_label)

	quest_label = Label.new()
	quest_label.position = Vector2(24, 50)
	quest_label.size = Vector2(820, 42)
	quest_label.add_theme_font_size_override("font_size", 21)
	top_panel.add_child(quest_label)

	assets_label = Label.new()
	assets_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	assets_label.position = Vector2(-390, 18)
	assets_label.size = Vector2(360, 55)
	assets_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	assets_label.text = "Assets : %d images | %d modèles | %d sons" % [image_assets.size(), model_assets.size(), audio_assets.size()]
	top_panel.add_child(assets_label)

	message_label = Label.new()
	message_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	message_label.position = Vector2(-360, 125)
	message_label.size = Vector2(720, 72)
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	message_label.add_theme_font_size_override("font_size", 27)
	message_label.add_theme_constant_override("outline_size", 8)
	root.add_child(message_label)

	var joystick_base: ColorRect = ColorRect.new()
	joystick_base.color = Color(0.15, 0.3, 0.55, 0.38)
	joystick_base.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	joystick_base.position = Vector2(35, -245)
	joystick_base.size = Vector2(210, 210)
	joystick_base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(joystick_base)
	joystick_knob = ColorRect.new()
	joystick_knob.color = Color(0.65, 0.85, 1.0, 0.8)
	joystick_knob.position = Vector2(69, 69)
	joystick_knob.size = Vector2(72, 72)
	joystick_knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	joystick_base.add_child(joystick_knob)

	var attack_button: Button = _make_button(root, "ATTAQUE", Vector2(-180, -185), Vector2(145, 72))
	attack_button.button_down.connect(player.attack)
	var dodge_button: Button = _make_button(root, "ESQUIVE", Vector2(-345, -115), Vector2(135, 62))
	dodge_button.button_down.connect(player.dodge)
	var interact_button: Button = _make_button(root, "ACTION", Vector2(-190, -95), Vector2(145, 62))
	interact_button.button_down.connect(player.interact)
	var jump_button: Button = _make_button(root, "SAUT", Vector2(-345, -190), Vector2(135, 62))
	jump_button.button_down.connect(_mobile_jump)

func _connect_gameplay() -> void:
	player.health_changed.connect(_on_health_changed)
	player.attack_requested.connect(_on_player_attack)
	player.interact_requested.connect(_on_interact)
	var autosave: Timer = Timer.new()
	autosave.wait_time = 20.0
	autosave.autostart = true
	autosave.timeout.connect(_save_game)
	add_child(autosave)

func _on_player_attack() -> void:
	var forward: Vector3 = player.get_forward()
	for enemy: EnemyController in enemies.duplicate():
		if not is_instance_valid(enemy) or enemy.health <= 0:
			continue
		var enemy_offset: Vector3 = enemy.global_position - player.global_position
		var flat_offset: Vector3 = Vector3(enemy_offset.x, 0, enemy_offset.z)
		if flat_offset.length() <= 2.8 and forward.dot(flat_offset.normalized()) > -0.05:
			enemy.take_damage(32, player.global_position)

func _on_interact() -> void:
	if is_instance_valid(relic) and relic.visible and player.global_position.distance_to(relic.global_position) < 3.2:
		relic_collected = true
		relic.visible = false
		_unlock_portal()
		_show_message("Relique céleste récupérée ! Le portail est ouvert.", 4.0)
		_update_hud()
		_save_game()
		return
	if player.global_position.distance_to(elder.global_position) < 3.5:
		if kills < 5:
			_show_message("Ancien : vaincs 5 créatures pour révéler la relique.", 4.0)
		elif not relic_collected:
			_show_message("Ancien : la relique t'attend dans les ruines du nord.", 4.0)
		else:
			_show_message("Ancien : traverse le portail et accomplis ta destinée.", 4.0)
		return
	if player.global_position.distance_to(campfire.global_position) < 3.2:
		player.heal(100)
		player.set_spawn(player.global_position)
		_show_message("Vie restaurée et point de retour sauvegardé.", 3.0)
		_save_game()
		return
	if player.global_position.distance_to(portal.global_position) < 4.0:
		if relic_collected:
			quest_complete = true
			_show_message("VICTOIRE — Le premier chapitre est terminé !", 8.0)
			_update_hud()
			_save_game()
		else:
			_show_message("Le portail est encore scellé.", 3.0)
		return
	_show_message("Approche-toi d'un personnage, du feu ou d'un objet de quête.", 2.6)

func _on_enemy_defeated(enemy: EnemyController) -> void:
	enemies.erase(enemy)
	kills += 1
	if kills == 5 and not relic_collected:
		relic.visible = true
		_show_message("La relique céleste apparaît dans les ruines !", 4.5)
	_update_hud()
	_save_game()

func _on_health_changed(current: int, maximum: int) -> void:
	if is_instance_valid(health_label):
		health_label.text = "PV  %d / %d" % [current, maximum]

func _update_hud() -> void:
	if not is_instance_valid(player) or not is_instance_valid(health_label):
		return
	health_label.text = "PV  %d / %d" % [player.health, player.max_health]
	if quest_complete:
		quest_label.text = "Quête : chapitre terminé — monde libre débloqué"
	elif relic_collected:
		quest_label.text = "Quête : traverse le portail des ruines"
	elif kills >= 5:
		quest_label.text = "Quête : récupère la relique céleste dans les ruines"
	else:
		quest_label.text = "Quête : protège le village — créatures vaincues %d / 5" % kills

func _unlock_portal() -> void:
	var surface: MeshInstance3D = portal.get_node_or_null("PortalSurface") as MeshInstance3D
	if surface != null:
		surface.set_surface_override_material(0, _material(Color(0.04, 0.55, 0.78, 0.72), Color(0, 0.6, 1)))
	for child: Node in portal.get_children():
		if child is Label3D:
			var portal_label: Label3D = child as Label3D
			portal_label.text = "Portail ouvert"
			portal_label.modulate = Color(0.35, 0.9, 1)

func _show_message(text: String, duration: float) -> void:
	if not is_instance_valid(message_label):
		return
	message_token += 1
	var token: int = message_token
	message_label.text = text
	await get_tree().create_timer(duration).timeout
	if token == message_token and is_instance_valid(message_label):
		message_label.text = ""

func _update_day_night() -> void:
	if not is_instance_valid(sun) or not is_instance_valid(world_environment) or world_environment.environment == null:
		return
	var daylight: float = clampf(sin((game_time - 6.0) / 24.0 * TAU) * 0.65 + 0.45, 0.08, 1.0)
	sun.rotation_degrees.x = -8.0 - daylight * 64.0
	sun.rotation_degrees.y = game_time * 15.0 - 180.0
	sun.light_energy = daylight * (0.85 if rain_enabled else 1.35)
	world_environment.environment.ambient_light_energy = 0.2 + daylight * 0.55

func _set_rain(enabled: bool) -> void:
	rain_enabled = enabled
	if is_instance_valid(rain):
		rain.emitting = enabled
	if is_instance_valid(world_environment) and world_environment.environment != null:
		world_environment.environment.fog_density = 0.012 if enabled else 0.004
		world_environment.environment.fog_light_color = Color(0.38, 0.48, 0.58) if enabled else Color(0.62, 0.72, 0.8)
	_show_message("La pluie commence." if enabled else "Le ciel s'éclaircit.", 2.5)

func _update_joystick(position: Vector2) -> void:
	var radius: float = 76.0
	var joystick_offset: Vector2 = (position - move_origin).limit_length(radius)
	virtual_move = joystick_offset / radius
	if is_instance_valid(joystick_knob):
		joystick_knob.position = Vector2(69, 69) + joystick_offset

func _reset_joystick() -> void:
	if is_instance_valid(joystick_knob):
		joystick_knob.position = Vector2(69, 69)

func _mobile_jump() -> void:
	if player.is_on_floor():
		player.velocity.y = player.jump_velocity

func _make_button(parent: Control, text: String, position: Vector2, button_size: Vector2) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	button.position = position
	button.size = button_size
	button.modulate = Color(0.16, 0.32, 0.58, 0.88)
	button.add_theme_font_size_override("font_size", 19)
	parent.add_child(button)
	return button

func _create_static_box(node_name: String, box_size: Vector3, box_position: Vector3, color: Color) -> StaticBody3D:
	var body: StaticBody3D = StaticBody3D.new()
	body.name = node_name
	body.position = box_position
	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = box_size
	mesh.material = _material(color)
	mesh_instance.mesh = mesh
	body.add_child(mesh_instance)
	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = box_size
	collision.shape = shape
	body.add_child(collision)
	add_child(body)
	return body

func _create_visual_box(node_name: String, box_size: Vector3, box_position: Vector3, color: Color) -> MeshInstance3D:
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.name = node_name
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = box_size
	mesh.material = _material(color)
	instance.mesh = mesh
	instance.position = box_position
	add_child(instance)
	return instance

func _create_tree(tree_position: Vector3, tree_scale: float) -> void:
	var tree: Node3D = Node3D.new()
	tree.position = tree_position
	tree.scale = Vector3.ONE * tree_scale
	add_child(tree)
	var trunk: MeshInstance3D = MeshInstance3D.new()
	var trunk_mesh: CylinderMesh = CylinderMesh.new()
	trunk_mesh.top_radius = 0.2
	trunk_mesh.bottom_radius = 0.34
	trunk_mesh.height = 2.8
	trunk_mesh.material = _material(Color(0.23, 0.1, 0.04))
	trunk.mesh = trunk_mesh
	trunk.position.y = 1.4
	tree.add_child(trunk)
	var crowns: Array[Vector3] = [Vector3(0, 3.0, 0), Vector3(-0.65, 2.65, 0), Vector3(0.65, 2.65, 0.2)]
	for crown_position: Vector3 in crowns:
		var crown: MeshInstance3D = MeshInstance3D.new()
		var crown_mesh: SphereMesh = SphereMesh.new()
		crown_mesh.radius = 1.15
		crown_mesh.height = 2.1
		crown_mesh.material = _material(Color(0.07, 0.34 + randf_range(-0.04, 0.05), 0.1))
		crown.mesh = crown_mesh
		crown.position = crown_position
		tree.add_child(crown)

func _create_rock(rock_position: Vector3, rock_scale: float) -> void:
	var rock: MeshInstance3D = MeshInstance3D.new()
	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius = rock_scale
	mesh.height = rock_scale * 1.3
	mesh.material = _material(Color(0.27, 0.3, 0.32))
	rock.mesh = mesh
	rock.position = rock_position + Vector3(0, rock_scale * 0.45, 0)
	rock.scale = Vector3(1.2, 0.7, 0.95)
	rock.rotation.y = randf_range(0, TAU)
	add_child(rock)

func _create_house(house_position: Vector3) -> void:
	var house: Node3D = Node3D.new()
	house.position = house_position
	add_child(house)
	var wall: MeshInstance3D = MeshInstance3D.new()
	var wall_mesh: BoxMesh = BoxMesh.new()
	wall_mesh.size = Vector3(4.2, 2.6, 3.4)
	wall_mesh.material = _material(Color(0.55, 0.4, 0.22))
	wall.mesh = wall_mesh
	wall.position.y = 1.3
	house.add_child(wall)
	var roof: MeshInstance3D = MeshInstance3D.new()
	var roof_mesh: PrismMesh = PrismMesh.new()
	roof_mesh.size = Vector3(4.8, 1.8, 4.0)
	roof_mesh.material = _material(Color(0.32, 0.07, 0.05))
	roof.mesh = roof_mesh
	roof.position.y = 3.15
	roof.rotation.y = PI * 0.5
	house.add_child(roof)

func _character_marker(title: String, marker_position: Vector3, color: Color) -> Node3D:
	var marker: Node3D = Node3D.new()
	marker.position = marker_position
	add_child(marker)
	var body: MeshInstance3D = MeshInstance3D.new()
	var body_mesh: CapsuleMesh = CapsuleMesh.new()
	body_mesh.radius = 0.42
	body_mesh.height = 1.5
	body_mesh.material = _material(color)
	body.mesh = body_mesh
	body.position.y = 0.9
	marker.add_child(body)
	_add_label(marker, title, Vector3(0, 2.2, 0), Color(1, 0.9, 0.45))
	return marker

func _add_label(parent: Node3D, text: String, label_position: Vector3, color: Color) -> void:
	var label: Label3D = Label3D.new()
	label.text = text
	label.position = label_position
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 36
	label.outline_size = 8
	label.modulate = color
	parent.add_child(label)

func _place_asset_previews() -> void:
	var candidates: Array[String] = []
	for path: String in model_assets:
		if not path.ends_with(".tscn") and not path.ends_with(".scn"):
			candidates.append(path)
	for path: String in image_assets:
		candidates.append(path)
	var count: int = mini(12, candidates.size())
	for index: int in range(count):
		var angle: float = TAU * float(index) / maxf(1.0, float(count))
		var preview_position: Vector3 = Vector3(cos(angle) * 18.0, 0.1, sin(angle) * 18.0)
		_place_asset_preview(candidates[index], preview_position, index)

func _place_asset_preview(path: String, preview_position: Vector3, index: int) -> void:
	var resource: Resource = load(path)
	if resource is PackedScene:
		var packed_scene: PackedScene = resource as PackedScene
		var scene_instance: Node = packed_scene.instantiate()
		scene_instance.name = "RepositoryAsset_%02d" % index
		if scene_instance is Node3D:
			var node_3d: Node3D = scene_instance as Node3D
			node_3d.position = preview_position
			node_3d.scale = Vector3.ONE * 0.7
			add_child(node_3d)
	elif resource is Texture2D:
		var sprite: Sprite3D = Sprite3D.new()
		sprite.name = "RepositoryImage_%02d" % index
		sprite.texture = resource as Texture2D
		sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		sprite.pixel_size = 0.0016
		sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		sprite.position = preview_position + Vector3(0, 1.7, 0)
		add_child(sprite)

func _find_best_asset(keywords: Array[String], include_images: bool) -> String:
	var pool: Array[String] = model_assets.duplicate()
	if include_images:
		pool.append_array(image_assets)
	for keyword: String in keywords:
		for path: String in pool:
			if keyword in path.to_lower():
				return path
	return pool[0] if not pool.is_empty() else ""

func _matching_assets(keywords: Array[String]) -> Array[String]:
	var result: Array[String] = []
	var pool: Array[String] = model_assets.duplicate()
	pool.append_array(image_assets)
	for path: String in pool:
		var lower: String = path.to_lower()
		for keyword: String in keywords:
			if keyword in lower:
				result.append(path)
				break
	return result

func _start_music() -> void:
	if audio_assets.is_empty():
		return
	var selected: String = audio_assets[0]
	for path: String in audio_assets:
		var lower: String = path.to_lower()
		if "music" in lower or "musique" in lower or "theme" in lower or "ambient" in lower:
			selected = path
			break
	var stream: AudioStream = load(selected) as AudioStream
	if stream == null:
		return
	var music: AudioStreamPlayer = AudioStreamPlayer.new()
	music.stream = stream
	music.volume_db = -10.0
	music.finished.connect(music.play)
	add_child(music)
	music.play()

func _material(color: Color, emission: Color = Color(0, 0, 0, 1)) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.58
	if color.a < 0.99:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if emission.r + emission.g + emission.b > 0.01:
		material.emission_enabled = true
		material.emission = emission
		material.emission_energy_multiplier = 2.0
	return material

func _save_game() -> void:
	if not is_instance_valid(player):
		return
	var config: ConfigFile = ConfigFile.new()
	config.set_value("player", "position", player.global_position)
	config.set_value("player", "spawn", player.spawn_position)
	config.set_value("player", "health", player.health)
	config.set_value("quest", "kills", kills)
	config.set_value("quest", "relic_collected", relic_collected)
	config.set_value("quest", "complete", quest_complete)
	config.set_value("world", "time", game_time)
	config.save(SAVE_PATH)

func _load_game() -> void:
	var config: ConfigFile = ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return
	player.global_position = config.get_value("player", "position", player.global_position)
	player.spawn_position = config.get_value("player", "spawn", player.spawn_position)
	player.health = int(config.get_value("player", "health", player.max_health))
	kills = int(config.get_value("quest", "kills", 0))
	relic_collected = bool(config.get_value("quest", "relic_collected", false))
	quest_complete = bool(config.get_value("quest", "complete", false))
	game_time = float(config.get_value("world", "time", 9.0))
	if kills >= 5 and not relic_collected:
		relic.visible = true
	if relic_collected:
		relic.visible = false
		_unlock_portal()
	player.health_changed.emit(player.health, player.max_health)
