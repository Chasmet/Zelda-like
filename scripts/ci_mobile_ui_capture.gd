extends Node

const SCREENSHOT_PATH := "res://build/validation/Interface-Mobile-Tutoriel.png"
const MAX_WAIT_SECONDS := 125.0


func _ready() -> void:
	if "--ci-mobile-ui-shot" not in OS.get_cmdline_user_args():
		return
	call_deferred("_capture_mobile_ui")


func _capture_mobile_ui() -> void:
	var game := get_parent()
	var started_at := Time.get_ticks_msec()
	while (Time.get_ticks_msec() - started_at) < int(MAX_WAIT_SECONDS * 1000.0):
		await get_tree().process_frame
		if game.has_method("get_mobile_ui_polish_debug"):
			var pending: Dictionary = game.call("get_mobile_ui_polish_debug")
			if bool(pending.get("tutorial_compact", false)):
				break

	if not game.has_method("_reopen_tutorial_v83"):
		_fail("la V8.3 n'est pas chargée", 130)
		return
	game.call("_reopen_tutorial_v83")
	var zone_banner = game.get("zone_banner")
	var message_label = game.get("message_label")
	if is_instance_valid(zone_banner):
		zone_banner.visible = false
	if is_instance_valid(message_label):
		message_label.text = ""
		message_label.visible = false
	await get_tree().create_timer(1.6).timeout
	await RenderingServer.frame_post_draw

	var output_path := ProjectSettings.globalize_path(SCREENSHOT_PATH)
	DirAccess.make_dir_recursive_absolute(output_path.get_base_dir())
	var image := get_viewport().get_texture().get_image()
	var save_error := image.save_png(output_path)
	if save_error != OK:
		_fail("échec de sauvegarde PNG %d" % save_error, 131)
		return
	print("CI MOBILE UI capture saved: %s" % output_path)
	if game.has_method("_shutdown_audio"):
		game.call("_shutdown_audio")
	get_tree().quit()


func _fail(message: String, code: int) -> void:
	push_error("CI MOBILE UI capture failed: %s" % message)
	get_tree().quit(code)
