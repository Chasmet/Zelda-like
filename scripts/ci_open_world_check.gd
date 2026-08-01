extends Node

const MAX_WAIT_SECONDS := 120.0


func _ready() -> void:
	if "--ci-open-world-check" not in OS.get_cmdline_user_args():
		return
	call_deferred("_run_check")


func _run_check() -> void:
	var game = get_parent()
	var started_at = Time.get_ticks_msec()
	while (Time.get_ticks_msec() - started_at) < int(MAX_WAIT_SECONDS * 1000.0):
		await get_tree().process_frame
		if game.has_method("get_open_world_debug"):
			var state: Dictionary = game.call("get_open_world_debug")
			if int(state.get("regions", 0)) == 10 and bool(state.get("clock_ready", false)):
				break

	if not game.has_method("get_open_world_debug"):
		_fail("le diagnostic du monde est absent", 20)
		return
	var state: Dictionary = game.call("get_open_world_debug")
	if int(state.get("regions", 0)) != 10:
		_fail("les dix régions ne sont pas chargées : %s" % state, 21)
		return
	var area_ratio = float(state.get("region_area", 0.0)) / maxf(1.0, float(state.get("baseline_area", 1.0)))
	if area_ratio < 10.0:
		_fail("la surface d'une région n'est agrandie que de %.2f fois" % area_ratio, 22)
		return
	if int(state.get("population_profiles", 0)) != 200 or int(state.get("active_npcs", 0)) != 20:
		_fail("la population attendue (200 profils, 20 actifs) est incorrecte : %s" % state, 23)
		return
	var wildlife: Dictionary = state.get("wildlife", {})
	if int(wildlife.get("terrestres", 0)) < 7 or int(wildlife.get("marins", 0)) < 8:
		_fail("l'écosystème actif est incomplet : %s" % wildlife, 24)
		return
	if int(state.get("boats", 0)) < 2 or int(state.get("autonomous_boats", 0)) < 4 or int(state.get("quests", 0)) != 10:
		_fail("bateaux ou quêtes manquants : %s" % state, 25)
		return
	if int(state.get("collectibles", 0)) < 35 or int(state.get("points_of_interest", 0)) != 10:
		_fail("objets ou points d'intérêt manquants : %s" % state, 26)
		return
	if int(state.get("puzzle_switches", 0)) != 3:
		_fail("l'énigme des Trois Sceaux n'a pas ses trois mécanismes", 45)
		return
	for ui_key in ["dialogue_ready", "inventory_ready", "pause_ready", "title_ready"]:
		if not bool(state.get(ui_key, false)):
			_fail("interface incomplète : %s" % ui_key, 27)
			return
	var hero_status = game.get("hero_status_label")
	if not is_instance_valid(hero_status) or String(hero_status.text) != "CHK HERO" or String(game.get("player").name) != "CHKHero":
		_fail("le remplacement du héros par CHK HERO n'est pas actif dans le monde et le HUD", 49)
		return
	if not bool(state.get("sound_ready", false)):
		_fail("les ambiances régionales ou sous-marines ne sont pas chargées", 37)
		return

	var progress = game.get("adventure_progress")
	var quest_message = String(progress.call("start_region_quest", 0))
	if "journal" not in quest_message.to_lower():
		_fail("la quête ne s'active pas réellement : %s" % quest_message, 28)
		return
	if not bool(progress.call("discover_point", "ci_phare", 0, "Phare de validation")):
		_fail("la découverte du point d'intérêt a échoué", 29)
		return
	if String(progress.quests[0].get("statut", "")) != "terminée" or progress.inventory.is_empty():
		_fail("la quête n'a pas remis sa récompense", 30)
		return

	var player = game.get("player")
	var boats: Array = game.get("player_boats")
	if not is_instance_valid(player) or boats.is_empty():
		_fail("le héros ou les bateaux ne sont pas disponibles", 31)
		return
	var first_boat = boats[0]
	first_boat.call("board")
	await get_tree().process_frame
	if not bool(first_boat.get("boarded")) or player.is_physics_processing():
		_fail("l'embarquement jouable ne désactive pas correctement la marche", 32)
		return
	first_boat.call("disembark")
	await get_tree().process_frame
	if bool(first_boat.get("boarded")) or not player.is_physics_processing():
		_fail("le débarquement ne rend pas le contrôle au héros", 33)
		return
	player.global_position = Vector3(0.0, -2.8, 250.0)
	player.velocity = Vector3.ZERO
	await get_tree().physics_frame
	await get_tree().physics_frame
	if not bool(player.get("is_swimming")):
		_fail("l'entrée dans l'océan n'active pas la nage", 38)
		return
	var depth_before = float(player.get("swim_depth"))
	player.call("dive")
	await get_tree().create_timer(0.32).timeout
	if float(player.get("swim_depth")) <= depth_before + 0.20:
		_fail("la commande de plongée ne fait pas descendre le héros", 39)
		return
	var puzzle_switches: Array = game.get("ancient_switches")
	for ancient_switch in puzzle_switches:
		player.global_position = ancient_switch.global_position
		game.call("_update_current_zone")
		if not bool(game.call("_try_activate_ancient_switch")):
			_fail("un sceau antique ne répond pas à ACTION", 46)
			return
	var puzzle_progress = game.get("adventure_progress")
	var puzzle_chest = game.get("ancient_puzzle_chest")
	if not bool(puzzle_progress.call("has_world_flag", "porte_trois_sceaux_ouverte")) or not bool(puzzle_chest.visible):
		_fail("la résolution des trois sceaux n'ouvre pas la porte et le coffre", 47)
		return

	game.set("graphics_quality", "faible")
	game.call("_apply_graphics_quality", false)
	if Engine.max_fps != 30:
		_fail("le profil faible ne cible pas 30 IPS", 34)
		return
	game.set("graphics_quality", "moyen")
	game.call("_apply_graphics_quality", false)
	if Engine.max_fps != 60:
		_fail("le profil moyen ne cible pas 60 IPS", 35)
		return
	game.call("_open_pause_settings")
	if not get_tree().paused or not bool(game.get("pause_panel").visible):
		_fail("le menu pause n'interrompt pas réellement la simulation", 43)
		return
	game.call("_close_pause_settings")
	if get_tree().paused or bool(game.get("pause_panel").visible):
		_fail("le bouton reprendre ne restaure pas la simulation", 44)
		return

	# Les constantes ne sont pas exposées par Object.get : utilise un point déjà créé
	# dans la région 2 pour valider le streaming et le remplacement des IA actives.
	var points: Array = game.get("point_of_interest_nodes")
	if points.size() >= 6 and is_instance_valid(points[5]):
		player.global_position = points[5].global_position
		player.velocity = Vector3.ZERO
		await get_tree().physics_frame
		await get_tree().physics_frame
		game.call("_update_current_zone")
		game.call("_update_region_movement_effects")
		if float(player.get("move_speed")) > 3.6:
			_fail("la boue du marais ne ralentit pas les déplacements", 48)
			return
	if points.size() >= 2 and is_instance_valid(points[1]):
		player.global_position = points[1].global_position
		game.call("_update_current_zone")
		await get_tree().process_frame
		var population = game.get("population_manager")
		var fauna = game.get("wildlife_manager")
		if int(game.get("current_zone")) != 1 or int(population.get("active_region")) != 1 or int(fauna.get("active_region")) != 1:
			_fail("le changement rapide de région n'a pas resynchronisé les habitants et la faune", 36)
			return

	game.call("_save_progress")
	var save_path = ProjectSettings.globalize_path("user://skypiea_worldmap_v2.cfg")
	if not FileAccess.file_exists(save_path):
		_fail("la sauvegarde automatique n'a créé aucun fichier", 40)
		return
	game.call("_save_progress")
	var corrupt_file = FileAccess.open(save_path, FileAccess.WRITE)
	if corrupt_file == null:
		_fail("impossible de préparer le test de corruption", 41)
		return
	corrupt_file.store_string("sauvegarde volontairement corrompue")
	corrupt_file.close()
	game.call("_load_progress")
	if not is_instance_valid(game.get("player")) or int(game.get("zone_roots").size()) != 10:
		_fail("la copie de secours n'a pas restauré le monde", 42)
		return

	print("CI OPEN WORLD CHECK OK: régions=10 surface=%.2fx PNJ=200 actifs=20 faune=%s objets=%d quêtes=10 bateaux=2" % [area_ratio, wildlife, int(state.get("collectibles", 0))])
	game.call("_shutdown_audio")
	await get_tree().create_timer(0.35).timeout
	get_tree().quit()


func _fail(message: String, code: int) -> void:
	push_error("CI OPEN WORLD CHECK: %s" % message)
	get_tree().quit(code)
