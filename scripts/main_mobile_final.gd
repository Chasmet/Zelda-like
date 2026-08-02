extends "res://scripts/main_hud_final.gd"

const FIXED_JOYSTICK_RADIUS := 72.0
const JOYSTICK_DEAD_ZONE := 0.10

var fixed_joystick_base: Control
var fixed_joystick_label: Label


# The previous ConcavePolygonShape3D incorrectly treated the centre of every
# island as a vertical wall. Use a real height-map collider: this terrain is a
# regular height grid, which is exactly what HeightMapShape3D is designed for.
func _build_terrain(zone_index):
	var center: Vector3 = ZONE_CENTERS[zone_index]
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_material(_terrain_material(zone_index))

	var step_x: float = TERRAIN_SIZE.x / float(TERRAIN_STEPS)
	var step_z: float = TERRAIN_SIZE.y / float(TERRAIN_STEPS)

	for z_index in range(TERRAIN_STEPS):
		for x_index in range(TERRAIN_STEPS):
			var x0: float = -TERRAIN_SIZE.x * 0.5 + float(x_index) * step_x
			var x1: float = x0 + step_x
			var z0: float = -TERRAIN_SIZE.y * 0.5 + float(z_index) * step_z
			var z1: float = z0 + step_z

			var p00 := Vector3(x0, _zone_height(zone_index, x0, z0), z0)
			var p10 := Vector3(x1, _zone_height(zone_index, x1, z0), z0)
			var p01 := Vector3(x0, _zone_height(zone_index, x0, z1), z1)
			var p11 := Vector3(x1, _zone_height(zone_index, x1, z1), z1)

			var uv00 := Vector2(float(x_index), float(z_index)) / float(TERRAIN_STEPS) * 7.0
			var uv10 := Vector2(float(x_index + 1), float(z_index)) / float(TERRAIN_STEPS) * 7.0
			var uv01 := Vector2(float(x_index), float(z_index + 1)) / float(TERRAIN_STEPS) * 7.0
			var uv11 := Vector2(float(x_index + 1), float(z_index + 1)) / float(TERRAIN_STEPS) * 7.0

			surface.set_uv(uv00)
			surface.add_vertex(p00)
			surface.set_uv(uv01)
			surface.add_vertex(p01)
			surface.set_uv(uv11)
			surface.add_vertex(p11)

			surface.set_uv(uv00)
			surface.add_vertex(p00)
			surface.set_uv(uv11)
			surface.add_vertex(p11)
			surface.set_uv(uv10)
			surface.add_vertex(p10)

	surface.generate_normals()
	var terrain_mesh: ArrayMesh = surface.commit()

	var body := StaticBody3D.new()
	body.name = "Zone_%02d_Terrain" % (zone_index + 1)
	body.position = center

	var visual := MeshInstance3D.new()
	visual.mesh = terrain_mesh
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	body.add_child(visual)

	var collision_width: int = int(round(TERRAIN_SIZE.x)) + 1
	var collision_depth: int = int(round(TERRAIN_SIZE.y)) + 1
	var half_width: float = float(collision_width - 1) * 0.5
	var half_depth: float = float(collision_depth - 1) * 0.5
	var heights := PackedFloat32Array()
	heights.resize(collision_width * collision_depth)
	var data_index: int = 0
	for depth_index in range(collision_depth):
		var local_z: float = float(depth_index) - half_depth
		for width_index in range(collision_width):
			var local_x: float = float(width_index) - half_width
			heights[data_index] = float(_zone_height(zone_index, local_x, local_z))
			data_index += 1

	var height_shape := HeightMapShape3D.new()
	height_shape.map_width = collision_width
	height_shape.map_depth = collision_depth
	height_shape.map_data = heights

	var collision := CollisionShape3D.new()
	collision.name = "WalkableHeightMap"
	collision.shape = height_shape
	body.add_child(collision)
	add_child(body)


# The old bridges crossed the middle of each island at y=1.35, above the
# terrain. Their box colliders cut through the spawn area like invisible walls.
# Keep the bridge floor near sea level so it only becomes walkable after the
# island shore descends, while remaining safely above the ocean.
func _build_bridge(zone_a, zone_b, width, color):
	var start: Vector3 = ZONE_CENTERS[zone_a]
	var finish: Vector3 = ZONE_CENTERS[zone_b]
	var delta: Vector3 = finish - start
	var horizontal := Vector3(delta.x, 0.0, delta.z)
	var length: float = horizontal.length()
	if length < 1.0:
		return

	var midpoint: Vector3 = (start + finish) * 0.5
	midpoint.y = 0.12
	var bridge = _static_box(
		"Route_%02d_%02d" % [zone_a + 1, zone_b + 1],
		Vector3(width, 0.34, length),
		midpoint,
		color
	)
	bridge.rotation.y = atan2(horizontal.x, horizontal.z)

	var rail_y: float = midpoint.y + 0.42
	var left_offset: Vector3 = Vector3(-width * 0.48, 0.0, 0.0).rotated(Vector3.UP, bridge.rotation.y)
	var right_offset: Vector3 = Vector3(width * 0.48, 0.0, 0.0).rotated(Vector3.UP, bridge.rotation.y)
	var left_rail = _visual_box("Rail", Vector3(0.20, 0.65, length), Vector3(midpoint.x, rail_y, midpoint.z) + left_offset, Color(0.24, 0.16, 0.08))
	left_rail.rotation.y = bridge.rotation.y
	var right_rail = _visual_box("Rail", Vector3(0.20, 0.65, length), Vector3(midpoint.x, rail_y, midpoint.z) + right_offset, Color(0.24, 0.16, 0.08))
	right_rail.rotation.y = bridge.rotation.y


func _build_joystick(root):
	fixed_joystick_base = ColorRect.new()
	fixed_joystick_base.name = "FixedMovementJoystick"
	fixed_joystick_base.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	fixed_joystick_base.position = Vector2(28.0, -190.0)
	fixed_joystick_base.size = Vector2(160.0, 160.0)
	fixed_joystick_base.color = Color(0.055, 0.16, 0.34, 0.78)
	fixed_joystick_base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(fixed_joystick_base)

	var cross_vertical := ColorRect.new()
	cross_vertical.position = Vector2(76.0, 20.0)
	cross_vertical.size = Vector2(8.0, 120.0)
	cross_vertical.color = Color(0.46, 0.70, 0.96, 0.24)
	cross_vertical.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fixed_joystick_base.add_child(cross_vertical)

	var cross_horizontal := ColorRect.new()
	cross_horizontal.position = Vector2(20.0, 76.0)
	cross_horizontal.size = Vector2(120.0, 8.0)
	cross_horizontal.color = Color(0.46, 0.70, 0.96, 0.24)
	cross_horizontal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fixed_joystick_base.add_child(cross_horizontal)

	joystick_knob = ColorRect.new()
	joystick_knob.name = "MovementKnob"
	joystick_knob.position = Vector2(52.0, 52.0)
	joystick_knob.size = Vector2(56.0, 56.0)
	joystick_knob.color = Color(0.66, 0.86, 1.0, 0.96)
	joystick_knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fixed_joystick_base.add_child(joystick_knob)

	fixed_joystick_label = Label.new()
	fixed_joystick_label.text = "DÉPLACEMENT"
	fixed_joystick_label.position = Vector2(8.0, 132.0)
	fixed_joystick_label.size = Vector2(144.0, 24.0)
	fixed_joystick_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fixed_joystick_label.add_theme_font_size_override("font_size", 12)
	fixed_joystick_label.add_theme_constant_override("outline_size", 4)
	fixed_joystick_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fixed_joystick_base.add_child(fixed_joystick_label)


func _input(event):
	if is_instance_valid(map_panel) and map_panel.visible:
		_release_movement_touch()
		return

	if event is InputEventScreenTouch:
		_handle_screen_touch(event)
	elif event is InputEventScreenDrag:
		_handle_screen_drag(event)


func _unhandled_input(_event):
	pass


func _handle_screen_touch(event: InputEventScreenTouch):
	var screen_size: Vector2 = get_viewport().get_visible_rect().size

	if event.pressed:
		if move_touch_id < 0 and _is_movement_area(event.position, screen_size):
			move_touch_id = event.index
			move_origin = _fixed_joystick_center()
			_update_fixed_joystick(event.position)
			get_viewport().set_input_as_handled()
			return

		if look_touch_id < 0 and _is_camera_area(event.position, screen_size):
			look_touch_id = event.index
			get_viewport().set_input_as_handled()
			return
	else:
		if event.index == move_touch_id:
			_release_movement_touch()
			get_viewport().set_input_as_handled()
			return
		if event.index == look_touch_id:
			look_touch_id = -1
			get_viewport().set_input_as_handled()
			return


func _handle_screen_drag(event: InputEventScreenDrag):
	if event.index == move_touch_id:
		_update_fixed_joystick(event.position)
		get_viewport().set_input_as_handled()
		return

	if event.index == look_touch_id and is_instance_valid(player):
		player.add_camera_look(event.relative * 0.0042)
		get_viewport().set_input_as_handled()


func _is_movement_area(position: Vector2, screen_size: Vector2) -> bool:
	if position.x > screen_size.x * 0.48:
		return false
	if position.y < screen_size.y * 0.34:
		return false
	return true


func _is_camera_area(position: Vector2, screen_size: Vector2) -> bool:
	if position.x > screen_size.x * 0.70 and position.y > screen_size.y * 0.67:
		return false
	if position.x > screen_size.x * 0.78 and position.y < 105.0:
		return false
	return position.x >= screen_size.x * 0.42


func _fixed_joystick_center() -> Vector2:
	if is_instance_valid(fixed_joystick_base):
		var rect: Rect2 = fixed_joystick_base.get_global_rect()
		return rect.position + rect.size * 0.5
	var visible_size: Vector2 = get_viewport().get_visible_rect().size
	return Vector2(108.0, visible_size.y - 110.0)


func _update_fixed_joystick(screen_position: Vector2):
	move_origin = _fixed_joystick_center()
	var offset: Vector2 = (screen_position - move_origin).limit_length(FIXED_JOYSTICK_RADIUS)
	var direction: Vector2 = offset / FIXED_JOYSTICK_RADIUS
	if direction.length() < JOYSTICK_DEAD_ZONE:
		direction = Vector2.ZERO
	virtual_move = direction
	_apply_movement_to_player()

	if is_instance_valid(joystick_knob):
		joystick_knob.position = Vector2(52.0, 52.0) + offset
	if is_instance_valid(fixed_joystick_label):
		fixed_joystick_label.text = "AVANCE" if virtual_move.length() > JOYSTICK_DEAD_ZONE else "DÉPLACEMENT"


func _apply_movement_to_player():
	if is_instance_valid(player):
		player.set_virtual_move(virtual_move)


func _release_movement_touch():
	move_touch_id = -1
	virtual_move = Vector2.ZERO
	_apply_movement_to_player()
	if is_instance_valid(joystick_knob):
		joystick_knob.position = Vector2(52.0, 52.0)
	if is_instance_valid(fixed_joystick_label):
		fixed_joystick_label.text = "DÉPLACEMENT"


# Restore saved progress without duplicating guardians in partially completed
# zones. Older builds spawned every guardian before applying the saved counter,
# which could leave an impossible extra enemy after restarting the game.
func _load_progress():
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return

	var saved_remaining = config.get_value("world", "remaining", zone_remaining)
	if saved_remaining is Array and saved_remaining.size() == zone_remaining.size():
		for zone_index in range(zone_remaining.size()):
			zone_remaining[zone_index] = clampi(int(saved_remaining[zone_index]), 0, int(zone_total[zone_index]))

	var saved_completed = config.get_value("world", "completed", zone_completed)
	if saved_completed is Array and saved_completed.size() == zone_completed.size():
		for zone_index in range(zone_completed.size()):
			zone_completed[zone_index] = bool(saved_completed[zone_index])

	for zone_index in range(zone_remaining.size()):
		if zone_index == START_ZONE:
			zone_remaining[zone_index] = 0
			zone_completed[zone_index] = true
		elif bool(zone_completed[zone_index]):
			zone_remaining[zone_index] = 0
		else:
			zone_completed[zone_index] = int(zone_remaining[zone_index]) == 0

	_reconcile_loaded_enemies()
	total_defeated = _count_defeated_from_progress()
	game_complete = _all_hostile_zones_complete()

	var saved_position = config.get_value("player", "position", player.global_position)
	if saved_position is Vector3 and saved_position.is_finite():
		player.global_position = saved_position
		player.set_spawn(saved_position)
	player.health = clampi(int(config.get_value("player", "health", player.max_health)), 1, player.max_health)
	player.health_changed.emit(player.health, player.max_health)
	current_zone = _nearest_zone_for_position(player.global_position)


func _reconcile_loaded_enemies():
	var enemies_by_zone := {}
	for zone_index in range(zone_remaining.size()):
		enemies_by_zone[zone_index] = []

	for enemy in enemies.duplicate():
		if not is_instance_valid(enemy) or enemy.is_queued_for_deletion():
			enemies.erase(enemy)
			continue
		var enemy_zone := int(enemy.get_meta("zone_index", -1))
		if enemy_zone < 0 or enemy_zone >= zone_remaining.size():
			enemies.erase(enemy)
			enemy.queue_free()
			continue
		enemies_by_zone[enemy_zone].append(enemy)

	for zone_index in range(zone_remaining.size()):
		var desired_count := 0 if bool(zone_completed[zone_index]) else clampi(int(zone_remaining[zone_index]), 0, int(zone_total[zone_index]))
		var live_enemies: Array = enemies_by_zone[zone_index]
		while live_enemies.size() > desired_count:
			var extra_enemy = live_enemies.pop_back()
			enemies.erase(extra_enemy)
			if is_instance_valid(extra_enemy):
				extra_enemy.queue_free()

		# A corrupted old save must never request more enemies than are actually
		# present, otherwise the objective can become impossible to finish.
		if live_enemies.size() < desired_count:
			desired_count = live_enemies.size()
		zone_remaining[zone_index] = desired_count
		zone_completed[zone_index] = zone_index == START_ZONE or desired_count == 0


func _count_defeated_from_progress() -> int:
	var defeated_count := 0
	for zone_index in range(zone_total.size()):
		if zone_index == START_ZONE:
			continue
		defeated_count += maxi(0, int(zone_total[zone_index]) - int(zone_remaining[zone_index]))
	return defeated_count


func _nearest_zone_for_position(world_position: Vector3) -> int:
	var nearest_zone := START_ZONE
	var nearest_distance := INF
	for zone_index in range(ZONE_CENTERS.size()):
		var center: Vector3 = ZONE_CENTERS[zone_index]
		var dx := world_position.x - center.x
		var dz := world_position.z - center.z
		var dy := world_position.y - center.y
		var distance := dx * dx + dz * dz + dy * dy * 4.0
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_zone = zone_index
	return nearest_zone
