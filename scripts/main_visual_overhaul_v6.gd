extends "res://scripts/main_mobile_final.gd"

# Passe visuelle V6. Elle conserve tous les systèmes V5 et remplace uniquement
# leur présentation : matériaux de terrain, ponts, détails de biome, atmosphère,
# caméra et encombrement du HUD. Les implantations sont déterministes et fixes.

const V6_VERSION := "0.6.0-qualite-visuelle"
const V6_CAMERA_DISTANCE := 8.4
const V6_DETAIL_VISIBILITY := 210.0

const CLUSTER_OFFSETS := [
	Vector2(-8.0, -5.0), Vector2(-4.0, 3.0), Vector2(0.0, -8.0),
	Vector2(4.0, 6.0), Vector2(8.0, -2.0), Vector2(-7.0, 8.0),
	Vector2(7.0, 9.0), Vector2(-1.0, 11.0), Vector2(11.0, 3.0),
	Vector2(-11.0, 1.0), Vector2(2.0, -12.0), Vector2(12.0, -9.0)
]

const TREE_ANCHORS := [
	[Vector2(-52, -38), Vector2(48, -34), Vector2(-50, 38), Vector2(52, 34)],
	[Vector2(-48, -40), Vector2(-18, -44), Vector2(20, -42), Vector2(50, -36), Vector2(-52, 8), Vector2(50, 10), Vector2(-44, 43), Vector2(0, 48), Vector2(44, 42)],
	[Vector2(-48, 38), Vector2(44, 42)],
	[Vector2(-56, -44), Vector2(54, 42)],
	[],
	[Vector2(-48, -36), Vector2(46, -40), Vector2(-52, 34), Vector2(50, 38)],
	[],
	[Vector2(-56, 38), Vector2(55, 36)],
	[Vector2(-50, -42), Vector2(48, 40)],
	[Vector2(-50, -38), Vector2(48, -36), Vector2(-46, 39), Vector2(46, 42)]
]

const ROCK_ANCHORS := [
	[Vector2(-58, -20), Vector2(58, -16), Vector2(-54, 34), Vector2(56, 36)],
	[Vector2(-58, -50), Vector2(58, 48)],
	[Vector2(-52, -38), Vector2(-18, -48), Vector2(20, -46), Vector2(50, -36), Vector2(-55, 12), Vector2(54, 16), Vector2(-42, 46), Vector2(44, 48)],
	[Vector2(-58, -48), Vector2(58, 48)],
	[Vector2(-50, -42), Vector2(0, -50), Vector2(50, -40), Vector2(-56, 5), Vector2(56, 8), Vector2(-42, 44), Vector2(42, 46)],
	[Vector2(-54, -42), Vector2(52, 44)],
	[Vector2(-52, -42), Vector2(0, -48), Vector2(52, -38), Vector2(-58, 12), Vector2(56, 18), Vector2(-44, 46), Vector2(46, 44)],
	[Vector2(-58, -46), Vector2(58, 45)],
	[Vector2(-54, -44), Vector2(0, -50), Vector2(52, -42), Vector2(-56, 14), Vector2(54, 18), Vector2(-44, 46), Vector2(44, 48)],
	[Vector2(-54, -42), Vector2(-18, -50), Vector2(20, -48), Vector2(52, -38), Vector2(-50, 42), Vector2(50, 44)]
]

var v6_authored_detail_instances := 0
var v6_bridge_count := 0
var v6_atmosphere_count := 0
var v6_hud_compacted := false
var v6_camera_upgraded := false
var v6_terrain_shader_count := 0
var v6_start_position := Vector3.ZERO


func _build_environment() -> void:
	super._build_environment()
	if is_instance_valid(environment_state):
		environment_state.ambient_light_energy = 0.74
		environment_state.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
		environment_state.fog_density = 0.00125
		environment_state.fog_sky_affect = 0.28
		environment_state.adjustment_enabled = true
		environment_state.adjustment_brightness = 1.02
		environment_state.adjustment_contrast = 1.08
		environment_state.adjustment_saturation = 1.08
	if is_instance_valid(sun_light):
		sun_light.light_energy = 1.32
		sun_light.shadow_blur = 1.35
		sun_light.directional_shadow_max_distance = 185.0
		if "directional_shadow_fade_start" in sun_light:
			sun_light.directional_shadow_fade_start = 0.72
	_add_soft_fill_light()


func _terrain_material(zone_index):
	if terrain_material_cache.has(zone_index):
		return terrain_material_cache[zone_index]
	var material := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform vec4 couleur_base : source_color;
uniform vec4 couleur_detail : source_color;
uniform vec4 couleur_roche : source_color;
uniform float humidite = 0.0;
uniform float neige = 0.0;
uniform float chaleur = 0.0;
varying vec3 position_terrain;
varying vec3 normale_terrain;

float hachage(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float bruit(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hachage(i), hachage(i + vec2(1.0, 0.0)), f.x), mix(hachage(i + vec2(0.0, 1.0)), hachage(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	position_terrain = VERTEX;
	normale_terrain = NORMAL;
}

void fragment() {
	float macro = bruit(position_terrain.xz * 0.030);
	float moyen = bruit(position_terrain.xz * 0.105 + vec2(13.0, 7.0));
	float fin = bruit(position_terrain.xz * 0.42 + vec2(3.0, 19.0));
	float melange = clamp(macro * 0.52 + moyen * 0.34 + fin * 0.14, 0.0, 1.0);
	float pente = 1.0 - clamp(normale_terrain.y, 0.0, 1.0);
	vec3 couleur = mix(couleur_base.rgb, couleur_detail.rgb, smoothstep(0.18, 0.82, melange));
	couleur = mix(couleur, couleur_roche.rgb, smoothstep(0.28, 0.70, pente));
	couleur = mix(couleur, vec3(0.90, 0.96, 1.0), neige * smoothstep(0.48, 0.78, normale_terrain.y) * (0.58 + macro * 0.42));
	couleur += vec3(0.22, 0.035, 0.0) * chaleur * smoothstep(0.78, 0.98, fin);
	ALBEDO = couleur;
	ROUGHNESS = clamp(0.92 - humidite * 0.36 - chaleur * 0.08, 0.42, 0.96);
	METALLIC = chaleur * 0.04;
	SPECULAR = 0.30 + humidite * 0.28;
}
"""
	material.shader = shader
	var base: Color = ZONE_BASE_COLORS[zone_index]
	var accent: Color = ZONE_ACCENT_COLORS[zone_index]
	var rock := Color(0.25, 0.24, 0.23)
	if zone_index == 0:
		rock = Color(0.36, 0.35, 0.31)
	elif zone_index == 1:
		rock = Color(0.18, 0.23, 0.16)
	elif zone_index == 2:
		rock = Color(0.34, 0.33, 0.32)
	elif zone_index == 3:
		rock = Color(0.35, 0.31, 0.22)
	elif zone_index == 4:
		rock = Color(0.065, 0.055, 0.052)
	elif zone_index == 5:
		rock = Color(0.12, 0.16, 0.13)
	elif zone_index == 6:
		rock = Color(0.31, 0.29, 0.27)
	elif zone_index == 7:
		rock = Color(0.31, 0.30, 0.28)
	elif zone_index == 8:
		rock = Color(0.46, 0.40, 0.29)
	elif zone_index == 9:
		rock = Color(0.48, 0.55, 0.60)
	material.set_shader_parameter("couleur_base", base)
	material.set_shader_parameter("couleur_detail", base.lerp(accent, 0.42))
	material.set_shader_parameter("couleur_roche", rock)
	material.set_shader_parameter("humidite", 0.72 if zone_index in [0, 1, 5, 7] else 0.18)
	material.set_shader_parameter("neige", 1.0 if zone_index == 9 else 0.0)
	material.set_shader_parameter("chaleur", 1.0 if zone_index == 4 else 0.0)
	terrain_material_cache[zone_index] = material
	v6_terrain_shader_count += 1
	return material


func _build_zone(zone_index) -> void:
	super._build_zone(zone_index)
	if zone_index < 0 or zone_index >= zone_roots.size():
		return
	active_build_parent = zone_roots[zone_index]
	_add_authored_biome_details(zone_index)
	_add_region_atmosphere(zone_index)
	active_build_parent = null


func _build_bridge(zone_a, zone_b, width, color) -> void:
	var start: Vector3 = ZONE_CENTERS[zone_a]
	var finish: Vector3 = ZONE_CENTERS[zone_b]
	var delta := finish - start
	var horizontal := Vector3(delta.x, 0.0, delta.z)
	var length := horizontal.length()
	if length < 1.0:
		return
	var midpoint := (start + finish) * 0.5
	midpoint.y = 0.10
	var bridge_root := StaticBody3D.new()
	bridge_root.name = "PontV6_%02d_%02d" % [zone_a + 1, zone_b + 1]
	bridge_root.position = midpoint
	bridge_root.rotation.y = atan2(horizontal.x, horizontal.z)
	bridge_root.set_meta("pont_v6", true)
	add_child(bridge_root)

	var collision := CollisionShape3D.new()
	collision.name = "CollisionContinue"
	var deck_shape := BoxShape3D.new()
	deck_shape.size = Vector3(width, 0.38, length)
	collision.shape = deck_shape
	bridge_root.add_child(collision)

	var deck := MeshInstance3D.new()
	deck.name = "TablierPlanches"
	var deck_mesh := BoxMesh.new()
	deck_mesh.size = Vector3(width, 0.38, length)
	deck_mesh.material = _bridge_material(color)
	deck.mesh = deck_mesh
	deck.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	bridge_root.add_child(deck)

	var rail_color := Color(0.17, 0.095, 0.035)
	for side in [-1.0, 1.0]:
		var rail := MeshInstance3D.new()
		var rail_mesh := BoxMesh.new()
		rail_mesh.size = Vector3(0.18, 0.20, length)
		rail_mesh.material = _simple_material(rail_color)
		rail.mesh = rail_mesh
		rail.position = Vector3(side * (width * 0.49), 0.88, 0.0)
		rail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		bridge_root.add_child(rail)

	var post_mesh := BoxMesh.new()
	post_mesh.size = Vector3(0.22, 1.65, 0.22)
	post_mesh.material = _simple_material(rail_color.darkened(0.08))
	var post_count := maxi(4, int(length / 7.5) + 1)
	var posts := MultiMeshInstance3D.new()
	posts.name = "PoteauxPont"
	var post_multimesh := MultiMesh.new()
	post_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	post_multimesh.mesh = post_mesh
	post_multimesh.instance_count = post_count * 2
	var transform_index := 0
	for post_index in range(post_count):
		var z_position := -length * 0.5 + length * float(post_index) / float(maxi(1, post_count - 1))
		for side in [-1.0, 1.0]:
			post_multimesh.set_instance_transform(transform_index, Transform3D(Basis.IDENTITY, Vector3(side * (width * 0.49), 0.72, z_position)))
			transform_index += 1
	posts.multimesh = post_multimesh
	posts.visibility_range_end = V6_DETAIL_VISIBILITY
	bridge_root.add_child(posts)
	v6_authored_detail_instances += post_count * 2
	v6_bridge_count += 1


func _spawn_player() -> void:
	super._spawn_player()
	if not is_instance_valid(player):
		return
	var center: Vector3 = ZONE_CENTERS[START_ZONE]
	var spawn_x := center.x
	var spawn_z := center.z + 27.0
	v6_start_position = Vector3(spawn_x, _terrain_world_height(START_ZONE, spawn_x, spawn_z) + 0.62, spawn_z)
	player.global_position = v6_start_position
	player.set_spawn(v6_start_position)


func _build_hud() -> void:
	super._build_hud()
	_compact_mobile_hud()


func _finish_loading() -> void:
	super._finish_loading()
	call_deferred("_finalize_v6_camera")


func get_visual_overhaul_debug() -> Dictionary:
	var camera_distance := 0.0
	if is_instance_valid(player):
		var arm := player.get_node_or_null("CameraPivot/SpringArm") as SpringArm3D
		if is_instance_valid(arm):
			camera_distance = arm.spring_length
	return {
		"version": V6_VERSION,
		"terrain_shaders": v6_terrain_shader_count,
		"authored_detail_instances": v6_authored_detail_instances,
		"bridges": v6_bridge_count,
		"atmospheres": v6_atmosphere_count,
		"camera_distance": camera_distance,
		"camera_upgraded": v6_camera_upgraded,
		"hud_compact": v6_hud_compacted,
		"start_position": v6_start_position,
		"start_region_distance": Vector2(v6_start_position.x - ZONE_CENTERS[START_ZONE].x, v6_start_position.z - ZONE_CENTERS[START_ZONE].z).length()
	}


func _add_soft_fill_light() -> void:
	var fill := DirectionalLight3D.new()
	fill.name = "LumiereAmbianteV6"
	fill.rotation_degrees = Vector3(-28.0, 142.0, 0.0)
	fill.light_color = Color(0.46, 0.62, 0.82)
	fill.light_energy = 0.18
	fill.shadow_enabled = false
	add_child(fill)


func _add_authored_biome_details(zone_index: int) -> void:
	_add_authored_tree_clusters(zone_index)
	_add_authored_rock_clusters(zone_index)
	match zone_index:
		0:
			_add_coastal_market_details(zone_index)
		1:
			_add_forest_floor_details(zone_index)
		2:
			_add_mountain_ledge_details(zone_index)
		3:
			_add_crop_rows(zone_index)
		4:
			_add_obsidian_spires(zone_index)
		5:
			_add_marsh_reeds(zone_index)
		6:
			_add_ash_ribs(zone_index)
		7:
			_add_port_cargo(zone_index)
		8:
			_add_ruin_fragments(zone_index)
		9:
			_add_snow_pines(zone_index)


func _add_authored_tree_clusters(zone_index: int) -> void:
	var anchors: Array = TREE_ANCHORS[zone_index]
	if anchors.is_empty():
		return
	var positions: Array[Vector3] = []
	for anchor_value in anchors:
		var anchor: Vector2 = anchor_value
		for offset_index in range(CLUSTER_OFFSETS.size()):
			if (offset_index + zone_index) % 3 == 0 and zone_index in [0, 2, 3, 7, 8, 9]:
				continue
			var offset: Vector2 = CLUSTER_OFFSETS[offset_index] * (0.62 + float((offset_index + zone_index) % 3) * 0.09)
			positions.append(_terrain_position(zone_index, anchor + offset, 0.0))
	if positions.is_empty():
		return
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.16
	trunk_mesh.bottom_radius = 0.25
	trunk_mesh.height = 3.1
	trunk_mesh.radial_segments = 7
	trunk_mesh.material = _simple_material(Color(0.20, 0.105, 0.040))
	var crown_mesh: PrimitiveMesh
	if zone_index == 9:
		var pine := CylinderMesh.new()
		pine.top_radius = 0.05
		pine.bottom_radius = 1.35
		pine.height = 3.5
		pine.radial_segments = 8
		pine.material = _simple_material(Color(0.08, 0.25, 0.20))
		crown_mesh = pine
	else:
		var crown := SphereMesh.new()
		crown.radius = 1.25
		crown.height = 2.25
		crown.radial_segments = 8
		crown.rings = 5
		var foliage := ZONE_ACCENT_COLORS[zone_index].darkened(0.18)
		if zone_index == 0:
			foliage = Color(0.12, 0.48, 0.24)
		elif zone_index == 5:
			foliage = Color(0.10, 0.25, 0.14)
		crown.material = _simple_material(foliage)
		crown_mesh = crown
	_create_multimesh("TroncsV6", positions, trunk_mesh, Vector3(1.0, 1.0, 1.0), Vector3(0.0, 1.55, 0.0))
	_create_multimesh("FeuillagesV6", positions, crown_mesh, Vector3(1.0, 1.0, 1.0), Vector3(0.0, 3.65, 0.0))


func _add_authored_rock_clusters(zone_index: int) -> void:
	var anchors: Array = ROCK_ANCHORS[zone_index]
	if anchors.is_empty():
		return
	var positions: Array[Vector3] = []
	for anchor_value in anchors:
		var anchor: Vector2 = anchor_value
		for offset_index in range(0, CLUSTER_OFFSETS.size(), 2):
			var offset: Vector2 = CLUSTER_OFFSETS[offset_index] * 0.48
			positions.append(_terrain_position(zone_index, anchor + offset, 0.32))
	var rock_mesh := SphereMesh.new()
	rock_mesh.radius = 0.75
	rock_mesh.height = 1.15
	rock_mesh.radial_segments = 7
	rock_mesh.rings = 4
	var rock_color := Color(0.31, 0.30, 0.28)
	if zone_index == 4:
		rock_color = Color(0.055, 0.050, 0.048)
	elif zone_index == 6:
		rock_color = Color(0.36, 0.34, 0.31)
	elif zone_index == 9:
		rock_color = Color(0.66, 0.72, 0.76)
	rock_mesh.material = _simple_material(rock_color)
	_create_multimesh("RochersV6", positions, rock_mesh, Vector3(1.25, 0.82, 1.05), Vector3.ZERO)


func _add_coastal_market_details(zone_index: int) -> void:
	var stall_offsets := [Vector2(-18, 20), Vector2(-9, 22), Vector2(9, 22), Vector2(18, 20), Vector2(-14, 32), Vector2(14, 32)]
	for stall_index in range(stall_offsets.size()):
		var local: Vector2 = stall_offsets[stall_index]
		var ground := _terrain_position(zone_index, local, 0.0)
		_add_visual_box_to_region("EtalMarche_%02d" % stall_index, Vector3(4.8, 0.85, 2.6), ground + Vector3(0, 0.55, 0), Color(0.31, 0.17, 0.065))
		var canopy_color := Color(0.84, 0.28, 0.18) if stall_index % 2 == 0 else Color(0.93, 0.77, 0.34)
		_add_visual_box_to_region("ToileMarche_%02d" % stall_index, Vector3(5.2, 0.16, 3.0), ground + Vector3(0, 2.65, 0), canopy_color)
		for side in [-1.0, 1.0]:
			_add_visual_box_to_region("PiedEtal", Vector3(0.16, 2.5, 0.16), ground + Vector3(side * 2.1, 1.25, 0), Color(0.20, 0.105, 0.04))
	var crate_positions: Array[Vector3] = []
	for local in [Vector2(-22, 14), Vector2(-19, 15), Vector2(21, 15), Vector2(24, 14), Vector2(-6, 28), Vector2(5, 29), Vector2(0, 34), Vector2(8, 35)]:
		crate_positions.append(_terrain_position(zone_index, local, 0.42))
	var crate_mesh := BoxMesh.new()
	crate_mesh.size = Vector3(1.15, 0.82, 1.0)
	crate_mesh.material = _simple_material(Color(0.38, 0.20, 0.065))
	_create_multimesh("CaissesMarcheV6", crate_positions, crate_mesh, Vector3.ONE, Vector3.ZERO)
	_add_shoreline_foam(zone_index, Vector2(0, -55), Vector2(118, 9))


func _add_forest_floor_details(zone_index: int) -> void:
	var positions: Array[Vector3] = []
	for x in range(-54, 55, 9):
		for z in range(-48, 49, 10):
			if abs(x) < 12 and abs(z) < 18:
				continue
			positions.append(_terrain_position(zone_index, Vector2(x, z), 0.18))
	var bush := SphereMesh.new()
	bush.radius = 0.42
	bush.height = 0.58
	bush.radial_segments = 6
	bush.rings = 3
	bush.material = _simple_material(Color(0.08, 0.32, 0.10))
	_create_multimesh("SousBoisV6", positions, bush, Vector3(1.25, 0.72, 1.10), Vector3.ZERO)


func _add_mountain_ledge_details(zone_index: int) -> void:
	for ledge_index in range(7):
		var local := Vector2(-44.0 + float(ledge_index) * 14.0, -30.0 + float(ledge_index % 3) * 24.0)
		var position := _terrain_position(zone_index, local, 0.7)
		_add_visual_box_to_region("Corniche_%02d" % ledge_index, Vector3(11.0, 1.4, 4.0), position, Color(0.29, 0.28, 0.27))


func _add_crop_rows(zone_index: int) -> void:
	var crop_positions: Array[Vector3] = []
	for field_x in [-44.0, -15.0, 15.0, 44.0]:
		for row in range(7):
			for plant in range(10):
				var local := Vector2(field_x - 9.0 + float(plant) * 2.0, -42.0 + float(row) * 4.1)
				crop_positions.append(_terrain_position(zone_index, local, 0.45))
	var crop_mesh := BoxMesh.new()
	crop_mesh.size = Vector3(0.24, 0.88, 0.24)
	crop_mesh.material = _simple_material(Color(0.75, 0.62, 0.12))
	_create_multimesh("CulturesV6", crop_positions, crop_mesh, Vector3.ONE, Vector3.ZERO)


func _add_obsidian_spires(zone_index: int) -> void:
	var positions: Array[Vector3] = []
	for local in [Vector2(-48, -30), Vector2(-32, 38), Vector2(-12, -48), Vector2(18, 44), Vector2(42, -34), Vector2(50, 18), Vector2(-52, 12), Vector2(30, 10)]:
		positions.append(_terrain_position(zone_index, local, 2.0))
	var mesh := PrismMesh.new()
	mesh.size = Vector3(1.4, 4.2, 1.4)
	mesh.material = _simple_material(Color(0.035, 0.032, 0.040), Color(0.15, 0.025, 0.01))
	_create_multimesh("ObsidiennesV6", positions, mesh, Vector3.ONE, Vector3.ZERO)


func _add_marsh_reeds(zone_index: int) -> void:
	var positions: Array[Vector3] = []
	for anchor in [Vector2(-48, -38), Vector2(-20, -46), Vector2(20, -44), Vector2(48, -35), Vector2(-52, 24), Vector2(52, 28), Vector2(-28, 46), Vector2(28, 48)]:
		for offset in CLUSTER_OFFSETS:
			positions.append(_terrain_position(zone_index, anchor + offset * 0.42, 0.62))
	var reed := CylinderMesh.new()
	reed.top_radius = 0.035
	reed.bottom_radius = 0.055
	reed.height = 1.35
	reed.radial_segments = 5
	reed.material = _simple_material(Color(0.30, 0.42, 0.12))
	_create_multimesh("RoseauxV6", positions, reed, Vector3.ONE, Vector3.ZERO)


func _add_ash_ribs(zone_index: int) -> void:
	for rib_index in range(8):
		var local := Vector2(-45.0 + float(rib_index) * 13.0, 30.0 + sin(float(rib_index)) * 8.0)
		var position := _terrain_position(zone_index, local, 2.4)
		var rib := _add_visual_box_to_region("CoteSquelette_%02d" % rib_index, Vector3(0.45, 5.0, 0.55), position, Color(0.72, 0.68, 0.57))
		rib.rotation.z = -0.72 + float(rib_index % 3) * 0.18


func _add_port_cargo(zone_index: int) -> void:
	var cargo_positions: Array[Vector3] = []
	for row in range(4):
		for column in range(8):
			var local := Vector2(-42.0 + float(column) * 12.0, 24.0 + float(row) * 6.0)
			cargo_positions.append(_terrain_position(zone_index, local, 0.75))
	var cargo := BoxMesh.new()
	cargo.size = Vector3(2.4, 1.5, 1.8)
	cargo.material = _simple_material(Color(0.34, 0.17, 0.055))
	_create_multimesh("CargaisonsV6", cargo_positions, cargo, Vector3.ONE, Vector3.ZERO)


func _add_ruin_fragments(zone_index: int) -> void:
	var positions: Array[Vector3] = []
	for local in [Vector2(-48, -36), Vector2(-33, 42), Vector2(-14, -50), Vector2(12, 48), Vector2(34, -42), Vector2(50, 32), Vector2(-52, 8), Vector2(54, -4), Vector2(28, 12), Vector2(-26, -8)]:
		positions.append(_terrain_position(zone_index, local, 0.38))
	var fragment := BoxMesh.new()
	fragment.size = Vector3(2.6, 0.75, 1.4)
	fragment.material = _simple_material(Color(0.53, 0.45, 0.31))
	_create_multimesh("FragmentsRuinesV6", positions, fragment, Vector3.ONE, Vector3.ZERO)


func _add_snow_pines(zone_index: int) -> void:
	var snow_positions: Array[Vector3] = []
	for local in [Vector2(-56, -28), Vector2(-44, 18), Vector2(-22, 46), Vector2(18, 48), Vector2(44, 20), Vector2(56, -24), Vector2(-8, -48), Vector2(28, -42)]:
		snow_positions.append(_terrain_position(zone_index, local, 0.8))
	var snow_bank := SphereMesh.new()
	snow_bank.radius = 1.6
	snow_bank.height = 0.72
	snow_bank.radial_segments = 8
	snow_bank.rings = 4
	snow_bank.material = _simple_material(Color(0.90, 0.95, 0.98))
	_create_multimesh("CongeresV6", snow_positions, snow_bank, Vector3(1.8, 0.52, 1.2), Vector3.ZERO)


func _add_shoreline_foam(zone_index: int, local_center: Vector2, size_value: Vector2) -> void:
	var position := _terrain_position(zone_index, local_center, 0.20)
	var foam := MeshInstance3D.new()
	foam.name = "EcumeRivageV6"
	var plane := PlaneMesh.new()
	plane.size = size_value
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.82, 0.96, 1.0, 0.48)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	plane.material = material
	foam.mesh = plane
	foam.position = Vector3(position.x, -0.72, position.z)
	foam.visibility_range_end = V6_DETAIL_VISIBILITY
	active_build_parent.add_child(foam)
	v6_authored_detail_instances += 1


func _add_region_atmosphere(zone_index: int) -> void:
	if zone_index not in [1, 4, 5, 6, 9]:
		return
	var particles := GPUParticles3D.new()
	particles.name = "AtmosphereV6_%02d" % (zone_index + 1)
	particles.amount = 110 if zone_index in [5, 6, 9] else 72
	particles.lifetime = 7.0 if zone_index in [1, 5] else 4.5
	particles.visibility_aabb = AABB(Vector3(-76, -5, -68), Vector3(152, 42, 136))
	particles.emitting = true
	particles.position = ZONE_CENTERS[zone_index] + Vector3(0, 14, 0)
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(68, 12, 60)
	process.direction = Vector3(0.25, -0.45, 0.10)
	process.spread = 28.0
	process.initial_velocity_min = 0.25
	process.initial_velocity_max = 1.1
	process.gravity = Vector3(0.08, -0.18, 0.03)
	particles.process_material = process
	var quad := QuadMesh.new()
	quad.size = Vector2(0.22, 0.22)
	var material := StandardMaterial3D.new()
	var particle_color := Color(0.78, 0.90, 0.62, 0.22)
	if zone_index == 4:
		particle_color = Color(0.20, 0.17, 0.15, 0.42)
	elif zone_index == 5:
		particle_color = Color(0.68, 0.78, 0.72, 0.16)
		quad.size = Vector2(2.8, 1.4)
	elif zone_index == 6:
		particle_color = Color(0.42, 0.39, 0.36, 0.38)
	elif zone_index == 9:
		particle_color = Color(0.94, 0.98, 1.0, 0.72)
	material.albedo_color = particle_color
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	quad.material = material
	particles.draw_pass_1 = quad
	active_build_parent.add_child(particles)
	v6_atmosphere_count += 1


func _terrain_position(zone_index: int, local: Vector2, y_offset: float) -> Vector3:
	var center: Vector3 = ZONE_CENTERS[zone_index]
	var world_x := center.x + local.x
	var world_z := center.z + local.y
	return Vector3(world_x, _terrain_world_height(zone_index, world_x, world_z) + y_offset, world_z)


func _create_multimesh(node_name: String, positions: Array[Vector3], mesh: Mesh, scale_value: Vector3, extra_offset: Vector3) -> MultiMeshInstance3D:
	var instance := MultiMeshInstance3D.new()
	instance.name = node_name
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = positions.size()
	for index in range(positions.size()):
		var angle := float((index * 37) % 360) * PI / 180.0
		var local_scale := scale_value * (0.86 + float(index % 5) * 0.065)
		var basis := Basis(Vector3.UP, angle).scaled(local_scale)
		multimesh.set_instance_transform(index, Transform3D(basis, positions[index] + extra_offset))
	instance.multimesh = multimesh
	instance.visibility_range_end = V6_DETAIL_VISIBILITY
	instance.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	active_build_parent.add_child(instance)
	v6_authored_detail_instances += positions.size()
	return instance


func _add_visual_box_to_region(node_name: String, size_value: Vector3, position: Vector3, color: Color) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size_value
	mesh.material = _simple_material(color)
	mesh_instance.mesh = mesh
	mesh_instance.position = position
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	mesh_instance.visibility_range_end = V6_DETAIL_VISIBILITY
	active_build_parent.add_child(mesh_instance)
	v6_authored_detail_instances += 1
	return mesh_instance


func _bridge_material(base_color: Color) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
uniform vec4 bois : source_color;
void fragment() {
	float planches = step(0.82, fract(UV.y * 34.0));
	float fibres = sin(UV.x * 95.0 + sin(UV.y * 27.0) * 1.4) * 0.045;
	vec3 couleur = bois.rgb * (0.86 + fibres) - planches * vec3(0.16, 0.11, 0.06);
	ALBEDO = couleur;
	ROUGHNESS = 0.90;
}
"""
	material.shader = shader
	material.set_shader_parameter("bois", base_color.darkened(0.04))
	return material


func _simple_material(color: Color, emission: Color = Color(0, 0, 0, 1)) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.84
	if emission.r > 0.001 or emission.g > 0.001 or emission.b > 0.001:
		material.emission_enabled = true
		material.emission = emission
		material.emission_energy_multiplier = 1.6
	return material


func _compact_mobile_hud() -> void:
	if is_instance_valid(zone_label):
		var top_bar := zone_label.get_parent() as Control
		if is_instance_valid(top_bar):
			top_bar.offset_bottom = 72.0
		zone_label.position = Vector2(16, 5)
		zone_label.size = Vector2(500, 31)
		zone_label.add_theme_font_size_override("font_size", 20)
	if is_instance_valid(health_label):
		health_label.position = Vector2(16, 38)
		health_label.add_theme_font_size_override("font_size", 16)
	if is_instance_valid(objective_label):
		objective_label.position = Vector2(-510, 5)
		objective_label.size = Vector2(365, 58)
		objective_label.add_theme_font_size_override("font_size", 15)
	if is_instance_valid(map_button):
		map_button.position = Vector2(-126, 7)
		map_button.size = Vector2(112, 56)
		map_button.add_theme_font_size_override("font_size", 14)
	if is_instance_valid(message_label):
		message_label.position = Vector2(-360, 72)
		message_label.size = Vector2(720, 44)
		message_label.add_theme_font_size_override("font_size", 19)
	if is_instance_valid(zone_banner):
		zone_banner.position = Vector2(-360, -72)
		zone_banner.size = Vector2(720, 72)
		zone_banner.add_theme_font_size_override("font_size", 27)
	if is_instance_valid(mini_map_frame):
		var mini_panel := mini_map_frame.get_parent() as Control
		if is_instance_valid(mini_panel):
			mini_panel.position = Vector2(10, 86)
			mini_panel.scale = Vector2(0.72, 0.72)
	if is_instance_valid(controls_help_label):
		controls_help_label.visible = false
	if is_instance_valid(adventure_inventory_button):
		adventure_inventory_button.position = Vector2(14, 246)
		adventure_inventory_button.size = Vector2(108, 36)
		adventure_inventory_button.add_theme_font_size_override("font_size", 12)
	if is_instance_valid(adventure_journal_button):
		adventure_journal_button.position = Vector2(126, 246)
		adventure_journal_button.size = Vector2(108, 36)
		adventure_journal_button.add_theme_font_size_override("font_size", 12)
	var portrait_title := _find_text_control(self, "CHEIKH")
	if is_instance_valid(portrait_title):
		var portrait_panel := portrait_title.get_parent() as Control
		if is_instance_valid(portrait_panel):
			portrait_panel.position = Vector2(-128, 86)
			portrait_panel.scale = Vector2(0.72, 0.72)
	var pause_button := _find_button_prefix(self, "PAUSE")
	if is_instance_valid(pause_button):
		pause_button.position = Vector2(14, 286)
		pause_button.size = Vector2(220, 38)
		pause_button.add_theme_font_size_override("font_size", 12)
	for button_text in ["SAUT", "ATTAQUE", "ESQUIVE", "ACTION", "PLONGER"]:
		var action_button := _find_button_prefix(self, button_text)
		if is_instance_valid(action_button):
			action_button.modulate.a = 0.84
			action_button.add_theme_font_size_override("font_size", 14)
	v6_hud_compacted = true


func _finalize_v6_camera() -> void:
	if not is_instance_valid(player):
		return
	var pivot := player.get_node_or_null("CameraPivot") as Node3D
	var arm := player.get_node_or_null("CameraPivot/SpringArm") as SpringArm3D
	var camera := player.get_node_or_null("CameraPivot/SpringArm/Camera") as Camera3D
	if is_instance_valid(pivot):
		pivot.position.y = 1.72
		pivot.rotation.y = PI
	if is_instance_valid(arm):
		arm.spring_length = V6_CAMERA_DISTANCE
		arm.margin = 0.28
	if is_instance_valid(camera):
		camera.fov = 62.0
		camera.near = 0.08
	v6_camera_upgraded = is_instance_valid(arm) and arm.spring_length >= 8.0


func _find_text_control(root: Node, exact_text: String) -> Control:
	for child in root.get_children():
		if child is Label and String(child.text) == exact_text:
			return child
		var nested := _find_text_control(child, exact_text)
		if is_instance_valid(nested):
			return nested
	return null


func _find_button_prefix(root: Node, prefix: String) -> Button:
	for child in root.get_children():
		if child is Button and String(child.text).begins_with(prefix):
			return child
		var nested := _find_button_prefix(child, prefix)
		if is_instance_valid(nested):
			return nested
	return null
