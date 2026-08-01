extends Node

const SCREENSHOT_PATH := "res://build/validation/HUD-Carte-Portrait.png"
const MAX_WAIT_SECONDS := 110.0


func _ready() -> void:
	if "--ci-hud-shot" not in OS.get_cmdline_user_args():
		return
	call_deferred("_capture_loaded_hud")


func _capture_loaded_hud() -> void:
	var game := get_parent()
	var started_at := Time.get_ticks_msec()

	while (Time.get_ticks_msec() - started_at) < int(MAX_WAIT_SECONDS * 1000.0):
		await get_tree().process_frame
		if _hud_is_ready(game):
			await get_tree().create_timer(2.0).timeout
			if game.has_method("_update_live_hud"):
				game.call("_update_live_hud")
			await RenderingServer.frame_post_draw
			var output_path := ProjectSettings.globalize_path(SCREENSHOT_PATH)
			DirAccess.make_dir_recursive_absolute(output_path.get_base_dir())
			var image := get_viewport().get_texture().get_image()
			var save_error := image.save_png(output_path)
			if save_error != OK:
				push_error("CI HUD capture failed with error %d" % save_error)
				get_tree().quit(2)
				return
			print("CI HUD capture saved: %s" % output_path)
			get_tree().quit()
			return

	push_error("CI HUD capture timed out before the world and interface were ready")
	get_tree().quit(3)


func _hud_is_ready(game: Node) -> bool:
	if not is_instance_valid(game):
		return false
	var player = game.get("player")
	var mini_map_frame = game.get("mini_map_frame")
	var mini_map_marker = game.get("mini_map_marker")
	var portrait_viewport = game.get("portrait_viewport")
	var zone_label = game.get("zone_label")
	var loading_screen = game.get("loading_screen")
	if not is_instance_valid(player):
		return false
	if not is_instance_valid(mini_map_frame) or not is_instance_valid(mini_map_marker):
		return false
	if not is_instance_valid(portrait_viewport) or not is_instance_valid(zone_label):
		return false
	if is_instance_valid(loading_screen) and loading_screen.visible:
		return false
	return true
