extends "res://scripts/main_v4.gd"

var _boot_layer: CanvasLayer
var _boot_label: Label
var _boot_camera: Camera3D

func _ready() -> void:
	seed(20260801)
	if OS.has_feature("mobile"):
		DisplayServer.screen_set_orientation(DisplayServer.SCREEN_SENSOR_LANDSCAPE)
	_setup_input()
	_build_boot_screen()
	_build_environment()
	await get_tree().process_frame

	for zone_index in range(ZONE_CENTERS.size()):
		_set_boot_text("Chargement de la zone %d / 10\n%s" % [zone_index + 1, ZONE_NAMES[zone_index]])
		_build_zone_light(zone_index)
		await get_tree().process_frame

	_set_boot_text("Connexion des dix zones…")
	_build_connectors()
	_build_progression_gates()
	await get_tree().process_frame

	_set_boot_text("Chargement du héros et des gardiens…")
	_spawn_player()
	_spawn_zone_enemies_light()
	_build_hud()
	_play_music(MUSIC_WORLD)
	_load_progress()
	_update_hud()
	await get_tree().process_frame

	_finish_boot_screen()
	_show_message("Monde ouvert chargé — 10 zones", 3.5)

func _build_boot_screen() -> void:
	_boot_camera = Camera3D.new()
	_boot_camera.name = "BootCamera"
	_boot_camera.position = ZONE_CENTERS[0] + Vector3(0.0, 30.0, 34.0)
	add_child(_boot_camera)
	_boot_camera.look_at(ZONE_CENTERS[0], Vector3.UP)
	_boot_camera.current = true

	_boot_layer = CanvasLayer.new()
	_boot_layer.layer = 100
	add_child(_boot_layer)
	var background := ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = Color(0.018, 0.035, 0.075, 1.0)
	_boot_layer.add_child(background)

	var title := Label.new()
	title.text = "LES CHRONIQUES DE SKYPIEA"
	title.set_anchors_preset(Control.PRESET_CENTER)
	title.position = Vector2(-360.0, -95.0)
	title.size = Vector2(720.0, 55.0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	background.add_child(title)

	_boot_label = Label.new()
	_boot_label.text = "Initialisation du moteur 3D…"
	_boot_label.set_anchors_preset(Control.PRESET_CENTER)
	_boot_label.position = Vector2(-360.0, -20.0)
	_boot_label.size = Vector2(720.0, 90.0)
	_boot_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boot_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_boot_label.add_theme_font_size_override("font_size", 23)
	background.add_child(_boot_label)

	var hint := Label.new()
	hint.text = "Optimisation Android — ne ferme pas l’application"
	hint.set_anchors_preset(Control.PRESET_CENTER)
	hint.position = Vector2(-360.0, 85.0)
	hint.size = Vector2(720.0, 40.0)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.modulate = Color(0.68, 0.78, 0.92)
	hint.add_theme_font_size_override("font_size", 17)
	background.add_child(hint)

func _set_boot_text(text: String) -> void:
	if is_instance_valid(_boot_label):
		_boot_label.text = text

func _finish_boot_screen() -> void:
	if is_instance_valid(_boot_layer):
		_boot_layer.queue_free()
	if is_instance_valid(_boot_camera):
		_boot_camera.queue_free()

func _build_zone_light(zone_index: int) -> void:
	var center := ZONE_CENTERS[zone_index]
	_static_box("Zone_%02d_Ground" % (zone_index + 1), Vector3(50.0, 1.2, 46.0), center + Vector3(0.0, -0.6, 0.0), ZONE_COLORS[zone_index])
	_add_zone_title(zone_index, center + Vector3(0.0, 4.8, -18.5))

	match zone_index:
		0:
			for offset in [Vector3(-11, 0, -8), Vector3(11, 0, -8), Vector3(-11, 0, 10), Vector3(11, 0, 10)]:
				_spawn_model(HOUSE_MODEL, center + offset, Vector3.ONE * 0.88)
			for offset in [Vector3(-19, 0, -16), Vector3(19, 0, -16), Vector3(-19, 0, 16), Vector3(19, 0, 16)]:
				_spawn_model(TREE_MODEL, center + offset, Vector3.ONE * 0.84)
			_visual_box("VillagePath", Vector3(7.0, 0.10, 34.0), center + Vector3(0, 0.06, 0), Color(0.48, 0.34, 0.20))
		1:
			for index in range(10):
				var x := -20.0 + float(index % 5) * 10.0
				var z := -14.0 + float(index / 5) * 27.0
				_spawn_model(TREE_MODEL, center + Vector3(x, 0, z), Vector3.ONE * (0.82 + float(index % 3) * 0.08), Vector3(0, float(index) * 0.4, 0))
		2:
			_visual_box("SwampPoolA", Vector3(14.0, 0.05, 9.0), center + Vector3(-11, 0.06, -8), Color(0.06, 0.26, 0.20, 0.78))
			_visual_box("SwampPoolB", Vector3(14.0, 0.05, 9.0), center + Vector3(11, 0.06, 9), Color(0.06, 0.26, 0.20, 0.78))
			for offset in [Vector3(-19, 0, -16), Vector3(19, 0, -16), Vector3(-19, 0, 16), Vector3(19, 0, 16)]:
				_spawn_model(TREE_MODEL, center + offset, Vector3(0.65, 0.88, 0.65))
		3:
			for side in [-1.0, 1.0]:
				for index in range(5):
					_static_box("CanyonWall", Vector3(5.0, 5.0, 5.0), center + Vector3(side * 18.0, 2.5, -16.0 + float(index) * 8.0), Color(0.42, 0.16, 0.07))
		4:
			for index in range(7):
				var px := -18.0 + float(index % 4) * 12.0
				var pz := -12.0 + float(index / 4) * 24.0
				_dune(center + Vector3(px, 0.35, pz), 2.0 + float(index % 3) * 0.4)
			_spawn_model(RUIN_MODEL, center + Vector3(0, 0, -12), Vector3.ONE * 1.08)
		5:
			_visual_box("Lagoon", Vector3(44.0, 0.06, 14.0), center + Vector3(0, 0.08, -14), Color(0.02, 0.40, 0.61, 0.82))
			_spawn_model(BOAT_MODEL, center + Vector3(0, 0.12, -13), Vector3.ONE * 0.88, Vector3(0, -0.35, 0))
			for x in [-18.0, -6.0, 6.0, 18.0]:
				_spawn_model(TREE_MODEL, center + Vector3(x, 0, 13), Vector3(0.56, 0.88, 0.56))
		6:
			for index in range(8):
				var angle := TAU * float(index) / 8.0
				_ice_crystal(center + Vector3(cos(angle) * 16.0, 0, sin(angle) * 14.0), 1.3 + float(index % 2) * 0.35)
		7:
			_visual_box("LavaPoolA", Vector3(13.0, 0.08, 8.0), center + Vector3(-11, 0.09, -8), Color(0.92, 0.11, 0.01), Color(1.0, 0.04, 0.0))
			_visual_box("LavaPoolB", Vector3(13.0, 0.08, 8.0), center + Vector3(11, 0.09, 9), Color(0.92, 0.11, 0.01), Color(1.0, 0.04, 0.0))
			for offset in [Vector3(-19, 1, -16), Vector3(19, 1, -16), Vector3(-19, 1, 16), Vector3(19, 1, 16)]:
				_rock(center + offset, Vector3(3.0, 2.0, 2.6), Color(0.10, 0.08, 0.075))
		8:
			for index in range(5):
				var x := -18.0 + float(index) * 9.0
				_visual_box("SkyPlatform", Vector3(11.0, 0.8, 9.0), center + Vector3(x, 0.4 + float(index % 2) * 0.4, 0), Color(0.56, 0.66, 0.74))
			_spawn_model(RUIN_MODEL, center + Vector3(0, 0, -13), Vector3.ONE * 1.1)
		9:
			_spawn_model(RUIN_MODEL, center + Vector3(0, 0, 8), Vector3.ONE * 1.5)
			for x in [-18.0, -8.0, 8.0, 18.0]:
				_static_box("CitadelTower", Vector3(5.0, 9.0, 5.0), center + Vector3(x, 4.5, -10.0), Color(0.08, 0.07, 0.11))

func _spawn_zone_enemies_light() -> void:
	zone_enemies_remaining.resize(ZONE_CENTERS.size())
	zone_enemies_total.resize(ZONE_CENTERS.size())
	zone_enemies_remaining.fill(0)
	zone_enemies_total.fill(0)
	for zone_index in range(1, ZONE_CENTERS.size()):
		var count := 2 if zone_index == 9 else 1
		zone_enemies_remaining[zone_index] = count
		zone_enemies_total[zone_index] = count
		for enemy_index in range(count):
			var enemy := ENEMY_SCRIPT.new() as EnemyController
			enemy.name = "Zone_%02d_Guardian_%02d" % [zone_index + 1, enemy_index + 1]
			enemy.position = ZONE_CENTERS[zone_index] + Vector3(-5.0 + float(enemy_index) * 10.0, 0.35, 3.0)
			enemy.set_meta("zone_index", zone_index)
			add_child(enemy)
			var model_index := (zone_index + enemy_index - 1) % ENEMY_MODELS.size()
			enemy.setup(player, model_index, ENEMY_MODELS[model_index])
			enemy.defeated.connect(_on_enemy_defeated)
			enemies.append(enemy)
