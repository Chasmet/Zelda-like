extends "res://scripts/main_visual_overhaul_v6.gd"

# V7 : correction ciblée de l'écran réellement visible au démarrage.
# Le héros n'apparaît plus dans l'axe du grand pont. La place du village,
# les maisons, la plage et les éléments de pêche sont implantés manuellement.

const V7_VERSION: String = "0.7.0-village-cotier"
const V7_SPAWN_LOCAL := Vector2(24.0, 10.0)

var v7_house_count: int = 0
var v7_fishing_detail_count: int = 0
var v7_beach_detail_count: int = 0
var v7_message_centered: bool = false
var v7_spawn_off_bridge: bool = false


func _build_zone(zone_index) -> void:
	super._build_zone(zone_index)
	if int(zone_index) != 0:
		return
	active_build_parent = zone_roots[0]
	_build_coastal_square_v7()
	_build_coastal_houses_v7()
	_build_fishing_quarter_v7()
	_build_beach_v7()
	active_build_parent = null


func _spawn_player() -> void:
	super._spawn_player()
	if not is_instance_valid(player):
		return
	var center: Vector3 = ZONE_CENTERS[START_ZONE]
	var spawn_x: float = center.x + V7_SPAWN_LOCAL.x
	var spawn_z: float = center.z + V7_SPAWN_LOCAL.y
	v6_start_position = Vector3(spawn_x, _terrain_world_height(START_ZONE, spawn_x, spawn_z) + 0.62, spawn_z)
	player.global_position = v6_start_position
	player.set_spawn(v6_start_position)
	v7_spawn_off_bridge = absf(v6_start_position.x - center.x) >= 18.0


func _finish_loading() -> void:
	super._finish_loading()
	call_deferred("_finalize_coastal_presentation_v7")


func get_v7_presentation_debug() -> Dictionary:
	return {
		"version": V7_VERSION,
		"houses": v7_house_count,
		"fishing_details": v7_fishing_detail_count,
		"beach_details": v7_beach_detail_count,
		"message_centered": v7_message_centered,
		"spawn_off_bridge": v7_spawn_off_bridge,
		"spawn": v6_start_position
	}


func _build_coastal_square_v7() -> void:
	var plaza_position: Vector3 = _terrain_position_v6(0, Vector2(24.0, 10.0), 0.18)
	var plaza: MeshInstance3D = MeshInstance3D.new()
	plaza.name = "PlaceDesPêcheursV7"
	var plaza_mesh: CylinderMesh = CylinderMesh.new()
	plaza_mesh.top_radius = 13.5
	plaza_mesh.bottom_radius = 13.8
	plaza_mesh.height = 0.28
	plaza_mesh.radial_segments = 32
	plaza_mesh.material = _standard_material_v6(Color(0.54, 0.48, 0.35))
	plaza.mesh = plaza_mesh
	plaza.position = plaza_position
	plaza.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	active_build_parent.add_child(plaza)

	var well_base: MeshInstance3D = MeshInstance3D.new()
	well_base.name = "PuitsDuVillageV7"
	var well_mesh: CylinderMesh = CylinderMesh.new()
	well_mesh.top_radius = 1.55
	well_mesh.bottom_radius = 1.72
	well_mesh.height = 1.15
	well_mesh.radial_segments = 16
	well_mesh.material = _standard_material_v6(Color(0.34, 0.33, 0.30))
	well_base.mesh = well_mesh
	well_base.position = plaza_position + Vector3(0.0, 0.70, 0.0)
	active_build_parent.add_child(well_base)

	for side in [-1.0, 1.0]:
		_add_box_v6("MontantPuitsV7", Vector3(0.18, 2.4, 0.18), plaza_position + Vector3(float(side) * 1.25, 1.65, 0.0), Color(0.24, 0.12, 0.04))
	_add_box_v6("TraversePuitsV7", Vector3(3.0, 0.20, 0.20), plaza_position + Vector3(0.0, 2.78, 0.0), Color(0.24, 0.12, 0.04))

	for bench_index in range(4):
		var angle: float = float(bench_index) * TAU / 4.0
		var bench_position: Vector3 = plaza_position + Vector3(cos(angle) * 8.5, 0.65, sin(angle) * 8.5)
		var bench: MeshInstance3D = _add_box_v6("BancPlaceV7_%02d" % bench_index, Vector3(3.2, 0.32, 0.9), bench_position, Color(0.31, 0.16, 0.055))
		bench.rotation.y = -angle

	var path_material: Color = Color(0.65, 0.56, 0.39)
	_add_box_v6("CheminPlacePortV7", Vector3(6.0, 0.18, 37.0), _terrain_position_v6(0, Vector2(24.0, -10.0), 0.12), path_material)
	_add_box_v6("CheminPlaceMarchéV7", Vector3(34.0, 0.18, 5.0), _terrain_position_v6(0, Vector2(8.0, 10.0), 0.12), path_material)


func _build_coastal_houses_v7() -> void:
	var house_data := [
		[Vector2(5.0, -8.0), Vector3(8.4, 4.8, 6.8), Color(0.78, 0.65, 0.48), Color(0.45, 0.12, 0.08), 0.18],
		[Vector2(8.0, 28.0), Vector3(7.2, 4.3, 6.2), Color(0.70, 0.79, 0.68), Color(0.16, 0.31, 0.42), -0.12],
		[Vector2(38.0, -8.0), Vector3(7.8, 5.2, 7.0), Color(0.82, 0.69, 0.43), Color(0.42, 0.18, 0.06), -0.24],
		[Vector2(42.0, 25.0), Vector3(8.6, 4.6, 6.6), Color(0.68, 0.74, 0.82), Color(0.20, 0.18, 0.36), 0.20],
		[Vector2(25.0, 39.0), Vector3(9.2, 5.4, 7.4), Color(0.80, 0.57, 0.38), Color(0.38, 0.10, 0.06), 0.02],
		[Vector2(49.0, 8.0), Vector3(6.8, 4.1, 5.8), Color(0.73, 0.66, 0.55), Color(0.15, 0.28, 0.30), -0.30]
	]
	for house_index in range(house_data.size()):
		var data: Array = house_data[house_index]
		_add_detailed_house_v7(house_index, data[0], data[1], data[2], data[3], float(data[4]))


func _add_detailed_house_v7(index: int, local_position: Vector2, size_value: Vector3, wall_color: Color, roof_color: Color, rotation_y: float) -> void:
	var ground: Vector3 = _terrain_position_v6(0, local_position, 0.0)
	var house_root: Node3D = Node3D.new()
	house_root.name = "MaisonPêcheurV7_%02d" % index
	house_root.position = ground
	house_root.rotation.y = rotation_y
	active_build_parent.add_child(house_root)

	var body: StaticBody3D = StaticBody3D.new()
	body.name = "CorpsMaison"
	house_root.add_child(body)
	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = size_value
	collision.shape = shape
	collision.position.y = size_value.y * 0.5
	body.add_child(collision)
	var wall_mesh: MeshInstance3D = MeshInstance3D.new()
	var wall_box: BoxMesh = BoxMesh.new()
	wall_box.size = size_value
	wall_box.material = _standard_material_v6(wall_color)
	wall_mesh.mesh = wall_box
	wall_mesh.position.y = size_value.y * 0.5
	wall_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	body.add_child(wall_mesh)

	var roof: MeshInstance3D = MeshInstance3D.new()
	roof.name = "Toit"
	var roof_mesh: PrismMesh = PrismMesh.new()
	roof_mesh.size = Vector3(size_value.x + 1.2, 2.5, size_value.z + 1.0)
	roof_mesh.material = _standard_material_v6(roof_color)
	roof.mesh = roof_mesh
	roof.position.y = size_value.y + 1.05
	roof.rotation.y = PI * 0.5
	house_root.add_child(roof)

	var door: MeshInstance3D = _make_box_mesh_v7(Vector3(1.25, 2.35, 0.20), Color(0.24, 0.11, 0.035))
	door.position = Vector3(0.0, 1.18, size_value.z * 0.5 + 0.11)
	house_root.add_child(door)
	for window_x in [-size_value.x * 0.27, size_value.x * 0.27]:
		var window: MeshInstance3D = _make_box_mesh_v7(Vector3(1.25, 1.05, 0.16), Color(0.40, 0.78, 0.92), Color(0.08, 0.25, 0.34))
		window.position = Vector3(window_x, size_value.y * 0.58, size_value.z * 0.5 + 0.13)
		house_root.add_child(window)

	var chimney: MeshInstance3D = _make_box_mesh_v7(Vector3(0.75, 2.0, 0.75), Color(0.33, 0.23, 0.18))
	chimney.position = Vector3(size_value.x * 0.25, size_value.y + 1.6, 0.0)
	house_root.add_child(chimney)
	v7_house_count += 1


func _build_fishing_quarter_v7() -> void:
	var crate_positions := [Vector2(-28, 20), Vector2(-25, 22), Vector2(-22, 20), Vector2(-32, 12), Vector2(-29, 10), Vector2(-18, 30), Vector2(-15, 32), Vector2(-12, 30)]
	for crate_index in range(crate_positions.size()):
		var crate: MeshInstance3D = _add_box_v6("CaissePoissonV7_%02d" % crate_index, Vector3(1.4, 1.0, 1.2), _terrain_position_v6(0, crate_positions[crate_index], 0.55), Color(0.34, 0.18, 0.055))
		crate.rotation.y = float(crate_index % 4) * 0.22
		v7_fishing_detail_count += 1

	for barrel_index in range(6):
		var barrel: MeshInstance3D = MeshInstance3D.new()
		barrel.name = "TonneauV7_%02d" % barrel_index
		var barrel_mesh: CylinderMesh = CylinderMesh.new()
		barrel_mesh.top_radius = 0.55
		barrel_mesh.bottom_radius = 0.58
		barrel_mesh.height = 1.25
		barrel_mesh.radial_segments = 12
		barrel_mesh.material = _standard_material_v6(Color(0.31, 0.15, 0.04))
		barrel.mesh = barrel_mesh
		barrel.position = _terrain_position_v6(0, Vector2(-34.0 + float(barrel_index) * 3.0, 27.0 + float(barrel_index % 2) * 2.0), 0.65)
		active_build_parent.add_child(barrel)
		v7_fishing_detail_count += 1

	for rack_index in range(3):
		var rack_position: Vector3 = _terrain_position_v6(0, Vector2(-37.0 + float(rack_index) * 8.0, 37.0), 0.0)
		_add_box_v6("SéchoirPoissonV7", Vector3(0.18, 2.4, 0.18), rack_position + Vector3(-2.0, 1.2, 0.0), Color(0.20, 0.10, 0.03))
		_add_box_v6("SéchoirPoissonV7", Vector3(0.18, 2.4, 0.18), rack_position + Vector3(2.0, 1.2, 0.0), Color(0.20, 0.10, 0.03))
		_add_box_v6("TraverseSéchoirV7", Vector3(4.3, 0.18, 0.18), rack_position + Vector3(0.0, 2.25, 0.0), Color(0.20, 0.10, 0.03))
		for fish_index in range(5):
			_add_box_v6("PoissonSuspenduV7", Vector3(0.22, 0.72, 0.12), rack_position + Vector3(-1.5 + float(fish_index) * 0.75, 1.65, 0.0), Color(0.45, 0.64, 0.67))
			v7_fishing_detail_count += 1


func _build_beach_v7() -> void:
	var beach: MeshInstance3D = MeshInstance3D.new()
	beach.name = "PlageCôtièreV7"
	var beach_mesh: PlaneMesh = PlaneMesh.new()
	beach_mesh.size = Vector2(112.0, 18.0)
	beach_mesh.material = _standard_material_v6(Color(0.82, 0.69, 0.43))
	beach.mesh = beach_mesh
	beach.position = _terrain_position_v6(0, Vector2(0.0, 56.0), 0.16)
	active_build_parent.add_child(beach)

	var shell_positions: Array[Vector3] = []
	for shell_index in range(32):
		var x_value: float = -51.0 + float(shell_index % 16) * 6.8
		var z_value: float = 50.0 + float(shell_index / 16) * 7.0 + sin(float(shell_index) * 1.7) * 1.4
		shell_positions.append(_terrain_position_v6(0, Vector2(x_value, z_value), 0.28))
	var shell_mesh: SphereMesh = SphereMesh.new()
	shell_mesh.radius = 0.22
	shell_mesh.height = 0.14
	shell_mesh.radial_segments = 7
	shell_mesh.rings = 3
	shell_mesh.material = _standard_material_v6(Color(0.92, 0.82, 0.67))
	_create_multimesh_v6("CoquillagesV7", shell_positions, shell_mesh, Vector3.ONE, Vector3.ZERO)
	v7_beach_detail_count += shell_positions.size()

	var palm_positions := [Vector2(-46, 45), Vector2(-35, 51), Vector2(36, 50), Vector2(47, 44)]
	for palm_index in range(palm_positions.size()):
		var palm_ground: Vector3 = _terrain_position_v6(0, palm_positions[palm_index], 0.0)
		var trunk: MeshInstance3D = MeshInstance3D.new()
		var trunk_mesh: CylinderMesh = CylinderMesh.new()
		trunk_mesh.top_radius = 0.20
		trunk_mesh.bottom_radius = 0.36
		trunk_mesh.height = 5.4
		trunk_mesh.radial_segments = 8
		trunk_mesh.material = _standard_material_v6(Color(0.28, 0.14, 0.045))
		trunk.mesh = trunk_mesh
		trunk.position = palm_ground + Vector3(0.0, 2.7, 0.0)
		active_build_parent.add_child(trunk)
		for leaf_index in range(6):
			var leaf: MeshInstance3D = _make_box_mesh_v7(Vector3(0.35, 0.12, 3.5), Color(0.08, 0.42, 0.18))
			leaf.position = palm_ground + Vector3(0.0, 5.5, 0.0)
			leaf.rotation.y = float(leaf_index) * TAU / 6.0
			leaf.rotation.x = -0.30
			active_build_parent.add_child(leaf)
		v7_beach_detail_count += 7


func _finalize_coastal_presentation_v7() -> void:
	if is_instance_valid(message_label):
		message_label.anchor_left = 0.5
		message_label.anchor_right = 0.5
		message_label.anchor_top = 0.0
		message_label.anchor_bottom = 0.0
		message_label.offset_left = -340.0
		message_label.offset_right = 340.0
		message_label.offset_top = 82.0
		message_label.offset_bottom = 126.0
		message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		message_label.clip_text = false
		v7_message_centered = message_label.offset_left < 0.0 and message_label.offset_right > 0.0
	if is_instance_valid(zone_banner):
		zone_banner.anchor_left = 0.5
		zone_banner.anchor_right = 0.5
		zone_banner.anchor_top = 0.5
		zone_banner.anchor_bottom = 0.5
		zone_banner.offset_left = -360.0
		zone_banner.offset_right = 360.0
		zone_banner.offset_top = -76.0
		zone_banner.offset_bottom = -4.0
	if is_instance_valid(player):
		var pivot: Node3D = player.get_node_or_null("CameraPivot") as Node3D
		if is_instance_valid(pivot):
			pivot.rotation.y = deg_to_rad(212.0)


func _make_box_mesh_v7(size_value: Vector3, color: Color, emission: Color = Color(0, 0, 0, 1)) -> MeshInstance3D:
	var instance: MeshInstance3D = MeshInstance3D.new()
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size_value
	mesh.material = _standard_material_v6(color, emission)
	instance.mesh = mesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	return instance
