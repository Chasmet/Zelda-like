extends Node

const SAVE_PATH := "user://skypiea_worldmap_v2.cfg"
const MAX_WAIT_SECONDS := 180.0
const OPEN_WATER := Vector2(420.0, 250.0)


func _ready() -> void:
	if "--ci-water-physics" not in OS.get_cmdline_user_args():
		return
	_remove_test_save()
	call_deferred("_run_physics_check")


func _run_physics_check() -> void:
	var game = get_parent()
	var player = await _wait_for_loaded_world(game)
	if not is_instance_valid(player):
		_fail("le monde V8 ou le héros n'a pas fini de charger", 70)
		return

	if not player.has_method("get_water_debug"):
		_fail("le contrôleur aquatique V8 n'est pas actif", 71)
		return
	if not player.has_method("request_water_flight"):
		_fail("le vol de secours aquatique est absent", 72)
		return

	var swim_volume = game.get("ocean_swim_volume")
	var seabed = game.get("ocean_floor")
	if not is_instance_valid(swim_volume) or not (swim_volume is Area3D):
		_fail("le volume physique du grand océan est absent", 73)
		return
	if not is_instance_valid(seabed) or not (seabed is StaticBody3D):
		_fail("le fond marin du grand océan est absent", 74)
		return

	var volume_collision = swim_volume.get_node_or_null("WaterVolumeCollision")
	var seabed_collision = seabed.get_node_or_null("SeabedCollision")
	if not is_instance_valid(volume_collision) or not (volume_collision.shape is BoxShape3D):
		_fail("la collision du volume d'eau V8 est invalide", 75)
		return
	if not is_instance_valid(seabed_collision) or not (seabed_collision.shape is BoxShape3D):
		_fail("la collision du fond marin V8 est invalide", 76)
		return

	var water: Dictionary = player.get_water_debug()
	var surface_y := float(water.get("surface_y", -0.92))
	var bottom_y := float(water.get("bottom_y", -10.0))
	var safe_position: Vector3 = player.get_safe_save_position()
	player.set_spawn(safe_position)
	player.max_health = 100
	player.health = 100
	player.invulnerability = 0.0
	player.oxygen = player.max_oxygen
	player.can_control = true

	# Bord de la nouvelle région 1 : terre stable puis eau ouverte quelques mètres plus loin.
	var shore_x := -300.0
	var shore_z := -104.55
	var shore_y := float(game.call("_expanded_height", 0, shore_x, shore_z))
	player.global_position = Vector3(shore_x, shore_y + 0.80, shore_z)
	player.velocity = Vector3.ZERO
	_set_game_move(game, player, Vector2.ZERO)
	if not await _wait_for_floor(player, 4.0):
		_fail("la côte agrandie ne fournit pas de sol stable", 77)
		return
	water = player.get_water_debug()
	if bool(water.get("in_water", false)) or bool(water.get("open_water_column", true)):
		_fail("la terre de la côte est détectée comme de l'eau", 78)
		return

	player.global_position = Vector3(shore_x, surface_y - 1.15, -98.85)
	player.velocity = Vector3.ZERO
	await _wait_physics_frames(18)
	water = player.get_water_debug()
	if not bool(water.get("in_water", false)):
		_fail("l'océan après la plage n'active pas la nage", 79)
		return

	player.global_position = Vector3(shore_x, shore_y + 0.80, shore_z)
	player.velocity = Vector3.ZERO
	await _wait_physics_frames(12)
	if not await _wait_for_floor(player, 4.0):
		_fail("le retour de l'eau vers la côte bloque le héros", 80)
		return
	water = player.get_water_debug()
	if bool(water.get("in_water", false)) or not player.can_control:
		_fail("le héros reste coincé en mode nage sur la terre", 81)
		return

	# Vol de secours : activable dans l'eau, limité à cinq secondes et impossible sur terre.
	if bool(player.request_water_flight()):
		_fail("le vol s'active alors que le héros est sur terre", 82)
		return

	player.global_position = Vector3(OPEN_WATER.x, surface_y - 1.15, OPEN_WATER.y)
	player.velocity = Vector3.ZERO
	await _wait_physics_frames(18)
	water = player.get_water_debug()
	if not bool(water.get("in_water", false)):
		_fail("la zone de test en pleine mer n'active pas la nage", 83)
		return
	if not bool(player.request_water_flight()):
		_fail("le vol de secours ne s'active pas depuis l'eau", 84)
		return

	_set_game_move(game, player, Vector2(0.0, -1.0))
	var flight_start := player.global_position
	await _wait_physics_frames(55)
	water = player.get_water_debug()
	if not bool(water.get("flight_active", false)):
		_fail("le vol aquatique s'arrête beaucoup trop tôt", 85)
		return
	if player.global_position.y <= surface_y + 0.35:
		_fail("le vol aquatique ne soulève pas le héros au-dessus de l'eau", 86)
		return
	if Vector2(
		player.global_position.x - flight_start.x,
		player.global_position.z - flight_start.z
	).length() < 1.0:
		_fail("le héros ne peut pas se diriger pendant le vol", 87)
		return

	_set_game_move(game, player, Vector2.ZERO)
	await _wait_physics_frames(300)
	water = player.get_water_debug()
	if bool(water.get("flight_active", false)) or float(water.get("flight_remaining", 1.0)) > 0.05:
		_fail("le vol dépasse sa limite de cinq secondes", 88)
		return

	# Nage horizontale et arrêt de l'inertie.
	player.global_position = Vector3(OPEN_WATER.x, surface_y - 1.15, OPEN_WATER.y)
	player.velocity = Vector3.ZERO
	await _wait_physics_frames(18)
	var swim_start: Vector3 = player.global_position
	_set_game_move(game, player, Vector2(0.0, -1.0))
	await _wait_physics_frames(52)
	_set_game_move(game, player, Vector2.ZERO)
	var swim_end: Vector3 = player.global_position
	var swim_distance := Vector2(
		swim_end.x - swim_start.x,
		swim_end.z - swim_start.z
	).length()
	if swim_distance < 1.8 or not swim_end.is_finite():
		_fail("la nage horizontale ne déplace pas correctement le héros", 89)
		return

	var drift_start := player.global_position
	await _wait_physics_frames(38)
	var drift_distance := Vector2(
		player.global_position.x - drift_start.x,
		player.global_position.z - drift_start.z
	).length()
	if drift_distance > 1.5:
		_fail("l'inertie aquatique reste excessive", 90)
		return

	# Plongée, oxygène et remontée.
	var oxygen_before: float = player.oxygen
	player.request_swim_vertical(-1.0, 1.55)
	await _wait_physics_frames(82)
	water = player.get_water_debug()
	if not bool(water.get("underwater", false)):
		_fail("la commande de plongée ne passe pas sous la surface", 91)
		return
	if player.oxygen >= oxygen_before - 0.35:
		_fail("l'oxygène ne diminue pas pendant la plongée", 92)
		return

	player.health = player.max_health
	player.invulnerability = 0.0
	player.oxygen = 0.01
	player.request_swim_vertical(-1.0, 2.0)
	await _wait_physics_frames(82)
	if player.health >= player.max_health:
		_fail("le manque d'oxygène ne provoque aucun dégât", 93)
		return

	player.health = player.max_health
	player.oxygen = player.max_oxygen
	player.request_swim_vertical(1.0, 2.7)
	var surfaced := false
	for _frame in range(200):
		await get_tree().physics_frame
		water = player.get_water_debug()
		if bool(water.get("in_water", false)) and not bool(water.get("underwater", false)):
			surfaced = true
			break
	if not surfaced:
		_fail("la remontée ne ramène pas le héros à la surface", 94)
		return

	# Le fond marin doit rester infranchissable.
	player.global_position = Vector3(OPEN_WATER.x, bottom_y + 0.90, OPEN_WATER.y)
	player.velocity = Vector3(0.0, -8.0, 0.0)
	player.request_swim_vertical(-1.0, 1.8)
	await _wait_physics_frames(95)
	if player.global_position.y < bottom_y - 0.30 or not player.global_position.is_finite():
		_fail("le héros traverse le fond marin", 95)
		return

	# Retour au point sûr : marche, saut et esquive.
	player.global_position = safe_position
	player.velocity = Vector3.ZERO
	_set_game_move(game, player, Vector2.ZERO)
	if not await _wait_for_floor(player, 4.0):
		_fail("le héros ne retrouve pas un sol stable", 96)
		return

	var walk_start: Vector3 = player.global_position
	_set_game_move(game, player, Vector2(0.0, -1.0))
	await _wait_physics_frames(45)
	_set_game_move(game, player, Vector2.ZERO)
	if Vector2(
		player.global_position.x - walk_start.x,
		player.global_position.z - walk_start.z
	).length() < 1.4:
		_fail("la marche terrestre est bloquée", 97)
		return

	if not await _wait_for_floor(player, 3.0):
		_fail("le héros ne reste pas posé au sol", 98)
		return
	var jump_start_y: float = player.global_position.y
	var peak_y := jump_start_y
	Input.action_press("jump")
	await get_tree().physics_frame
	Input.action_release("jump")
	for frame_index in range(140):
		await get_tree().physics_frame
		peak_y = maxf(peak_y, player.global_position.y)
		if frame_index > 28 and player.is_on_floor():
			break
	if peak_y - jump_start_y < 0.9 or not player.is_on_floor():
		_fail("le saut ou l'atterrissage est défectueux", 99)
		return

	player.velocity = Vector3.ZERO
	player.dodge_cooldown = 0.0
	player.invulnerability = 0.0
	player.dodge()
	await get_tree().physics_frame
	if Vector2(player.velocity.x, player.velocity.z).length() < 4.0 or player.invulnerability <= 0.0:
		_fail("l'esquive terrestre est défectueuse", 100)
		return

	# Chute hors du monde : retour automatique au dernier point sûr.
	player.set_spawn(safe_position)
	player.last_safe_ground_position = safe_position
	player.global_position = Vector3(safe_position.x, bottom_y - 5.0, safe_position.z)
	player.velocity = Vector3.ZERO
	await _wait_physics_frames(55)
	if player.global_position.distance_to(safe_position) > 1.7 or player.health != player.max_health:
		_fail("le respawn après une chute profonde est incorrect", 101)
		return

	print("CI WATER FLIGHT OK: water_only=OK duration_5s=OK steering=OK")
	print("CI WATER PHYSICS OK: swim=OK dive=OK surface=OK seabed=OK oxygen=OK walk=OK jump=OK dodge=OK respawn=OK")
	_remove_test_save()
	get_tree().quit()


func _set_game_move(game, player, value: Vector2) -> void:
	game.set("virtual_move", value)
	player.set_virtual_move(value)


func _wait_for_loaded_world(game):
	var started_at := Time.get_ticks_msec()
	while Time.get_ticks_msec() - started_at < int(MAX_WAIT_SECONDS * 1000.0):
		await get_tree().process_frame
		var player = game.get("player")
		var enemy_list = game.get("enemies")
		var boot_layer = game.get("boot_layer")
		var swim_volume = game.get("ocean_swim_volume")
		if (
			is_instance_valid(player)
			and enemy_list is Array
			and enemy_list.size() == 20
			and not is_instance_valid(boot_layer)
			and is_instance_valid(swim_volume)
		):
			return player
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
