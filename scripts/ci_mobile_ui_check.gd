extends Node

const MAX_WAIT_SECONDS := 145.0
const ACTION_TEXTS := ["ATTAQUE", "SAUT", "ESQUIVE", "ACTION", "PLONGER"]


func _ready() -> void:
	if "--ci-mobile-ui-check" not in OS.get_cmdline_user_args():
		return
	call_deferred("_run_check")


func _run_check() -> void:
	var game := get_parent()
	var started_at := Time.get_ticks_msec()
	while (Time.get_ticks_msec() - started_at) < int(MAX_WAIT_SECONDS * 1000.0):
		await get_tree().process_frame
		if game.has_method("get_mobile_ui_polish_debug"):
			var pending: Dictionary = game.call("get_mobile_ui_polish_debug")
			if bool(pending.get("tutorial_compact", false)):
				break

	if not game.has_method("get_mobile_ui_polish_debug"):
		_fail("la finition mobile V8.3 n'est pas chargée", 110)
		return
	game.call("_reopen_tutorial_v83")
	await get_tree().process_frame

	var state: Dictionary = game.call("get_mobile_ui_polish_debug")
	if String(state.get("version", "")) != "0.8.3-interface-mobile":
		_fail("mauvaise version d'interface : %s" % state, 111)
		return
	if not bool(state.get("tutorial_compact", false)) or not bool(state.get("help_visible", false)):
		_fail("le tutoriel compact ou le bouton AIDE est absent : %s" % state, 112)
		return

	var screen_rect := Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size)
	var tutorial_rect: Rect2 = state.get("tutorial_rect", Rect2())
	var help_rect: Rect2 = state.get("help_rect", Rect2())
	if not _inside_screen(tutorial_rect, screen_rect):
		_fail("le tutoriel sort de l'écran : %s" % tutorial_rect, 113)
		return
	if not _inside_screen(help_rect, screen_rect):
		_fail("le bouton AIDE sort de l'écran : %s" % help_rect, 114)
		return
	if tutorial_rect.size.x > 540.0 or tutorial_rect.size.y > 125.0:
		_fail("le tutoriel masque encore trop le jeu : %s" % tutorial_rect, 115)
		return
	if tutorial_rect.get_area() > screen_rect.get_area() * 0.08:
		_fail("le tutoriel occupe plus de 8 %% de l'écran : %s" % tutorial_rect, 116)
		return

	var joystick = game.get("fixed_joystick_base")
	if not is_instance_valid(joystick):
		_fail("le joystick fixe est absent", 117)
		return
	var joystick_rect: Rect2 = joystick.get_global_rect()
	if not _inside_screen(joystick_rect, screen_rect):
		_fail("le joystick sort de l'écran : %s" % joystick_rect, 118)
		return
	if tutorial_rect.intersects(joystick_rect):
		_fail("le tutoriel recouvre le joystick", 119)
		return

	var portrait = game.get("v8_portrait_panel")
	if not is_instance_valid(portrait):
		_fail("le panneau CHK HERO est absent", 120)
		return
	var portrait_rect: Rect2 = portrait.get_global_rect()
	if tutorial_rect.intersects(portrait_rect):
		_fail("le tutoriel recouvre CHK HERO", 121)
		return

	var action_buttons: Array[Button] = []
	_collect_action_buttons(game, action_buttons)
	if action_buttons.size() < ACTION_TEXTS.size():
		_fail("commandes tactiles incomplètes : %d / %d" % [action_buttons.size(), ACTION_TEXTS.size()], 122)
		return
	for button in action_buttons:
		var button_rect: Rect2 = button.get_global_rect()
		if not _inside_screen(button_rect, screen_rect):
			_fail("la commande %s sort de l'écran : %s" % [button.text, button_rect], 123)
			return
		if tutorial_rect.intersects(button_rect):
			_fail("le tutoriel recouvre la commande %s" % button.text, 124)
			return

	var message_label = game.get("message_label")
	if is_instance_valid(message_label):
		var message_rect: Rect2 = message_label.get_global_rect()
		if absf(message_rect.get_center().x - screen_rect.get_center().x) > 4.0:
			_fail("les notifications ne sont pas centrées : %s" % message_rect, 125)
			return

	print("CI MOBILE UI CHECK OK: tutoriel=%s joystick=%s commandes=%d" % [tutorial_rect, joystick_rect, action_buttons.size()])
	if game.has_method("_shutdown_audio"):
		game.call("_shutdown_audio")
	await get_tree().create_timer(0.2).timeout
	get_tree().quit()


func _collect_action_buttons(node: Node, output: Array[Button]) -> void:
	for child in node.get_children():
		if child is Button and child.visible and String(child.text) in ACTION_TEXTS:
			output.append(child as Button)
		_collect_action_buttons(child, output)


func _inside_screen(rect: Rect2, screen_rect: Rect2) -> bool:
	return rect.size.x > 0.0 and rect.size.y > 0.0 and rect.position.x >= -0.5 and rect.position.y >= -0.5 and rect.end.x <= screen_rect.end.x + 0.5 and rect.end.y <= screen_rect.end.y + 0.5


func _fail(message: String, code: int) -> void:
	push_error("CI MOBILE UI CHECK: %s" % message)
	get_tree().quit(code)
