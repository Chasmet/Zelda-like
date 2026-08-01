extends Node

const MAX_WAIT_SECONDS := 145.0


func _ready() -> void:
	if "--ci-critical-bug-check" not in OS.get_cmdline_user_args():
		return
	call_deferred("_run_check")


func _run_check() -> void:
	var game := get_parent()
	var started_at := Time.get_ticks_msec()
	while (Time.get_ticks_msec() - started_at) < int(MAX_WAIT_SECONDS * 1000.0):
		await get_tree().process_frame
		if not game.has_method("get_critical_bugfix_debug") or not game.has_method("get_portrait_front_debug") or not game.has_method("get_spawn_safety_debug") or not game.has_method("get_coastline_polish_debug"):
			continue
		var pending: Dictionary = game.call("get_critical_bugfix_debug")
		var pending_portrait: Dictionary = game.call("get_portrait_front_debug")
		var pending_spawn: Dictionary = game.call("get_spawn_safety_debug")
		var pending_coastline: Dictionary = game.call("get_coastline_polish_debug")
		if bool(pending.get("portrait_restored", false)) and bool(pending.get("water_material", false)) and bool(pending_portrait.get("portrait_front_applied", false)) and bool(pending_spawn.get("spawn_safety_applied", false)) and bool(pending_coastline.get("conforming_beach", false)):
			break

	if not game.has_method("get_critical_bugfix_debug"):
		_fail("le diagnostic V8 est absent", 80)
		return
	var state: Dictionary = game.call("get_critical_bugfix_debug")
	if String(state.get("version", "")) != "0.8.0-eau-et-portrait":
		_fail("la scène ne charge pas la V8 : %s" % state, 81)
		return
	if not bool(state.get("water_material", false)) or not bool(state.get("coastline_rebuilt", false)):
		_fail("la nouvelle eau ou le littoral n'est pas actif : %s" % state, 82)
		return
	var ocean_level: float = float(state.get("ocean_level", -0.92))
	if float(state.get("land_sample", -99.0)) <= ocean_level + 0.7:
		_fail("la place du village est immergée : %s" % state, 83)
		return
	if float(state.get("deep_sample", 99.0)) >= ocean_level - 1.5:
		_fail("le bord de carte reste un sol marchable au niveau de l'eau : %s" % state, 84)
		return
	if float(state.get("shore_sample", 99.0)) >= ocean_level:
		_fail("la pente côtière ne passe pas sous la surface : %s" % state, 85)
		return
	if not game.has_method("get_coastline_polish_debug"):
		_fail("la plage conforme V8.5 n'est pas chargée", 98)
		return
	var coastline_state: Dictionary = game.call("get_coastline_polish_debug")
	if String(coastline_state.get("version", "")) != "0.8.5-littoral-conforme" or not bool(coastline_state.get("conforming_beach", false)):
		_fail("la plage reste une plateforme plate : %s" % coastline_state, 99)
		return
	if int(coastline_state.get("beach_vertices", 0)) < 1500:
		_fail("le maillage de plage est trop grossier : %s" % coastline_state, 100)
		return
	if not bool(state.get("portrait_restored", false)):
		_fail("le panneau chevalier CHK HERO est absent", 86)
		return
	var portrait_rect: Rect2 = state.get("portrait_rect", Rect2())
	if portrait_rect.position.x < 0.0 or portrait_rect.position.y < 0.0 or portrait_rect.end.x > 1280.5 or portrait_rect.end.y > 720.5:
		_fail("le panneau CHK HERO sort de l'écran : %s" % portrait_rect, 87)
		return
	if portrait_rect.size.x < 150.0 or portrait_rect.size.y < 240.0:
		_fail("le panneau CHK HERO est trop petit : %s" % portrait_rect, 88)
		return
	if not game.has_method("get_portrait_front_debug"):
		_fail("la correction du chevalier de face n'est pas chargée", 93)
		return
	var portrait_state: Dictionary = game.call("get_portrait_front_debug")
	if not bool(portrait_state.get("portrait_front_applied", false)) or not bool(portrait_state.get("portrait_is_official", false)) or not bool(portrait_state.get("portrait_visible", false)):
		_fail("le panneau n'affiche pas le portrait officiel de face : %s" % portrait_state, 94)
		return
	if not game.has_method("get_spawn_safety_debug"):
		_fail("la sécurité du point de départ V8.4 n'est pas chargée", 95)
		return
	var spawn_state: Dictionary = game.call("get_spawn_safety_debug")
	if String(spawn_state.get("version", "")) != "0.8.4-spawn-securise" or not bool(spawn_state.get("spawn_safety_applied", false)):
		_fail("CHK Hero peut encore apparaître dans le puits : %s" % spawn_state, 96)
		return
	if float(spawn_state.get("well_distance", 0.0)) < float(spawn_state.get("minimum_distance", 5.5)):
		_fail("le point de départ reste trop proche du puits : %s" % spawn_state, 97)
		return
	if not bool(state.get("water_label_centered", false)):
		_fail("l'indicateur de nage reste coupé sur le côté", 89)
		return
	if absf(float(state.get("player_water_level", 999.0)) - ocean_level) > 0.02:
		_fail("le contrôleur et le visuel n'utilisent pas le même niveau d'eau : %s" % state, 90)
		return

	var player = game.get("player")
	if not is_instance_valid(player):
		_fail("le héros est absent", 91)
		return
	var original_position: Vector3 = player.global_position
	player.velocity = Vector3.ZERO
	player.global_position = Vector3(original_position.x, ocean_level - 0.55, original_position.z + 70.0)
	for _frame in range(10):
		await get_tree().physics_frame
	if not bool(player.is_swimming):
		_fail("le héros continue de marcher au lieu de nager sous la surface", 92)
		return

	player.global_position = original_position
	player.velocity = Vector3.ZERO
	player.is_swimming = false
	print("CI CRITICAL BUG CHECK OK: eau, plage conforme, nage, CHK HERO et point de départ sécurisé")
	if game.has_method("_shutdown_audio"):
		game.call("_shutdown_audio")
	await get_tree().create_timer(0.25).timeout
	get_tree().quit()


func _fail(message: String, code: int) -> void:
	push_error("CI CRITICAL BUG CHECK: %s" % message)
	get_tree().quit(code)
