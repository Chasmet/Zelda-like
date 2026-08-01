extends "res://scripts/main_coastal_presentation_v7.gd"

# V8 : correction des deux régressions critiques constatées sur téléphone.
# - les bords de terrain sont désormais réellement sous le niveau de l'océan ;
# - le panneau chevalier / CHK HERO est ancré explicitement dans l'écran.

const V8_VERSION: String = "0.8.0-eau-et-portrait"
const OCEAN_LEVEL_V8: float = -0.92
const DEEP_SEABED_V8: float = -6.4

var v8_water_material_applied: bool = false
var v8_coastline_rebuilt: bool = false
var v8_portrait_restored: bool = false
var v8_water_label_centered: bool = false
var v8_health_bar: ProgressBar
var v8_portrait_panel: Control
var v8_portrait_texture: TextureRect


func _build_environment() -> void:
	super._build_environment()
	_apply_ocean_material_v8()


func _build_zone(zone_index) -> void:
	super._build_zone(zone_index)
	if int(zone_index) != 0:
		return
	active_build_parent = zone_roots[0]
	_add_shore_foam_v8()
	_add_coastal_rocks_v8()
	active_build_parent = null
	v8_coastline_rebuilt = true


func _zone_height(zone_index, local_x, local_z):
	var region_index: int = int(zone_index)
	var x_value: float = float(local_x)
	var z_value: float = float(local_z)
	var nx: float = x_value / (TERRAIN_SIZE.x * 0.5)
	var nz: float = z_value / (TERRAIN_SIZE.y * 0.5)
	var edge: float = maxf(absf(nx), absf(nz))

	# Le village côtier possède une vraie plage en pente, puis un fond marin.
	# L'ancienne hauteur de bord (-0,72 m) était au-dessus de l'océan (-0,92 m),
	# ce qui créait un sol invisible juste sous les vagues et donnait l'impression
	# que CHK Hero marchait directement sur l'eau.
	if region_index == 0:
		var relief: float = 1.20
		relief += maxf(0.0, -nz) * 1.55
		relief += sin(nx * 7.0) * 0.16 + cos(nz * 8.0) * 0.12

		if z_value > 38.0 and z_value <= 49.0:
			var beach_t: float = smoothstep(38.0, 49.0, z_value)
			relief = lerpf(relief, -0.54, beach_t)
		elif z_value > 49.0 and z_value <= 57.0:
			var shelf_t: float = smoothstep(49.0, 57.0, z_value)
			relief = lerpf(-0.54, -1.85, shelf_t)
		elif z_value > 57.0:
			var sea_t: float = smoothstep(57.0, TERRAIN_SIZE.y * 0.5, z_value)
			relief = lerpf(-1.85, DEEP_SEABED_V8, sea_t)

		var side_sink: float = smoothstep(0.80, 1.0, absf(nx))
		relief = lerpf(relief, DEEP_SEABED_V8, side_sink)
		var north_sink: float = smoothstep(0.88, 1.0, -nz)
		relief = lerpf(relief, -4.8, north_sink)
		return relief

	# Toutes les autres régions deviennent de vraies îles. Le terrain reste
	# collisionnable sous l'eau pour la plongée, mais plus aucun bord ne forme
	# une passerelle invisible à la surface.
	var inherited_height: float = float(super._zone_height(region_index, x_value, z_value))
	var edge_sink: float = smoothstep(0.82, 1.0, edge)
	return lerpf(inherited_height, DEEP_SEABED_V8, edge_sink)


func _build_beach_v7() -> void:
	var sand_color: Color = Color(0.78, 0.64, 0.39)
	for row_index in range(3):
		var z_value: float = 39.5 + float(row_index) * 4.0
		for column_index in range(10):
			var x_value: float = -50.0 + float(column_index) * 11.0
			var tile_position: Vector3 = _terrain_position_v6(0, Vector2(x_value, z_value), 0.07)
			_add_box_v6(
				"SablePlageV8_%02d_%02d" % [row_index, column_index],
				Vector3(11.4, 0.10, 4.5),
				tile_position,
				sand_color.lightened(float((column_index + row_index) % 3) * 0.035)
			)
			v7_beach_detail_count += 1

	var shell_positions: Array[Vector3] = []
	for shell_index in range(42):
		var shell_x: float = -50.0 + float(shell_index % 14) * 7.7
		var shell_z: float = 41.0 + float(shell_index / 14) * 3.8 + sin(float(shell_index) * 1.35) * 0.75
		shell_positions.append(_terrain_position_v6(0, Vector2(shell_x, shell_z), 0.20))
	var shell_mesh: SphereMesh = SphereMesh.new()
	shell_mesh.radius = 0.20
	shell_mesh.height = 0.12
	shell_mesh.radial_segments = 7
	shell_mesh.rings = 3
	shell_mesh.material = _standard_material_v6(Color(0.94, 0.84, 0.70))
	_create_multimesh_v6("CoquillagesPlageV8", shell_positions, shell_mesh, Vector3.ONE, Vector3.ZERO)
	v7_beach_detail_count += shell_positions.size()

	var palm_positions := [Vector2(-48, 35), Vector2(-35, 38), Vector2(35, 38), Vector2(48, 34)]
	for palm_index in range(palm_positions.size()):
		_add_palm_v8(palm_positions[palm_index], palm_index)


func _spawn_player() -> void:
	super._spawn_player()
	if is_instance_valid(player):
		player.water_level = OCEAN_LEVEL_V8


func _build_hud() -> void:
	super._build_hud()
	call_deferred("_restore_critical_hud_v8")


func _finish_loading() -> void:
	super._finish_loading()
	call_deferred("_restore_critical_hud_v8")


func _process(delta: float) -> void:
	super._process(delta)
	if is_instance_valid(v8_health_bar) and is_instance_valid(player):
		v8_health_bar.max_value = float(player.max_health)
		v8_health_bar.value = float(player.health)
	if is_instance_valid(portrait_model):
		portrait_model.rotation.y = PI + sin(Time.get_ticks_msec() * 0.0007) * 0.10


func get_critical_bugfix_debug() -> Dictionary:
	var portrait_rect: Rect2 = Rect2()
	if is_instance_valid(v8_portrait_panel):
		portrait_rect = v8_portrait_panel.get_global_rect()
	return {
		"version": V8_VERSION,
		"water_material": v8_water_material_applied,
		"coastline_rebuilt": v8_coastline_rebuilt,
		"portrait_restored": v8_portrait_restored,
		"water_label_centered": v8_water_label_centered,
		"portrait_rect": portrait_rect,
		"ocean_level": OCEAN_LEVEL_V8,
		"land_sample": _zone_height(0, 24.0, 10.0),
		"beach_sample": _zone_height(0, 0.0, 46.0),
		"shore_sample": _zone_height(0, 0.0, 53.0),
		"deep_sample": _zone_height(0, 0.0, 66.0),
		"player_water_level": float(player.water_level) if is_instance_valid(player) else 999.0
	}


func _apply_ocean_material_v8() -> void:
	if not is_instance_valid(ocean_surface):
		return
	var material: ShaderMaterial = ShaderMaterial.new()
	var shader: Shader = Shader.new()
	shader.code = """
shader_type spatial;
render_mode blend_mix, depth_prepass_alpha, cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform vec4 eau_cotiere : source_color = vec4(0.025, 0.34, 0.46, 0.72);
uniform vec4 eau_profonde : source_color = vec4(0.005, 0.055, 0.14, 0.86);
uniform vec4 ecume : source_color = vec4(0.82, 0.95, 1.0, 1.0);
uniform float amplitude = 0.105;
varying float vague;

void vertex() {
	float v1 = sin(VERTEX.x * 0.047 + TIME * 0.72);
	float v2 = cos(VERTEX.z * 0.063 - TIME * 0.54);
	float v3 = sin((VERTEX.x + VERTEX.z) * 0.13 + TIME * 1.05);
	vague = v1 * 0.58 + v2 * 0.30 + v3 * 0.12;
	VERTEX.y += vague * amplitude;
}

void fragment() {
	float rides = sin(UV.x * 150.0 + TIME * 1.15) * cos(UV.y * 118.0 - TIME * 0.86);
	float fresnel = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 3.0);
	float profondeur_visuelle = clamp(0.36 + fresnel * 0.58 + rides * 0.025, 0.0, 1.0);
	vec3 couleur = mix(eau_cotiere.rgb, eau_profonde.rgb, profondeur_visuelle);
	float mousse = smoothstep(0.72, 0.96, vague + rides * 0.10);
	ALBEDO = mix(couleur, ecume.rgb, mousse * 0.24);
	ROUGHNESS = mix(0.18, 0.07, fresnel);
	METALLIC = 0.05;
	SPECULAR = 0.88;
	EMISSION = ecume.rgb * mousse * 0.035;
	ALPHA = mix(eau_cotiere.a, eau_profonde.a, fresnel);
}
"""
	material.shader = shader
	ocean_surface.material_override = material
	ocean_surface.position.y = OCEAN_LEVEL_V8
	v8_water_material_applied = true


func _add_shore_foam_v8() -> void:
	var foam_positions: Array[Vector3] = []
	for foam_index in range(38):
		var x_value: float = -55.0 + float(foam_index) * 3.0
		var z_value: float = 50.8 + sin(float(foam_index) * 0.62) * 0.7
		foam_positions.append(Vector3(ZONE_CENTERS[0].x + x_value, OCEAN_LEVEL_V8 + 0.055, ZONE_CENTERS[0].z + z_value))
	var foam_mesh: QuadMesh = QuadMesh.new()
	foam_mesh.size = Vector2(3.8, 0.72)
	foam_mesh.orientation = PlaneMesh.FACE_Y
	var foam_material: StandardMaterial3D = StandardMaterial3D.new()
	foam_material.albedo_color = Color(0.86, 0.97, 1.0, 0.46)
	foam_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	foam_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	foam_mesh.material = foam_material
	_create_multimesh_v6("EcumeRivageV8", foam_positions, foam_mesh, Vector3.ONE, Vector3.ZERO)


func _add_coastal_rocks_v8() -> void:
	for rock_index in range(18):
		var side: float = -1.0 if rock_index % 2 == 0 else 1.0
		var local_x: float = side * (56.0 + float(rock_index % 4) * 3.0)
		var local_z: float = -42.0 + float(rock_index) * 5.1
		var position: Vector3 = _terrain_position_v6(0, Vector2(local_x, local_z), 0.8)
		var rock: MeshInstance3D = _add_box_v6(
			"RocherCoteV8_%02d" % rock_index,
			Vector3(2.2 + float(rock_index % 3), 1.6 + float(rock_index % 4) * 0.5, 2.0),
			position,
			Color(0.31, 0.32, 0.30)
		)
		rock.rotation = Vector3(0.08 * float(rock_index % 3), 0.37 * float(rock_index), 0.05 * float(rock_index % 2))


func _add_palm_v8(local_position: Vector2, palm_index: int) -> void:
	var ground: Vector3 = _terrain_position_v6(0, local_position, 0.0)
	var trunk: MeshInstance3D = MeshInstance3D.new()
	trunk.name = "PalmierV8_%02d" % palm_index
	var trunk_mesh: CylinderMesh = CylinderMesh.new()
	trunk_mesh.top_radius = 0.18
	trunk_mesh.bottom_radius = 0.34
	trunk_mesh.height = 5.2
	trunk_mesh.radial_segments = 8
	trunk_mesh.material = _standard_material_v6(Color(0.28, 0.14, 0.045))
	trunk.mesh = trunk_mesh
	trunk.position = ground + Vector3(0.0, 2.6, 0.0)
	active_build_parent.add_child(trunk)
	for leaf_index in range(7):
		var leaf: MeshInstance3D = _make_box_mesh_v7(Vector3(0.30, 0.10, 3.4), Color(0.07, 0.40, 0.16))
		leaf.position = ground + Vector3(0.0, 5.35, 0.0)
		leaf.rotation.y = float(leaf_index) * TAU / 7.0
		leaf.rotation.x = -0.27
		active_build_parent.add_child(leaf)
	v7_beach_detail_count += 8


func _restore_critical_hud_v8() -> void:
	await get_tree().process_frame
	if is_instance_valid(hero_status_label):
		v8_portrait_panel = hero_status_label.get_parent() as Control
	if is_instance_valid(v8_portrait_panel):
		v8_portrait_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		v8_portrait_panel.offset_left = -180.0
		v8_portrait_panel.offset_right = -12.0
		v8_portrait_panel.offset_top = 82.0
		v8_portrait_panel.offset_bottom = 354.0
		v8_portrait_panel.scale = Vector2.ONE
		v8_portrait_panel.visible = true
		v8_portrait_panel.z_index = 90
		v8_portrait_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hero_status_label.text = "CHK HERO"
		hero_status_label.visible = true

		for child in v8_portrait_panel.get_children():
			if child is TextureRect:
				v8_portrait_texture = child as TextureRect
				v8_portrait_texture.visible = true
				v8_portrait_texture.modulate = Color.WHITE
				v8_portrait_texture.position = Vector2(8.0, 34.0)
				v8_portrait_texture.size = Vector2(152.0, 184.0)
				v8_portrait_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

		if is_instance_valid(portrait_viewport) and is_instance_valid(portrait_model) and is_instance_valid(v8_portrait_texture):
			portrait_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
			v8_portrait_texture.texture = portrait_viewport.get_texture()

		if not is_instance_valid(v8_health_bar):
			v8_health_bar = ProgressBar.new()
			v8_health_bar.name = "VieCHKHeroV8"
			v8_health_bar.position = Vector2(10.0, 246.0)
			v8_health_bar.size = Vector2(148.0, 15.0)
			v8_health_bar.show_percentage = false
			v8_health_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
			v8_portrait_panel.add_child(v8_health_bar)
		v8_portrait_restored = true

	if is_instance_valid(water_depth_label):
		water_depth_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
		water_depth_label.offset_left = -280.0
		water_depth_label.offset_right = 280.0
		water_depth_label.offset_top = -116.0
		water_depth_label.offset_bottom = -68.0
		water_depth_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		water_depth_label.clip_text = false
		v8_water_label_centered = water_depth_label.offset_left < 0.0 and water_depth_label.offset_right > 0.0

	if is_instance_valid(message_label):
		message_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
		message_label.offset_left = -340.0
		message_label.offset_right = 340.0
		message_label.offset_top = 78.0
		message_label.offset_bottom = 124.0
		message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		message_label.clip_text = false
