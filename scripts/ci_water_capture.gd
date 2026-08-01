extends Node

const SCREENSHOT_PATH := "res://build/validation/Eau-Littoral-Nage.png"
const MAX_WAIT_SECONDS := 120.0


func _ready() -> void:
	if "--ci-water-shot" not in OS.get_cmdline_user_args():
		return
	call_deferred("_capture_water")


func _capture_water() -> void:
	var game := get_parent()
	var started_at := Time.get_ticks_msec()
	var player: Node3D = null
	while (Time.get_ticks_msec() - started_at) < int(MAX_WAIT_SECONDS * 1000.0):
		await get_tree().process_frame
		player = game.get("player") as Node3D
		var loading_screen = game.get("loading_screen")
		if is_instance_valid(player) and (not is_instance_valid(loading_screen) or not loading_screen.visible):
			break

	if not is_instance_valid(player):
		_fail("le héros n'est pas chargé", 101)
		return

	var center: Vector3 = game.ZONE_CENTERS[0]
	var beach_height: float = float(game.call("_zone_height", 0, 0.0, 37.0))
	player.velocity = Vector3.ZERO
	player.global_position = Vector3(center.x, beach_height + 0.08, center.z + 37.0)
	player.set("spawn_position", player.global_position)

	var pivot := player.get_node_or_null("CameraPivot") as Node3D
	var arm := player.get_node_or_null("CameraPivot/SpringArm") as SpringArm3D
	if not is_instance_valid(pivot) or not is_instance_valid(arm):
		_fail("la caméra troisième personne est absente", 102)
		return
	pivot.position = Vector3(0.0, 2.15, 0.0)
	pivot.rotation = Vector3(-0.075, PI, 0.0)
	arm.spring_length = 10.2

	var visual := player.get_node_or_null("Visual") as Node3D
	if is_instance_valid(visual):
		visual.rotation.y = PI

	if game.has_method("_update_live_hud"):
		game.call("_update_live_hud")

	await get_tree().create_timer(2.4).timeout
	# Les bannières ont leurs propres temporisateurs : les masquer juste avant
	# la capture garantit que la plage, la ligne d'écume et l'océan restent lisibles.
	var zone_banner = game.get("zone_banner")
	var message_label = game.get("message_label")
	if is_instance_valid(zone_banner):
		zone_banner.visible = false
	if is_instance_valid(message_label):
		message_label.text = ""
		message_label.visible = false
	await RenderingServer.frame_post_draw
	var output_path := ProjectSettings.globalize_path(SCREENSHOT_PATH)
	DirAccess.make_dir_recursive_absolute(output_path.get_base_dir())
	var image := get_viewport().get_texture().get_image()
	var save_error := image.save_png(output_path)
	if save_error != OK:
		_fail("échec de sauvegarde PNG %d" % save_error, 103)
		return
	print("CI WATER capture saved: %s" % output_path)
	if game.has_method("_shutdown_audio"):
		game.call("_shutdown_audio")
	get_tree().quit()


func _fail(message: String, code: int) -> void:
	push_error("CI WATER capture failed: %s" % message)
	get_tree().quit(code)
