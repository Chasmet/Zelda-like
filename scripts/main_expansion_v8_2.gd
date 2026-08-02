extends "res://scripts/main_expansion_v8.gd"

const SNOW_SUMMIT_HEIGHT := 28.0


func _wait_for_blender_placeholder_swap(_placeholder: Variant = null) -> void:
	# Compatibilité avec la couche mobile historique : le modèle généré par
	# Blender est déjà appliqué au spawn. Le paramètre optionnel accepte aussi
	# l'ancienne signature interne sans casser les appels sans argument.
	await get_tree().process_frame
	await get_tree().process_frame

	if not is_instance_valid(player):
		return

	var visual: Node = player.get_node_or_null("Visual")
	var imported_model: Node = null
	if is_instance_valid(visual):
		imported_model = visual.get_node_or_null("ImportedHeroModel")

	if not is_instance_valid(imported_model) and ResourceLoader.exists(HERO_MODEL):
		player.apply_asset(HERO_MODEL)
		await get_tree().process_frame


func _build_ocean_physics() -> void:
	super._build_ocean_physics()

	if is_instance_valid(ocean_swim_volume) and ocean_swim_volume.get_child_count() > 0:
		var volume_collision = ocean_swim_volume.get_child(0)
		if volume_collision is CollisionShape3D:
			volume_collision.name = "WaterVolumeCollision"

	if is_instance_valid(ocean_floor):
		for child in ocean_floor.get_children():
			if child is CollisionShape3D:
				child.name = "SeabedCollision"
			elif child is MeshInstance3D:
				child.name = "SeabedVisual"


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
	var height: float = super._expanded_height(region_index, world_x, world_z)
	if region_index == 9:
		height += SNOW_SUMMIT_HEIGHT
	return height


func _load_progress() -> void:
	super._load_progress()
	_recover_invalid_expanded_position()


func _recover_invalid_expanded_position() -> void:
	if not is_instance_valid(player):
		return

	var position_2d := Vector2(
		player.global_position.x,
		player.global_position.z
	)
	var outside_world := not EXP_OCEAN_BOUNDS.has_point(position_2d)
	var below_world := player.global_position.y < EXP_OCEAN_BOTTOM_Y - 1.0
	if not outside_world and not below_world:
		return

	# Certaines sauvegardes transitoires sans numéro de version pouvaient être
	# migrées deux fois, plaçant le héros au-delà de l'océan puis dans le vide.
	# On le replace sur la région de départ au lieu de le laisser tomber.
	var center: Vector3 = REGION_CENTERS[EXP_START_REGION]
	var spawn_x: float = center.x
	var spawn_z: float = center.z + 10.0
	var recovered_position := Vector3(
		spawn_x,
		_expanded_height(EXP_START_REGION, spawn_x, spawn_z) + 0.55,
		spawn_z
	)
	player.global_position = recovered_position
	player.velocity = Vector3.ZERO
	player.set_spawn(recovered_position)
	if "last_safe_ground_position" in player:
		player.set("last_safe_ground_position", recovered_position)
	current_zone = EXP_START_REGION


func _build_portals() -> void:
	capital_portal_position = REGION_CENTERS[8] + Vector3(0.0, 2.0, 0.0)
	sky_portal_position = REGION_CENTERS[9] + Vector3(0.0, SNOW_SUMMIT_HEIGHT + 2.0, 0.0)
	_add_expansion_portal_marker(
		"PortailSommet",
		capital_portal_position,
		Color(0.95, 0.72, 0.20)
	)
	_add_expansion_portal_marker(
		"PortailRetour",
		sky_portal_position,
		Color(0.58, 0.90, 1.0)
	)


func _add_expansion_portal_marker(
	node_name: String,
	position_value: Vector3,
	color: Color
) -> void:
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
