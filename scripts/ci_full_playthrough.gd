extends Node

const ENEMY_SCRIPT = preload("res://scripts/enemy.gd")
const SAVE_PATH := "user://skypiea_worldmap_v2.cfg"
const MAX_WAIT_SECONDS := 150.0
const EXPECTED_ZONE_COUNT := 10
const EXPECTED_GUARDIAN_COUNT := 20
const START_ZONE := 7
const TEST_ROUTE := [6, 1, 0, 8, 5, 4, 3, 2]


func _ready() -> void:
	if "--ci-full-playthrough" not in OS.get_cmdline_user_args():
		return
	_remove_test_save()
	call_deferred("_run_full_playthrough")


func _run_full_playthrough() -> void:
	var game = get_parent()
	var player = await _wait_for_loaded_world(game)
	if not is_instance_valid(player):
		_fail("le monde, le héros ou les gardiens n'ont pas fini de charger", 20)
		return

	var zone_total = game.get("zone_total")
	var zone_remaining = game.get("zone_remaining")
	var zone_completed = game.get("zone_completed")
	if not (zone_total is Array and zone_remaining is Array and zone_completed is Array):
		_fail("les tableaux de progression sont absents", 21)
		return
	if zone_total.size() != EXPECTED_ZONE_COUNT or zone_remaining.size() != EXPECTED_ZONE_COUNT or zone_completed.size() != EXPECTED_ZONE_COUNT:
		_fail("la progression ne contient pas exactement 10 zones", 22)
		return

	var guardian_total := 0
	for value in zone_total:
		guardian_total += int(value)
	if guardian_total != EXPECTED_GUARDIAN_COUNT:
		_fail("20 gardiens attendus, %d trouvés" % guardian_total, 23)
		return
	if not bool(zone_completed[START_ZONE]) or int(zone_remaining[START_ZONE]) != 0:
		_fail("la zone de départ doit être sûre et déjà libérée", 24)
		return

	player.set("max_health", 9999)
	player.set("health", 9999)
	player.set("invulnerability", 9999.0)
	player.set("can_control", true)

	# Test réel d'une sauvegarde partielle : un gardien est vaincu, la partie est
	# sauvegardée, un doublon est injecté comme lors d'un ancien chargement
	# défectueux, puis le chargement doit rétablir exactement le bon nombre.
	var first_guardian = _first_live_enemy_in_zone(game, 6)
	if not is_instance_valid(first_guardian):
		_fail("aucun gardien trouvé dans la zone 7", 25)
		return
	await _defeat_enemy_with_player(game, player, first_guardian)
	if int(game.get("zone_remaining")[6]) != 1:
		_fail("la première victoire n'a pas décrémenté la zone 7", 26)
		return
	game.call("_save_progress")

	var survivor = _first_live_enemy_in_zone(game, 6)
	if not is_instance_valid(survivor):
		_fail("le gardien restant de la zone 7 a disparu", 27)
		return
	_add_extra_guardian(game, player, 6, survivor.global_position + Vector3(0.9, 0.0, 0.9))
	if _live_enemies_for_zone(game, 6).size() != 2:
		_fail("le scénario de restauration partielle n'a pas été créé", 28)
		return
	game.call("_load_progress")
	await get_tree().process_frame
	if int(game.get("zone_remaining")[6]) != 1 or _live_enemies_for_zone(game, 6).size() != 1:
		_fail("le chargement partiel laisse des gardiens en double", 29)
		return

	for zone_index in TEST_ROUTE:
		await _complete_zone(game, player, int(zone_index))
		if int(game.get("zone_remaining")[zone_index]) != 0 or not bool(game.get("zone_completed")[zone_index]):
			_fail("la zone %d ne se valide pas après le dernier gardien" % (int(zone_index) + 1), 30 + int(zone_index))
			return

	# La zone 10 n'est accessible que par le portail du Royaume Central.
	if not await _test_sky_portal_round_trip(game, player):
		return
	await _complete_zone(game, player, 9)

	var final_remaining = game.get("zone_remaining")
	var final_completed = game.get("zone_completed")
	var completed_count := 0
	for zone_index in range(EXPECTED_ZONE_COUNT):
		if bool(final_completed[zone_index]):
			completed_count += 1
		if int(final_remaining[zone_index]) != 0:
			_fail("la zone %d conserve un objectif impossible" % (zone_index + 1), 50 + zone_index)
			return

	if completed_count != EXPECTED_ZONE_COUNT:
		_fail("seulement %d zones sur 10 sont libérées" % completed_count, 61)
		return
	if not bool(game.get("game_complete")):
		_fail("la victoire finale ne se déclenche pas", 62)
		return
	if int(game.get("total_defeated")) != EXPECTED_GUARDIAN_COUNT:
		_fail("le compteur final vaut %d au lieu de 20" % int(game.get("total_defeated")), 63)
		return
	if _all_live_enemies(game).size() != 0:
		_fail("des gardiens restent actifs après la victoire", 64)
		return
	if int(game.get("current_zone")) != 9:
		_fail("le test n'a pas terminé dans la zone 10", 65)
		return

	game.call("_save_progress")
	game.call("_load_progress")
	await get_tree().process_frame
	if not bool(game.get("game_complete")) or int(game.get("total_defeated")) != EXPECTED_GUARDIAN_COUNT:
		_fail("la sauvegarde finale ne restaure pas la victoire", 66)
		return

	print("CI FULL PLAYTHROUGH OK: zones=10 guardians=20 last_zone=10 save_restore=OK")
	_remove_test_save()
	get_tree().quit()


func _wait_for_loaded_world(game):
	var started_at := Time.get_ticks_msec()
	while (Time.get_ticks_msec() - started_at) < int(MAX_WAIT_SECONDS * 1000.0):
		await get_tree().process_frame
		var player = game.get("player")
		var enemy_list = game.get("enemies")
		var boot_layer = game.get("boot_layer")
		if is_instance_valid(player) and enemy_list is Array and enemy_list.size() == EXPECTED_GUARDIAN_COUNT and not is_instance_valid(boot_layer):
			return player
	return null


func _complete_zone(game, player, zone_index: int) -> void:
	var safety := 0
	while true:
		var targets = _live_enemies_for_zone(game, zone_index)
		if targets.is_empty():
			break
		safety += 1
		if safety > 6:
			_fail("boucle de combat bloquée dans la zone %d" % (zone_index + 1), 70 + zone_index)
			return
		await _defeat_enemy_with_player(game, player, targets[0])
	game.call("_update_current_zone")
	await get_tree().process_frame


func _defeat_enemy_with_player(game, player, enemy) -> void:
	if not is_instance_valid(enemy):
		return
	enemy.set_physics_process(false)
	enemy.set("collision_layer", 0)
	enemy.set("collision_mask", 0)
	player.set("can_control", true)
	player.set("invulnerability", 9999.0)
	player.set("velocity", Vector3.ZERO)
	player.global_position = enemy.global_position + Vector3(0.0, 0.08, 1.85)
	player.set_spawn(player.global_position)

	var visual = player.get("_visual")
	if is_instance_valid(visual):
		visual.look_at(enemy.global_position, Vector3.UP)
	game.call("_update_current_zone")
	await get_tree().process_frame

	for _hit in range(8):
		if not is_instance_valid(enemy) or int(enemy.get("health")) <= 0:
			break
		player.set("attack_cooldown", 0.0)
		player.attack()
		await get_tree().create_timer(0.07).timeout

	if is_instance_valid(enemy) and int(enemy.get("health")) > 0:
		_fail("les attaques du héros n'infligent pas assez de dégâts", 80)
		return
	await get_tree().create_timer(0.05).timeout


func _test_sky_portal_round_trip(game, player) -> bool:
	var capital_portal = game.get("capital_portal_position")
	var sky_portal = game.get("sky_portal_position")
	if not (capital_portal is Vector3 and sky_portal is Vector3):
		_fail("les portails de la zone 10 sont absents", 81)
		return false

	player.global_position = capital_portal + Vector3(0.0, 0.0, 1.0)
	game.call("_on_interact")
	await get_tree().process_frame
	game.call("_update_current_zone")
	if int(game.get("current_zone")) != 9 or player.global_position.y < 20.0:
		_fail("le portail du Royaume Central n'ouvre pas la zone 10", 82)
		return false

	player.global_position = sky_portal + Vector3(0.0, 0.0, 1.0)
	game.call("_on_interact")
	await get_tree().process_frame
	game.call("_update_current_zone")
	if int(game.get("current_zone")) != 8 or player.global_position.y > 15.0:
		_fail("le portail retour de l'Île Céleste ne fonctionne pas", 83)
		return false

	player.global_position = capital_portal + Vector3(0.0, 0.0, 1.0)
	game.call("_on_interact")
	await get_tree().process_frame
	game.call("_update_current_zone")
	if int(game.get("current_zone")) != 9:
		_fail("le second accès à la zone 10 échoue", 84)
		return false
	return true


func _add_extra_guardian(game, player, zone_index: int, position: Vector3) -> void:
	var enemy = ENEMY_SCRIPT.new()
	enemy.name = "CI_Extra_Save_Guardian"
	enemy.position = position
	enemy.set_meta("zone_index", zone_index)
	game.add_child(enemy)
	enemy.setup(player, 0, "")
	enemy.set_physics_process(false)
	enemy.defeated.connect(Callable(game, "_on_enemy_defeated"))
	var enemy_list = game.get("enemies")
	enemy_list.append(enemy)


func _first_live_enemy_in_zone(game, zone_index: int):
	var targets = _live_enemies_for_zone(game, zone_index)
	return targets[0] if not targets.is_empty() else null


func _live_enemies_for_zone(game, zone_index: int) -> Array:
	var result: Array = []
	var enemy_list = game.get("enemies")
	if not (enemy_list is Array):
		return result
	for enemy in enemy_list:
		if is_instance_valid(enemy) and not enemy.is_queued_for_deletion() and int(enemy.get("health")) > 0 and int(enemy.get_meta("zone_index", -1)) == zone_index:
			result.append(enemy)
	return result


func _all_live_enemies(game) -> Array:
	var result: Array = []
	var enemy_list = game.get("enemies")
	if not (enemy_list is Array):
		return result
	for enemy in enemy_list:
		if is_instance_valid(enemy) and not enemy.is_queued_for_deletion() and int(enemy.get("health")) > 0:
			result.append(enemy)
	return result


func _remove_test_save() -> void:
	var absolute_path := ProjectSettings.globalize_path(SAVE_PATH)
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(absolute_path)


func _fail(message: String, code: int) -> void:
	push_error("CI FULL PLAYTHROUGH: %s" % message)
	_remove_test_save()
	get_tree().quit(code)
