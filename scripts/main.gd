extends Node3D

const PLAYER_SCRIPT := preload("res://scripts/player.gd")
const ENEMY_SCRIPT := preload("res://scripts/enemy.gd")
const SAVE_PATH := "user://zelda_like_save.cfg"

var player: PlayerController
var enemies: Array[EnemyController] = []
var discovered_images: Array[String] = []
var discovered_models: Array[String] = []
var discovered_audio: Array[String] = []

var kills := 0
var relic_collected := false
var quest_complete := false
var game_time := 9.0
var weather_timer := 38.0
var is_raining := false

var world_environment: WorldEnvironment
var sun: DirectionalLight3D
var rain: GPUParticles3D
var relic: Node3D
var portal: Node3D
var campfire: Node3D
var npc: Node3D

var hud_health: Label
var hud_quest: Label
var hud_message: Label
var hud_assets: Label
var move_pad: Control
var move_knob: ColorRect
var look_pad: Control
var move_touch_id := -1
var look_touch_id := -1
var mouse_move_active := false
var virtual_move := Vector2.ZERO
var pending_look := Vector2.ZERO
var message_serial := 0

func _ready() -> void:
	_ensure_input_actions()
	_scan_repository_assets("res://")
	_start_audio()
	_build_environment()
	_build_world()
	_spawn_player()
	_spawn_quest_objects()
	_spawn_enemies()
	_build_interface()
	_connect_gameplay()
	_load_game()
	_show_message("Bienvenue dans Les Chroniques de Skypiea", 3.5)

func _process(delta: float) -> void:
	game_time = fmod(game_time + delta * 0.018, 24.0)
	_update_day_night()
	weather_timer -= delta
	if weather_timer <= 0.0:
		weather_timer = randf_range(32.0, 70.0)
		_set_rain(not is_raining and randf() > 0.38)
	if is_instance_valid(relic) and relic.visible:
		relic.rotate_y(delta * 1.4)
	if is_instance_valid(player):
		player.set_virtual_move(virtual_move)
		if pending_look.length_squared() > 0.0:
			player.add_camera_look(pending_look * 0.004)
			pending_look = Vector2.ZERO
		if is_instance_valid(rain):
			rain.global_position = player.global_position + Vector3(0, 10, 0)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save_game()

func _ensure_input_actions() -> void:
	_add_key_action("move_forward", KEY_W)
	_add_key_action("move_forward", KEY_UP)
	_add_key_action("move_back", KEY_S)
	_add_key_action("move_back", KEY_DOWN)
	_add_key_action("move_left", KEY_A)
	_add_key_action("move_left", KEY_LEFT)
	_add_key_action("move_right", KEY_D)
	_add_key_action("move_right", KEY_RIGHT)
	_add_key_action("jump", KEY_SPACE)
	_add_key_action("attack", KEY_F)
	_add_key_action("dodge", KEY_SHIFT)
	_add_key_action("interact", KEY_E)
	_add_key_action("sprint", KEY_CTRL)
	if not InputMap.has_action("attack"):
		InputMap.add_action("attack")
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	InputMap.action_add_event("attack", mouse)

func _add_key_action(action: StringName, key) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var event := InputEventKey.new()
	event.physical_keycode = key
	InputMap.action_add_event(action, event)

func _scan_repository_assets(path: String) -> void:
	var directory := DirAccess.open(path)
	if directory == null:
		return
	for file_name in directory.get_files():
		if file_name.ends_with(".import"):
			continue
		var full_path := path.path_join(file_name)
		var extension := file_name.get_extension().to_lower()
		if extension in ["png", "jpg", "jpeg", "webp", "svg"]:
			discovered_images.append(full_path)
		elif extension in ["glb", "gltf", "fbx", "obj", "dae", "tscn", "scn"] and not full_path.ends_with("scenes/main.tscn"):
			discovered_models.append(full_path)
		elif extension in ["ogg", "wav", "mp3"]:
			discovered_audio.append(full_path)
	for directory_name in directory.get_directories():
		if directory_name in [".git", ".godot", ".github", "scripts", "scenes"]:
			continue
		_scan_repository_assets(path.path_join(directory_name))

func _start_audio() -> void:
	if discovered_audio.is_empty():
		return
	var selected := discovered_audio[0]
	for path in discovered_audio:
		var lower := path.to_lower()
		if "music" in lower or "musique" in lower or "theme" in lower or "ambient" in lower:
			selected = path
			break
	var stream := load(selected)
	if stream == null:
		return
	var music := AudioStreamPlayer.new()
	music.name = "RepositoryMusic"
	music.stream = stream
	music.volume_db = -10.0
	music.finished.connect(music.play)
	add_child(music)
	music.play()

func _build_environment() -> void:
	world_environment = WorldEnvironment.new()
	world_environment.name = "WorldEnvironment"
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.05, 0.16, 0.34)
	sky_material.sky_horizon_color = Color(0.68, 0.78, 0.88)
	sky_material.ground_bottom_color = Color(0.02, 0.04, 0.07)
	sky_material.ground_horizon_color = Color(0.42, 0.48, 0.46)
	sky.sky_material = sky_material
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.72
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.glow_enabled = true
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.62, 0.72, 0.8)
	environment.fog_density = 0.004
	environment.fog_sky_affect = 0.45
	world_environment.environment = environment
	add_child(world_environment)

	sun = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-52, -35, 0)
	sun.light_energy = 1.35
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 70.0
	add_child(sun)

	rain = GPUParticles3D.new()
	rain.name = "Rain"
	rain.amount = 420
	rain.lifetime = 1.25
	rain.visibility_aabb = AABB(Vector3(-28, -16, -28), Vector3(56, 28, 56))
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(24, 1, 24)
	process.direction = Vector3(0, -1, 0)
	process.initial_velocity_min = 21.0
	process.initial_velocity_max = 28.0
	process.gravity = Vector3(1.5, -8.0, 0.8)
	rain.process_material = process
	var drop := QuadMesh.new()
	drop.size = Vector2(0.035, 0.72)
	var drop_material := StandardMaterial3D.new()
	drop_material.albedo_color = Color(0.55, 0.78, 1.0, 0.58)
	drop_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	drop_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	drop_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	drop.material = drop_material
	rain.draw_pass_1 = drop
	rain.emitting = false
	add_child(rain)

func _build_world() -> void:
	_create_static_box("Island", Vector3(72, 1.0, 72), Vector3(0, -0.5, 0), Color(0.16, 0.38, 0.15))
	_create_visual_box("Path", Vector3(7, 0.08, 54), Vector3(0, 0.04, 0), Color(0.45, 0.34, 0.2))
	_create_visual_box("TempleFloor", Vector3(18, 0.4, 18), Vector3(0, 0.2, -26), Color(0.28, 0.29, 0.34))
	_create_visual_box("VillageFloor", Vector3(22, 0.25, 18), Vector3(0, 0.12, 22), Color(0.34, 0.28, 0.18))

	var water := MeshInstance3D.new()
	water.name = "Ocean"
	var water_mesh := PlaneMesh.new()
	water_mesh.size = Vector2(180, 180)
	var water_material := StandardMaterial3D.new()
	water_material.albedo_color = Color(0.02, 0.25, 0.42, 0.78)
	water_material.metallic = 0.2
	water_material.roughness = 0.22
	water_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water_mesh.material = water_material
	water.mesh = water_mesh
	water.position.y = -0.72
	add_child(water)

	for i in range(28):
		var angle := TAU * float(i) / 28.0 + randf_range(-0.12, 0.12)
		var radius := randf_range(24.0, 32.0)
		_create_tree(Vector3(cos(angle) * radius, 0, sin(angle) * radius), randf_range(0.8, 1.35))
	for i in range(20):
		var position := Vector3(randf_range(-29, 29), 0, randf_range(-29, 29))
		if absf(position.x) < 5.0:
			position.x += 8.0 * signf(position.x if position.x != 0.0 else 1.0)
		_create_rock(position, randf_range(0.45, 1.4))

	_build_ruins()
	_build_village()
	_place_repository_assets()

func _build_ruins() -> void:
	for x in [-7.0, 7.0]:
		for z in [-32.0, -20.0]:
			_create_static_box("TemplePillar", Vector3(1.4, 6.0, 1.4), Vector3(x, 3.0, z), Color(0.34, 0.36, 0.4))
	_create_static_box("TempleBack", Vector3(16, 4.0, 1.2), Vector3(0, 2.0, -34), Color(0.3, 0.32, 0.37))
	_create_static_box("TempleStep1", Vector3(8, 0.6, 3), Vector3(0, 0.3, -17), Color(0.36, 0.36, 0.38))
	_create_static_box("TempleStep2", Vector3(6, 0.6, 2.2), Vector3(0, 0.9, -18.4), Color(0.4, 0.4, 0.42))

func _build_village() -> void:
	for position in [Vector3(-8, 0, 20), Vector3(8, 0, 20), Vector3(-8, 0, 27), Vector3(8, 0, 27)]:
		_create_house(position)

func _spawn_player() -> void:
	player = PLAYER_SCRIPT.new()
	player.name = "Hero"
	player.position = Vector3(0, 0.2, 13)
	add_child(player)
	player.set_spawn(player.global_position)
	var hero_asset := _find_best_asset(["cheikh", "yvane", "nelvin", "nelvyn", "hero", "player", "personnage", "chevalier", "knight"], true)
	if not hero_asset.is_empty():
		player.apply_asset(hero_asset)

func _spawn_enemies() -> void:
	var enemy_assets := _find_matching_assets(["enemy", "ennemi", "monster", "monstre", "goblin", "tortue", "lievre", "wolf", "bandit"])
	var positions := [
		Vector3(-12, 0.2, 7), Vector3(12, 0.2, 5), Vector3(-16, 0.2, -6),
		Vector3(16, 0.2, -9), Vector3(-11, 0.2, -20), Vector3(11, 0.2, -23),
		Vector3(0, 0.2, -29), Vector3(22, 0.2, 15)
	]
	for i in range(positions.size()):
		var enemy: EnemyController = ENEMY_SCRIPT.new()
		enemy.name = "Enemy_%02d" % (i + 1)
		enemy.position = positions[i]
		add_child(enemy)
		var asset := ""
		if not enemy_assets.is_empty():
			asset = enemy_assets[i % enemy_assets.size()]
		enemy.setup(player, i % 6, asset)
		enemy.defeated.connect(_on_enemy_defeated)
		enemies.append(enemy)

func _spawn_quest_objects() -> void:
	npc = Node3D.new()
	npc.name = "VillageElder"
	npc.position = Vector3(0, 0, 25)
	add_child(npc)
	var npc_body := MeshInstance3D.new()
	var npc_mesh := CapsuleMesh.new()
	npc_mesh.radius = 0.42
	npc_mesh.height = 1.55
	npc_mesh.material = _material(Color(0.42, 0.2, 0.48))
	npc_body.mesh = npc_mesh
	npc_body.position.y = 0.9
	npc.add_child(npc_body)
	_add_label_3d(npc, "Ancien du village", Vector3(0, 2.2, 0), Color(1, 0.9, 0.45))

	campfire = Node3D.new()
	campfire.name = "Campfire"
	campfire.position = Vector3(-4, 0, 15)
	add_child(campfire)
	for angle in [0.0, PI * 0.5]:
		var log := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.12
		mesh.bottom_radius = 0.12
		mesh.height = 1.5
		mesh.material = _material(Color(0.24, 0.11, 0.04))
		log.mesh = mesh
		log.rotation = Vector3(PI * 0.5, angle, 0)
		log.position.y = 0.18
		campfire.add_child(log)
	var flame := MeshInstance3D.new()
	var flame_mesh := SphereMesh.new()
	flame_mesh.radius = 0.38
	flame_mesh.height = 0.8
	flame_mesh.material = _material(Color(1, 0.35, 0.03), Color(1, 0.12, 0.01))
	flame.mesh = flame_mesh
	flame.position.y = 0.62
	campfire.add_child(flame)
	_add_label_3d(campfire, "Feu de repos", Vector3(0, 1.45, 0), Color(1, 0.65, 0.2))

	relic = Node3D.new()
	relic.name = "Relic"
	relic.position = Vector3(0, 1.2, -28)
	relic.visible = false
	add_child(relic)
	var relic_mesh_instance := MeshInstance3D.new()
	var relic_mesh := PrismMesh.new()
	relic_mesh.size = Vector3(0.8, 1.5, 0.8)
	relic_mesh.material = _material(Color(0.22, 0.86, 1.0), Color(0.08, 0.65, 1.0))
	relic_mesh_instance.mesh = relic_mesh
	relic.add_child(relic_mesh_instance)
	_add_label_3d(relic, "Relique céleste", Vector3(0, 1.35, 0), Color(0.35, 0.9, 1))

	portal = Node3D.new()
	portal.name = "Portal"
	portal.position = Vector3(0, 0, -32.8)
	add_child(portal)
	for x in [-2.0, 2.0]:
		var pillar := MeshInstance3D.new()
		var pillar_mesh := BoxMesh.new()
		pillar_mesh.size = Vector3(0.55, 4.0, 0.55)
		pillar_mesh.material = _material(Color(0.22, 0.1, 0.1), Color(0.18, 0.01, 0.01))
		pillar.mesh = pillar_mesh
		pillar.position = Vector3(x, 2, 0)
		portal.add_child(pillar)
	var portal_surface := MeshInstance3D.new()
	portal_surface.name = "PortalSurface"
	var portal_mesh := QuadMesh.new()
	portal_mesh.size = Vector2(3.6, 3.4)
	portal_mesh.material = _material(Color(0.35, 0.02, 0.05, 0.72), Color(0.4, 0.01, 0.03))
	portal_surface.mesh = portal_mesh
	portal_surface.position.y = 2.0
	portal.add_child(portal_surface)
	_add_label_3d(portal, "Portail scellé", Vector3(0, 4.35, 0), Color(1, 0.25, 0.22))

func _build_interface() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "Interface"
	add_child(canvas)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(root)

	var top_panel := ColorRect.new()
	top_panel.color = Color(0.015, 0.025, 0.05, 0.78)
	top_panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_panel.offset_bottom = 102
	top_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(top_panel)

	hud_health = Label.new()
	hud_health.position = Vector2(24, 12)
	hud_health.size = Vector2(420, 36)
	hud_health.add_theme_font_size_override("font_size", 25)
	top_panel.add_child(hud_health)

	hud_quest = Label.new()
	hud_quest.position = Vector2(24, 50)
	hud_quest.size = Vector2(800, 40)
	hud_quest.add_theme_font_size_override("font_size", 21)
	hud_quest.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	top_panel.add_child(hud_quest)

	hud_assets = Label.new()
	hud_assets.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	hud_assets.position = Vector2(-330, 15)
	hud_assets.size = Vector2(300, 72)
	hud_assets.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hud_assets.add_theme_font_size_override("font_size", 16)
	hud_assets.text = "Assets détectés : %d images | %d modèles | %d sons" % [discovered_images.size(), discovered_models.size(), discovered_audio.size()]
	top_panel.add_child(hud_assets)

	hud_message = Label.new()
	hud_message.set_anchors_preset(Control.PRESET_CENTER_TOP)
	hud_message.position = Vector2(-360, 125)
	hud_message.size = Vector2(720, 70)
	hud_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud_message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hud_message.add_theme_font_size_override("font_size", 28)
	hud_message.add_theme_color_override("font_color", Color(1, 0.9, 0.45))
	hud_message.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	hud_message.add_theme_constant_override("outline_size", 8)
	root.add_child(hud_message)

	move_pad = Panel.new()
	move_pad.name = "MovePad"
	move_pad.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	move_pad.position = Vector2(35, -245)
	move_pad.size = Vector2(210, 210)
	move_pad.modulate = Color(0.2, 0.35, 0.55, 0.52)
	move_pad.mouse_filter = Control.MOUSE_FILTER_STOP
	move_pad.gui_input.connect(_on_move_pad_input)
	root.add_child(move_pad)
	move_knob = ColorRect.new()
	move_knob.color = Color(0.65, 0.85, 1.0, 0.8)
	move_knob.size = Vector2(72, 72)
	move_knob.position = Vector2(69, 69)
	move_knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	move_pad.add_child(move_knob)

	look_pad = Control.new()
	look_pad.name = "LookPad"
	look_pad.anchor_left = 0.48
	look_pad.anchor_top = 0.18
	look_pad.anchor_right = 1.0
	look_pad.anchor_bottom = 1.0
	look_pad.mouse_filter = Control.MOUSE_FILTER_STOP
	look_pad.gui_input.connect(_on_look_pad_input)
	root.add_child(look_pad)

	var attack_button := _make_action_button(root, "ATTAQUE", Vector2(-180, -185), Vector2(145, 72))
	attack_button.button_down.connect(player.attack)
	var dodge_button := _make_action_button(root, "ESQUIVE", Vector2(-345, -115), Vector2(135, 62))
	dodge_button.button_down.connect(player.dodge)
	var interact_button := _make_action_button(root, "ACTION", Vector2(-190, -95), Vector2(145, 62))
	interact_button.button_down.connect(player.interact)
	var jump_button := _make_action_button(root, "SAUT", Vector2(-345, -190), Vector2(135, 62))
	jump_button.button_down.connect(_mobile_jump)

	_update_hud()

func _connect_gameplay() -> void:
	player.health_changed.connect(_on_player_health_changed)
	player.attack_requested.connect(_on_player_attack)
	player.interact_requested.connect(_on_player_interact)
	var autosave := Timer.new()
	autosave.wait_time = 20.0
	autosave.autostart = true
	autosave.timeout.connect(_save_game)
	add_child(autosave)

func _on_player_attack() -> void:
	var forward := player.get_forward()
	for enemy in enemies.duplicate():
		if not is_instance_valid(enemy) or enemy.health <= 0:
			continue
		var offset := enemy.global_position - player.global_position
		var flat := Vector3(offset.x, 0, offset.z)
		if flat.length() <= 2.8 and forward.dot(flat.normalized()) > -0.05:
			enemy.take_damage(32, player.global_position)

func _on_player_interact() -> void:
	if is_instance_valid(relic) and relic.visible and player.global_position.distance_to(relic.global_position) < 3.2:
		relic_collected = true
		relic.visible = false
		_unlock_portal()
		_show_message("Relique céleste récupérée ! Le portail est ouvert.", 4.0)
		_update_hud()
		_save_game()
		return
	if player.global_position.distance_to(npc.global_position) < 3.5:
		if kills < 5:
			_show_message("Ancien : vaincs 5 créatures pour révéler la relique.", 4.0)
		elif not relic_collected:
			_show_message("Ancien : la relique t’attend dans les ruines du nord.", 4.0)
		else:
			_show_message("Ancien : traverse le portail et accomplis ta destinée.", 4.0)
		return
	if player.global_position.distance_to(campfire.global_position) < 3.2:
		player.heal(100)
		player.set_spawn(player.global_position)
		_show_message("Repos terminé. Vie restaurée et point de retour sauvegardé.", 3.0)
		_save_game()
		return
	if player.global_position.distance_to(portal.global_position) < 4.0:
		if relic_collected:
			quest_complete = true
			_show_message("VICTOIRE — Le premier chapitre est terminé !", 8.0)
			_update_hud()
			_save_game()
		else:
			_show_message("Le portail est scellé par une force ancienne.", 3.0)
		return
	_show_message("Approche-toi d’un personnage, du feu ou d’un objet de quête.", 2.6)

func _on_enemy_defeated(enemy: EnemyController) -> void:
	enemies.erase(enemy)
	kills += 1
	if kills == 5 and not relic_collected:
		relic.visible = true
		_show_message("La relique céleste vient d’apparaître dans les ruines !", 4.5)
	_update_hud()
	_save_game()

func _on_player_health_changed(current: int, maximum: int) -> void:
	if is_instance_valid(hud_health):
		hud_health.text = "PV  %d / %d" % [current, maximum]

func _update_hud() -> void:
	if not is_instance_valid(hud_health) or not is_instance_valid(hud_quest):
		return
	hud_health.text = "PV  %d / %d" % [player.health, player.max_health]
	if quest_complete:
		hud_quest.text = "Quête : chapitre terminé — monde libre débloqué"
	elif relic_collected:
		hud_quest.text = "Quête : traverse le portail des ruines"
	elif kills >= 5:
		hud_quest.text = "Quête : récupère la relique céleste dans les ruines"
	else:
		hud_quest.text = "Quête : protège le village — créatures vaincues %d / 5" % kills

func _unlock_portal() -> void:
	if not is_instance_valid(portal):
		return
	var surface := portal.get_node_or_null("PortalSurface") as MeshInstance3D
	if surface and surface.mesh:
		surface.set_surface_override_material(0, _material(Color(0.04, 0.55, 0.78, 0.72), Color(0.0, 0.6, 1.0)))
	for child in portal.get_children():
		if child is Label3D:
			child.text = "Portail ouvert"
			child.modulate = Color(0.35, 0.9, 1.0)

func _show_message(text: String, duration: float) -> void:
	if not is_instance_valid(hud_message):
		return
	message_serial += 1
	var serial := message_serial
	hud_message.text = text
	await get_tree().create_timer(duration).timeout
	if serial == message_serial and is_instance_valid(hud_message):
		hud_message.text = ""

func _update_day_night() -> void:
	if not is_instance_valid(sun) or world_environment.environment == null:
		return
	var daylight := clampf(sin((game_time - 6.0) / 24.0 * TAU) * 0.65 + 0.45, 0.08, 1.0)
	sun.rotation_degrees.x = -8.0 - daylight * 64.0
	sun.rotation_degrees.y = game_time * 15.0 - 180.0
	sun.light_energy = daylight * (0.85 if is_raining else 1.35)
	world_environment.environment.ambient_light_energy = 0.2 + daylight * 0.55

func _set_rain(enabled: bool) -> void:
	is_raining = enabled
	if is_instance_valid(rain):
		rain.emitting = enabled
	if world_environment.environment:
		world_environment.environment.fog_density = 0.012 if enabled else 0.004
		world_environment.environment.fog_light_color = Color(0.38, 0.48, 0.58) if enabled else Color(0.62, 0.72, 0.8)
	_show_message("La pluie commence." if enabled else "Le ciel s’éclaircit.", 2.5)

func _on_move_pad_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and move_touch_id == -1:
			move_touch_id = event.index
			_update_move_vector(event.position)
		elif not event.pressed and event.index == move_touch_id:
			move_touch_id = -1
			virtual_move = Vector2.ZERO
			move_knob.position = Vector2(69, 69)
	elif event is InputEventScreenDrag and event.index == move_touch_id:
		_update_move_vector(event.position)
	elif event is InputEventMouseButton:
		mouse_move_active = event.pressed
		if event.pressed:
			_update_move_vector(event.position)
		else:
			virtual_move = Vector2.ZERO
			move_knob.position = Vector2(69, 69)
	elif event is InputEventMouseMotion and mouse_move_active:
		_update_move_vector(event.position)

func _update_move_vector(local_position: Vector2) -> void:
	var center := move_pad.size * 0.5
	var radius := minf(move_pad.size.x, move_pad.size.y) * 0.36
	var offset := (local_position - center).limit_length(radius)
	virtual_move = offset / radius
	move_knob.position = center + offset - move_knob.size * 0.5

func _on_look_pad_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and look_touch_id == -1:
			look_touch_id = event.index
		elif not event.pressed and event.index == look_touch_id:
			look_touch_id = -1
	elif event is InputEventScreenDrag and event.index == look_touch_id:
		pending_look += event.relative

func _mobile_jump() -> void:
	if player.is_on_floor():
		player.velocity.y = player.jump_velocity

func _make_action_button(parent: Control, text: String, position: Vector2, size: Vector2) -> Button:
	var button := Button.new()
	button.text = text
	button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	button.position = position
	button.size = size
	button.modulate = Color(0.16, 0.32, 0.58, 0.88)
	button.add_theme_font_size_override("font_size", 19)
	parent.add_child(button)
	return button

func _create_static_box(node_name: String, size: Vector3, position: Vector3, color: Color) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = position
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = _material(color)
	mesh_instance.mesh = mesh
	body.add_child(mesh_instance)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	add_child(body)
	return body

func _create_visual_box(node_name: String, size: Vector3, position: Vector3, color: Color) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = _material(color)
	instance.mesh = mesh
	instance.position = position
	add_child(instance)
	return instance

func _create_tree(position: Vector3, scale_value: float) -> void:
	var tree := Node3D.new()
	tree.name = "Tree"
	tree.position = position
	tree.scale = Vector3.ONE * scale_value
	add_child(tree)
	var trunk := MeshInstance3D.new()
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.2
	trunk_mesh.bottom_radius = 0.34
	trunk_mesh.height = 2.8
	trunk_mesh.material = _material(Color(0.23, 0.1, 0.04))
	trunk.mesh = trunk_mesh
	trunk.position.y = 1.4
	tree.add_child(trunk)
	for crown_position in [Vector3(0, 3.0, 0), Vector3(-0.65, 2.65, 0), Vector3(0.65, 2.65, 0.2)]:
		var crown := MeshInstance3D.new()
		var crown_mesh := SphereMesh.new()
		crown_mesh.radius = 1.15
		crown_mesh.height = 2.1
		crown_mesh.material = _material(Color(0.07, 0.34 + randf_range(-0.04, 0.05), 0.1))
		crown.mesh = crown_mesh
		crown.position = crown_position
		tree.add_child(crown)

func _create_rock(position: Vector3, scale_value: float) -> void:
	var rock := MeshInstance3D.new()
	rock.name = "Rock"
	var mesh := SphereMesh.new()
	mesh.radius = scale_value
	mesh.height = scale_value * 1.3
	mesh.material = _material(Color(0.27, 0.3, 0.32))
	rock.mesh = mesh
	rock.position = position + Vector3(0, scale_value * 0.45, 0)
	rock.scale = Vector3(1.2, 0.7, 0.95)
	rock.rotation.y = randf_range(0, TAU)
	add_child(rock)

func _create_house(position: Vector3) -> void:
	var house := Node3D.new()
	house.name = "House"
	house.position = position
	add_child(house)
	var wall := MeshInstance3D.new()
	var wall_mesh := BoxMesh.new()
	wall_mesh.size = Vector3(4.2, 2.6, 3.4)
	wall_mesh.material = _material(Color(0.55, 0.4, 0.22))
	wall.mesh = wall_mesh
	wall.position.y = 1.3
	house.add_child(wall)
	var roof := MeshInstance3D.new()
	var roof_mesh := PrismMesh.new()
	roof_mesh.size = Vector3(4.8, 1.8, 4.0)
	roof_mesh.material = _material(Color(0.32, 0.07, 0.05))
	roof.mesh = roof_mesh
	roof.position.y = 3.15
	roof.rotation.y = PI * 0.5
	house.add_child(roof)

func _place_repository_assets() -> void:
	var candidates: Array[String] = []
	for path in discovered_models:
		if not path.ends_with(".tscn") and not path.ends_with(".scn"):
			candidates.append(path)
	for path in discovered_images:
		candidates.append(path)
	var count := mini(12, candidates.size())
	for i in range(count):
		var angle := TAU * float(i) / maxf(1.0, float(count))
		var position := Vector3(cos(angle) * 18.0, 0.1, sin(angle) * 18.0)
		_place_asset_preview(candidates[i], position, i)

func _place_asset_preview(path: String, position: Vector3, index: int) -> void:
	var resource := load(path)
	if resource is PackedScene:
		var instance := resource.instantiate()
		instance.name = "RepositoryAsset_%02d" % index
		if instance is Node3D:
			instance.position = position
			instance.scale = Vector3.ONE * 0.7
			add_child(instance)
	elif resource is Texture2D:
		var sprite := Sprite3D.new()
		sprite.name = "RepositoryImage_%02d" % index
		sprite.texture = resource
		sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		sprite.pixel_size = 0.0016
		sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		sprite.position = position + Vector3(0, 1.7, 0)
		add_child(sprite)

func _find_best_asset(keywords: Array[String], include_images: bool) -> String:
	var pool: Array[String] = discovered_models.duplicate()
	if include_images:
		pool.append_array(discovered_images)
	for keyword in keywords:
		for path in pool:
			if keyword in path.to_lower():
				return path
	return pool[0] if not pool.is_empty() else ""

func _find_matching_assets(keywords: Array[String]) -> Array[String]:
	var result: Array[String] = []
	var pool: Array[String] = discovered_models.duplicate()
	pool.append_array(discovered_images)
	for path in pool:
		var lower := path.to_lower()
		for keyword in keywords:
			if keyword in lower:
				result.append(path)
				break
	return result

func _add_label_3d(parent: Node3D, text: String, position: Vector3, color: Color) -> void:
	var label := Label3D.new()
	label.text = text
	label.position = position
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 36
	label.outline_size = 8
	label.modulate = color
	parent.add_child(label)

func _material(color: Color, emission := Color(0, 0, 0, 1)) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
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
	var config := ConfigFile.new()
	config.set_value("player", "position", player.global_position)
	config.set_value("player", "spawn", player.spawn_position)
	config.set_value("player", "health", player.health)
	config.set_value("quest", "kills", kills)
	config.set_value("quest", "relic_collected", relic_collected)
	config.set_value("quest", "complete", quest_complete)
	config.set_value("world", "time", game_time)
	config.save(SAVE_PATH)

func _load_game() -> void:
	var config := ConfigFile.new()
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
	_update_hud()
