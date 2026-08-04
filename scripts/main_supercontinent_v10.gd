extends "res://scripts/main_supercontinent_gameplay.gd"

func _build_map_panel(root) -> void:
	map_panel = ColorRect.new()
	map_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	map_panel.color = Color(0.005, 0.012, 0.03, 0.97)
	map_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	map_panel.visible = false
	root.add_child(map_panel)

	var title := Label.new()
	title.text = "CARTE DU SUPERCONTINENT — 10 GRANDES RÉGIONS"
	title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title.position = Vector2(-390.0, 6.0)
	title.size = Vector2(780.0, 40.0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 23)
	map_panel.add_child(title)

	map_frame = Control.new()
	map_frame.set_anchors_preset(Control.PRESET_CENTER)
	map_frame.position = Vector2(-300.0, -150.0)
	map_frame.size = Vector2(600.0, 360.0)
	map_panel.add_child(map_frame)

	var ocean_background := ColorRect.new()
	ocean_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ocean_background.color = Color(0.02, 0.20, 0.34)
	map_frame.add_child(ocean_background)

	var continent := Polygon2D.new()
	continent.polygon = PackedVector2Array([
		Vector2(42, 100), Vector2(88, 48), Vector2(185, 26), Vector2(310, 31),
		Vector2(451, 22), Vector2(552, 78), Vector2(574, 178), Vector2(550, 276),
		Vector2(467, 333), Vector2(340, 340), Vector2(208, 330), Vector2(92, 301),
		Vector2(27, 228)
	])
	continent.color = Color(0.30, 0.53, 0.22)
	map_frame.add_child(continent)

	_add_map_river(true)
	_add_map_river(false)
	_add_map_roads()

	for zone_index in range(SUPER_ZONE_CENTERS.size()):
		var label := Label.new()
		label.text = str(zone_index + 1)
		label.position = _world_to_map(SUPER_ZONE_CENTERS[zone_index]) - Vector2(14.0, 14.0)
		label.size = Vector2(28.0, 28.0)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 15)
		label.add_theme_constant_override("outline_size", 5)
		label.modulate = ZONE_ACCENT_COLORS[zone_index]
		map_frame.add_child(label)

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
	map_zone_label.position = Vector2(-300.0, 177.0)
	map_zone_label.size = Vector2(600.0, 36.0)
	map_zone_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	map_zone_label.add_theme_font_size_override("font_size", 18)
	map_panel.add_child(map_zone_label)

	map_status_label = Label.new()
	map_status_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	map_status_label.position = Vector2(-330.0, 207.0)
	map_status_label.size = Vector2(660.0, 34.0)
	map_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	map_status_label.add_theme_font_size_override("font_size", 15)
	map_panel.add_child(map_status_label)

	var close_button := Button.new()
	close_button.text = "FERMER"
	close_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	close_button.position = Vector2(-112.0, 9.0)
	close_button.size = Vector2(98.0, 42.0)
	close_button.pressed.connect(_toggle_map)
	map_panel.add_child(close_button)

func _add_map_river(north_south: bool) -> void:
	var line := Line2D.new()
	line.width = 5.0
	line.default_color = Color(0.20, 0.70, 0.96)
	var points := PackedVector2Array()
	for index in range(25):
		var t := float(index) / 24.0
		if north_south:
			var z := lerpf(-225.0, 225.0, t)
			points.append(_world_to_map(Vector3(_river_one_x(z), 0.0, z)))
		else:
			var x := lerpf(-310.0, 310.0, t)
			points.append(_world_to_map(Vector3(x, 0.0, _river_two_z(x))))
	line.points = points
	map_frame.add_child(line)

func _add_map_roads() -> void:
	var links = [[7, 6], [6, 8], [8, 4], [7, 5], [5, 9], [6, 1], [1, 0], [1, 2], [2, 3], [3, 4], [8, 9], [5, 8]]
	for link in links:
		var line := Line2D.new()
		line.width = 2.2
		line.default_color = Color(0.50, 0.33, 0.17)
		line.points = PackedVector2Array([_world_to_map(SUPER_ZONE_CENTERS[int(link[0])]), _world_to_map(SUPER_ZONE_CENTERS[int(link[1])])])
		map_frame.add_child(line)

func _world_to_map(world_position: Vector3) -> Vector2:
	var nx := clampf((world_position.x + CONTINENT_HALF.x) / CONTINENT_SIZE.x, 0.0, 1.0)
	var nz := clampf((world_position.z + CONTINENT_HALF.y) / CONTINENT_SIZE.y, 0.0, 1.0)
	return Vector2(nx * map_frame.size.x, nz * map_frame.size.y)

func _update_map_marker() -> void:
	if not is_instance_valid(map_player_marker) or not is_instance_valid(map_frame):
		return
	var marker_position := _world_to_map(player.global_position if is_instance_valid(player) else SUPER_ZONE_CENTERS[current_zone])
	map_player_marker.position = marker_position - Vector2(38.0, 22.0)
	map_zone_label.text = "VOUS ÊTES EN ZONE %d — %s" % [current_zone + 1, SUPER_ZONE_NAMES[current_zone]]
	var completed_count := 0
	for zone_index in range(zone_completed.size()):
		if bool(zone_completed[zone_index]):
			completed_count += 1
	map_status_label.text = "Régions libérées : %d / 10 — un océan extérieur et seulement deux fleuves intérieurs" % completed_count

func _update_hud() -> void:
	if is_instance_valid(player) and is_instance_valid(health_label):
		health_label.text = "PV %d / %d" % [player.health, player.max_health]
	if is_instance_valid(zone_label):
		zone_label.text = "ZONE %d / 10 — %s" % [current_zone + 1, SUPER_ZONE_NAMES[current_zone]]
		zone_label.modulate = ZONE_ACCENT_COLORS[current_zone]
	if is_instance_valid(objective_label):
		if game_complete:
			objective_label.text = "MONDE LIBÉRÉ\n%d gardiens vaincus" % total_defeated
		elif current_zone == START_ZONE:
			objective_label.text = "Explore le supercontinent\nRoutes, plaines et deux fleuves"
		elif int(zone_remaining[current_zone]) > 0:
			objective_label.text = "Gardiens : %d / %d\nCarte disponible" % [zone_remaining[current_zone], zone_total[current_zone]]
		else:
			objective_label.text = "ZONE LIBÉRÉE\nExplore une autre région"

func _show_zone_banner() -> void:
	if not is_instance_valid(zone_banner):
		return
	zone_banner_token += 1
	var token := zone_banner_token
	zone_banner.text = "ZONE %d\n%s" % [current_zone + 1, SUPER_ZONE_NAMES[current_zone]]
	zone_banner.modulate = ZONE_ACCENT_COLORS[current_zone]
	zone_banner.visible = true
	await get_tree().create_timer(2.8).timeout
	if token == zone_banner_token and is_instance_valid(zone_banner):
		zone_banner.visible = false

func _on_enemy_defeated(enemy) -> void:
	enemies.erase(enemy)
	var zone_index := int(enemy.get_meta("zone_index", -1))
	if zone_index < 0 or zone_index >= zone_remaining.size():
		return
	zone_remaining[zone_index] = maxi(0, int(zone_remaining[zone_index]) - 1)
	total_defeated += 1
	if zone_remaining[zone_index] == 0:
		zone_completed[zone_index] = true
		_show_message("ZONE %d LIBÉRÉE — %s" % [zone_index + 1, SUPER_ZONE_NAMES[zone_index]], 5.0)
	game_complete = _all_hostile_zones_complete()
	if game_complete:
		_show_message("VICTOIRE — toutes les régions du supercontinent sont libérées !", 8.0)
	_update_hud()
	_update_map_marker()
	_save_progress()
