extends "res://scripts/main_worldmap.gd"

const HUD_MAP_TEXTURE = preload("res://carte monde.png")

var mini_map_frame
var mini_map_marker
var full_map_marker
var controls_help_label
var portrait_viewport
var portrait_model
var live_hud_timer
var smoothed_marker = Vector2.ZERO
var marker_ready = false


func _build_hud():
	var canvas = CanvasLayer.new()
	canvas.layer = 20
	add_child(canvas)

	var root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(root)

	_build_top_information_bar(root)
	_build_persistent_world_map(root)
	_build_character_portrait(root)

	message_label = Label.new()
	message_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	message_label.position = Vector2(-430.0, 92.0)
	message_label.size = Vector2(860.0, 58.0)
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	message_label.add_theme_font_size_override("font_size", 24)
	message_label.add_theme_constant_override("outline_size", 8)
	root.add_child(message_label)

	zone_banner = Label.new()
	zone_banner.set_anchors_preset(Control.PRESET_CENTER)
	zone_banner.position = Vector2(-470.0, -96.0)
	zone_banner.size = Vector2(940.0, 96.0)
	zone_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	zone_banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	zone_banner.add_theme_font_size_override("font_size", 34)
	zone_banner.add_theme_constant_override("outline_size", 11)
	zone_banner.visible = false
	root.add_child(zone_banner)

	_build_joystick(root)
	_build_action_buttons(root)
	_build_controls_help(root)
	_build_full_world_map(root)

	live_hud_timer = Timer.new()
	live_hud_timer.wait_time = 0.05
	live_hud_timer.one_shot = false
	live_hud_timer.timeout.connect(_update_live_hud)
	add_child(live_hud_timer)
	live_hud_timer.start()


func _build_top_information_bar(root):
	var bar = ColorRect.new()
	bar.color = Color(0.008, 0.018, 0.043, 0.94)
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar.offset_bottom = 86.0
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bar)

	zone_label = Label.new()
	zone_label.position = Vector2(18.0, 8.0)
	zone_label.size = Vector2(570.0, 38.0)
	zone_label.add_theme_font_size_override("font_size", 24)
	zone_label.add_theme_constant_override("outline_size", 5)
	bar.add_child(zone_label)

	health_label = Label.new()
	health_label.position = Vector2(18.0, 47.0)
	health_label.size = Vector2(280.0, 31.0)
	health_label.add_theme_font_size_override("font_size", 19)
	health_label.add_theme_constant_override("outline_size", 4)
	bar.add_child(health_label)

	objective_label = Label.new()
	objective_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	objective_label.position = Vector2(-600.0, 8.0)
	objective_label.size = Vector2(458.0, 68.0)
	objective_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	objective_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	objective_label.add_theme_font_size_override("font_size", 19)
	objective_label.add_theme_constant_override("outline_size", 4)
	bar.add_child(objective_label)

	map_button = Button.new()
	map_button.text = "OUVRIR\nLA CARTE"
	map_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	map_button.position = Vector2(-132.0, 9.0)
	map_button.size = Vector2(118.0, 66.0)
	map_button.add_theme_font_size_override("font_size", 16)
	map_button.pressed.connect(_toggle_map)
	bar.add_child(map_button)


func _build_persistent_world_map(root):
	var panel = ColorRect.new()
	panel.position = Vector2(14.0, 100.0)
	panel.size = Vector2(292.0, 214.0)
	panel.color = Color(0.008, 0.018, 0.04, 0.90)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(panel)

	var title = Label.new()
	title.text = "CARTE DU MONDE • POSITION EN DIRECT"
	title.position = Vector2(7.0, 5.0)
	title.size = Vector2(278.0, 27.0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_constant_override("outline_size", 4)
	panel.add_child(title)

	mini_map_frame = Control.new()
	mini_map_frame.position = Vector2(8.0, 34.0)
	mini_map_frame.size = Vector2(276.0, 172.0)
	mini_map_frame.clip_contents = true
	mini_map_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(mini_map_frame)

	var map_texture = TextureRect.new()
	map_texture.texture = HUD_MAP_TEXTURE
	map_texture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	map_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	map_texture.stretch_mode = TextureRect.STRETCH_SCALE
	map_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mini_map_frame.add_child(map_texture)

	_add_zone_numbers(mini_map_frame, 11, false)
	mini_map_marker = _create_player_marker(mini_map_frame, false)


func _build_character_portrait(root):
	var panel = ColorRect.new()
	panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	panel.position = Vector2(-170.0, 100.0)
	panel.size = Vector2(156.0, 250.0)
	panel.color = Color(0.008, 0.018, 0.04, 0.90)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(panel)

	var title = Label.new()
	title.text = "CHEIKH"
	title.position = Vector2(4.0, 5.0)
	title.size = Vector2(148.0, 28.0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 17)
	title.add_theme_constant_override("outline_size", 4)
	panel.add_child(title)

	portrait_viewport = SubViewport.new()
	portrait_viewport.name = "HeroPortraitViewport"
	portrait_viewport.size = Vector2i(148, 188)
	portrait_viewport.transparent_bg = true
	portrait_viewport.own_world_3d = true
	portrait_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(portrait_viewport)

	var environment = WorldEnvironment.new()
	var env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.0, 0.0, 0.0, 0.0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.72, 0.80, 1.0)
	env.ambient_light_energy = 1.25
	environment.environment = env
	portrait_viewport.add_child(environment)

	var key_light = DirectionalLight3D.new()
	key_light.rotation_degrees = Vector3(-34.0, -28.0, 0.0)
	key_light.light_energy = 2.1
	portrait_viewport.add_child(key_light)

	var rim_light = OmniLight3D.new()
	rim_light.position = Vector3(-1.5, 2.2, -1.5)
	rim_light.light_color = Color(0.35, 0.60, 1.0)
	rim_light.light_energy = 2.0
	rim_light.omni_range = 6.0
	portrait_viewport.add_child(rim_light)

	var camera = Camera3D.new()
	camera.position = Vector3(0.0, 1.28, 3.75)
	portrait_viewport.add_child(camera)
	camera.look_at(Vector3(0.0, 1.20, 0.0), Vector3.UP)
	camera.current = true

	if ResourceLoader.exists(HERO_MODEL):
		var hero_resource = load(HERO_MODEL)
		if hero_resource is PackedScene:
			portrait_model = hero_resource.instantiate()
			portrait_model.rotation.y = PI
			portrait_model.position = Vector3(0.0, 0.0, 0.0)
			portrait_viewport.add_child(portrait_model)

	var portrait_texture = TextureRect.new()
	portrait_texture.position = Vector2(4.0, 32.0)
	portrait_texture.size = Vector2(148.0, 188.0)
	portrait_texture.texture = portrait_viewport.get_texture()
	portrait_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(portrait_texture)

	var status = Label.new()
	status.text = "HÉROS • PRÊT"
	status.position = Vector2(4.0, 220.0)
	status.size = Vector2(148.0, 25.0)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.add_theme_font_size_override("font_size", 14)
	status.add_theme_constant_override("outline_size", 4)
	panel.add_child(status)


func _build_controls_help(root):
	controls_help_label = Label.new()
	controls_help_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	controls_help_label.position = Vector2(-425.0, -54.0)
	controls_help_label.size = Vector2(850.0, 42.0)
	controls_help_label.text = "JOYSTICK : BOUGER   •   GLISSER À DROITE : CAMÉRA   •   CARTE : VOIR TA POSITION"
	controls_help_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	controls_help_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	controls_help_label.add_theme_font_size_override("font_size", 17)
	controls_help_label.add_theme_constant_override("outline_size", 6)
	controls_help_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(controls_help_label)


func _build_full_world_map(root):
	map_panel = ColorRect.new()
	map_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	map_panel.color = Color(0.003, 0.008, 0.022, 0.975)
	map_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	map_panel.visible = false
	root.add_child(map_panel)

	var title = Label.new()
	title.text = "CARTE DU MONDE — TA POSITION SE DÉPLACE EN TEMPS RÉEL"
	title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title.position = Vector2(-430.0, 10.0)
	title.size = Vector2(860.0, 46.0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 25)
	title.add_theme_constant_override("outline_size", 6)
	map_panel.add_child(title)

	map_frame = Control.new()
	map_frame.set_anchors_preset(Control.PRESET_CENTER)
	map_frame.position = Vector2(-390.0, -260.0)
	map_frame.size = Vector2(780.0, 500.0)
	map_frame.clip_contents = true
	map_panel.add_child(map_frame)

	var backdrop = ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.02, 0.05, 0.08, 1.0)
	map_frame.add_child(backdrop)

	var map_texture = TextureRect.new()
	map_texture.texture = HUD_MAP_TEXTURE
	map_texture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	map_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	map_texture.stretch_mode = TextureRect.STRETCH_SCALE
	map_frame.add_child(map_texture)

	_add_zone_numbers(map_frame, 20, true)
	full_map_marker = _create_player_marker(map_frame, true)
	map_player_marker = full_map_marker

	map_zone_label = Label.new()
	map_zone_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	map_zone_label.position = Vector2(-420.0, 240.0)
	map_zone_label.size = Vector2(840.0, 42.0)
	map_zone_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	map_zone_label.add_theme_font_size_override("font_size", 21)
	map_zone_label.add_theme_constant_override("outline_size", 6)
	map_panel.add_child(map_zone_label)

	map_status_label = Label.new()
	map_status_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	map_status_label.position = Vector2(-420.0, 280.0)
	map_status_label.size = Vector2(840.0, 35.0)
	map_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	map_status_label.add_theme_font_size_override("font_size", 17)
	map_status_label.add_theme_constant_override("outline_size", 5)
	map_panel.add_child(map_status_label)

	var close_button = Button.new()
	close_button.text = "FERMER LA CARTE"
	close_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	close_button.position = Vector2(-176.0, 10.0)
	close_button.size = Vector2(160.0, 48.0)
	close_button.add_theme_font_size_override("font_size", 16)
	close_button.pressed.connect(_toggle_map)
	map_panel.add_child(close_button)


func _add_zone_numbers(frame, font_size, show_names):
	for zone_index in range(MAP_MARKERS.size()):
		var label = Label.new()
		label.text = str(zone_index + 1)
		if show_names:
			label.tooltip_text = ZONE_NAMES[zone_index]
		label.size = Vector2(34.0, 28.0)
		label.position = Vector2(
			MAP_MARKERS[zone_index].x * frame.size.x - 17.0,
			MAP_MARKERS[zone_index].y * frame.size.y - 14.0
		)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.modulate = ZONE_ACCENT_COLORS[zone_index]
		label.add_theme_font_size_override("font_size", font_size)
		label.add_theme_constant_override("outline_size", 5)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.add_child(label)


func _create_player_marker(frame, large):
	var marker = Label.new()
	marker.text = "●"
	marker.size = Vector2(42.0, 42.0) if large else Vector2(28.0, 28.0)
	marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	marker.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	marker.modulate = Color(1.0, 0.08, 0.03)
	marker.add_theme_font_size_override("font_size", 34 if large else 23)
	marker.add_theme_constant_override("outline_size", 7 if large else 5)
	marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(marker)
	return marker


func _update_live_hud():
	if not is_instance_valid(player):
		return

	var target = _calculate_live_marker()
	if not marker_ready:
		smoothed_marker = target
		marker_ready = true
	else:
		smoothed_marker = smoothed_marker.lerp(target, 0.32)

	_position_marker(mini_map_marker, mini_map_frame, smoothed_marker)
	_position_marker(full_map_marker, map_frame, smoothed_marker)

	var pulse = 1.0 + sin(Time.get_ticks_msec() * 0.010) * 0.13
	if is_instance_valid(mini_map_marker):
		mini_map_marker.scale = Vector2.ONE * pulse
	if is_instance_valid(full_map_marker):
		full_map_marker.scale = Vector2.ONE * pulse

	if is_instance_valid(portrait_model):
		portrait_model.rotation.y = PI + sin(Time.get_ticks_msec() * 0.0012) * 0.10


func _calculate_live_marker():
	var center = ZONE_CENTERS[current_zone]
	var base = MAP_MARKERS[current_zone]
	var local_x = clamp((player.global_position.x - center.x) / TERRAIN_SIZE.x, -0.55, 0.55)
	var local_z = clamp((player.global_position.z - center.z) / TERRAIN_SIZE.y, -0.55, 0.55)
	var movement = Vector2(local_x * 0.115, local_z * 0.095)
	return Vector2(
		clamp(base.x + movement.x, 0.035, 0.965),
		clamp(base.y + movement.y, 0.035, 0.965)
	)


func _position_marker(marker, frame, normalized):
	if not is_instance_valid(marker) or not is_instance_valid(frame):
		return
	marker.position = Vector2(
		normalized.x * frame.size.x - marker.size.x * 0.5,
		normalized.y * frame.size.y - marker.size.y * 0.5
	)


func _update_map_marker():
	_update_live_hud()
	if is_instance_valid(map_zone_label):
		map_zone_label.text = "● VOUS ÊTES EN ZONE %d — %s" % [current_zone + 1, ZONE_NAMES[current_zone]]

	var completed_count = 0
	for zone_index in range(zone_completed.size()):
		if bool(zone_completed[zone_index]):
			completed_count += 1
	if is_instance_valid(map_status_label):
		map_status_label.text = "RÉGIONS LIBÉRÉES : %d / 10   •   LE POINT ROUGE INDIQUE TA POSITION" % completed_count


func _update_hud():
	if is_instance_valid(player) and is_instance_valid(health_label):
		health_label.text = "VIE : %d / %d" % [player.health, player.max_health]

	if is_instance_valid(zone_label):
		zone_label.text = "ZONE %d / 10  •  %s" % [current_zone + 1, ZONE_NAMES[current_zone]]
		zone_label.modulate = ZONE_ACCENT_COLORS[current_zone]

	if is_instance_valid(objective_label):
		if game_complete:
			objective_label.text = "OBJECTIF TERMINÉ\nMONDE LIBÉRÉ • %d GARDIENS VAINCUS" % total_defeated
		elif current_zone == START_ZONE:
			objective_label.text = "OBJECTIF : OUVRE LA CARTE\nPUIS REJOINS UNE NOUVELLE RÉGION"
		elif int(zone_remaining[current_zone]) > 0:
			objective_label.text = "OBJECTIF : LIBÉRER LA ZONE\nGARDIENS RESTANTS : %d / %d" % [zone_remaining[current_zone], zone_total[current_zone]]
		else:
			objective_label.text = "ZONE LIBÉRÉE\nSUIS LA CARTE VERS UNE AUTRE RÉGION"

	_update_map_marker()
