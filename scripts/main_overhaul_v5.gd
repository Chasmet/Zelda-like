extends "res://scripts/main_mobile_final.gd"

const PORTRAIT_DATA := "res://assets/cheikh_portrait.b64"
const MODE_EXPLORATION := "exploration"
const MODE_AVENTURE := "aventure"
const MODE_SURVIE := "survie"

var game_started := false
var block_initial_load := true
var active_slot := 1
var active_mode := MODE_EXPLORATION
var ui_blocked := false
var menu_layer: CanvasLayer
var menu_box: VBoxContainer
var pause_layer: CanvasLayer
var menu_button: Button
var save_notice: Label
var portrait_cache: Texture2D
var animals: Array[Node3D] = []
var animal_clock := 0.0


func _ready() -> void:
	await super._ready()
	_build_bigger_world()
	_configure_player()
	_build_menu_button()
	var args := OS.get_cmdline_user_args()
	if "--ci-walk-check" in args or "--ci-hud-shot" in args:
		_start_new_game(1, MODE_EXPLORATION)
	else:
		_show_home()


func _process(delta: float) -> void:
	super._process(delta)
	if game_started:
		animal_clock += delta
		_animate_animals()


func _input(event: InputEvent) -> void:
	if ui_blocked:
		_release_movement_touch()
		return
	super._input(event)


func _terrain_material(zone_index):
	if terrain_material_cache.has(zone_index):
		return terrain_material_cache[zone_index]
	var image := Image.create(64, 64, false, Image.FORMAT_RGB8)
	var base: Color = ZONE_BASE_COLORS[zone_index]
	var accent: Color = ZONE_ACCENT_COLORS[zone_index]
	for y in range(64):
		for x in range(64):
			var n := float(int((x * 92821 + y * 68917 + zone_index * 7919) & 255)) / 255.0
			var amount := 0.06 + n * 0.20 + (0.05 * sin(float(x + y + zone_index * 11) * 0.28))
			var color := base.lerp(accent, clampf(amount, 0.02, 0.30))
			image.set_pixel(x, y, color.darkened((0.5 - n) * 0.12) if n < 0.5 else color.lightened((n - 0.5) * 0.12))
	var material := StandardMaterial3D.new()
	material.albedo_color = Color.WHITE
	material.albedo_texture = ImageTexture.create_from_image(image)
	material.roughness = 0.88
	terrain_material_cache[zone_index] = material
	return material


func _build_character_portrait(root):
	var panel := ColorRect.new()
	panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	panel.position = Vector2(-192.0, 100.0)
	panel.size = Vector2(178.0, 306.0)
	panel.color = Color(0.006, 0.014, 0.035, 0.94)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(panel)
	var title := Label.new()
	title.text = "CHEIKH"
	title.position = Vector2(4.0, 4.0)
	title.size = Vector2(170.0, 31.0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 19)
	title.add_theme_constant_override("outline_size", 5)
	panel.add_child(title)
	portrait_viewport = SubViewport.new()
	portrait_viewport.size = Vector2i(2, 2)
	portrait_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(portrait_viewport)
	portrait_model = null
	var portrait := TextureRect.new()
	portrait.position = Vector2(5.0, 36.0)
	portrait.size = Vector2(168.0, 233.0)
	portrait.texture = _portrait_texture()
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(portrait)
	var status := Label.new()
	status.text = "HÉROS • PRÊT"
	status.position = Vector2(4.0, 270.0)
	status.size = Vector2(170.0, 30.0)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.add_theme_font_size_override("font_size", 15)
	status.add_theme_constant_override("outline_size", 4)
	panel.add_child(status)


func _portrait_texture() -> Texture2D:
	if is_instance_valid(portrait_cache):
		return portrait_cache
	if not FileAccess.file_exists(PORTRAIT_DATA):
		return null
	var image := Image.new()
	var error := image.load_jpg_from_buffer(Marshalls.base64_to_raw(FileAccess.get_file_as_string(PORTRAIT_DATA).strip_edges()))
	if error != OK:
		push_error("Portrait Cheikh illisible : %d" % error)
		return null
	portrait_cache = ImageTexture.create_from_image(image)
	return portrait_cache


func _configure_player() -> void:
	if not is_instance_valid(player):
		return
	player.move_speed = 4.15
	player.sprint_speed = 5.80
	player.acceleration = 14.0
	player.jump_velocity = 7.2
	player.floor_snap_length = 0.55
	player.floor_max_angle = deg_to_rad(48.0)
	var arm = player.get_node_or_null("CameraPivot/SpringArm")
	if is_instance_valid(arm):
		arm.spring_length = 7.2
		arm.margin = 0.30


func _build_bigger_world() -> void:
	for zone in range(ZONE_CENTERS.size()):
		var center: Vector3 = ZONE_CENTERS[zone]
		var outer = _static_box("Zone_%02d_OuterLand" % (zone + 1), Vector3(62.0, 0.70, 58.0), center + Vector3(0.0, -1.03, 0.0), ZONE_BASE_COLORS[zone].darkened(0.10))
		if is_instance_valid(outer) and outer.get_child_count() > 0:
			var visual = outer.get_child(0)
			if visual is MeshInstance3D and visual.mesh != null:
				visual.mesh.material = _terrain_material(zone)
		for index in range(8):
			var angle := TAU * float(index) / 8.0 + float(zone) * 0.17
			var edge := center + Vector3(cos(angle) * 26.0, -0.15, sin(angle) * 24.0)
			if zone in [1, 4, 7, 8]:
				_add_lowpoly_tree(edge, zone, 0.8 + float(index % 3) * 0.16)
			else:
				_add_lowpoly_rock(edge, ZONE_BASE_COLORS[zone].lightened(0.12), 1.2 + float(index % 3) * 0.35)
		_spawn_zone_animals(zone, 6 if zone in [1, 4, 7, 8] else 4)
	_add_mountain(0, Vector3(-17, 0, -12), 14.0, 6.7, Color(0.20, 0.11, 0.09), Color(0.85, 0.08, 0.01))
	_add_mountain(0, Vector3(16, 0, 14), 10.0, 5.2, Color(0.25, 0.14, 0.10))
	_add_mountain(1, Vector3(-18, 0, 13), 9.0, 5.0, Color(0.15, 0.25, 0.12))
	_add_mountain(2, Vector3(-17, 0, -12), 15.0, 7.0, Color(0.72, 0.84, 0.92), Color(0.45, 0.76, 1.0))
	_add_mountain(2, Vector3(16, 0, 13), 11.0, 5.6, Color(0.65, 0.77, 0.88))
	_add_mountain(3, Vector3(18, 0, -13), 8.0, 5.0, Color(0.56, 0.38, 0.19))
	_add_mountain(8, Vector3(18, 0, 14), 12.0, 6.0, Color(0.28, 0.34, 0.25))
	_add_mountain(9, Vector3(-15, 0, -10), 10.0, 5.4, Color(0.70, 0.78, 0.80), Color(0.55, 0.82, 1.0))


func _add_mountain(zone: int, offset: Vector3, height: float, radius: float, color: Color, glow: Color = Color(0, 0, 0, 1)) -> void:
	var center: Vector3 = ZONE_CENTERS[zone]
	var x := center.x + offset.x
	var z := center.z + offset.z
	var body := StaticBody3D.new()
	body.position = Vector3(x, _terrain_world_height(zone, x, z), z)
	body.name = "Zone_%02d_Mountain" % (zone + 1)
	add_child(body)
	var visual := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.2
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 10
	mesh.material = _material(color, glow)
	visual.mesh = mesh
	visual.position.y = height * 0.5
	body.add_child(visual)
	var collision := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = radius * 0.76
	shape.height = height * 0.82
	collision.shape = shape
	collision.position.y = height * 0.41
	body.add_child(collision)


func _add_lowpoly_tree(position: Vector3, zone: int, scale_value: float) -> void:
	var tree := Node3D.new()
	tree.position = position
	tree.scale = Vector3.ONE * scale_value
	add_child(tree)
	var trunk: MeshInstance3D = _mesh_box(Vector3(0.55, 3.0, 0.55), Color(0.28, 0.15, 0.07)) as MeshInstance3D
	trunk.position.y = 1.5
	tree.add_child(trunk)
	var crown := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 1.75
	mesh.height = 3.2
	mesh.material = _material(ZONE_ACCENT_COLORS[zone].darkened(0.12))
	crown.mesh = mesh
	crown.position.y = 3.9
	tree.add_child(crown)


func _add_lowpoly_rock(position: Vector3, color: Color, size_value: float) -> void:
	var rock := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 1.6
	mesh.material = _material(color)
	rock.mesh = mesh
	rock.position = position + Vector3(0.0, size_value * 0.5, 0.0)
	rock.scale = Vector3(size_value, size_value * 0.8, size_value * 0.9)
	rock.rotation = Vector3(position.z * 0.02, position.x * 0.03, position.x * 0.01)
	add_child(rock)


func _spawn_zone_animals(zone: int, count: int) -> void:
	for index in range(count):
		var center: Vector3 = ZONE_CENTERS[zone]
		var angle := TAU * float(index) / float(count)
		var radius := 8.0 + float((index * 3 + zone) % 10)
		var x := center.x + cos(angle) * radius
		var z := center.z + sin(angle) * radius
		var flying := (zone + index) % 4 == 3
		var animal := Node3D.new()
		animal.name = "Oiseau" if flying else (["Lapin", "Cerf", "Sanglier"][(zone + index) % 3])
		animal.position = Vector3(x, _terrain_world_height(zone, x, z) + (3.0 if flying else 0.2), z)
		var body := MeshInstance3D.new()
		var body_mesh := CapsuleMesh.new()
		body_mesh.radius = 0.25 if flying else 0.38
		body_mesh.height = 0.70 if flying else 1.0
		body_mesh.material = _material(ZONE_ACCENT_COLORS[zone].lightened(0.14))
		body.mesh = body_mesh
		body.rotation.x = PI * 0.5
		body.position.y = 0.5
		animal.add_child(body)
		animal.set_meta("home", animal.position)
		animal.set_meta("phase", angle + float(zone) * 0.61)
		animal.set_meta("radius", 2.0 + float(index % 4))
		animal.set_meta("speed", 0.16 + float((index + zone) % 4) * 0.035)
		animal.set_meta("flying", flying)
		add_child(animal)
		animals.append(animal)


func _animate_animals() -> void:
	for animal in animals:
		if not is_instance_valid(animal):
			continue
		var home: Vector3 = animal.get_meta("home", animal.position)
		var phase := float(animal.get_meta("phase", 0.0))
		var radius := float(animal.get_meta("radius", 2.0))
		var speed := float(animal.get_meta("speed", 0.2))
		var angle := animal_clock * speed + phase
		var target := home + Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
		target.y = home.y + (sin(animal_clock * 1.6 + phase) if bool(animal.get_meta("flying", false)) else absf(sin(animal_clock * 2.2 + phase)) * 0.08)
		animal.position = animal.position.lerp(target, 0.035)
		animal.rotation.y = lerp_angle(animal.rotation.y, atan2(-sin(angle), -cos(angle)), 0.08)


func _build_menu_button() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 35
	add_child(layer)
	menu_button = Button.new()
	menu_button.text = "MENU"
	menu_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	menu_button.position = Vector2(-288.0, 12.0)
	menu_button.size = Vector2(88.0, 52.0)
	menu_button.visible = false
	menu_button.pressed.connect(_show_pause)
	layer.add_child(menu_button)
	save_notice = Label.new()
	save_notice.set_anchors_preset(Control.PRESET_CENTER_TOP)
	save_notice.position = Vector2(-260.0, 145.0)
	save_notice.size = Vector2(520.0, 52.0)
	save_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	save_notice.add_theme_font_size_override("font_size", 22)
	save_notice.add_theme_constant_override("outline_size", 7)
	save_notice.visible = false
	layer.add_child(save_notice)


func _show_home() -> void:
	game_started = false
	ui_blocked = true
	virtual_move = Vector2.ZERO
	_release_movement_touch()
	if is_instance_valid(player):
		player.can_control = false
	if is_instance_valid(menu_button):
		menu_button.visible = false
	if is_instance_valid(menu_layer):
		menu_layer.queue_free()
	menu_layer = CanvasLayer.new()
	menu_layer.layer = 80
	add_child(menu_layer)
	var overlay := ColorRect.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.004, 0.01, 0.03, 0.97)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	menu_layer.add_child(overlay)
	var portrait := TextureRect.new()
	portrait.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	portrait.position = Vector2(55.0, -255.0)
	portrait.size = Vector2(282.0, 510.0)
	portrait.texture = _portrait_texture()
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	overlay.add_child(portrait)
	var title := Label.new()
	title.text = "LES CHRONIQUES DE SKYPIEA"
	title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title.position = Vector2(-320.0, 40.0)
	title.size = Vector2(640.0, 55.0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_constant_override("outline_size", 8)
	overlay.add_child(title)
	menu_box = VBoxContainer.new()
	menu_box.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	menu_box.position = Vector2(-560.0, -175.0)
	menu_box.size = Vector2(470.0, 390.0)
	menu_box.add_theme_constant_override("separation", 14)
	overlay.add_child(menu_box)
	_show_home_buttons()


func _show_home_buttons() -> void:
	_clear_menu()
	menu_box.add_child(_heading("MENU PRINCIPAL"))
	var continue_button := _button("CONTINUER")
	continue_button.disabled = not _has_save()
	continue_button.pressed.connect(_show_continue_slots)
	menu_box.add_child(continue_button)
	var new_button := _button("NOUVELLE PARTIE")
	new_button.pressed.connect(_show_new_slots)
	menu_box.add_child(new_button)
	var info := Label.new()
	info.text = "3 sauvegardes • 3 modes de jeu"
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.add_theme_font_size_override("font_size", 17)
	menu_box.add_child(info)


func _show_continue_slots() -> void:
	_clear_menu()
	menu_box.add_child(_heading("CONTINUER"))
	for slot in range(1, 4):
		var b := _button(_slot_text(slot))
		b.disabled = not FileAccess.file_exists(_slot_path(slot))
		b.pressed.connect(_continue_game.bind(slot))
		menu_box.add_child(b)
	_add_back_button(_show_home_buttons)


func _show_new_slots() -> void:
	_clear_menu()
	menu_box.add_child(_heading("NOUVELLE PARTIE"))
	for slot in range(1, 4):
		var b := _button(_slot_text(slot))
		b.pressed.connect(_show_modes.bind(slot))
		menu_box.add_child(b)
	_add_back_button(_show_home_buttons)


func _show_modes(slot: int) -> void:
	_clear_menu()
	menu_box.add_child(_heading("CHOISIS TON MODE"))
	for data in [[MODE_EXPLORATION, "EXPLORATION — DÉBUTANT"], [MODE_AVENTURE, "AVENTURE — MOYEN"], [MODE_SURVIE, "SURVIE — DIFFICILE"]]:
		var b := _button(data[1])
		b.pressed.connect(_start_new_game.bind(slot, data[0]))
		menu_box.add_child(b)
	_add_back_button(_show_new_slots)


func _heading(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.custom_minimum_size = Vector2(0, 54)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 24)
	return label


func _button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 58)
	button.add_theme_font_size_override("font_size", 19)
	return button


func _add_back_button(callback: Callable) -> void:
	var back := _button("RETOUR")
	back.pressed.connect(callback)
	menu_box.add_child(back)


func _clear_menu() -> void:
	for child in menu_box.get_children():
		menu_box.remove_child(child)
		child.queue_free()


func _start_new_game(slot: int, mode: String) -> void:
	active_slot = clampi(slot, 1, 3)
	active_mode = mode
	block_initial_load = false
	game_started = true
	_apply_mode()
	var center: Vector3 = ZONE_CENTERS[START_ZONE]
	var spawn := Vector3(center.x, _terrain_world_height(START_ZONE, center.x, center.z + 4.0) + 0.55, center.z + 4.0)
	player.global_position = spawn
	player.set_spawn(spawn)
	player.velocity = Vector3.ZERO
	current_zone = START_ZONE
	player.health = player.max_health
	_finish_menu()
	_save_progress()
	_update_hud()
	_show_message("Nouvelle partie — %s" % _mode_name(active_mode), 4.0)


func _continue_game(slot: int) -> void:
	active_slot = clampi(slot, 1, 3)
	block_initial_load = false
	game_started = true
	_load_progress()
	_apply_mode()
	_finish_menu()
	_update_hud()
	_show_message("Partie %d chargée — %s" % [active_slot, _mode_name(active_mode)], 4.0)


func _finish_menu() -> void:
	ui_blocked = false
	if is_instance_valid(menu_layer):
		menu_layer.visible = false
	if is_instance_valid(pause_layer):
		pause_layer.visible = false
	menu_button.visible = true
	player.can_control = true


func _show_pause() -> void:
	ui_blocked = true
	virtual_move = Vector2.ZERO
	_release_movement_touch()
	player.can_control = false
	if is_instance_valid(pause_layer):
		pause_layer.queue_free()
	pause_layer = CanvasLayer.new()
	pause_layer.layer = 90
	add_child(pause_layer)
	var overlay := ColorRect.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.002, 0.008, 0.024, 0.94)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	pause_layer.add_child(overlay)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.position = Vector2(-290, -235)
	box.size = Vector2(580, 480)
	box.add_theme_constant_override("separation", 12)
	overlay.add_child(box)
	box.add_child(_heading("MENU DE PARTIE — %s" % _mode_name(active_mode)))
	var resume := _button("REPRENDRE")
	resume.pressed.connect(_resume)
	box.add_child(resume)
	for slot in range(1, 4):
		var save := _button("SAUVEGARDER DANS PARTIE %d" % slot)
		save.pressed.connect(_manual_save.bind(slot))
		box.add_child(save)
	var home := _button("RETOUR À L'ACCUEIL")
	home.pressed.connect(_return_home)
	box.add_child(home)


func _resume() -> void:
	ui_blocked = false
	pause_layer.visible = false
	player.can_control = true


func _manual_save(slot: int) -> void:
	active_slot = clampi(slot, 1, 3)
	_save_progress()
	_resume()
	save_notice.text = "PARTIE %d SAUVEGARDÉE" % active_slot
	save_notice.visible = true
	await get_tree().create_timer(2.2).timeout
	if is_instance_valid(save_notice):
		save_notice.visible = false


func _return_home() -> void:
	_save_progress()
	pause_layer.queue_free()
	_show_home()


func _apply_mode() -> void:
	match active_mode:
		MODE_EXPLORATION:
			player.max_health = 145
		MODE_SURVIE:
			player.max_health = 90
		_:
			player.max_health = 110
	player.health = clampi(player.health, 1, player.max_health)
	player.move_speed = 4.15
	player.sprint_speed = 5.8
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		if not enemy.has_meta("base_stats"):
			enemy.set_meta("base_stats", [enemy.max_health, enemy.damage, enemy.move_speed, enemy.aggro_range])
		var base: Array = enemy.get_meta("base_stats")
		var factor := 0.72 if active_mode == MODE_EXPLORATION else (1.38 if active_mode == MODE_SURVIE else 1.0)
		enemy.max_health = maxi(30, int(round(float(base[0]) * factor)))
		enemy.damage = maxi(4, int(round(float(base[1]) * (0.62 if active_mode == MODE_EXPLORATION else (1.42 if active_mode == MODE_SURVIE else 1.0)))))
		enemy.move_speed = float(base[2]) * (0.86 if active_mode == MODE_EXPLORATION else (1.12 if active_mode == MODE_SURVIE else 1.0))
		enemy.aggro_range = float(base[3]) * (0.78 if active_mode == MODE_EXPLORATION else (1.16 if active_mode == MODE_SURVIE else 1.0))
		enemy.health = enemy.max_health


func _mode_name(mode: String) -> String:
	return "EXPLORATION — DÉBUTANT" if mode == MODE_EXPLORATION else ("SURVIE — DIFFICILE" if mode == MODE_SURVIE else "AVENTURE — MOYEN")


func _slot_path(slot: int) -> String:
	return "user://skypiea_save_%d.cfg" % clampi(slot, 1, 3)


func _has_save() -> bool:
	return FileAccess.file_exists(_slot_path(1)) or FileAccess.file_exists(_slot_path(2)) or FileAccess.file_exists(_slot_path(3))


func _slot_text(slot: int) -> String:
	if not FileAccess.file_exists(_slot_path(slot)):
		return "PARTIE %d — VIDE" % slot
	var config := ConfigFile.new()
	if config.load(_slot_path(slot)) != OK:
		return "PARTIE %d — ILLISIBLE" % slot
	return "PARTIE %d — %s — ZONE %d" % [slot, _mode_name(String(config.get_value("game", "mode", MODE_EXPLORATION))), int(config.get_value("world", "current_zone", START_ZONE)) + 1]


func _save_progress() -> void:
	if block_initial_load or not game_started or not is_instance_valid(player):
		return
	var config := ConfigFile.new()
	config.set_value("game", "mode", active_mode)
	config.set_value("world", "remaining", zone_remaining)
	config.set_value("world", "completed", zone_completed)
	config.set_value("world", "total_defeated", total_defeated)
	config.set_value("world", "complete", game_complete)
	config.set_value("world", "current_zone", current_zone)
	config.set_value("player", "position", player.global_position)
	config.set_value("player", "health", player.health)
	config.save(_slot_path(active_slot))


func _load_progress() -> void:
	if block_initial_load or not is_instance_valid(player):
		return
	var config := ConfigFile.new()
	if config.load(_slot_path(active_slot)) != OK:
		return
	active_mode = String(config.get_value("game", "mode", MODE_EXPLORATION))
	total_defeated = int(config.get_value("world", "total_defeated", 0))
	game_complete = bool(config.get_value("world", "complete", false))
	current_zone = clampi(int(config.get_value("world", "current_zone", START_ZONE)), 0, ZONE_CENTERS.size() - 1)
	var remaining = config.get_value("world", "remaining", zone_remaining)
	var completed = config.get_value("world", "completed", zone_completed)
	if remaining is Array and remaining.size() == zone_remaining.size():
		for zone in range(zone_remaining.size()):
			zone_remaining[zone] = int(remaining[zone])
	if completed is Array and completed.size() == zone_completed.size():
		for zone in range(zone_completed.size()):
			zone_completed[zone] = bool(completed[zone])
	for zone in range(zone_remaining.size()):
		var zone_enemies: Array = []
		for enemy in enemies:
			if is_instance_valid(enemy) and int(enemy.get_meta("zone_index", -1)) == zone:
				zone_enemies.append(enemy)
		var desired := 0 if bool(zone_completed[zone]) else maxi(0, int(zone_remaining[zone]))
		while zone_enemies.size() > desired:
			var removed = zone_enemies.pop_back()
			enemies.erase(removed)
			removed.queue_free()
	var saved_position = config.get_value("player", "position", player.global_position)
	if saved_position is Vector3:
		player.global_position = saved_position
		player.set_spawn(saved_position)
	player.health = clampi(int(config.get_value("player", "health", player.max_health)), 1, player.max_health)


func _update_hud() -> void:
	super._update_hud()
	if not game_started:
		return
	zone_label.text = "ZONE %d / 10 — %s — %s" % [current_zone + 1, ZONE_NAMES[current_zone], _mode_name(active_mode)]
	if game_complete:
		objective_label.text = "CHAPITRE 3/3 — MONDE LIBÉRÉ\n%d gardiens vaincus" % total_defeated
	elif total_defeated < 5:
		objective_label.text = "CHAPITRE 1/3 — EXPÉDITION\nExplore les régions proches du village"
	elif total_defeated < 13:
		objective_label.text = "CHAPITRE 2/3 — ROYAUME CENTRAL\nLibère les routes vers la capitale"
	else:
		objective_label.text = "CHAPITRE 3/3 — ÎLE CÉLESTE\nAtteins le portail du Royaume"
