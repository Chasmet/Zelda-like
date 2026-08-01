extends "res://scripts/main_portrait_front_v8_2.gd"

# V8.3 : l'ancien tutoriel occupait presque toute la largeur et cachait le jeu.
# Cette couche conserve les 13 étapes en français, mais les place dans une carte
# compacte sous la barre d'état, hors du joystick, des commandes et du portrait.

const V83_VERSION: String = "0.8.3-interface-mobile"
var tutorial_help_button: Button
var tutorial_compact_layout_ready: bool = false


func _build_tutorial_panel(root: Control) -> void:
	tutorial_panel = ColorRect.new()
	tutorial_panel.name = "TutorielFrançaisCompactV83"
	tutorial_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	tutorial_panel.position = Vector2(318.0, 96.0)
	tutorial_panel.size = Vector2(510.0, 112.0)
	tutorial_panel.color = Color(0.008, 0.022, 0.052, 0.90)
	tutorial_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	tutorial_panel.visible = false
	tutorial_panel.z_index = 72
	root.add_child(tutorial_panel)

	var accent := ColorRect.new()
	accent.name = "AccentTutoriel"
	accent.position = Vector2.ZERO
	accent.size = Vector2(6.0, 112.0)
	accent.color = Color(0.12, 0.68, 0.96, 0.96)
	accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tutorial_panel.add_child(accent)

	tutorial_step_label = Label.new()
	tutorial_step_label.name = "ÉtapeTutoriel"
	tutorial_step_label.position = Vector2(16.0, 8.0)
	tutorial_step_label.size = Vector2(220.0, 24.0)
	tutorial_step_label.add_theme_font_size_override("font_size", 14)
	tutorial_step_label.add_theme_constant_override("outline_size", 4)
	tutorial_step_label.modulate = Color(0.48, 0.84, 1.0)
	tutorial_step_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tutorial_panel.add_child(tutorial_step_label)

	tutorial_label = Label.new()
	tutorial_label.name = "TexteTutoriel"
	tutorial_label.position = Vector2(16.0, 34.0)
	tutorial_label.size = Vector2(350.0, 68.0)
	tutorial_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tutorial_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tutorial_label.add_theme_font_size_override("font_size", 15)
	tutorial_label.add_theme_constant_override("outline_size", 4)
	tutorial_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tutorial_panel.add_child(tutorial_label)

	var next_button := Button.new()
	next_button.name = "TutorielSuivant"
	next_button.text = "SUIVANT"
	next_button.position = Vector2(380.0, 14.0)
	next_button.size = Vector2(116.0, 42.0)
	next_button.add_theme_font_size_override("font_size", 14)
	next_button.pressed.connect(_next_tutorial)
	tutorial_panel.add_child(next_button)

	var hide_button := Button.new()
	hide_button.name = "TutorielMasquer"
	hide_button.text = "MASQUER"
	hide_button.position = Vector2(380.0, 62.0)
	hide_button.size = Vector2(116.0, 36.0)
	hide_button.add_theme_font_size_override("font_size", 12)
	hide_button.pressed.connect(_hide_tutorial_v83)
	tutorial_panel.add_child(hide_button)

	# L'aide peut être rouverte sans recommencer une partie. Le bouton est aligné
	# avec INVENTAIRE, JOURNAL et PAUSE au lieu de flotter devant le monde.
	tutorial_help_button = Button.new()
	tutorial_help_button.name = "RouvrirTutorielV83"
	tutorial_help_button.text = "? AIDE / TUTORIEL"
	tutorial_help_button.set_anchors_preset(Control.PRESET_TOP_LEFT)
	tutorial_help_button.position = Vector2(14.0, 330.0)
	tutorial_help_button.size = Vector2(220.0, 38.0)
	tutorial_help_button.add_theme_font_size_override("font_size", 12)
	tutorial_help_button.pressed.connect(_reopen_tutorial_v83)
	root.add_child(tutorial_help_button)

	tutorial_compact_layout_ready = true


func _hide_tutorial_v83() -> void:
	tutorial_completed = true
	if is_instance_valid(tutorial_panel):
		tutorial_panel.visible = false
	_show_message("Tutoriel masqué. Appuie sur ? AIDE pour le rouvrir.", 3.2)
	_save_progress()


func _reopen_tutorial_v83() -> void:
	if not is_instance_valid(tutorial_panel):
		return
	tutorial_completed = false
	tutorial_index = clampi(tutorial_index, 0, TUTORIAL_MESSAGES.size() - 1)
	tutorial_panel.visible = true
	_refresh_tutorial()


func _skip_tutorial() -> void:
	# Compatibilité avec les anciennes sauvegardes et d'éventuels appels existants.
	# Le panneau disparaît, mais le bouton ? AIDE permet toujours de le rouvrir.
	tutorial_completed = true
	if is_instance_valid(tutorial_panel):
		tutorial_panel.visible = false
	_show_message("Tutoriel désactivé. Appuie sur ? AIDE pour le rouvrir.", 3.5)
	_save_progress()


func get_mobile_ui_polish_debug() -> Dictionary:
	return {
		"version": V83_VERSION,
		"tutorial_compact": tutorial_compact_layout_ready,
		"tutorial_rect": tutorial_panel.get_global_rect() if is_instance_valid(tutorial_panel) else Rect2(),
		"help_rect": tutorial_help_button.get_global_rect() if is_instance_valid(tutorial_help_button) else Rect2(),
		"help_visible": tutorial_help_button.visible if is_instance_valid(tutorial_help_button) else false
	}
