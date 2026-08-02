extends "res://scripts/main_expansion_v8.gd"

const SNOW_SUMMIT_HEIGHT := 28.0


func _relocate_zone_node(
	node: Node3D,
	source_center: Vector3,
	destination_center: Vector3
) -> void:
	super._relocate_zone_node(node, source_center, destination_center)
	if destination_center == REGION_CENTERS[9]:
		node.position.y += SNOW_SUMMIT_HEIGHT


func _expanded_height(
	region_index: int,
	world_x: float,
	world_z: float
) -> float:
	var height := super._expanded_height(region_index, world_x, world_z)
	if region_index == 9:
		height += SNOW_SUMMIT_HEIGHT
	return height


func _build_portals() -> void:
	capital_portal_position = REGION_CENTERS[8] + Vector3(0.0, 2.0, 0.0)
	sky_portal_position = REGION_CENTERS[9] + Vector3(0.0, SNOW_SUMMIT_HEIGHT + 2.0, 0.0)
	_add_portal_marker("PortailSommet", capital_portal_position, Color(0.95, 0.72, 0.20))
	_add_portal_marker("PortailRetour", sky_portal_position, Color(0.58, 0.90, 1.0))


func _add_portal_marker(node_name: String, position_value: Vector3, color: Color) -> void:
	var marker := MeshInstance3D.new()
	marker.name = node_name
	var mesh := CylinderMesh.new()
	mesh.top_radius = 1.45
	mesh.bottom_radius = 1.45
	mesh.height = 0.25
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color * 2.0
	mesh.material = material
	marker.mesh = mesh
	marker.position = position_value
	add_child(marker)


func _on_interact() -> void:
	if is_instance_valid(player):
		if player.global_position.distance_to(capital_portal_position) <= 3.5:
			player.global_position = sky_portal_position + Vector3(0.0, 1.0, 4.0)
			player.velocity = Vector3.ZERO
			player.set_spawn(player.global_position)
			current_zone = 9
			_show_message("Portail activé : Sommet enneigé.", 3.0)
			_show_zone_banner()
			return

		if player.global_position.distance_to(sky_portal_position) <= 3.5:
			player.global_position = capital_portal_position + Vector3(0.0, 1.0, 4.0)
			player.velocity = Vector3.ZERO
			player.set_spawn(player.global_position)
			current_zone = 8
			_show_message("Retour aux Ruines anciennes.", 3.0)
			_show_zone_banner()
			return

	super._on_interact()
