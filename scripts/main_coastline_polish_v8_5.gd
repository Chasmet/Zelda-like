extends "res://scripts/main_spawn_safety_v8_4.gd"

# V8.5 : la plage précédente était composée de grandes plaques rectangulaires.
# Elle ressemblait à une plateforme artificielle. Le nouveau maillage suit
# précisément la hauteur du terrain et conserve une pente naturelle vers l'eau.

const V85_VERSION: String = "0.8.5-littoral-conforme"
var conforming_beach_ready: bool = false
var conforming_beach_vertices: int = 0


func _build_beach_v7() -> void:
	var beach_mesh_instance := MeshInstance3D.new()
	beach_mesh_instance.name = "PlageConformeV85"
	beach_mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	beach_mesh_instance.visibility_range_end = V6_DETAIL_VISIBILITY

	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var beach_material := StandardMaterial3D.new()
	beach_material.albedo_color = Color(0.80, 0.67, 0.42)
	beach_material.roughness = 0.96
	surface.set_material(beach_material)

	var x_segments: int = 28
	var z_segments: int = 8
	var x_min: float = -56.0
	var x_max: float = 56.0
	var z_min: float = 37.0
	var z_max: float = 52.0
	for z_index in range(z_segments):
		var z0: float = lerpf(z_min, z_max, float(z_index) / float(z_segments))
		var z1: float = lerpf(z_min, z_max, float(z_index + 1) / float(z_segments))
		for x_index in range(x_segments):
			var x0: float = lerpf(x_min, x_max, float(x_index) / float(x_segments))
			var x1: float = lerpf(x_min, x_max, float(x_index + 1) / float(x_segments))
			var p00: Vector3 = _terrain_position_v6(0, Vector2(x0, z0), 0.055)
			var p10: Vector3 = _terrain_position_v6(0, Vector2(x1, z0), 0.055)
			var p01: Vector3 = _terrain_position_v6(0, Vector2(x0, z1), 0.055)
			var p11: Vector3 = _terrain_position_v6(0, Vector2(x1, z1), 0.055)
			var uv00 := Vector2(float(x_index) / 6.0, float(z_index) / 3.0)
			var uv10 := Vector2(float(x_index + 1) / 6.0, float(z_index) / 3.0)
			var uv01 := Vector2(float(x_index) / 6.0, float(z_index + 1) / 3.0)
			var uv11 := Vector2(float(x_index + 1) / 6.0, float(z_index + 1) / 3.0)
			_add_beach_triangle_v85(surface, p00, p10, p11, uv00, uv10, uv11)
			_add_beach_triangle_v85(surface, p00, p11, p01, uv00, uv11, uv01)
			conforming_beach_vertices += 6
	surface.generate_normals()
	beach_mesh_instance.mesh = surface.commit()
	active_build_parent.add_child(beach_mesh_instance)

	# Bande de sable humide au bord de l'eau. Elle suit elle aussi le relief et
	# évite une rupture nette entre le sable sec et les vagues.
	var wet_strip := MeshInstance3D.new()
	wet_strip.name = "SableHumideV85"
	wet_strip.visibility_range_end = V6_DETAIL_VISIBILITY
	var wet_surface := SurfaceTool.new()
	wet_surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var wet_material := StandardMaterial3D.new()
	wet_material.albedo_color = Color(0.51, 0.43, 0.31)
	wet_material.roughness = 0.74
	wet_material.metallic = 0.02
	wet_surface.set_material(wet_material)
	for x_index in range(x_segments):
		var x0: float = lerpf(x_min, x_max, float(x_index) / float(x_segments))
		var x1: float = lerpf(x_min, x_max, float(x_index + 1) / float(x_segments))
		var z0: float = 49.2 + sin(float(x_index) * 0.63) * 0.35
		var z1: float = 52.0 + sin(float(x_index + 1) * 0.63) * 0.35
		var p00: Vector3 = _terrain_position_v6(0, Vector2(x0, z0), 0.072)
		var p10: Vector3 = _terrain_position_v6(0, Vector2(x1, z0), 0.072)
		var p01: Vector3 = _terrain_position_v6(0, Vector2(x0, z1), 0.072)
		var p11: Vector3 = _terrain_position_v6(0, Vector2(x1, z1), 0.072)
		_add_beach_triangle_v85(wet_surface, p00, p10, p11, Vector2.ZERO, Vector2.RIGHT, Vector2.ONE)
		_add_beach_triangle_v85(wet_surface, p00, p11, p01, Vector2.ZERO, Vector2.ONE, Vector2.DOWN)
		conforming_beach_vertices += 6
	wet_surface.generate_normals()
	wet_strip.mesh = wet_surface.commit()
	active_build_parent.add_child(wet_strip)

	var shell_positions: Array[Vector3] = []
	for shell_index in range(44):
		var shell_x: float = -51.0 + float(shell_index % 15) * 7.2
		var shell_z: float = 42.0 + float(shell_index / 15) * 3.1 + sin(float(shell_index) * 1.31) * 0.65
		shell_positions.append(_terrain_position_v6(0, Vector2(shell_x, shell_z), 0.18))
	var shell_mesh := SphereMesh.new()
	shell_mesh.radius = 0.18
	shell_mesh.height = 0.11
	shell_mesh.radial_segments = 7
	shell_mesh.rings = 3
	shell_mesh.material = _standard_material_v6(Color(0.94, 0.85, 0.72))
	_create_multimesh_v6("CoquillagesPlageV85", shell_positions, shell_mesh, Vector3.ONE, Vector3.ZERO)

	var palm_positions := [Vector2(-48, 35), Vector2(-35, 38), Vector2(35, 38), Vector2(48, 34)]
	for palm_index in range(palm_positions.size()):
		_add_palm_v8(palm_positions[palm_index], palm_index)

	v7_beach_detail_count += shell_positions.size() + palm_positions.size() * 8 + 2
	conforming_beach_ready = is_instance_valid(beach_mesh_instance.mesh) and conforming_beach_vertices >= 1500


func _add_beach_triangle_v85(surface: SurfaceTool, first: Vector3, second: Vector3, third: Vector3, first_uv: Vector2, second_uv: Vector2, third_uv: Vector2) -> void:
	surface.set_uv(first_uv)
	surface.add_vertex(first)
	surface.set_uv(second_uv)
	surface.add_vertex(second)
	surface.set_uv(third_uv)
	surface.add_vertex(third)


func get_coastline_polish_debug() -> Dictionary:
	return {
		"version": V85_VERSION,
		"conforming_beach": conforming_beach_ready,
		"beach_vertices": conforming_beach_vertices
	}
