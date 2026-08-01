extends Node

const MAX_WAIT_SECONDS := 135.0
const EXPECTED_BRIDGES := 11


func _ready() -> void:
	if "--ci-visual-quality-check" not in OS.get_cmdline_user_args():
		return
	call_deferred("_run_check")


func _run_check() -> void:
	var game := get_parent()
	var started_at := Time.get_ticks_msec()
	while (Time.get_ticks_msec() - started_at) < int(MAX_WAIT_SECONDS * 1000.0):
		await get_tree().process_frame
		if game.has_method("get_visual_overhaul_debug"):
			var state: Dictionary = game.call("get_visual_overhaul_debug")
			if bool(state.get("camera_upgraded", false)) and int(state.get("terrain_shaders", 0)) == 10:
				break

	if not game.has_method("get_visual_overhaul_debug"):
		_fail("le diagnostic de qualité V6 est absent", 60)
		return
	var state: Dictionary = game.call("get_visual_overhaul_debug")
	if String(state.get("version", "")) != "0.6.0-qualite-visuelle":
		_fail("la scène ne charge pas la passe V6 : %s" % state, 61)
		return
	if int(state.get("terrain_shaders", 0)) != 10:
		_fail("les dix terrains n'utilisent pas leurs matériaux multi-échelles : %s" % state, 62)
		return
	if int(state.get("authored_detail_instances", 0)) < 700:
		_fail("le monde reste trop vide : moins de 700 détails déterministes : %s" % state, 63)
		return
	if int(state.get("bridges", 0)) != EXPECTED_BRIDGES:
		_fail("les onze liaisons réelles de la carte n'ont pas toutes été reconstruites : %s" % state, 64)
		return
	if int(state.get("atmospheres", 0)) != 5:
		_fail("les cinq biomes météo n'ont pas leur atmosphère locale : %s" % state, 65)
		return
	if not bool(state.get("camera_upgraded", false)) or float(state.get("camera_distance", 0.0)) < 8.0:
		_fail("la caméra reste trop proche du héros : %s" % state, 66)
		return
	if not bool(state.get("hud_compact", false)):
		_fail("le HUD mobile n'a pas été compacté", 67)
		return
	if float(state.get("start_region_distance", 0.0)) < 20.0:
		_fail("CHK Hero démarre encore sur le raccord du pont au lieu de la place du village", 68)
		return

	var game_state: Dictionary = game.call("get_open_world_debug") if game.has_method("get_open_world_debug") else {}
	if int(game_state.get("regions", 0)) != 10 or int(game_state.get("population_profiles", 0)) != 200:
		_fail("la passe visuelle a cassé les systèmes V5 : %s" % game_state, 69)
		return
	var player = game.get("player")
	if not is_instance_valid(player):
		_fail("le héros n'est pas disponible après la passe visuelle", 70)
		return
	var arm := player.get_node_or_null("CameraPivot/SpringArm") as SpringArm3D
	if not is_instance_valid(arm) or absf(arm.spring_length - 8.4) > 0.05:
		_fail("la distance réelle de caméra ne correspond pas au diagnostic", 71)
		return
	var controls_help = game.get("controls_help_label")
	if is_instance_valid(controls_help) and controls_help.visible:
		_fail("l'aide permanente masque encore le bas de l'écran", 72)
		return

	print("CI VISUAL QUALITY CHECK OK: shaders=10 détails=%d ponts=%d atmosphères=5 caméra=%.1f HUD=compact" % [int(state.get("authored_detail_instances", 0)), EXPECTED_BRIDGES, float(state.get("camera_distance", 0.0))])
	if game.has_method("_shutdown_audio"):
		game.call("_shutdown_audio")
	await get_tree().create_timer(0.25).timeout
	get_tree().quit()


func _fail(message: String, code: int) -> void:
	push_error("CI VISUAL QUALITY CHECK: %s" % message)
	get_tree().quit(code)