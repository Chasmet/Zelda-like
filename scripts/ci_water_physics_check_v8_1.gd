extends Node

const SAVE_PATH := "user://skypiea_worldmap_v2.cfg"
const MAX_WAIT_SECONDS := 180.0
const OPEN_WATER := Vector2(420.0, 250.0)


func _ready() -> void:
	if "--ci-water-physics" not in OS.get_cmdline_user_args():
		return
	_remove_test_save()
	call_deferred("_run")


func _run() -> void:
	var game = get_parent()
	var player = await _wait_for_world(game)
	if not is_instance_valid(player):
		_fail("le monde V8 n'a pas fini de charger", 70)
		return

	if not player.has_method("request_water_flight"):
		_fail("le vol aquatique est absent", 71)
		return
	if not player.has_method("get_water_debug"):
		_fail("le contrôleur de nage est absent", 72)
		return

	var swim_volume = game.get("ocean_swim_volume")
	var ocean_floor = game.get("ocean_floor")
	if not is_instance_valid(swim_volume) or not is_instance_valid(ocean_floor):
		_fail("l'océan physique est incomplet", 73)
		return
	if not is_instance_valid(swim_volume.get_node_or_null("WaterVolumeCollision")):
		_fail("la collision de l'eau est absente", 74)
		return
	if not is_instance_valid(ocean_floor.get_node_or_null("SeabedCollision")):
		_fail("la collision du fond marin est absente", 75)
		return

	var water: Dictionary = player.get_water_debug()
	var surface_y: float = float(water.get("surface_y", -0.92))
	var bottom_y: float = float(water.get("bottom_y", -10.0))
	var safe_position: Vector3 = player.get_safe_save_position()
	player.max_health = 100
	player.health = 100
	player.oxygen = player.max_oxygen
	player.can_control = true
	player.set_spawn(safe_position)

	# Le vol doit être refusé sur terre.
	player.global_position = safe_position
	player.velocity = Vector3.ZERO
	if not await _wait_for_floor(player, 4.0):
		_fail("le point de départ n'a pas de sol stable", 76)
		return
	if bool(player.request_water_flight()):
		_fail("le vol s'active sur terre", 77)
		return

	# Activation uniquement dans l'eau et durée maximale de cinq secondes.
	player.global_position = Vector3(OPEN_WATER.x, surface_y - 1.15, OPEN_WATER.y)
	player.velocity = Vector3.ZERO
	await _wait_physics_frames(18)
	water = player.get_water_debug()
	if not bool(water.get("in_water", false)):
		_fail("la pleine mer n'active pas la nage", 78)
		return
	if not bool(player.request_water_flight()):
		_fail("le vol ne s'active pas depuis l'eau", 79)
		return

	var flight_start: Vector3 = player.global_position
	_set_move(game, player, Vector2(0.0, -1.0))
	await _wait_physics_frames(35)
	water = player.get_water_debug()
	if not bool(water.get("flight_active", false)):
		_fail("le vol s'arrête trop tôt", 80)
		return
	if player.global_position.y <= surface_y + 0.30:
		_fail("le vol ne soulève pas le héros", 81)
		return
	var flight_distance: float = Vector2(
		player.global_position.x - flight_start.x,
		player.global_position.z - flight_start.z
	).length()
	if flight_distance < 0.8:
		_fail("le vol n'est pas dirigeable", 82)
		return

	_set_move(game, player, Vector2.ZERO)
	await _wait_physics_frames(330)
	water = player.get_water_debug()
	if bool(water.get("flight_active", false)):
		_fail("le vol dépasse cinq secondes", 83)
		return
	if float(water.get("flight_remaining", 1.0)) > 0.05:
		_fail("le compte à rebours du vol ne revient pas à zéro", 84)
		return

	# Nage horizontale, plongée et oxygène.
	player.global_position = Vector3(OPEN_WATER.x, surface_y - 1.15, OPEN_WATER.y)
	player.velocity = Vector3.ZERO
	await _wait_physics_frames(18)
	var swim_start: Vector3 = player.global_position
	_set_move(game, player, Vector2(0.0, -1.0))
	await _wait_physics_frames(52)
	_set_move(game, player, Vector2.ZERO)
	var swim_distance: float = Vector2(
		player.global_position.x - swim_start.x,
		player.global_position.z - swim_start.z
	).length()
	if swim_distance < 1.8 or not player.global_position.is_finite():
		_fail("la nage horizontale est bloquée", 85)
		return

	var drift_start: Vector3 = player.global_position
	await _wait_physics_frames(38)
	var drift_distance: float = Vector2(
		player.global_position.x - drift_start.x,
		player.global_position.z - drift_start.z
	).length()
	if drift_distance > 1.5:
		_fail("l'inertie aquatique est excessive", 86)
		return

	var oxygen_before: float = player.oxygen
	player.request_swim_vertical(-1.0, 1.6)
	await _wait_physics_frames(82)
	water = player.get_water_debug()
	if not bool(water.get("underwater", false)):
		_fail("la plongée ne passe pas sous la surface", 87)
		return
	if player.oxygen >= oxygen_before - 0.35:
		_fail("l'oxygène ne diminue pas", 88)
		return

	player.request_swim_vertical(1.0, 2.7)
	var surfaced := false
	for _frame in range(210):
		await get_tree().physics_frame
		water = player.get_water_debug()
		if bool(water.get("in_water", false)) and not bool(water.get("underwater", false)):
			surfaced = true
			break
	if not surfaced:
		_fail("le héros ne remonte pas à la surface", 89)
		return

	# Le fond marin doit arrêter le héros.
	player.global_position = Vector3(OPEN_WATER.x, bottom_y + 0.9, OPEN_WATER.y)
	player.velocity = Vector3(0.0, -8.0, 0.0)
	player.request_swim_vertical(-1.0, 1.8)
	await _wait_physics_frames(95)
	if player.global_position.y < bottom_y - 0.30:
		_fail("le héros traverse le fond marin", 90)
		return

	# Marche, saut, esquive et respawn terrestre.
	player.global_position = safe_position
	player.velocity = Vector3.ZERO
	_set_move(game, player, Vector2.ZERO)
	if not await _wait_for_floor(player, 4.0):
		_fail("le retour sur terre est instable", 91)
		return

	var walk_start: Vector3 = player.global_position
	_set_move(game, player, Vector2(0.0, -1.0))
	await _wait_physics_frames(45)
	_set_move(game, player, Vector2.ZERO)
	var walk_distance: float = Vector2(
		player.global_position.x - walk_start.x,
		player.global_position.z - walk_start.z
	).length()
	if walk_distance < 1.4:
		_fail("la marche terrestre est bloquée", 92)
		return

	if not await _wait_for_floor(player, 3.0):
		_fail("le héros ne reste pas au sol", 93)
		return
	var jump_start_y: float = player.global_position.y
	var peak_y: float = jump_start_y
	Input.action_press("jump")
	await get_tree().physics_frame
	Input.action_release("jump")
	for frame_index in range(140):
		await get_tree().physics_frame
		peak_y = maxf(peak_y, player.global_position.y)
		if frame_index > 28 and player.is_on_floor():
			break
	if peak_y - jump_start_y < 0.9 or not player.is_on_floor():
		_fail("le saut ou l'atterrissage est défectueux", 94)
		return

	player.velocity = Vector3.ZERO
	player.dodge_cooldown = 0.0
	player.invulnerability = 0.0
	player.dodge()
	await get_tree().physics_frame
	if Vector2(player.velocity.x, player.velocity.z).length() < 4.0:
		_fail("l'esquive ne donne pas d'impulsion", 95)
		return

	player.set_spawn(safe_position)
	player.last_safe_ground_position = safe_position
	player.health = player.max_health
	player.global_position = Vector3(safe_position.x, bottom_y - 5.0, safe_position.z)
	player.velocity = Vector3.ZERO
	await _wait_physics_frames(55)
	if player.global_position.distance_to(safe_position) > 1.7:
		_fail("le respawn hors du monde est incorrect", 96)
		return

	print("CI WATER FLIGHT OK: water_only=OK duration_5s=OK steering=OK")
	print("CI WATER PHYSICS OK: swim=OK dive=OK surface=OK seabed=OK oxygen=OK walk=OK jump=OK dodge=OK respawn=OK")
	_remove_test_save()
	get_tree().quit()


func _set_move(game, player, value: Vector2) -> void:
	game.set("virtual_move", value)
	player.set_virtual_move(value)


func _wait_for_world(game):
	var deadline := Time.get_ticks_msec() + int(MAX_WAIT_SECONDS * 1000.0)
	while Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
		var candidate = game.get("player")
		var enemy_list = game.get("enemies")
		var boot_layer = game.get("boot_layer")
		if (
			is_instance_valid(candidate)
			and enemy_list is Array
			and enemy_list.size() == 20
			and not is_instance_valid(boot_layer)
		):
			return candidate
	return null


func _wait_physics_frames(frame_count: int) -> void:
	for _frame in range(frame_count):
		await get_tree().physics_frame


func _wait_for_floor(player, seconds: float) -> bool:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		await get_tree().physics_frame
		if player.is_on_floor():
			return true
	return false


func _remove_test_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))


func _fail(message: String, exit_code: int) -> void:
	push_error("CI WATER PHYSICS: %s" % message)
	_remove_test_save()
	get_tree().quit(exit_code)
