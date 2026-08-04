extends Node

const SAVE_PATH := "user://skypiea_worldmap_v2.cfg"
const MAX_WAIT_SECONDS := 180.0


func _ready() -> void:
	if "--ci-water-physics" not in OS.get_cmdline_user_args():
		return
	_remove_test_save()
	call_deferred("_run_physics_check")


func _run_physics_check() -> void:
	var game := get_parent()
	var player = await _wait_for_loaded_world(game)
	if not is_instance_valid(player):
		_fail("le supercontinent aquatique ou le héros n'a pas fini de charger", 70)
		return
	if not player.has_method("get_water_debug") or not game.has_method("get_ci_water_points"):
		_fail("les points de validation du nouveau monde sont absents", 71)
		return

	var swim_volume = game.get("ocean_swim_volume")
	var seabed = game.get("ocean_floor")
	if not is_instance_valid(swim_volume) or not (swim_volume is Area3D):
		_fail("le volume physique de l'océan est absent", 72)
		return
	if not is_instance_valid(seabed) or not (seabed is StaticBody3D):
		_fail("le fond marin avec collision est absent", 73)
		return
	var volume_collision = swim_volume.get_node_or_null("WaterVolumeCollision")
	var seabed_collision = seabed.get_node_or_null("SeabedCollision")
	if not is_instance_valid(volume_collision) or not (volume_collision.shape is BoxShape3D):
		_fail("la collision du volume d'eau est invalide", 74)
		return
	if not is_instance_valid(seabed_collision) or not (seabed_collision.shape is BoxShape3D):
		_fail("la collision du fond marin est invalide", 75)
		return

	var points: Dictionary = game.call("get_ci_water_points")
	var shore_land: Vector3 = points.get("shore_land", Vector3.ZERO)
	var shore_water: Vector3 = points.get("shore_water", Vector3.ZERO)
	var river_water: Vector3 = points.get("river_water", Vector3.ZERO)
	var deep_water: Vector3 = points.get("deep_water", Vector3.ZERO)
	var water: Dictionary = player.get_water_debug()
	var bottom_y := float(water.get("bottom_y", -8.5))
	var safe_position: Vector3 = player.get_safe_save_position()
	player.set_spawn(safe_position)
	player.max_health = 100
	player.health = 100
	player.invulnerability = 0.0
	player.oxygen = player.max_oxygen
	player.can_control = true

	player.global_position = shore_land
	player.velocity = Vector3.ZERO
	_set_game_move(game, player, Vector2.ZERO)
	if not await _wait_for_floor(player, 4.0):
		_fail("la plage du supercontinent ne fournit pas de sol stable", 76)
		return
	water = player.get_water_debug()
	if bool(water.get("in_water", false)) or bool(water.get("open_water_column", true)):
		_fail("la terre ferme est détectée à tort comme de l'eau", 77)
		return

	player.global_position = shore_water
	player.velocity = Vector3.ZERO
	await _wait_physics_frames(14)
	water = player.get_water_debug()
	if not bool(water.get("in_water", false)):
		_fail("l'océan extérieur n'active pas la nage", 78)
		return

	player.global_position = deep_water
	player.velocity = Vector3.ZERO
	await _wait_physics_frames(12)
	var swim_start: Vector3 = player.global_position
	_set_game_move(game, player, Vector2(0.0, -1.0))
	await _wait_physics_frames(50)
	_set_game_move(game, player, Vector2.ZERO)
	var swim_end: Vector3 = player.global_position
	var swim_distance := Vector2(swim_end.x - swim_start.x, swim_end.z - swim_start.z).length()
	if swim_distance < 1.8 or not swim_end.is_finite():
		_fail("la nage horizontale est bloquée : %.3f m" % swim_distance, 79)
		return
	var drift_start: Vector3 = player.global_position
	await _wait_physics_frames(35)
	var drift_distance := Vector2(player.global_position.x - drift_start.x, player.global_position.z - drift_start.z).length()
	if drift_distance > 1.5:
		_fail("l'inertie aquatique continue trop longtemps", 80)
		return

	var dive_start_y := player.global_position.y
	var oxygen_before := player.oxygen
	player.request_swim_vertical(-1.0, 1.45)
	await _wait_physics_frames(78)
	water = player.get_water_debug()
	if dive_start_y - player.global_position.y < 1.2 or not bool(water.get("underwater", false)):
		_fail("la commande PLONGER ne descend pas sous la surface", 81)
		return
	if player.oxygen >= oxygen_before - 0.35:
		_fail("l'oxygène ne diminue pas pendant la plongée", 82)
		return

	player.health = player.max_health
	player.invulnerability = 0.0
	player.oxygen = 0.02
	player.request_swim_vertical(-1.0, 2.0)
	await _wait_physics_frames(85)
	if player.health >= player.max_health:
		_fail("le manque d'oxygène ne provoque aucun dégât", 83)
		return
	player.health = player.max_health
	player.invulnerability = 0.0
	player.oxygen = player.max_oxygen
	player.request_swim_vertical(1.0, 2.6)
	var surfaced := false
	for _frame in range(190):
		await get_tree().physics_frame
		water = player.get_water_debug()
		if bool(water.get("in_water", false)) and not bool(water.get("underwater", false)):
			surfaced = true
			break
	if not surfaced:
		_fail("la commande REMONTER ne rejoint pas la surface", 84)
		return

	player.global_position = Vector3(deep_water.x + 14.0, bottom_y + 0.85, deep_water.z)
	player.velocity = Vector3(0.0, -8.0, 0.0)
	player.request_swim_vertical(-1.0, 1.6)
	await _wait_physics_frames(90)
	if player.global_position.y < bottom_y - 0.28 or not player.global_position.is_finite():
		_fail("la collision du fond marin est traversée", 85)
		return

	player.global_position = river_water
	player.velocity = Vector3.ZERO
	await _wait_physics_frames(14)
	water = player.get_water_debug()
	if not bool(water.get("in_water", false)) or not bool(water.get("open_water_column", false)):
		_fail("le fleuve intérieur n'est pas reconnu comme une vraie colonne d'eau", 86)
		return

	player.global_position = safe_position
	player.velocity = Vector3.ZERO
	_set_game_move(game, player, Vector2.ZERO)
	if not await _wait_for_floor(player, 4.0):
		_fail("le héros ne retrouve pas le sol du supercontinent", 87)
		return
	var walk_start: Vector3 = player.global_position
	_set_game_move(game, player, Vector2(0.0, -1.0))
	await _wait_physics_frames(42)
	_set_game_move(game, player, Vector2.ZERO)
	var walk_distance := Vector2(player.global_position.x - walk_start.x, player.global_position.z - walk_start.z).length()
	if walk_distance < 1.4:
		_fail("la marche terrestre est bloquée", 88)
		return
	if not await _wait_for_floor(player, 2.0):
		_fail("le héros ne reste pas posé au sol", 89)
		return

	var jump_start_y := player.global_position.y
	var peak_y := jump_start_y
	Input.action_press("jump")
	await get_tree().physics_frame
	Input.action_release("jump")
	for frame_index in range(130):
		await get_tree().physics_frame
		peak_y = maxf(peak_y, player.global_position.y)
		if frame_index > 25 and player.is_on_floor():
			break
	if peak_y - jump_start_y < 0.9 or not player.is_on_floor():
		_fail("le saut ou l'atterrissage est défectueux", 90)
		return

	player.velocity = Vector3.ZERO
	player.dodge_cooldown = 0.0
	player.invulnerability = 0.0
	player.dodge()
	await get_tree().physics_frame
	if Vector2(player.velocity.x, player.velocity.z).length() < 4.0 or player.invulnerability <= 0.0:
		_fail("l'esquive terrestre est défectueuse", 91)
		return

	player.set_spawn(safe_position)
	player.last_safe_ground_position = safe_position
	player.global_position = Vector3(safe_position.x, -13.2, safe_position.z)
	player.velocity = Vector3.ZERO
	await _wait_physics_frames(45)
	if player.global_position.distance_to(safe_position) > 1.5 or player.health != player.max_health:
		_fail("le respawn après une chute profonde est incorrect", 92)
		return

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
		if is_instance_valid(player) and enemy_list is Array and enemy_list.size() == 20 and not is_instance_valid(boot_layer) and is_instance_valid(swim_volume):
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
