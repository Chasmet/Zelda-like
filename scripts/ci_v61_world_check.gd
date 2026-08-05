extends Node

const MAX_WAIT_SECONDS := 210.0


func _ready() -> void:
	if "--ci-v61-world" not in OS.get_cmdline_user_args():
		return
	call_deferred("_run_v61_check")


func _run_v61_check() -> void:
	var game := get_parent()
	var player = await _wait_for_loaded_world(game)
	if not is_instance_valid(player):
		_fail("le monde V6.1 n'a pas fini de charger", 101)
		return

	if not game.has_method("get_v61_world_metrics"):
		_fail("les métriques V6.1 sont absentes", 102)
		return
	var metrics: Dictionary = game.call("get_v61_world_metrics")
	var centers: Array = metrics.get("centers", [])
	if centers.size() != 10:
		_fail("les dix centres de régions sont absents", 102)
		return

	var minimum_spacing := INF
	for a_index in range(centers.size()):
		var center_a: Vector3 = centers[a_index]
		var center_height: float = float(game.call("_super_height", center_a.x, center_a.z))
		if center_height <= float(metrics.get("water_surface_y", -1.5)) + 2.0:
			_fail("la région %d est noyée : hauteur %.2f" % [a_index + 1, center_height], 103)
			return
		for b_index in range(a_index + 1, centers.size()):
			var center_b: Vector3 = centers[b_index]
			minimum_spacing = minf(minimum_spacing, Vector2(center_a.x - center_b.x, center_a.z - center_b.z).length())
	if minimum_spacing < 350.0:
		_fail("les régions restent trop rapprochées : %.2f m" % minimum_spacing, 104)
		return

	var region_size: Vector2 = metrics.get("region_size", Vector2.ZERO)
	var continent_size: Vector2 = metrics.get("continent_size", Vector2.ZERO)
	if region_size.x < 390.0 or region_size.y < 310.0:
		_fail("une région reste trop petite : %s" % region_size, 105)
		return
	if continent_size.x < 1750.0 or continent_size.y < 1080.0:
		_fail("le supercontinent reste trop petit : %s" % continent_size, 106)
		return

	var terrain = game.get_node_or_null("SupercontinentTerrainV61")
	if not is_instance_valid(terrain) or not (terrain is StaticBody3D):
		_fail("le terrain V6.1 avec collision est absent", 107)
		return
	var terrain_collision = terrain.get_node_or_null("SupercontinentHeightMap")
	if not is_instance_valid(terrain_collision) or not (terrain_collision.shape is HeightMapShape3D):
		_fail("le collider HeightMap continu est absent", 108)
		return

	for river_name: String in ["FleuveNordSud", "FleuveEstOuest"]:
		if _count_nodes_named(game, river_name) <= 0:
			_fail("le fleuve %s est absent" % river_name, 109)
			return
	for ocean_name: String in ["OceanNorth", "OceanSouth", "OceanWest", "OceanEast"]:
		var ocean = game.get_node_or_null(ocean_name)
		if not is_instance_valid(ocean) or not (ocean is MeshInstance3D):
			_fail("la bordure d'océan %s est absente" % ocean_name, 110)
			return
	if game.get_node_or_null("SupercontinentOcean") != null:
		_fail("l'ancienne dalle d'eau couvrant tout le continent existe encore", 111)
		return

	var handmade_count := 0
	handmade_count += _count_nodes_named(game, "HandmadeRock")
	handmade_count += _count_nodes_named(game, "HandmadeCrystal")
	handmade_count += _count_nodes_named(game, "HandmadeColumn")
	handmade_count += _count_nodes_named(game, "HandmadeTower")
	if handmade_count < 45:
		_fail("le décor manuel est trop pauvre : %d éléments physiques" % handmade_count, 112)
		return

	if not player.has_method("_try_exit_water"):
		_fail("l'assistance de sortie d'eau V6.1 est absente", 113)
		return
	var water_surface: float = float(metrics.get("water_surface_y", -1.5))
	var shore_boundary_x := _find_west_shore_boundary(game, water_surface)
	if shore_boundary_x <= -890.0:
		_fail("impossible de trouver une berge praticable", 114)
		return

	var water_x := shore_boundary_x - 6.5
	player.global_position = Vector3(water_x, water_surface - 0.25, 0.0)
	player.velocity = Vector3.ZERO
	player.call("_update_water_probe")
	player.call("_refresh_water_flags")
	await _wait_physics_frames(4)
	var water_debug: Dictionary = player.get_water_debug()
	if not bool(water_debug.get("in_water", false)):
		_fail("le point devant la berge n'active pas la nage", 115)
		return
	var exited: bool = bool(player.call("_try_exit_water", Vector3.RIGHT))
	await _wait_physics_frames(10)
	water_debug = player.get_water_debug()
	if not exited or bool(water_debug.get("in_water", true)):
		_fail("le héros reste bloqué dans l'eau devant la berge", 116)
		return
	if player.global_position.y < water_surface - 0.05:
		_fail("la sortie d'eau laisse le héros sous la surface", 117)
		return

	print("CI V6.1 WORLD OK: regions=10 spacing=%.1f region=%s continent=%s rivers=2 ocean_ring=OK handmade=%d shore_exit=OK" % [
		minimum_spacing, region_size, continent_size, handmade_count
	])
	get_tree().quit()


func _find_west_shore_boundary(game, water_surface: float) -> float:
	var previous_height := float(game.call("_super_height", -900.0, 0.0))
	for step in range(1, 71):
		var x := -900.0 + float(step) * 2.0
		var height := float(game.call("_super_height", x, 0.0))
		if previous_height < water_surface - 0.05 and height >= water_surface + 0.05:
			return x
		previous_height = height
	return -900.0


func _count_nodes_named(root: Node, target_name: String) -> int:
	var count := 1 if String(root.name) == target_name else 0
	for child: Node in root.get_children():
		count += _count_nodes_named(child, target_name)
	return count


func _wait_for_loaded_world(game):
	var started_at: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - started_at < int(MAX_WAIT_SECONDS * 1000.0):
		await get_tree().process_frame
		var player = game.get("player")
		var enemies = game.get("enemies")
		var boot_layer = game.get("boot_layer")
		if is_instance_valid(player) and enemies is Array and enemies.size() == 20 and not is_instance_valid(boot_layer):
			return player
	return null


func _wait_physics_frames(frame_count: int) -> void:
	for _frame in range(frame_count):
		await get_tree().physics_frame


func _fail(message: String, exit_code: int) -> void:
	push_error("CI V6.1 WORLD: %s" % message)
	get_tree().quit(exit_code)
