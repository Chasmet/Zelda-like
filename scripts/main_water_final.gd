extends "res://scripts/main_mobile_final.gd"

const WATER_PLAYER_SCRIPT = preload("res://scripts/player_water.gd")
const OCEAN_SURFACE_Y := -0.92
const OCEAN_BOTTOM_Y := -8.50
const OCEAN_SIZE := Vector2(260.0, 220.0)
const OCEAN_BOUNDS := Rect2(Vector2(-128.0, -108.0), Vector2(256.0, 216.0))

var ocean_swim_volume: Area3D
var ocean_floor: StaticBody3D
var water_status_label: Label
var underwater_overlay: ColorRect
var water_hud_timer: Timer


func _build_environment():
	super._build_environment()
	_build_ocean_physics()


func _build_ocean_physics() -> void:
	var water_depth: float = OCEAN_SURFACE_Y - OCEAN_BOTTOM_Y

	ocean_swim_volume = Area3D.new()
	ocean_swim_volume.name = "OceanSwimVolume"
	ocean_swim_volume.collision_layer = 0
	ocean_swim_volume.collision_mask = 1
	ocean_swim_volume.monitoring = true
	ocean_swim_volume.monitorable = true
	ocean_swim_volume.position = Vector3(0.0, OCEAN_BOTTOM_Y + water_depth * 0.5, 0.0)
	var volume_collision := CollisionShape3D.new()
	volume_collision.name = "WaterVolumeCollision"
	var volume_shape := BoxShape3D.new()
	volume_shape.size = Vector3(OCEAN_SIZE.x, water_depth, OCEAN_SIZE.y)
	volume_collision.shape = volume_shape
	ocean_swim_volume.add_child(volume_collision)
	add_child(ocean_swim_volume)

	ocean_floor = StaticBody3D.new()
	ocean_floor.name = "OceanSeabed"
	ocean_floor.collision_layer = 1
	ocean_floor.collision_mask = 1
	ocean_floor.position = Vector3(0.0, OCEAN_BOTTOM_Y - 0.40, 0.0)
	var floor_collision := CollisionShape3D.new()
	floor_collision.name = "SeabedCollision"
	var floor_shape := BoxShape3D.new()
	floor_shape.size = Vector3(OCEAN_SIZE.x - 2.0, 0.80, OCEAN_SIZE.y - 2.0)
	floor_collision.shape = floor_shape
	ocean_floor.add_child(floor_collision)

	var floor_visual := MeshInstance3D.new()
	floor_visual.name = "SeabedVisual"
	var floor_mesh := BoxMesh.new()
	floor_mesh.size = floor_shape.size
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color(0.055, 0.10, 0.095)
	floor_material.roughness = 0.94
	floor_mesh.material = floor_material
	floor_visual.mesh = floor_mesh
	ocean_floor.add_child(floor_visual)
	add_child(ocean_floor)

	var wall_height: float = water_depth + 6.0
	var wall_center_y: float = OCEAN_BOTTOM_Y + wall_height * 0.5
	_add_ocean_boundary("OceanBoundaryWest", Vector3(1.0, wall_height, OCEAN_SIZE.y), Vector3(-129.5, wall_center_y, 0.0))
	_add_ocean_boundary("OceanBoundaryEast", Vector3(1.0, wall_height, OCEAN_SIZE.y), Vector3(129.5, wall_center_y, 0.0))
	_add_ocean_boundary("OceanBoundaryNorth", Vector3(OCEAN_SIZE.x, wall_height, 1.0), Vector3(0.0, wall_center_y, -109.5))
	_add_ocean_boundary("OceanBoundarySouth", Vector3(OCEAN_SIZE.x, wall_height, 1.0), Vector3(0.0, wall_center_y, 109.5))


func _add_ocean_boundary(node_name: String, size_value: Vector3, position_value: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = node_name
	body.collision_layer = 1
	body.collision_mask = 1
	body.position = position_value
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size_value
	collision.shape = shape
	body.add_child(collision)
	add_child(body)


func _spawn_player():
	player = WATER_PLAYER_SCRIPT.new()
	player.name = "CheikhHero"
	var center = ZONE_CENTERS[START_ZONE]
	var spawn_x = center.x
	var spawn_z = center.z + 4.0
	player.position = Vector3(spawn_x, _terrain_world_height(START_ZONE, spawn_x, spawn_z) + 0.45, spawn_z)
	add_child(player)
	player.set_spawn(player.global_position)
	player.set_water_profile(OCEAN_SURFACE_Y, OCEAN_BOTTOM_Y, OCEAN_BOUNDS)
	if ResourceLoader.exists(HERO_MODEL):
		player.apply_asset(HERO_MODEL)
	player.health_changed.connect(_on_health_changed)
	player.attack_requested.connect(_on_player_attack)
	player.interact_requested.connect(_on_interact)


func _build_hud():
	super._build_hud()

	var underwater_canvas := CanvasLayer.new()
	underwater_canvas.name = "UnderwaterVisualLayer"
	underwater_canvas.layer = 19
	add_child(underwater_canvas)
	underwater_overlay = ColorRect.new()
	underwater_overlay.name = "UnderwaterOverlay"
	underwater_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	underwater_overlay.color = Color(0.0, 0.19, 0.34, 0.23)
	underwater_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	underwater_overlay.visible = false
	underwater_canvas.add_child(underwater_overlay)

	var status_canvas := CanvasLayer.new()
	status_canvas.name = "WaterStatusLayer"
	status_canvas.layer = 21
	add_child(status_canvas)
	water_status_label = Label.new()
	water_status_label.name = "WaterStatus"
	water_status_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	water_status_label.position = Vector2(-285.0, 145.0)
	water_status_label.size = Vector2(570.0, 48.0)
	water_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	water_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	water_status_label.add_theme_font_size_override("font_size", 19)
	water_status_label.add_theme_constant_override("outline_size", 7)
	water_status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status_canvas.add_child(water_status_label)

	water_hud_timer = Timer.new()
	water_hud_timer.wait_time = 0.08
	water_hud_timer.one_shot = false
	water_hud_timer.timeout.connect(_update_water_hud)
	add_child(water_hud_timer)
	water_hud_timer.start()
	_update_water_hud()


func _build_controls_help(root):
	super._build_controls_help(root)
	if is_instance_valid(controls_help_label):
		controls_help_label.text = "JOYSTICK : BOUGER/NAGER  •  SAUT : REMONTER  •  ESQUIVE : PLONGER  •  GLISSER À DROITE : CAMÉRA"


func _jump_button_pressed():
	if is_instance_valid(player) and bool(player.get("in_water")):
		player.request_swim_vertical(1.0, 0.55)
		return
	super._jump_button_pressed()


func _dodge_button_pressed():
	if is_instance_valid(player) and bool(player.get("in_water")):
		player.request_swim_vertical(-1.0, 0.55)
		return
	super._dodge_button_pressed()


func _update_water_hud() -> void:
	if not is_instance_valid(player) or not player.has_method("get_water_debug"):
		return
	var water: Dictionary = player.get_water_debug()
	var swimming := bool(water.get("in_water", false))
	var diving := bool(water.get("underwater", false))
	var current_oxygen := float(water.get("oxygen", 0.0))
	var maximum_oxygen := maxf(0.01, float(water.get("max_oxygen", 1.0)))

	if is_instance_valid(underwater_overlay):
		underwater_overlay.visible = diving
		var depth: float = maxf(0.0, OCEAN_SURFACE_Y - (player.global_position.y + 1.58))
		underwater_overlay.color = Color(0.0, 0.16, 0.30, clampf(0.20 + depth * 0.025, 0.20, 0.42))

	if not is_instance_valid(water_status_label):
		return
	if diving:
		var oxygen_percent := int(round(current_oxygen / maximum_oxygen * 100.0))
		var depth_value := maxf(0.0, OCEAN_SURFACE_Y - (player.global_position.y + 1.58))
		water_status_label.text = "PLONGÉE  •  OXYGÈNE %d%%  •  PROFONDEUR %.1f m" % [oxygen_percent, depth_value]
		water_status_label.modulate = Color(0.62, 0.90, 1.0)
	elif swimming:
		water_status_label.text = "NAGE  •  SAUT POUR REMONTER  •  ESQUIVE POUR PLONGER"
		water_status_label.modulate = Color(0.70, 0.92, 1.0)
	else:
		water_status_label.text = ""


func _save_progress():
	if not is_instance_valid(player):
		return
	var config := ConfigFile.new()
	config.set_value("world", "remaining", zone_remaining)
	config.set_value("world", "completed", zone_completed)
	config.set_value("world", "total_defeated", total_defeated)
	config.set_value("world", "complete", game_complete)
	var safe_position: Vector3 = player.global_position
	if player.has_method("get_safe_save_position"):
		safe_position = player.get_safe_save_position()
	config.set_value("player", "position", safe_position)
	config.set_value("player", "health", player.health)
	config.save(SAVE_PATH)
