extends Node3D

const PLAYER_SCRIPT = preload("res://scripts/player.gd")
const ENEMY_SCRIPT = preload("res://scripts/enemy.gd")
const WORLD_CLOCK_SCRIPT = preload("res://scripts/world/world_clock_weather.gd")
const POPULATION_SCRIPT = preload("res://scripts/world/population_manager.gd")
const PLAYER_BOAT_SCRIPT = preload("res://scripts/world/player_boat.gd")
const WILDLIFE_SCRIPT = preload("res://scripts/world/wildlife_manager.gd")
const ADVENTURE_SCRIPT = preload("res://scripts/game/adventure_progress.gd")
const AMBIENT_AUDIO_SCRIPT = preload("res://scripts/world/ambient_audio_manager.gd")
const AUTONOMOUS_BOAT_SCRIPT = preload("res://scripts/world/autonomous_boat.gd")

const WORLD_MAP_PATH = "res://carte monde.png"
const HERO_MODEL = "res://generated_models/hero_knight.glb"
const HERO_FALLBACK = "res://assets/characters/chk_hero.png"
const TREE_MODEL = "res://generated_models/world_tree.glb"
const HOUSE_MODEL = "res://generated_models/village_house.glb"
const RUIN_MODEL = "res://generated_models/ruin_gate.glb"
const BOAT_MODEL = "res://generated_models/boat.glb"
const MUSIC_WORLD_PATH = "res://music.mp3"
const MUSIC_BATTLE_PATH = "res://music 2.mp3"
const SAVE_PATH = "user://skypiea_worldmap_v2.cfg"
const SAVE_BACKUP_PATH = "user://skypiea_worldmap_v2.backup.cfg"
const SAVE_TEMP_PATH = "user://skypiea_worldmap_v2.temp.cfg"

const ENEMY_MODELS = [
	"res://generated_models/enemy_01_armored_boar.glb",
	"res://generated_models/enemy_02_crystal_golem.glb",
	"res://generated_models/enemy_03_lava_hound.glb",
	"res://generated_models/enemy_04_anubis_knight.glb",
	"res://generated_models/enemy_05_goblin_raider.glb",
	"res://generated_models/enemy_06_ice_ogre.glb",
	"res://generated_models/enemy_07_orc_warlord.glb"
]

# Ordre officiel du monde. Chaque région conserve un centre et une identité fixes :
# le relief, les routes et les points d'intérêt sont déterministes et placés à la main.
const ZONE_NAMES = [
	"Village côtier",
	"Grande forêt",
	"Montagnes rocheuses",
	"Plaines agricoles",
	"Région volcanique",
	"Marais brumeux",
	"Désert de cendres",
	"Grand port commercial",
	"Ruines antiques",
	"Montagnes enneigées"
]

const ZONE_CENTERS = [
	Vector3(-270.0, 0.0, 155.0), # 1 côte sud-ouest
	Vector3(-90.0, 0.0, 75.0),   # 2 forêt intérieure
	Vector3(90.0, 0.0, -75.0),   # 3 chaîne rocheuse
	Vector3(90.0, 0.0, 155.0),   # 4 terres cultivées
	Vector3(-270.0, 0.0, -155.0),# 5 volcan
	Vector3(270.0, 0.0, 155.0),  # 6 marais
	Vector3(270.0, 0.0, -155.0), # 7 cendres
	Vector3(-270.0, 0.0, 0.0),   # 8 port
	Vector3(270.0, 0.0, 0.0),    # 9 ruines
	Vector3(90.0, 0.0, -230.0)   # 10 neige
]

const MAP_MARKERS = [
	Vector2(0.14, 0.78),
	Vector2(0.40, 0.59),
	Vector2(0.59, 0.38),
	Vector2(0.59, 0.78),
	Vector2(0.14, 0.18),
	Vector2(0.86, 0.78),
	Vector2(0.86, 0.38),
	Vector2(0.14, 0.49),
	Vector2(0.86, 0.49),
	Vector2(0.59, 0.12)
]

const ZONE_BASE_COLORS = [
	Color(0.38, 0.55, 0.25),
	Color(0.045, 0.20, 0.055),
	Color(0.34, 0.32, 0.30),
	Color(0.38, 0.52, 0.17),
	Color(0.12, 0.075, 0.055),
	Color(0.055, 0.16, 0.095),
	Color(0.25, 0.24, 0.23),
	Color(0.34, 0.30, 0.22),
	Color(0.47, 0.39, 0.23),
	Color(0.66, 0.77, 0.84)
]

const ZONE_ACCENT_COLORS = [
	Color(0.16, 0.72, 0.86),
	Color(0.15, 0.58, 0.12),
	Color(0.70, 0.66, 0.59),
	Color(0.82, 0.68, 0.20),
	Color(0.94, 0.15, 0.015),
	Color(0.12, 0.48, 0.25),
	Color(0.58, 0.54, 0.48),
	Color(0.04, 0.60, 0.78),
	Color(0.86, 0.67, 0.28),
	Color(0.86, 0.95, 1.0)
]

const START_ZONE = 0
# 152 × 136 = 20 672 m², soit 10,70 fois la surface précédente (46 × 42).
const TERRAIN_SIZE = Vector2(152.0, 136.0)
const TERRAIN_STEPS = 48
const REGION_LAYOUT_SCALE = 3.30

const POINT_OF_INTEREST_NAMES = [
	"Phare des Trois-Vents",
	"Clairière des Chênes anciens",
	"Belvédère de la mine haute",
	"Moulin des Quatre-Champs",
	"Sanctuaire de basalte",
	"Autel des lueurs du marais",
	"Camp de la caravane ensevelie",
	"Capitainerie du grand port",
	"Temple de la Première Aube",
	"Cloche du sommet blanc"
]

const POINT_OF_INTEREST_OFFSETS = [
	Vector3(-14.0, 0.0, -12.0),
	Vector3(12.0, 0.0, -10.0),
	Vector3(13.0, 0.0, 9.0),
	Vector3(-11.0, 0.0, 12.0),
	Vector3(10.0, 0.0, -13.0),
	Vector3(-12.0, 0.0, 10.0),
	Vector3(14.0, 0.0, 7.0),
	Vector3(-10.0, 0.0, -11.0),
	Vector3(11.0, 0.0, 12.0),
	Vector3(-9.0, 0.0, 13.0)
]

const REGION_RESOURCE_NAMES = [
	["Coquillage nacré", "ressource marine"],
	["Champignon lunaire", "plante"],
	["Minerai de montagne", "minerai"],
	["Pomme du verger", "nourriture"],
	["Obsidienne", "minerai"],
	["Roseau médicinal", "plante"],
	["Éclat de cendre", "ressource"],
	["Cargaison scellée", "objet vendable"],
	["Tablette antique", "trésor"],
	["Cristal de givre", "objet rare"]
]

const TUTORIAL_MESSAGES = [
	"Déplacement : utilise le joystick gauche pour marcher dans toutes les directions.",
	"Caméra : fais glisser ton doigt sur la partie droite de l'écran pour regarder autour de toi.",
	"Course : maintiens la commande de course au clavier ; sur mobile, pousse complètement le joystick.",
	"Saut : touche SAUT pour franchir un obstacle ou remonter quand tu nages.",
	"Interaction : approche-toi d'un habitant, d'un coffre ou d'un bateau puis touche ACTION.",
	"Dialogues : lis les réponses en français, choisis LA RÉGION ou BESOIN D'AIDE, puis QUITTER.",
	"Inventaire : ouvre INVENTAIRE pour consulter, utiliser ou vendre les objets récupérés.",
	"Carte : ouvre la carte complète ; les étoiles n'apparaissent qu'après la découverte d'un lieu.",
	"Quêtes : accepte une mission auprès d'un PNJ puis suis son objectif dans JOURNAL.",
	"Nage : entre dans l'océan ; le héros passe automatiquement de la marche à la nage.",
	"Plongée : touche PLONGER pour descendre et SAUT pour remonter. Surveille le niveau de profondeur.",
	"Ramassage : les ressources brillantes et les coffres s'ajoutent au sac avec ACTION.",
	"Pause : ouvre PAUSE / RÉGLAGES pour sauvegarder, changer la qualité ou débloquer CHK HERO."
]

var player
var enemies = []
var zone_remaining = []
var zone_total = []
var zone_completed = []
var current_zone = START_ZONE
var total_defeated = 0
var game_complete = false

var virtual_move = Vector2.ZERO
var move_touch_id = -1
var look_touch_id = -1
var move_origin = Vector2.ZERO
var joystick_knob

var health_label
var zone_label
var objective_label
var message_label
var map_panel
var map_frame
var map_player_marker
var map_zone_label
var map_status_label
var map_button
var zone_banner
var zone_banner_token = 0
var world_status_label
var dialogue_panel
var dialogue_name_label
var dialogue_text_label
var dialogue_continue_button
var dialogue_region_button
var dialogue_quest_button
var dialogue_buy_button: Button
var dialogue_sell_button: Button
var active_dialogue: Dictionary = {}
var active_dialogue_line: int = 0

var music_player
var battle_music_active = false
var zone_check_timer = 0.0
var message_token = 0
var terrain_material_cache = {}
var zone_roots = []
var active_build_parent: Node3D
var world_clock: WorldClockWeather
var population_manager: PopulationManager
var wildlife_manager: WildlifeManager
var adventure_progress: AdventureProgress
var ambient_audio_manager: AmbientAudioManager
var player_boats: Array[PlayerBoat] = []
var autonomous_boats: Array[AutonomousBoat] = []
var controlled_boat: PlayerBoat
var collectible_nodes: Array[Node3D] = []
var point_of_interest_nodes: Array[Node3D] = []
var adventure_panel: Control
var adventure_title_label: Label
var adventure_content_label: RichTextLabel
var adventure_panel_mode: String = "inventaire"
var adventure_inventory_button: Button
var adventure_journal_button: Button
var adventure_use_button: Button
var adventure_sell_button: Button
var pause_panel: Control
var title_panel: Control
var quality_status_label: Label
var water_depth_label: Label
var map_discovery_markers: Array[Label] = []
var tutorial_panel: Control
var tutorial_label: Label
var tutorial_step_label: Label
var tutorial_index: int = 0
var tutorial_completed: bool = false
var night_lights: Array[OmniLight3D] = []
var autosave_timer: Timer
var ancient_switches: Array[StaticBody3D] = []
var ancient_gate: StaticBody3D
var ancient_puzzle_chest: StaticBody3D
var movement_slowed: bool = false
var hazard_tick: float = 0.0
var graphics_quality: String = "moyen"

var boot_layer
var boot_label
var boot_camera
var world_environment_node: WorldEnvironment
var environment_state: Environment
var sun_light: DirectionalLight3D
var ocean_surface: MeshInstance3D

var capital_portal_position = Vector3.ZERO
var sky_portal_position = Vector3.ZERO


func _ready():
	seed(20260801)
	if OS.has_feature("mobile"):
		DisplayServer.screen_set_orientation(DisplayServer.SCREEN_SENSOR_LANDSCAPE)

	_setup_input()
	_build_loading_screen()
	await get_tree().process_frame

	_set_loading_text("Création du ciel, de l'océan et des textures…")
	_build_environment()
	await get_tree().process_frame

	for zone_index in range(ZONE_CENTERS.size()):
		_set_loading_text("Construction du relief %d / 10\n%s" % [zone_index + 1, ZONE_NAMES[zone_index]])
		_build_zone(zone_index)
		await get_tree().process_frame

	_set_loading_text("Création des routes, ponts et repères…")
	_build_routes()
	_build_portals()
	_update_region_streaming()
	await get_tree().process_frame

	_set_loading_text("Chargement du héros…")
	_spawn_player()
	_setup_player_boats()
	_setup_autonomous_boats()
	await get_tree().process_frame

	_set_loading_text("Placement des gardiens…")
	_spawn_guardians()
	_update_region_streaming()
	await get_tree().process_frame

	_build_hud()
	_setup_world_clock()
	_setup_ambient_audio()
	_setup_population()
	_setup_wildlife()
	_setup_adventure_system()
	_apply_graphics_quality(false)
	_load_progress()
	_setup_autosave()
	_update_hud()
	_update_map_marker()
	_play_music(MUSIC_WORLD_PATH)
	_finish_loading()
	_show_zone_banner()
	_show_message("La carte est disponible avec le bouton CARTE", 4.5)
	if not _is_ci_mode():
		_show_title_screen()


func _process(delta):
	if not is_instance_valid(player):
		return

	if is_instance_valid(controlled_boat) and controlled_boat.boarded:
		controlled_boat.set_virtual_move(virtual_move)
		player.set_virtual_move(Vector2.ZERO)
	else:
		player.set_virtual_move(virtual_move)
	if is_instance_valid(world_clock):
		world_clock.set_underwater(player.is_swimming and player.swim_depth > 0.65, player.swim_depth)
	if is_instance_valid(ambient_audio_manager):
		ambient_audio_manager.set_underwater(player.is_swimming and player.swim_depth > 0.65, player.swim_depth)
	_update_water_depth_indicator()
	zone_check_timer -= delta
	if zone_check_timer <= 0.0:
		zone_check_timer = 0.18
		_update_current_zone()
		_update_nearby_discoveries()
		_update_night_lights()
		_update_region_movement_effects()

	if is_instance_valid(map_player_marker):
		var pulse = 1.0 + sin(Time.get_ticks_msec() * 0.006) * 0.12
		map_player_marker.scale = Vector2.ONE * pulse

	_update_battle_music()
	_update_environmental_hazards(delta)


func _notification(what):
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save_progress()
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE:
		_shutdown_audio()


func _shutdown_audio():
	if is_instance_valid(ambient_audio_manager):
		ambient_audio_manager.shutdown()
	if is_instance_valid(music_player):
		music_player.stop()
		music_player.stream = null


func _setup_autosave():
	autosave_timer = Timer.new()
	autosave_timer.name = "SauvegardeAutomatique"
	autosave_timer.wait_time = 45.0
	autosave_timer.one_shot = false
	autosave_timer.timeout.connect(_save_progress)
	add_child(autosave_timer)
	autosave_timer.start()


func _unhandled_input(event):
	if event is InputEventScreenTouch:
		var screen_size = get_viewport().get_visible_rect().size
		if is_instance_valid(map_panel) and map_panel.visible:
			return
		if event.pressed and event.position.x < screen_size.x * 0.43 and event.position.y > screen_size.y * 0.28 and move_touch_id < 0:
			move_touch_id = event.index
			move_origin = event.position
			_update_joystick(event.position)
		elif event.pressed and look_touch_id < 0:
			look_touch_id = event.index
		elif not event.pressed and event.index == move_touch_id:
			move_touch_id = -1
			virtual_move = Vector2.ZERO
			_reset_joystick()
		elif not event.pressed and event.index == look_touch_id:
			look_touch_id = -1
	elif event is InputEventScreenDrag:
		if is_instance_valid(map_panel) and map_panel.visible:
			return
		if event.index == move_touch_id:
			_update_joystick(event.position)
		elif event.index == look_touch_id and is_instance_valid(player):
			player.add_camera_look(event.relative * 0.0042)


func _setup_input():
	_add_key("move_forward", KEY_W)
	_add_key("move_forward", KEY_Z)
	_add_key("move_forward", KEY_UP)
	_add_key("move_back", KEY_S)
	_add_key("move_back", KEY_DOWN)
	_add_key("move_left", KEY_A)
	_add_key("move_left", KEY_Q)
	_add_key("move_left", KEY_LEFT)
	_add_key("move_right", KEY_D)
	_add_key("move_right", KEY_RIGHT)
	_add_key("jump", KEY_SPACE)
	_add_key("attack", KEY_F)
	_add_key("dodge", KEY_SHIFT)
	_add_key("interact", KEY_E)
	_add_key("sprint", KEY_CTRL)
	_add_key("world_map", KEY_M)

	if not InputMap.has_action("attack"):
		InputMap.add_action("attack")
	var mouse = InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	InputMap.action_add_event("attack", mouse)


func _add_key(action, keycode):
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var key_event = InputEventKey.new()
	key_event.physical_keycode = keycode
	InputMap.action_add_event(action, key_event)


func _build_loading_screen():
	boot_camera = Camera3D.new()
	boot_camera.position = Vector3(-55.0, 38.0, 96.0)
	add_child(boot_camera)
	boot_camera.look_at(ZONE_CENTERS[START_ZONE], Vector3.UP)
	boot_camera.current = true

	boot_layer = CanvasLayer.new()
	boot_layer.layer = 100
	add_child(boot_layer)

	var background = ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = Color(0.01, 0.025, 0.055, 1.0)
	boot_layer.add_child(background)

	if ResourceLoader.exists(WORLD_MAP_PATH):
		var map_preview = TextureRect.new()
		map_preview.texture = load(WORLD_MAP_PATH)
		map_preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		map_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		map_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		map_preview.modulate = Color(0.55, 0.62, 0.72, 0.52)
		background.add_child(map_preview)

	var shade = ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.01, 0.02, 0.045, 0.56)
	background.add_child(shade)

	var title = Label.new()
	title.text = "LES CHRONIQUES DE SKYPIEA"
	title.set_anchors_preset(Control.PRESET_CENTER)
	title.position = Vector2(-430.0, -112.0)
	title.size = Vector2(860.0, 64.0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	shade.add_child(title)

	boot_label = Label.new()
	boot_label.text = "Lecture de la carte du monde…"
	boot_label.set_anchors_preset(Control.PRESET_CENTER)
	boot_label.position = Vector2(-430.0, -20.0)
	boot_label.size = Vector2(860.0, 105.0)
	boot_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boot_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	boot_label.add_theme_font_size_override("font_size", 23)
	shade.add_child(boot_label)


func _set_loading_text(text):
	if is_instance_valid(boot_label):
		boot_label.text = text


func _finish_loading():
	if is_instance_valid(boot_layer):
		boot_layer.queue_free()
	if is_instance_valid(boot_camera):
		boot_camera.queue_free()


func _build_environment():
	world_environment_node = WorldEnvironment.new()
	environment_state = Environment.new()
	environment_state.background_mode = Environment.BG_SKY

	var sky = Sky.new()
	var sky_material = ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.02, 0.12, 0.33)
	sky_material.sky_horizon_color = Color(0.67, 0.84, 0.98)
	sky_material.ground_bottom_color = Color(0.01, 0.03, 0.055)
	sky_material.ground_horizon_color = Color(0.30, 0.43, 0.34)
	sky.sky_material = sky_material

	environment_state.sky = sky
	environment_state.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment_state.ambient_light_energy = 0.88
	environment_state.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment_state.fog_enabled = true
	environment_state.fog_density = 0.0018
	environment_state.fog_light_color = Color(0.64, 0.76, 0.88)
	world_environment_node.environment = environment_state
	add_child(world_environment_node)

	sun_light = DirectionalLight3D.new()
	sun_light.rotation_degrees = Vector3(-50.0, -32.0, 0.0)
	sun_light.light_energy = 1.5
	sun_light.shadow_enabled = true
	sun_light.directional_shadow_max_distance = 120.0
	add_child(sun_light)

	ocean_surface = MeshInstance3D.new()
	var ocean_mesh = PlaneMesh.new()
	ocean_mesh.size = Vector2(900.0, 650.0)
	ocean_mesh.subdivide_width = 64
	ocean_mesh.subdivide_depth = 48
	var ocean_material = ShaderMaterial.new()
	var ocean_shader = Shader.new()
	ocean_shader.code = """
shader_type spatial;
render_mode blend_mix, depth_prepass_alpha, cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform vec4 eau_peu_profonde : source_color = vec4(0.025, 0.50, 0.66, 1.0);
uniform vec4 eau_profonde : source_color = vec4(0.008, 0.09, 0.24, 1.0);
uniform float force_vagues = 0.18;
varying float hauteur_vague;

void vertex() {
	float grande_vague = sin(VERTEX.x * 0.055 + TIME * 0.82) * force_vagues;
	float vague_croisee = cos(VERTEX.z * 0.072 - TIME * 0.61) * force_vagues * 0.58;
	float rides = sin((VERTEX.x + VERTEX.z) * 0.19 + TIME * 1.35) * force_vagues * 0.18;
	hauteur_vague = grande_vague + vague_croisee + rides;
	VERTEX.y += hauteur_vague;
}

void fragment() {
	float dessin = sin(UV.x * 120.0 + TIME * 0.7) * cos(UV.y * 95.0 - TIME * 0.5);
	float teinte = clamp(0.46 + hauteur_vague * 0.75 + dessin * 0.045, 0.0, 1.0);
	ALBEDO = mix(eau_profonde.rgb, eau_peu_profonde.rgb, teinte);
	METALLIC = 0.22;
	ROUGHNESS = 0.13;
	SPECULAR = 0.82;
	EMISSION = eau_peu_profonde.rgb * max(hauteur_vague, 0.0) * 0.10;
	ALPHA = 0.88;
}
"""
	ocean_material.shader = ocean_shader
	ocean_mesh.material = ocean_material
	ocean_surface.mesh = ocean_mesh
	ocean_surface.position.y = -0.92
	add_child(ocean_surface)
	_build_underwater_world()


func _build_underwater_world():
	_static_box("FondMarinExplorable", Vector3(900.0, 3.5, 650.0), Vector3(0.0, -28.0, 0.0), Color(0.018, 0.055, 0.065))

	var reef_positions = [
		Vector3(-205.0, -23.0, 84.0), Vector3(-190.0, -21.0, 70.0), Vector3(-178.0, -24.0, 95.0),
		Vector3(-22.0, -19.0, 18.0), Vector3(-8.0, -22.0, 28.0), Vector3(8.0, -20.0, 12.0),
		Vector3(165.0, -23.0, 62.0), Vector3(182.0, -21.0, 48.0), Vector3(198.0, -24.0, 70.0)
	]
	for reef_index in range(reef_positions.size()):
		var reef_color = Color(0.10, 0.42, 0.36) if reef_index % 2 == 0 else Color(0.54, 0.20, 0.28)
		var height = 2.8 + float(reef_index % 4) * 1.1
		_static_box("Corail_%02d" % reef_index, Vector3(1.4, height, 1.4), reef_positions[reef_index], reef_color)

	var ruin_center = Vector3(92.0, -24.5, 34.0)
	for column_index in range(8):
		var angle = TAU * float(column_index) / 8.0
		_static_box(
			"ColonneSousMarine_%02d" % column_index,
			Vector3(1.3, 6.5, 1.3),
			ruin_center + Vector3(cos(angle) * 11.0, 3.2, sin(angle) * 8.0),
			Color(0.24, 0.32, 0.31)
		)
	_add_underwater_label("RUINES SOUS-MARINES", ruin_center + Vector3(0.0, 7.5, 0.0), Color(0.24, 0.78, 0.82))

	var abyss_gate = Vector3(0.0, -23.0, -120.0)
	_static_box("PorteDesAbyssesGauche", Vector3(5.0, 12.0, 5.0), abyss_gate + Vector3(-7.0, 2.0, 0.0), Color(0.08, 0.10, 0.12))
	_static_box("PorteDesAbyssesDroite", Vector3(5.0, 12.0, 5.0), abyss_gate + Vector3(7.0, 2.0, 0.0), Color(0.08, 0.10, 0.12))
	_static_box("LinteauDesAbysses", Vector3(19.0, 3.0, 5.0), abyss_gate + Vector3(0.0, 8.5, 0.0), Color(0.08, 0.10, 0.12))
	_add_underwater_label("PASSAGE DES ABYSSES", abyss_gate + Vector3(0.0, 12.0, 0.0), Color(0.22, 0.68, 1.0))

	for chest_index in range(5):
		var chest_position = Vector3(-145.0 + float(chest_index) * 72.0, -25.2, -52.0 + float(chest_index % 2) * 105.0)
		var chest = _static_box("TrésorSousMarin_%02d" % chest_index, Vector3(2.0, 1.2, 1.4), chest_position, Color(0.42, 0.22, 0.045), Color(0.12, 0.06, 0.0))
		chest.set_meta("identifiant", "tresor_sous_marin_%02d" % chest_index)
		chest.set_meta("objet", "Trésor abyssal")
		chest.set_meta("categorie", "trésor")
		chest.set_meta("quantite", 1)
		collectible_nodes.append(chest)


func _add_underwater_label(text: String, position: Vector3, color: Color):
	var anchor = Node3D.new()
	anchor.position = position
	add_child(anchor)
	_add_world_label(anchor, text, Vector3.ZERO, color)


func _build_zone(zone_index):
	var zone_root = Node3D.new()
	zone_root.name = "Region_%02d_%s" % [zone_index + 1, ZONE_NAMES[zone_index].replace(" ", "_")]
	add_child(zone_root)
	zone_roots.append(zone_root)
	active_build_parent = zone_root

	_build_terrain(zone_index)
	_add_zone_title(zone_index)

	match zone_index:
		0:
			_decorate_village(zone_index)
			_decorate_coastal_landmarks(zone_index)
		1:
			_decorate_forest(zone_index)
		2:
			_decorate_rocky_mountains(zone_index)
		3:
			_decorate_farmland(zone_index)
		4:
			_decorate_volcano(zone_index)
		5:
			_decorate_dark_marsh(zone_index)
		6:
			_decorate_desert(zone_index)
		7:
			_decorate_pirate_coast(zone_index)
			_decorate_commercial_port(zone_index)
		8:
			_decorate_ruins(zone_index)
		9:
			_decorate_ice(zone_index)
	_build_region_lamps(zone_index)

	active_build_parent = null


func _build_terrain(zone_index):
	var center = ZONE_CENTERS[zone_index]
	var surface = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_material(_terrain_material(zone_index))

	var step_x = TERRAIN_SIZE.x / float(TERRAIN_STEPS)
	var step_z = TERRAIN_SIZE.y / float(TERRAIN_STEPS)

	for z_index in range(TERRAIN_STEPS):
		for x_index in range(TERRAIN_STEPS):
			var x0 = -TERRAIN_SIZE.x * 0.5 + float(x_index) * step_x
			var x1 = x0 + step_x
			var z0 = -TERRAIN_SIZE.y * 0.5 + float(z_index) * step_z
			var z1 = z0 + step_z

			var p00 = Vector3(x0, _zone_height(zone_index, x0, z0), z0)
			var p10 = Vector3(x1, _zone_height(zone_index, x1, z0), z0)
			var p01 = Vector3(x0, _zone_height(zone_index, x0, z1), z1)
			var p11 = Vector3(x1, _zone_height(zone_index, x1, z1), z1)

			var uv00 = Vector2(float(x_index) / float(TERRAIN_STEPS), float(z_index) / float(TERRAIN_STEPS)) * 7.0
			var uv10 = Vector2(float(x_index + 1) / float(TERRAIN_STEPS), float(z_index) / float(TERRAIN_STEPS)) * 7.0
			var uv01 = Vector2(float(x_index) / float(TERRAIN_STEPS), float(z_index + 1) / float(TERRAIN_STEPS)) * 7.0
			var uv11 = Vector2(float(x_index + 1) / float(TERRAIN_STEPS), float(z_index + 1) / float(TERRAIN_STEPS)) * 7.0

			surface.set_uv(uv00)
			surface.add_vertex(p00)
			surface.set_uv(uv01)
			surface.add_vertex(p01)
			surface.set_uv(uv11)
			surface.add_vertex(p11)

			surface.set_uv(uv00)
			surface.add_vertex(p00)
			surface.set_uv(uv11)
			surface.add_vertex(p11)
			surface.set_uv(uv10)
			surface.add_vertex(p10)

	surface.generate_normals()
	var terrain_mesh = surface.commit()

	var body = StaticBody3D.new()
	body.name = "Zone_%02d_Terrain" % (zone_index + 1)
	body.position = center

	var visual = MeshInstance3D.new()
	visual.mesh = terrain_mesh
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	body.add_child(visual)

	var collision = CollisionShape3D.new()
	var shape = ConcavePolygonShape3D.new()
	shape.set_faces(terrain_mesh.get_faces())
	collision.shape = shape
	body.add_child(collision)
	_attach_world_node(body)


func _zone_height(zone_index, local_x, local_z):
	var nx = local_x / (TERRAIN_SIZE.x * 0.5)
	var nz = local_z / (TERRAIN_SIZE.y * 0.5)
	var edge = max(abs(nx), abs(nz))
	var island = clamp((1.0 - edge) / 0.20, 0.0, 1.0)
	island = island * island * (3.0 - 2.0 * island)

	var wave = sin(nx * 7.4 + float(zone_index) * 0.7) * 0.35
	wave += cos(nz * 8.1 - float(zone_index) * 0.5) * 0.30
	wave += sin((nx + nz) * 5.2) * 0.22
	var core = 1.1 + wave

	match zone_index:
		0:
			var coastal_slope = max(0.0, -nz) * 1.8
			core = 1.15 + coastal_slope + wave * 0.55
		1:
			core = 1.45 + wave * 1.25 + exp(-((nx + 0.38) * (nx + 0.38) + (nz - 0.18) * (nz - 0.18)) * 5.0) * 3.2
		2:
			var peak_a = exp(-((nx + 0.28) * (nx + 0.28) + (nz + 0.12) * (nz + 0.12)) * 7.0) * 8.0
			var peak_b = exp(-((nx - 0.25) * (nx - 0.25) + (nz - 0.22) * (nz - 0.22)) * 9.0) * 6.2
			var ridge = exp(-pow(nx + nz * 0.42, 2.0) * 8.0) * 4.2
			core = 1.7 + peak_a + peak_b + ridge + wave * 0.7
		3:
			core = 1.25 + wave * 0.30 + sin(nx * 3.0) * 0.18
		4:
			var radius = Vector2(nx, nz).length()
			var cone = max(0.0, 1.0 - radius) * 11.5
			var crater = exp(-pow((radius - 0.18) * 11.0, 2.0)) * 4.4
			core = 1.0 + cone - crater + wave * 0.45
		5:
			core = 0.62 + wave * 0.42
		6:
			var canyon = -exp(-pow(nx - 0.08, 2.0) * 45.0) * 2.1
			core = 1.0 + sin(nx * 11.0) * 0.55 + cos(nz * 6.0) * 0.35 + canyon + wave * 0.32
		7:
			core = 1.05 + wave * 0.34 + max(0.0, -nz) * 0.45
		8:
			var ancient_plateau = exp(-(nx * nx + nz * nz) * 3.4) * 2.8
			core = 1.35 + ancient_plateau + wave * 0.45
		9:
			var snow_peak_a = exp(-((nx + 0.22) * (nx + 0.22) + (nz - 0.12) * (nz - 0.12)) * 6.2) * 9.5
			var snow_peak_b = exp(-((nx - 0.36) * (nx - 0.36) + (nz + 0.18) * (nz + 0.18)) * 8.0) * 7.0
			core = 1.6 + snow_peak_a + snow_peak_b + wave * 0.66

	var edge_height = -0.72
	return lerp(edge_height, core, island)


func _terrain_world_height(zone_index, world_x, world_z):
	var center = ZONE_CENTERS[zone_index]
	return center.y + _zone_height(zone_index, world_x - center.x, world_z - center.z)


func _terrain_material(zone_index):
	if terrain_material_cache.has(zone_index):
		return terrain_material_cache[zone_index]

	var material = StandardMaterial3D.new()
	material.albedo_color = Color.WHITE
	material.albedo_texture = _create_biome_texture(zone_index)
	material.roughness = 0.76
	material.metallic = 0.04 if zone_index in [0, 2, 9] else 0.0
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	terrain_material_cache[zone_index] = material
	return material


func _create_biome_texture(zone_index):
	var image = Image.create(64, 64, false, Image.FORMAT_RGBA8)
	var base = ZONE_BASE_COLORS[zone_index]
	var accent = ZONE_ACCENT_COLORS[zone_index]

	for y in range(64):
		for x in range(64):
			var seed_value = sin(float(x * 37 + y * 71 + zone_index * 193)) * 43758.5453
			var random_value = seed_value - floor(seed_value)
			var broad = (sin(float(x) * 0.24) + cos(float(y) * 0.19)) * 0.11
			var amount = clamp(random_value * 0.42 + 0.18 + broad, 0.0, 0.78)
			if zone_index == 3:
				amount += sin(float(x + y) * 0.34) * 0.12
			elif zone_index == 2:
				amount = clamp(amount + 0.18, 0.0, 0.86)
			elif zone_index == 4:
				amount *= 0.72
			image.set_pixel(x, y, base.lerp(accent, amount))

	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)


func _decorate_volcano(zone_index):
	var center = ZONE_CENTERS[zone_index]
	_add_disc(center + Vector3(0.0, 8.2, 0.0), 8.2, Color(0.98, 0.10, 0.01), Color(1.0, 0.05, 0.0))
	for index in range(32):
		var angle = TAU * float(index) / 32.0
		var radius = 8.0 + float(index % 5) * 3.0
		_add_rock(zone_index, Vector3(cos(angle) * radius, 0.0, sin(angle) * radius), Vector3(2.0, 2.6 + float(index % 4), 2.0), Color(0.075, 0.065, 0.06))
	for lane in [-1.0, 1.0]:
		var channel = _visual_box("LavaChannel", Vector3(4.2, 0.12, 58.0), center + Vector3(lane * 17.0, 2.2, 23.0), Color(0.95, 0.11, 0.01), Color(1.0, 0.05, 0.0))
		channel.rotation.y = lane * 0.32


func _decorate_forest(zone_index):
	for index in range(78):
		var x = -18.0 + float((index * 13) % 37)
		var z = -16.0 + float((index * 19) % 33)
		if abs(x) < 4.5 and abs(z) < 9.0:
			x += 8.0
		_place_model(TREE_MODEL, zone_index, Vector3(x, 0.0, z), Vector3.ONE * (0.72 + float(index % 5) * 0.08), Vector3(0.0, float(index) * 0.43, 0.0))
	_add_water_patch(zone_index, Vector3(-13.0, 0.0, 9.0), Vector2(11.0, 7.0), Color(0.02, 0.42, 0.54, 0.82))
	_add_waterfall(zone_index, Vector3(-18.5, 2.5, 10.0), Vector2(4.0, 6.5))


func _decorate_ice(zone_index):
	for index in range(36):
		var angle = TAU * float(index) / 36.0
		var radius = 9.0 + float(index % 4) * 3.0
		_add_crystal(zone_index, Vector3(cos(angle) * radius, 0.0, sin(angle) * radius), 1.1 + float(index % 4) * 0.35, Color(0.42, 0.84, 1.0))
	for offset in [Vector3(-15.0, 0.0, -13.0), Vector3(15.0, 0.0, 11.0), Vector3(0.0, 0.0, 16.0)]:
		_add_rock(zone_index, offset, Vector3(4.5, 3.2, 4.0), Color(0.54, 0.66, 0.75))


func _decorate_desert(zone_index):
	for index in range(28):
		var x = -19.0 + float((index * 11) % 39)
		var z = -15.0 + float((index * 17) % 31)
		_add_rock(zone_index, Vector3(x, 0.0, z), Vector3(2.5 + float(index % 3), 1.6 + float(index % 2), 2.2), Color(0.52, 0.31, 0.13))
	_add_colossus(zone_index, Vector3(11.0, 0.0, 3.0))
	_place_model(RUIN_MODEL, zone_index, Vector3(-10.0, 0.0, -11.0), Vector3.ONE * 1.25, Vector3.ZERO)


func _decorate_dark_marsh(zone_index):
	for offset in [Vector3(-13.0, 0.0, -10.0), Vector3(12.0, 0.0, -7.0), Vector3(-7.0, 0.0, 11.0), Vector3(13.0, 0.0, 12.0)]:
		_add_water_patch(zone_index, offset, Vector2(11.0, 7.0), Color(0.04, 0.35, 0.17, 0.82), Color(0.02, 0.85, 0.16))
	for index in range(42):
		var x = -18.0 + float((index * 15) % 37)
		var z = -16.0 + float((index * 23) % 33)
		_place_model(TREE_MODEL, zone_index, Vector3(x, 0.0, z), Vector3(0.52, 0.82, 0.52), Vector3(0.0, float(index), 0.0))
	for offset in [Vector3(-18.0, 0.0, 15.0), Vector3(17.0, 0.0, -14.0), Vector3(2.0, 0.0, -16.0)]:
		_add_crystal(zone_index, offset, 1.4, Color(0.08, 1.0, 0.34))


func _decorate_ruins(zone_index):
	_add_pyramid(zone_index, Vector3(0.0, 0.0, -7.0), 7.2)
	_add_pyramid(zone_index, Vector3(-12.0, 0.0, 8.0), 4.4)
	for offset in [Vector3(-16.0, 0.0, -12.0), Vector3(16.0, 0.0, -12.0), Vector3(-16.0, 0.0, 14.0), Vector3(16.0, 0.0, 14.0)]:
		_add_column(zone_index, offset, 5.2)
	_place_model(RUIN_MODEL, zone_index, Vector3(11.0, 0.0, 9.0), Vector3.ONE * 1.35, Vector3(0.0, -0.55, 0.0))
	for ring_index in range(12):
		var ring_angle = TAU * float(ring_index) / 12.0
		_add_column(zone_index, Vector3(cos(ring_angle) * 18.0, 0.0, sin(ring_angle) * 15.0), 3.8 + float(ring_index % 4))


func _decorate_pirate_coast(zone_index):
	_add_water_patch(zone_index, Vector3(0.0, 0.0, -5.0), Vector2(38.0, 12.0), Color(0.02, 0.46, 0.68, 0.90))
	_place_model(BOAT_MODEL, zone_index, Vector3(-2.0, 0.45, -6.0), Vector3.ONE * 1.08, Vector3(0.0, -0.35, 0.0))
	for index in range(10):
		var angle = TAU * float(index) / 10.0
		_add_rock(zone_index, Vector3(cos(angle) * 18.0, 0.0, sin(angle) * 15.0), Vector3(2.4, 1.5 + float(index % 3), 2.2), Color(0.26, 0.28, 0.27))
	for offset in [Vector3(-16.0, 0.0, 13.0), Vector3(16.0, 0.0, 13.0)]:
		_place_model(TREE_MODEL, zone_index, offset, Vector3(0.60, 0.88, 0.60), Vector3.ZERO)


func _decorate_village(zone_index):
	for offset in [Vector3(-16.0, 0.0, -10.0), Vector3(-8.0, 0.0, -13.0), Vector3(0.0, 0.0, -14.0), Vector3(8.0, 0.0, -12.0), Vector3(16.0, 0.0, -9.0), Vector3(-15.0, 0.0, 7.0), Vector3(-6.0, 0.0, 10.0), Vector3(7.0, 0.0, 10.0), Vector3(16.0, 0.0, 7.0)]:
		_place_model(HOUSE_MODEL, zone_index, offset, Vector3.ONE * 0.92, Vector3(0.0, offset.x * 0.02, 0.0))
	for index in range(42):
		var angle = TAU * float(index) / 42.0
		var radius = 17.0 + float(index % 3) * 2.0
		_place_model(TREE_MODEL, zone_index, Vector3(cos(angle) * radius, 0.0, sin(angle) * radius), Vector3.ONE * (0.76 + float(index % 4) * 0.07), Vector3(0.0, angle, 0.0))
	_add_path(zone_index, Vector3(0.0, 0.25, 0.0), Vector3(7.0, 0.16, 35.0), 0.0)
	_add_waterfall(zone_index, Vector3(-20.0, 1.8, 8.0), Vector2(3.5, 5.0))


func _decorate_coastal_landmarks(zone_index):
	# Phare, marché, plage, quai, pontons et deux bateaux placés explicitement.
	_add_tower(zone_index, Vector3(-19.0, 0.0, -15.0), 13.0)
	_add_world_label_at_region(zone_index, "PHARE DE SKYPIEA", Vector3(-19.0, 14.5, -15.0), Color(0.92, 0.84, 0.52))
	_add_water_patch(zone_index, Vector3(0.0, -0.55, 18.0), Vector2(41.0, 8.0), Color(0.02, 0.48, 0.70, 0.88))
	for dock_x in [-12.0, 0.0, 12.0]:
		_add_path(zone_index, Vector3(dock_x, 0.40, 16.0), Vector3(3.0, 0.18, 12.0), 0.0)
	# Deux rangées latérales conservent une large allée centrale entre le point
	# d'apparition de CHK Hero et le village. L'ancienne rangée plaçait Étal_01
	# directement dans l'axe du joystick et bloquait le héros dès le départ.
	for market_index in range(6):
		var side = -1.0 if market_index % 2 == 0 else 1.0
		var row = float(market_index / 2)
		var market_offset = Vector3(side * 2.4, 0.0, 1.0 + row * 6.0)
		_add_market_stall(zone_index, market_offset, market_index)
	_place_model(BOAT_MODEL, zone_index, Vector3(-12.0, 0.60, 19.0), Vector3.ONE * 0.86, Vector3(0.0, 0.2, 0.0))
	_place_model(BOAT_MODEL, zone_index, Vector3(12.0, 0.60, 19.0), Vector3.ONE * 1.05, Vector3(0.0, -0.25, 0.0))


func _decorate_rocky_mountains(zone_index):
	for index in range(44):
		var angle = TAU * float(index) / 44.0
		var radius = 5.0 + float(index % 8) * 2.5
		_add_rock(zone_index, Vector3(cos(angle) * radius, 0.0, sin(angle) * radius), Vector3(2.0 + float(index % 3), 2.5 + float(index % 5), 2.0 + float(index % 2)), Color(0.31, 0.29, 0.27))
	_place_model(RUIN_MODEL, zone_index, Vector3(-14.0, 0.0, 12.0), Vector3.ONE * 1.2, Vector3(0.0, 0.65, 0.0))
	_add_path(zone_index, Vector3(2.0, 0.30, 0.0), Vector3(5.0, 0.18, 36.0), 0.24)
	_add_waterfall(zone_index, Vector3(17.0, 5.0, -9.0), Vector2(4.5, 11.0))


func _decorate_farmland(zone_index):
	var field_offsets = [
		Vector3(-16.0, 0.0, -11.0), Vector3(-5.0, 0.0, -11.0), Vector3(8.0, 0.0, -11.0),
		Vector3(-15.0, 0.0, 3.0), Vector3(-3.0, 0.0, 4.0), Vector3(11.0, 0.0, 4.0),
		Vector3(-12.0, 0.0, 16.0), Vector3(3.0, 0.0, 16.0)
	]
	for field_index in range(field_offsets.size()):
		_add_field(zone_index, field_offsets[field_index], field_index)
	for farm_offset in [Vector3(-19.0, 0.0, -18.0), Vector3(17.0, 0.0, -17.0), Vector3(-18.0, 0.0, 17.0), Vector3(17.0, 0.0, 17.0)]:
		_place_model(HOUSE_MODEL, zone_index, farm_offset, Vector3.ONE, Vector3(0.0, farm_offset.x * 0.03, 0.0))
	_add_path(zone_index, Vector3(0.0, 0.22, 0.0), Vector3(6.0, 0.14, 40.0), 0.0)
	_add_water_patch(zone_index, Vector3(19.0, -0.08, 1.0), Vector2(3.5, 22.0), Color(0.04, 0.42, 0.58, 0.82))


func _decorate_commercial_port(zone_index):
	for warehouse_index in range(10):
		var side = -1.0 if warehouse_index % 2 == 0 else 1.0
		var row = float(warehouse_index / 2)
		var offset = Vector3(side * (10.0 + row * 1.2), 0.0, -15.0 + row * 7.0)
		_place_model(HOUSE_MODEL, zone_index, offset, Vector3(1.25, 0.92, 1.45), Vector3(0.0, PI if side > 0.0 else 0.0, 0.0))
	for quay_x in [-16.0, -8.0, 0.0, 8.0, 16.0]:
		_add_path(zone_index, Vector3(quay_x, 0.38, 18.0), Vector3(4.0, 0.20, 15.0), 0.0)
	for boat_index in range(4):
		_place_model(BOAT_MODEL, zone_index, Vector3(-15.0 + float(boat_index) * 10.0, 0.55, 20.0), Vector3.ONE * (0.82 + float(boat_index % 2) * 0.20), Vector3(0.0, 0.12 * float(boat_index), 0.0))
	_add_world_label_at_region(zone_index, "GRAND PORT COMMERCIAL", Vector3(0.0, 6.0, -19.0), Color(0.16, 0.78, 0.94))


func _add_market_stall(zone_index, offset, variant):
	var position = _region_surface_position(zone_index, offset, 1.0)
	var cloth_colors = [Color(0.72, 0.12, 0.08), Color(0.10, 0.34, 0.70), Color(0.78, 0.62, 0.10)]
	_static_box("Étal_%02d" % variant, Vector3(4.2, 1.8, 2.8), position, Color(0.30, 0.16, 0.07))
	_visual_box("Toile_Étal", Vector3(4.8, 0.18, 3.2), position + Vector3(0.0, 1.15, 0.0), cloth_colors[variant % cloth_colors.size()])


func _add_field(zone_index, offset, variant):
	var position = _region_surface_position(zone_index, offset, 0.10)
	var field_colors = [Color(0.70, 0.59, 0.16), Color(0.27, 0.55, 0.12), Color(0.47, 0.31, 0.10), Color(0.76, 0.69, 0.30)]
	_visual_box("Champ_%02d" % variant, Vector3(25.0, 0.08, 19.0), position, field_colors[variant % field_colors.size()])


func _add_world_label_at_region(zone_index, text, offset, color):
	var anchor = Node3D.new()
	anchor.position = _region_surface_position(zone_index, offset)
	_attach_world_node(anchor)
	_add_world_label(anchor, text, Vector3.ZERO, color)


func _build_region_lamps(zone_index: int):
	var lamp_offsets = [
		Vector3(-12.0, 0.0, -8.0),
		Vector3(12.0, 0.0, -8.0),
		Vector3(-12.0, 0.0, 9.0),
		Vector3(12.0, 0.0, 9.0)
	]
	if zone_index in [0, 7]:
		lamp_offsets.append_array([
			Vector3(-19.0, 0.0, 1.0),
			Vector3(19.0, 0.0, 1.0),
			Vector3(-5.0, 0.0, 16.0),
			Vector3(5.0, 0.0, 16.0)
		])
	for lamp_index in range(lamp_offsets.size()):
		var base_position = _region_surface_position(zone_index, lamp_offsets[lamp_index], 0.0)
		_visual_box("PoteauLanterne", Vector3(0.15, 2.8, 0.15), base_position + Vector3(0.0, 1.4, 0.0), Color(0.12, 0.075, 0.035))
		_visual_box("Lanterne", Vector3(0.42, 0.48, 0.42), base_position + Vector3(0.0, 2.85, 0.0), Color(0.92, 0.58, 0.16), Color(0.85, 0.34, 0.05))
		var light = OmniLight3D.new()
		light.name = "LumièreNocturne_%02d_%02d" % [zone_index + 1, lamp_index + 1]
		light.position = base_position + Vector3(0.0, 2.95, 0.0)
		light.light_color = Color(1.0, 0.62, 0.24)
		light.light_energy = 1.65
		light.omni_range = 8.5
		light.shadow_enabled = false
		light.visible = false
		_attach_world_node(light)
		night_lights.append(light)


func _update_night_lights():
	if not is_instance_valid(world_clock):
		return
	var hour = world_clock.game_minutes / 60.0
	var enabled = hour >= 19.0 or hour < 6.5
	for light in night_lights:
		if is_instance_valid(light):
			light.visible = enabled


func _decorate_capital(zone_index):
	_add_path(zone_index, Vector3(0.0, 0.15, 5.0), Vector3(8.0, 0.16, 34.0), 0.0)
	for x_value in [-16.0, -8.0, 8.0, 16.0]:
		_add_tower(zone_index, Vector3(x_value, 0.0, -12.0), 7.5)
	_add_wall(zone_index, Vector3(0.0, 0.0, -17.0), Vector3(40.0, 5.2, 2.4))
	_place_model(RUIN_MODEL, zone_index, Vector3(0.0, 0.0, -8.0), Vector3.ONE * 1.72, Vector3.ZERO)
	for offset in [Vector3(-15.0, 0.0, 10.0), Vector3(15.0, 0.0, 10.0), Vector3(-10.0, 0.0, 17.0), Vector3(10.0, 0.0, 17.0)]:
		_place_model(HOUSE_MODEL, zone_index, offset, Vector3.ONE * 0.82, Vector3(0.0, PI, 0.0))


func _decorate_sky_island(zone_index):
	_place_model(RUIN_MODEL, zone_index, Vector3(0.0, 0.0, -7.0), Vector3.ONE * 1.65, Vector3.ZERO)
	_place_model(TREE_MODEL, zone_index, Vector3(0.0, 0.0, 9.0), Vector3.ONE * 1.45, Vector3.ZERO)
	for index in range(12):
		var angle = TAU * float(index) / 12.0
		var radius = 15.0 + float(index % 3) * 3.0
		_add_crystal(zone_index, Vector3(cos(angle) * radius, 0.0, sin(angle) * radius), 1.0 + float(index % 3) * 0.3, Color(0.75, 0.94, 1.0))
		var floating = _add_rock(zone_index, Vector3(cos(angle) * (radius + 8.0), -5.0 - float(index % 4), sin(angle) * (radius + 8.0)), Vector3(2.8, 4.0, 2.8), Color(0.43, 0.50, 0.52))
		if is_instance_valid(floating):
			floating.rotation = Vector3(float(index) * 0.11, float(index) * 0.23, float(index) * 0.09)


func _build_routes():
	_build_bridge(0, 7, 8.0, Color(0.42, 0.30, 0.17))
	_build_bridge(0, 1, 7.0, Color(0.38, 0.30, 0.18))
	_build_bridge(7, 4, 7.0, Color(0.28, 0.22, 0.17))
	_build_bridge(7, 1, 8.0, Color(0.48, 0.35, 0.20))
	_build_bridge(1, 3, 7.5, Color(0.40, 0.34, 0.19))
	_build_bridge(1, 2, 7.0, Color(0.36, 0.31, 0.22))
	_build_bridge(2, 9, 6.5, Color(0.54, 0.50, 0.43))
	_build_bridge(2, 6, 7.0, Color(0.46, 0.38, 0.28))
	_build_bridge(3, 5, 7.5, Color(0.42, 0.34, 0.20))
	_build_bridge(5, 8, 7.0, Color(0.34, 0.30, 0.22))
	_build_bridge(8, 6, 7.0, Color(0.42, 0.36, 0.29))


func _build_bridge(zone_a, zone_b, width, color):
	var start = ZONE_CENTERS[zone_a]
	var finish = ZONE_CENTERS[zone_b]
	var delta = finish - start
	var horizontal = Vector3(delta.x, 0.0, delta.z)
	var length = horizontal.length()
	if length < 1.0:
		return

	var midpoint = (start + finish) * 0.5
	midpoint.y = 1.35
	var bridge = _static_box("Route_%02d_%02d" % [zone_a + 1, zone_b + 1], Vector3(width, 0.55, length), midpoint, color)
	bridge.rotation.y = atan2(horizontal.x, horizontal.z)

	var left_rail = _visual_box("Rail", Vector3(0.20, 0.65, length), midpoint + Vector3(-width * 0.48, 0.55, 0.0), Color(0.24, 0.16, 0.08))
	left_rail.rotation.y = bridge.rotation.y
	var right_rail = _visual_box("Rail", Vector3(0.20, 0.65, length), midpoint + Vector3(width * 0.48, 0.55, 0.0), Color(0.24, 0.16, 0.08))
	right_rail.rotation.y = bridge.rotation.y


func _build_portals():
	var capital = ZONE_CENTERS[7]
	capital_portal_position = Vector3(capital.x, _terrain_world_height(7, capital.x, capital.z - 36.0) + 0.4, capital.z - 36.0)
	_add_portal(capital_portal_position, Color(0.30, 0.72, 1.0), "PASSAGE VERS LE SOMMET ENNEIGÉ")

	var sky = ZONE_CENTERS[9]
	sky_portal_position = Vector3(sky.x, _terrain_world_height(9, sky.x, sky.z + 36.0) + 0.4, sky.z + 36.0)
	_add_portal(sky_portal_position, Color(1.0, 0.78, 0.24), "RETOUR AU GRAND PORT")


func _add_portal(position, color, text):
	var anchor = Node3D.new()
	anchor.position = position
	add_child(anchor)

	var ring = MeshInstance3D.new()
	var torus = TorusMesh.new()
	torus.inner_radius = 1.35
	torus.outer_radius = 1.72
	var portal_material = StandardMaterial3D.new()
	portal_material.albedo_color = color
	portal_material.emission_enabled = true
	portal_material.emission = color
	portal_material.emission_energy_multiplier = 3.0
	torus.material = portal_material
	ring.mesh = torus
	ring.rotation.x = PI * 0.5
	ring.position.y = 1.8
	anchor.add_child(ring)

	var light = OmniLight3D.new()
	light.light_color = color
	light.light_energy = 3.2
	light.omni_range = 8.0
	light.position.y = 1.8
	anchor.add_child(light)
	_add_world_label(anchor, text, Vector3(0.0, 4.0, 0.0), color)


func _spawn_player():
	player = PLAYER_SCRIPT.new()
	player.name = "CHKHero"
	var center = ZONE_CENTERS[START_ZONE]
	var spawn_x = center.x
	var spawn_z = center.z + 4.0
	player.position = Vector3(spawn_x, _terrain_world_height(START_ZONE, spawn_x, spawn_z) + 0.45, spawn_z)
	add_child(player)
	player.set_spawn(player.global_position)
	if ResourceLoader.exists(HERO_MODEL):
		player.apply_asset(HERO_MODEL)
	elif ResourceLoader.exists(HERO_FALLBACK):
		player.apply_asset(HERO_FALLBACK)
	player.health_changed.connect(_on_health_changed)
	player.attack_requested.connect(_on_player_attack)
	player.interact_requested.connect(_on_interact)
	player.water_state_changed.connect(_on_player_water_state_changed)


func _spawn_guardians():
	zone_remaining.resize(ZONE_CENTERS.size())
	zone_total.resize(ZONE_CENTERS.size())
	zone_completed.resize(ZONE_CENTERS.size())

	for zone_index in range(ZONE_CENTERS.size()):
		zone_remaining[zone_index] = 0
		zone_total[zone_index] = 0
		zone_completed[zone_index] = false

	zone_completed[START_ZONE] = true

	for zone_index in range(ZONE_CENTERS.size()):
		if zone_index == START_ZONE:
			continue
		var count = 4 if zone_index in [4, 8, 9] else 3
		zone_remaining[zone_index] = count
		zone_total[zone_index] = count

		for enemy_index in range(count):
			var enemy = ENEMY_SCRIPT.new()
			enemy.name = "Zone_%02d_Gardien_%02d" % [zone_index + 1, enemy_index + 1]
			var angle = TAU * float(enemy_index) / float(max(1, count)) + 0.8
			var radius = 22.0 + float(enemy_index % 3) * 12.0
			var world_x = ZONE_CENTERS[zone_index].x + cos(angle) * radius
			var world_z = ZONE_CENTERS[zone_index].z + sin(angle) * radius
			enemy.position = Vector3(world_x, _terrain_world_height(zone_index, world_x, world_z) + 0.45, world_z)
			enemy.set_meta("zone_index", zone_index)
			add_child(enemy)

			var model_index = (zone_index + enemy_index) % ENEMY_MODELS.size()
			enemy.setup(player, model_index, ENEMY_MODELS[model_index])
			enemy.defeated.connect(_on_enemy_defeated)
			enemies.append(enemy)


func _on_player_attack():
	if not is_instance_valid(player):
		return
	var forward = player.get_forward()
	if is_instance_valid(population_manager):
		population_manager.alert_nearby(player.global_position, 12.0)
	for enemy in enemies.duplicate():
		if not is_instance_valid(enemy) or enemy.health <= 0:
			continue
		var offset = enemy.global_position - player.global_position
		var flat_offset = Vector3(offset.x, 0.0, offset.z)
		if flat_offset.length() <= 3.15 and flat_offset.length() > 0.01:
			if forward.dot(flat_offset.normalized()) > -0.08:
				enemy.take_damage(34, player.global_position)


func _on_interact():
	if not is_instance_valid(player):
		return
	if is_instance_valid(dialogue_panel) and dialogue_panel.visible:
		_close_dialogue()
		return
	if is_instance_valid(controlled_boat) and controlled_boat.boarded:
		controlled_boat.disembark()
		return
	if _try_activate_ancient_switch():
		return
	if _try_collect_nearby_object():
		return
	for boat in player_boats:
		if is_instance_valid(boat) and boat.can_board(player.global_position):
			boat.board()
			return
	if is_instance_valid(population_manager) and population_manager.try_interact():
		return

	if player.global_position.distance_to(capital_portal_position) < 4.0:
		var sky = ZONE_CENTERS[9]
		var target_z = sky.z + 28.0
		player.global_position = Vector3(sky.x, _terrain_world_height(9, sky.x, target_z) + 0.65, target_z)
		player.set_spawn(player.global_position)
		_show_message("Bienvenue dans la Zone 10 — Montagnes enneigées", 4.0)
		return

	if player.global_position.distance_to(sky_portal_position) < 4.0:
		var capital = ZONE_CENTERS[7]
		var target_z = capital.z + 28.0
		player.global_position = Vector3(capital.x, _terrain_world_height(7, capital.x, target_z) + 0.65, target_z)
		player.set_spawn(player.global_position)
		_show_message("Retour au Grand port commercial", 3.0)
		return

	if current_zone == START_ZONE:
		_show_message("Ouvre CARTE pour choisir ta destination.", 3.0)
	elif zone_remaining[current_zone] > 0:
		_show_message("Zone %d : il reste %d gardien(s)." % [current_zone + 1, zone_remaining[current_zone]], 2.8)
	else:
		_show_message("Zone %d libérée." % (current_zone + 1), 2.5)


func _on_player_water_state_changed(swimming: bool):
	if swimming:
		_show_message("NAGE : déplace-toi, utilise SAUT pour remonter et PLONGER pour descendre.", 4.0)
	else:
		_show_message("Tu es revenu sur la terre ferme.", 2.2)


func _setup_player_boats():
	var boat_specs = [
		{"zone": 0, "offset": Vector3(0.0, -0.15, 18.0), "rotation": 0.12},
		{"zone": 7, "offset": Vector3(5.5, -0.15, 18.0), "rotation": -0.18}
	]
	for boat_index in range(boat_specs.size()):
		var spec: Dictionary = boat_specs[boat_index]
		var zone_index = int(spec.get("zone", 0))
		var boat_position = _region_surface_position(zone_index, spec.get("offset", Vector3.ZERO))
		var boat = PLAYER_BOAT_SCRIPT.new() as PlayerBoat
		boat.name = "BateauJouable_%02d" % [boat_index + 1]
		boat.position = boat_position
		boat.rotation.y = float(spec.get("rotation", 0.0))
		add_child(boat)
		boat.setup(player, BOAT_MODEL, boat_position.y)
		boat.boarding_changed.connect(_on_boat_boarding_changed)
		player_boats.append(boat)


func _setup_autonomous_boats():
	var routes = [
		[
			Vector3(-372.0, -0.82, 215.0), Vector3(-372.0, -0.82, 72.0),
			Vector3(-334.0, -0.82, 32.0), Vector3(-334.0, -0.82, 178.0)
		],
		[
			Vector3(-300.0, -0.82, 286.0), Vector3(-80.0, -0.82, 286.0),
			Vector3(180.0, -0.82, 286.0), Vector3(318.0, -0.82, 244.0)
		],
		[
			Vector3(378.0, -0.82, 205.0), Vector3(388.0, -0.82, 28.0),
			Vector3(382.0, -0.82, -195.0), Vector3(352.0, -0.82, -45.0)
		],
		[
			Vector3(-205.0, -0.82, -302.0), Vector3(-35.0, -0.82, -306.0),
			Vector3(210.0, -0.82, -306.0), Vector3(330.0, -0.82, -274.0)
		]
	]
	for route_index in range(routes.size()):
		var boat = AUTONOMOUS_BOAT_SCRIPT.new() as AutonomousBoat
		boat.name = "NavireMarchand_%02d" % [route_index + 1]
		add_child(boat)
		boat.setup(BOAT_MODEL, routes[route_index], 3.6 + float(route_index) * 0.55)
		autonomous_boats.append(boat)


func _on_boat_boarding_changed(boarded: bool, boat: PlayerBoat):
	controlled_boat = boat if boarded else null
	virtual_move = Vector2.ZERO
	_reset_joystick()
	if boarded:
		_show_message("BATEAU : joystick pour avancer et tourner, ACTION pour descendre.", 4.5)
	else:
		_show_message("Tu as quitté le bateau.", 2.2)


func _on_enemy_defeated(enemy):
	enemies.erase(enemy)
	var zone_index = int(enemy.get_meta("zone_index", -1))
	if zone_index < 0 or zone_index >= zone_remaining.size():
		return

	zone_remaining[zone_index] = max(0, int(zone_remaining[zone_index]) - 1)
	total_defeated += 1
	if zone_remaining[zone_index] == 0:
		zone_completed[zone_index] = true
		_show_message("ZONE %d LIBÉRÉE — %s" % [zone_index + 1, ZONE_NAMES[zone_index]], 5.0)

	game_complete = _all_hostile_zones_complete()
	if game_complete:
		_show_message("VICTOIRE — toutes les régions de la carte sont libérées !", 8.0)

	_update_hud()
	_update_map_marker()
	_save_progress()


func _all_hostile_zones_complete():
	for zone_index in range(ZONE_CENTERS.size()):
		if zone_index == START_ZONE:
			continue
		if not bool(zone_completed[zone_index]):
			return false
	return true


func _update_current_zone():
	var nearest_zone = current_zone
	var nearest_distance = INF

	for zone_index in range(ZONE_CENTERS.size()):
		var center = ZONE_CENTERS[zone_index]
		var dx = player.global_position.x - center.x
		var dz = player.global_position.z - center.z
		var dy = player.global_position.y - center.y
		var distance = dx * dx + dz * dz + dy * dy * 4.0
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_zone = zone_index

	if nearest_zone != current_zone:
		current_zone = nearest_zone
		_update_region_streaming()
		if is_instance_valid(world_clock):
			world_clock.set_region(current_zone)
		if is_instance_valid(population_manager):
			population_manager.activate_region(current_zone)
		if is_instance_valid(wildlife_manager):
			wildlife_manager.activate_region(current_zone)
		if is_instance_valid(ambient_audio_manager):
			ambient_audio_manager.set_region(current_zone)
		_update_hud()
		_update_map_marker()
		_show_zone_banner()


func _update_region_movement_effects():
	if not is_instance_valid(player):
		return
	var should_slow = current_zone == 5 and not player.is_swimming and _is_inside_marsh_pool(player.global_position)
	player.move_speed = 3.5 if should_slow else 6.0
	player.sprint_speed = 5.2 if should_slow else 9.0
	if should_slow != movement_slowed:
		movement_slowed = should_slow
		if should_slow:
			_show_message("BOUE PROFONDE — tes déplacements sont ralentis.", 3.0)
		else:
			_show_message("Tu as quitté la boue profonde.", 2.0)


func _is_inside_marsh_pool(world_position: Vector3) -> bool:
	var center = ZONE_CENTERS[5]
	var pool_offsets = [Vector2(-13.0, -10.0), Vector2(12.0, -7.0), Vector2(-7.0, 11.0), Vector2(13.0, 12.0)]
	for pool_offset in pool_offsets:
		var pool_center = Vector2(center.x + pool_offset.x * REGION_LAYOUT_SCALE, center.z + pool_offset.y * REGION_LAYOUT_SCALE)
		var local = Vector2(world_position.x, world_position.z) - pool_center
		if absf(local.x) <= 18.2 and absf(local.y) <= 11.6:
			return true
	return false


func _update_environmental_hazards(delta: float):
	hazard_tick = maxf(0.0, hazard_tick - delta)
	if hazard_tick > 0.0 or not is_instance_valid(player) or player.health <= 0:
		return
	var damage = 0
	var danger_name = ""
	if current_zone == 4:
		var volcanic_local = player.global_position - ZONE_CENTERS[4]
		if absf(absf(volcanic_local.x) - 17.0) <= 2.8 and absf(volcanic_local.z - 23.0) <= 29.0:
			damage = 9
			danger_name = "LAVE — éloigne-toi du courant brûlant !"
	elif current_zone == 5 and _is_inside_marsh_pool(player.global_position):
		var marsh_local = player.global_position - ZONE_CENTERS[5]
		if marsh_local.x > 18.0 or marsh_local.x < -18.0:
			damage = 4
			danger_name = "EAU TOXIQUE — rejoins un ponton !"
	if damage > 0:
		hazard_tick = 1.15
		player.take_damage(damage, player.global_position + Vector3(0.0, 0.0, 0.1))
		_show_message(danger_name, 2.2)


func _update_region_streaming():
	# Seule la région courante et ses voisines directes restent rendues et actives.
	# Les profils des habitants éloignés continuent d'être simulés par données.
	for zone_index in range(zone_roots.size()):
		var root = zone_roots[zone_index]
		if not is_instance_valid(root):
			continue
		var distance = Vector2(
			ZONE_CENTERS[zone_index].x - ZONE_CENTERS[current_zone].x,
			ZONE_CENTERS[zone_index].z - ZONE_CENTERS[current_zone].z
		).length()
		var streaming_distance = 170.0 if graphics_quality == "faible" else (320.0 if graphics_quality == "élevé" else 245.0)
		var should_stream = zone_index == current_zone or distance <= streaming_distance
		root.visible = should_stream
		root.process_mode = Node.PROCESS_MODE_INHERIT if should_stream else Node.PROCESS_MODE_DISABLED

	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		var enemy_zone = int(enemy.get_meta("zone_index", -1))
		if enemy_zone < 0 or enemy_zone >= ZONE_CENTERS.size():
			continue
		var enemy_distance = Vector2(
			ZONE_CENTERS[enemy_zone].x - ZONE_CENTERS[current_zone].x,
			ZONE_CENTERS[enemy_zone].z - ZONE_CENTERS[current_zone].z
		).length()
		var enemy_streaming_distance = 170.0 if graphics_quality == "faible" else (320.0 if graphics_quality == "élevé" else 245.0)
		var enemy_active = enemy_zone == current_zone or enemy_distance <= enemy_streaming_distance
		enemy.visible = enemy_active
		enemy.process_mode = Node.PROCESS_MODE_INHERIT if enemy_active else Node.PROCESS_MODE_DISABLED


func _setup_world_clock():
	world_clock = WORLD_CLOCK_SCRIPT.new()
	world_clock.name = "CycleJourNuitEtMétéo"
	add_child(world_clock)
	world_clock.status_changed.connect(_on_world_status_changed)
	world_clock.weather_changed.connect(_on_weather_visual_changed)
	world_clock.setup(environment_state, sun_light, ocean_surface, player, current_zone)
	_on_weather_visual_changed(world_clock.current_weather)


func _on_world_status_changed(time_text: String, weather_text: String):
	if is_instance_valid(world_status_label):
		world_status_label.text = "%s  •  %s" % [time_text, weather_text]


func _on_weather_visual_changed(weather_id: String):
	var surface_tint = Color.WHITE
	if weather_id in ["pluie", "forte_pluie", "orage"]:
		surface_tint = Color(0.66, 0.72, 0.79)
	elif weather_id == "cendres":
		surface_tint = Color(0.70, 0.62, 0.54)
	elif weather_id in ["neige", "blizzard"]:
		surface_tint = Color(0.88, 0.94, 1.0)
	for zone_index in terrain_material_cache.keys():
		var material = terrain_material_cache[zone_index]
		if material is StandardMaterial3D:
			(material as StandardMaterial3D).albedo_color = surface_tint


func _setup_ambient_audio():
	ambient_audio_manager = AMBIENT_AUDIO_SCRIPT.new()
	ambient_audio_manager.name = "AmbiancesRégionales"
	add_child(ambient_audio_manager)
	ambient_audio_manager.setup(world_clock, current_zone)


func _build_water_depth_indicator(root: Control):
	water_depth_label = Label.new()
	water_depth_label.name = "IndicateurProfondeur"
	water_depth_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	water_depth_label.position = Vector2(-280.0, -112.0)
	water_depth_label.size = Vector2(560.0, 48.0)
	water_depth_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	water_depth_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	water_depth_label.add_theme_font_size_override("font_size", 18)
	water_depth_label.add_theme_constant_override("outline_size", 7)
	water_depth_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	water_depth_label.visible = false
	root.add_child(water_depth_label)


func _update_water_depth_indicator():
	if not is_instance_valid(water_depth_label) or not is_instance_valid(player):
		return
	water_depth_label.visible = player.is_swimming
	if not player.is_swimming:
		return
	var depth = player.swim_depth
	var depth_name = "EAU TRÈS PEU PROFONDE"
	var depth_color = Color(0.58, 0.94, 1.0)
	if depth > 18.0:
		depth_name = "ABYSSES"
		depth_color = Color(0.34, 0.48, 1.0)
	elif depth > 10.0:
		depth_name = "GRANDES PROFONDEURS"
		depth_color = Color(0.24, 0.68, 0.94)
	elif depth > 4.0:
		depth_name = "PROFONDEUR MOYENNE"
		depth_color = Color(0.32, 0.80, 0.94)
	elif depth > 0.8:
		depth_name = "EAU PEU PROFONDE"
		depth_color = Color(0.48, 0.90, 1.0)
	water_depth_label.text = "%s  •  %.1f m" % [depth_name, depth]
	water_depth_label.modulate = depth_color


func _setup_population():
	population_manager = POPULATION_SCRIPT.new()
	population_manager.name = "PopulationDuMonde"
	add_child(population_manager)
	population_manager.setup(player, world_clock, ZONE_NAMES, ZONE_CENTERS, Callable(self, "_terrain_world_height"))
	population_manager.dialogue_requested.connect(_open_dialogue)
	population_manager.activate_region(current_zone)


func _setup_wildlife():
	wildlife_manager = WILDLIFE_SCRIPT.new()
	wildlife_manager.name = "ÉcosystèmeActif"
	add_child(wildlife_manager)
	wildlife_manager.setup(player, world_clock, ZONE_CENTERS, Callable(self, "_terrain_world_height"))
	wildlife_manager.activate_region(current_zone)


func _setup_adventure_system():
	adventure_progress = ADVENTURE_SCRIPT.new()
	adventure_progress.name = "ProgressionAventure"
	add_child(adventure_progress)
	adventure_progress.setup(ZONE_NAMES)
	adventure_progress.progress_changed.connect(_refresh_adventure_panel)
	adventure_progress.progress_changed.connect(_refresh_map_discoveries)
	adventure_progress.notification_requested.connect(_on_adventure_notification)
	_build_region_interactables()
	_build_ancient_puzzle()
	_refresh_adventure_panel()


func _build_region_interactables():
	for region_index in range(ZONE_CENTERS.size()):
		var point_position = _region_surface_position(region_index, POINT_OF_INTEREST_OFFSETS[region_index], 0.12)
		var point = Node3D.new()
		point.name = "PointInteret_%02d" % [region_index + 1]
		point.position = point_position
		point.set_meta("identifiant", "point_interet_%02d" % [region_index + 1])
		point.set_meta("region", region_index)
		point.set_meta("nom", POINT_OF_INTEREST_NAMES[region_index])
		zone_roots[region_index].add_child(point)

		var beacon = MeshInstance3D.new()
		var beacon_mesh = CylinderMesh.new()
		beacon_mesh.top_radius = 0.34
		beacon_mesh.bottom_radius = 0.54
		beacon_mesh.height = 2.8
		beacon_mesh.material = _material(ZONE_ACCENT_COLORS[region_index], ZONE_ACCENT_COLORS[region_index] * 0.48)
		beacon.mesh = beacon_mesh
		beacon.position.y = 1.4
		point.add_child(beacon)
		_add_world_label(point, POINT_OF_INTEREST_NAMES[region_index], Vector3(0.0, 3.4, 0.0), ZONE_ACCENT_COLORS[region_index])
		point_of_interest_nodes.append(point)

		for resource_index in range(3):
			var angle = 0.8 + float(resource_index) * 2.05 + float(region_index % 3) * 0.27
			var local_offset = Vector3(cos(angle) * (7.0 + resource_index * 2.2), 0.0, sin(angle) * (7.0 + resource_index * 2.2))
			_create_collectible(
				region_index,
				"ressource_%02d_%02d" % [region_index + 1, resource_index + 1],
				String(REGION_RESOURCE_NAMES[region_index][0]),
				String(REGION_RESOURCE_NAMES[region_index][1]),
				local_offset
			)


func _build_ancient_puzzle():
	var region_index = 8
	var previous_parent = active_build_parent
	active_build_parent = zone_roots[region_index]
	var gate_ground = _region_surface_position(region_index, Vector3(0.0, 0.0, 6.0))
	_static_box("MurTempleGauche", Vector3(8.0, 5.0, 1.0), gate_ground + Vector3(-6.0, 2.5, 0.0), Color(0.35, 0.30, 0.20))
	_static_box("MurTempleDroit", Vector3(8.0, 5.0, 1.0), gate_ground + Vector3(6.0, 2.5, 0.0), Color(0.35, 0.30, 0.20))
	ancient_gate = _static_box("PorteDesTroisSceaux", Vector3(4.0, 4.6, 0.85), gate_ground + Vector3(0.0, 2.3, 0.0), Color(0.12, 0.16, 0.18), Color(0.04, 0.18, 0.28))
	_add_world_label(ancient_gate, "PORTE DES TROIS SCEAUX", Vector3(0.0, 3.4, 0.0), Color(0.42, 0.84, 1.0))
	active_build_parent = previous_parent

	var switch_offsets = [Vector3(-7.0, 0.0, -4.0), Vector3(0.0, 0.0, -8.0), Vector3(7.0, 0.0, -4.0)]
	for switch_index in range(switch_offsets.size()):
		_create_ancient_switch(region_index, switch_index, switch_offsets[switch_index])
	ancient_puzzle_chest = _create_collectible(region_index, "coffre_trois_sceaux", "Relique de la Première Aube", "objet rare", Vector3(0.0, 0.0, 10.0))
	ancient_puzzle_chest.name = "CoffreDerrièreLaPorte"
	ancient_puzzle_chest.visible = false
	_set_body_collision_disabled(ancient_puzzle_chest, true)


func _create_ancient_switch(region_index: int, switch_index: int, local_offset: Vector3):
	var body = StaticBody3D.new()
	body.name = "SceauAntique_%02d" % [switch_index + 1]
	body.position = _region_surface_position(region_index, local_offset, 0.42)
	body.set_meta("active", false)
	body.set_meta("index", switch_index)

	var visual = MeshInstance3D.new()
	visual.name = "Visuel"
	var mesh = CylinderMesh.new()
	mesh.top_radius = 0.58
	mesh.bottom_radius = 0.72
	mesh.height = 0.45
	mesh.material = _material(Color(0.18, 0.22, 0.24), Color(0.0, 0.04, 0.06))
	visual.mesh = mesh
	body.add_child(visual)

	var collision = CollisionShape3D.new()
	var shape = CylinderShape3D.new()
	shape.radius = 0.72
	shape.height = 0.45
	collision.shape = shape
	body.add_child(collision)
	_add_world_label(body, "SCEAU %d — ACTION" % [switch_index + 1], Vector3(0.0, 1.1, 0.0), Color(0.58, 0.68, 0.72))
	zone_roots[region_index].add_child(body)
	ancient_switches.append(body)


func _try_activate_ancient_switch(max_distance: float = 3.8) -> bool:
	if current_zone != 8 or not is_instance_valid(adventure_progress):
		return false
	if adventure_progress.has_world_flag("porte_trois_sceaux_ouverte"):
		return false
	var nearest: StaticBody3D
	var nearest_distance = max_distance
	for ancient_switch in ancient_switches:
		if not is_instance_valid(ancient_switch) or bool(ancient_switch.get_meta("active", false)):
			continue
		var distance = player.global_position.distance_to(ancient_switch.global_position)
		if distance < nearest_distance:
			nearest = ancient_switch
			nearest_distance = distance
	if not is_instance_valid(nearest):
		return false
	_set_ancient_switch_active(nearest)
	var active_count = 0
	for ancient_switch in ancient_switches:
		if is_instance_valid(ancient_switch) and bool(ancient_switch.get_meta("active", false)):
			active_count += 1
	if active_count >= ancient_switches.size():
		adventure_progress.set_world_flag("porte_trois_sceaux_ouverte", true)
		_apply_ancient_puzzle_state()
		_show_message("ÉNIGME RÉSOLUE — la porte des Trois Sceaux est ouverte.", 5.0)
	else:
		_show_message("Sceau activé : %d / %d" % [active_count, ancient_switches.size()], 2.8)
	_save_progress()
	return true


func _set_ancient_switch_active(ancient_switch: StaticBody3D):
	ancient_switch.set_meta("active", true)
	var visual = ancient_switch.get_node_or_null("Visuel") as MeshInstance3D
	if is_instance_valid(visual) and visual.mesh != null:
		visual.mesh.material = _material(Color(0.16, 0.66, 0.82), Color(0.08, 0.52, 0.94))


func _apply_ancient_puzzle_state():
	if not is_instance_valid(adventure_progress) or not adventure_progress.has_world_flag("porte_trois_sceaux_ouverte"):
		return
	for ancient_switch in ancient_switches:
		if is_instance_valid(ancient_switch):
			_set_ancient_switch_active(ancient_switch)
	if is_instance_valid(ancient_gate):
		ancient_gate.queue_free()
	if is_instance_valid(ancient_puzzle_chest):
		ancient_puzzle_chest.visible = true
		_set_body_collision_disabled(ancient_puzzle_chest, false)


func _set_body_collision_disabled(body: CollisionObject3D, disabled: bool):
	for child in body.get_children():
		if child is CollisionShape3D:
			(child as CollisionShape3D).disabled = disabled


func _create_collectible(region_index: int, object_id: String, item_name: String, category: String, local_offset: Vector3) -> StaticBody3D:
	var body = StaticBody3D.new()
	body.name = "Objet_%s" % object_id
	body.position = _region_surface_position(region_index, local_offset, 0.52)
	body.set_meta("identifiant", object_id)
	body.set_meta("objet", item_name)
	body.set_meta("categorie", category)
	body.set_meta("quantite", 1)
	body.set_meta("region", region_index)

	var visual = MeshInstance3D.new()
	var mesh = SphereMesh.new()
	mesh.radius = 0.48
	mesh.height = 0.82
	mesh.material = _material(ZONE_ACCENT_COLORS[region_index].lightened(0.18), ZONE_ACCENT_COLORS[region_index] * 0.32)
	visual.mesh = mesh
	body.add_child(visual)

	var collision = CollisionShape3D.new()
	var shape = SphereShape3D.new()
	shape.radius = 0.48
	collision.shape = shape
	body.add_child(collision)
	_add_world_label(body, item_name, Vector3(0.0, 1.25, 0.0), Color(0.94, 0.96, 1.0))
	zone_roots[region_index].add_child(body)
	collectible_nodes.append(body)
	return body


func _update_nearby_discoveries():
	if not is_instance_valid(player) or not is_instance_valid(adventure_progress):
		return
	for point in point_of_interest_nodes:
		if not is_instance_valid(point):
			continue
		if int(point.get_meta("region", -1)) != current_zone:
			continue
		if player.global_position.distance_to(point.global_position) <= 8.0:
			adventure_progress.discover_point(
				String(point.get_meta("identifiant", "point")),
				current_zone,
				String(point.get_meta("nom", "Lieu remarquable"))
			)


func _try_collect_nearby_object(max_distance: float = 3.8) -> bool:
	if not is_instance_valid(adventure_progress):
		return false
	var nearest: Node3D
	var nearest_distance = max_distance
	for collectible in collectible_nodes:
		if not is_instance_valid(collectible) or not collectible.visible:
			continue
		var distance = player.global_position.distance_to(collectible.global_position)
		if distance < nearest_distance:
			nearest = collectible
			nearest_distance = distance
	if not is_instance_valid(nearest):
		return false
	var object_id = String(nearest.get_meta("identifiant", nearest.name))
	var collected = adventure_progress.collect_item(
		object_id,
		String(nearest.get_meta("objet", "Ressource")),
		String(nearest.get_meta("categorie", "ressource")),
		int(nearest.get_meta("quantite", 1))
	)
	if collected:
		collectible_nodes.erase(nearest)
		nearest.queue_free()
		_save_progress()
	return collected


func _apply_collected_object_state():
	if not is_instance_valid(adventure_progress):
		return
	for collectible in collectible_nodes.duplicate():
		if not is_instance_valid(collectible):
			continue
		var object_id = String(collectible.get_meta("identifiant", collectible.name))
		if adventure_progress.collected_objects.has(object_id):
			collectible_nodes.erase(collectible)
			collectible.queue_free()


func _on_adventure_notification(text: String):
	_show_message(text, 4.2)


func _build_discovery_markers(frame: Control):
	map_discovery_markers.clear()
	for region_index in range(MAP_MARKERS.size()):
		var marker = Label.new()
		marker.text = "★"
		marker.tooltip_text = POINT_OF_INTEREST_NAMES[region_index]
		marker.position = Vector2(MAP_MARKERS[region_index].x * frame.size.x + 12.0, MAP_MARKERS[region_index].y * frame.size.y - 30.0)
		marker.size = Vector2(32.0, 32.0)
		marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		marker.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		marker.add_theme_font_size_override("font_size", 24)
		marker.add_theme_constant_override("outline_size", 6)
		marker.modulate = ZONE_ACCENT_COLORS[region_index]
		marker.visible = false
		frame.add_child(marker)
		map_discovery_markers.append(marker)


func _refresh_map_discoveries():
	if not is_instance_valid(adventure_progress):
		return
	for region_index in range(map_discovery_markers.size()):
		var marker = map_discovery_markers[region_index]
		if is_instance_valid(marker):
			marker.visible = adventure_progress.discovered_points.has("point_interet_%02d" % [region_index + 1])


func _build_dialogue_panel(root: Control):
	dialogue_panel = ColorRect.new()
	dialogue_panel.name = "DialogueFrançais"
	dialogue_panel.set_anchors_preset(Control.PRESET_CENTER)
	dialogue_panel.position = Vector2(-380.0, -195.0)
	dialogue_panel.size = Vector2(760.0, 390.0)
	dialogue_panel.color = Color(0.008, 0.018, 0.045, 0.97)
	dialogue_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	dialogue_panel.visible = false
	root.add_child(dialogue_panel)

	dialogue_name_label = Label.new()
	dialogue_name_label.position = Vector2(24.0, 16.0)
	dialogue_name_label.size = Vector2(712.0, 42.0)
	dialogue_name_label.add_theme_font_size_override("font_size", 26)
	dialogue_name_label.add_theme_constant_override("outline_size", 6)
	dialogue_name_label.modulate = Color(0.70, 0.86, 1.0)
	dialogue_panel.add_child(dialogue_name_label)

	dialogue_text_label = Label.new()
	dialogue_text_label.position = Vector2(24.0, 66.0)
	dialogue_text_label.size = Vector2(712.0, 120.0)
	dialogue_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialogue_text_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	dialogue_text_label.add_theme_font_size_override("font_size", 21)
	dialogue_text_label.add_theme_constant_override("outline_size", 4)
	dialogue_panel.add_child(dialogue_text_label)

	dialogue_continue_button = _dialogue_button("CONTINUER", Vector2(24.0, 204.0), Vector2(168.0, 48.0), _continue_dialogue)
	dialogue_region_button = _dialogue_button("LA RÉGION", Vector2(202.0, 204.0), Vector2(168.0, 48.0), _dialogue_about_region)
	dialogue_quest_button = _dialogue_button("BESOIN D'AIDE", Vector2(380.0, 204.0), Vector2(176.0, 48.0), _dialogue_about_quest)
	_dialogue_button("QUITTER", Vector2(566.0, 204.0), Vector2(170.0, 48.0), _close_dialogue)
	dialogue_buy_button = _dialogue_button("ACHETER UNE RATION • 12 PIÈCES", Vector2(72.0, 260.0), Vector2(300.0, 48.0), _dialogue_buy_ration)
	dialogue_sell_button = _dialogue_button("VENDRE UN TRÉSOR", Vector2(388.0, 260.0), Vector2(300.0, 48.0), _dialogue_sell_treasure)

	var help = Label.new()
	help.text = "Tous les dialogues, choix et objectifs sont en français."
	help.position = Vector2(24.0, 332.0)
	help.size = Vector2(712.0, 34.0)
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.add_theme_font_size_override("font_size", 15)
	help.modulate = Color(0.68, 0.72, 0.78)
	dialogue_panel.add_child(help)


func _dialogue_button(text: String, position: Vector2, size: Vector2, callback: Callable) -> Button:
	var button = Button.new()
	button.text = text
	button.position = position
	button.size = size
	button.add_theme_font_size_override("font_size", 15)
	button.pressed.connect(callback)
	dialogue_panel.add_child(button)
	return button


func _open_dialogue(dialogue: Dictionary):
	if not is_instance_valid(dialogue_panel):
		return
	active_dialogue = dialogue.duplicate(true)
	active_dialogue_line = 0
	dialogue_name_label.text = "%s  •  %s" % [String(active_dialogue.get("nom", "Habitant")), String(active_dialogue.get("métier", "habitant"))]
	var trade_jobs = ["marchand", "cuisinier", "artisan", "pêcheur", "docker", "marin"]
	var can_trade = String(active_dialogue.get("métier", "habitant")) in trade_jobs
	dialogue_buy_button.visible = can_trade
	dialogue_sell_button.visible = can_trade
	if is_instance_valid(adventure_progress):
		var contextual_lines = active_dialogue.get("lignes", [])
		if contextual_lines is Array:
			var reputation = adventure_progress.get_reputation(current_zone)
			if reputation >= 25:
				contextual_lines.append("On parle de tes découvertes dans toute la région. Ta réputation est maintenant de %d sur 100." % reputation)
			var regional_item = String(REGION_RESOURCE_NAMES[current_zone][0])
			if adventure_progress.inventory.has(regional_item):
				contextual_lines.append("Je vois que tu as trouvé %s. Cette ressource est typique de notre région." % regional_item)
			var region_quest = adventure_progress.quests[current_zone]
			if String(region_quest.get("statut", "")) == "terminée":
				contextual_lines.append("Grâce à toi, la mission « %s » appartient désormais à notre histoire." % region_quest.get("titre", "Mission"))
			active_dialogue["lignes"] = contextual_lines
	_show_active_dialogue_line()
	dialogue_panel.visible = true
	virtual_move = Vector2.ZERO
	move_touch_id = -1
	look_touch_id = -1
	_reset_joystick()
	if is_instance_valid(player):
		player.can_control = false


func _show_active_dialogue_line():
	var lines = active_dialogue.get("lignes", [])
	if lines is Array and not lines.is_empty():
		active_dialogue_line = clampi(active_dialogue_line, 0, lines.size() - 1)
		dialogue_text_label.text = String(lines[active_dialogue_line])


func _continue_dialogue():
	var lines = active_dialogue.get("lignes", [])
	if lines is Array and not lines.is_empty():
		active_dialogue_line = (active_dialogue_line + 1) % lines.size()
		_show_active_dialogue_line()


func _dialogue_about_region():
	var lines = active_dialogue.get("lignes", [])
	if lines is Array and lines.size() > 1:
		active_dialogue_line = 1
		_show_active_dialogue_line()


func _dialogue_about_quest():
	if not is_instance_valid(adventure_progress):
		dialogue_text_label.text = "Je n'ai rien à te confier pour le moment."
		return
	dialogue_text_label.text = adventure_progress.start_region_quest(current_zone)
	_save_progress()


func _dialogue_buy_ration():
	if not is_instance_valid(adventure_progress):
		return
	if adventure_progress.buy_item("Ration de voyage", "nourriture", 12, 1):
		dialogue_text_label.text = "Marché conclu. La ration de voyage est dans ton inventaire."
	else:
		dialogue_text_label.text = "Il te faut 12 pièces pour acheter cette ration."
	_save_progress()


func _dialogue_sell_treasure():
	if not is_instance_valid(adventure_progress):
		return
	var result = adventure_progress.sell_first_treasure()
	if bool(result.get("vendu", false)):
		dialogue_text_label.text = "Je t'achète %s pour %d pièces. Merci !" % [result.get("objet", "ce trésor"), result.get("valeur", 0)]
	else:
		dialogue_text_label.text = "Tu n'as aucun trésor que je puisse acheter."
	_save_progress()


func _close_dialogue():
	if is_instance_valid(dialogue_panel):
		dialogue_panel.visible = false
	active_dialogue.clear()
	if is_instance_valid(player):
		player.can_control = true


func _build_adventure_panels(root: Control):
	adventure_inventory_button = Button.new()
	adventure_inventory_button.text = "INVENTAIRE"
	adventure_inventory_button.position = Vector2(14.0, 322.0)
	adventure_inventory_button.size = Vector2(138.0, 48.0)
	adventure_inventory_button.add_theme_font_size_override("font_size", 14)
	adventure_inventory_button.pressed.connect(_toggle_adventure_panel.bind("inventaire"))
	root.add_child(adventure_inventory_button)

	adventure_journal_button = Button.new()
	adventure_journal_button.text = "JOURNAL"
	adventure_journal_button.position = Vector2(162.0, 322.0)
	adventure_journal_button.size = Vector2(138.0, 48.0)
	adventure_journal_button.add_theme_font_size_override("font_size", 14)
	adventure_journal_button.pressed.connect(_toggle_adventure_panel.bind("journal"))
	root.add_child(adventure_journal_button)

	adventure_panel = ColorRect.new()
	adventure_panel.name = "InventaireEtJournal"
	adventure_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	adventure_panel.color = Color(0.004, 0.010, 0.028, 0.975)
	adventure_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	adventure_panel.visible = false
	root.add_child(adventure_panel)

	adventure_title_label = Label.new()
	adventure_title_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	adventure_title_label.position = Vector2(-360.0, 18.0)
	adventure_title_label.size = Vector2(720.0, 52.0)
	adventure_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	adventure_title_label.add_theme_font_size_override("font_size", 30)
	adventure_title_label.add_theme_constant_override("outline_size", 7)
	adventure_panel.add_child(adventure_title_label)

	adventure_content_label = RichTextLabel.new()
	adventure_content_label.set_anchors_preset(Control.PRESET_CENTER)
	adventure_content_label.position = Vector2(-430.0, -270.0)
	adventure_content_label.size = Vector2(860.0, 500.0)
	adventure_content_label.add_theme_font_size_override("normal_font_size", 20)
	adventure_content_label.add_theme_constant_override("outline_size", 3)
	adventure_content_label.scroll_active = true
	adventure_content_label.selection_enabled = false
	adventure_panel.add_child(adventure_content_label)

	adventure_use_button = Button.new()
	adventure_use_button.text = "UTILISER UN SOIN"
	adventure_use_button.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	adventure_use_button.position = Vector2(-330.0, -66.0)
	adventure_use_button.size = Vector2(208.0, 50.0)
	adventure_use_button.pressed.connect(_use_healing_item)
	adventure_panel.add_child(adventure_use_button)

	adventure_sell_button = Button.new()
	adventure_sell_button.text = "VENDRE UN TRÉSOR"
	adventure_sell_button.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	adventure_sell_button.position = Vector2(-110.0, -66.0)
	adventure_sell_button.size = Vector2(220.0, 50.0)
	adventure_sell_button.pressed.connect(_sell_inventory_treasure)
	adventure_panel.add_child(adventure_sell_button)

	var close_button = Button.new()
	close_button.text = "FERMER"
	close_button.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	close_button.position = Vector2(122.0, -66.0)
	close_button.size = Vector2(208.0, 50.0)
	close_button.pressed.connect(_close_adventure_panel)
	adventure_panel.add_child(close_button)


func _toggle_adventure_panel(mode: String):
	if not is_instance_valid(adventure_panel):
		return
	if adventure_panel.visible and adventure_panel_mode == mode:
		_close_adventure_panel()
		return
	adventure_panel_mode = mode
	if is_instance_valid(map_panel):
		map_panel.visible = false
	if is_instance_valid(dialogue_panel) and dialogue_panel.visible:
		_close_dialogue()
	adventure_panel.visible = true
	virtual_move = Vector2.ZERO
	move_touch_id = -1
	look_touch_id = -1
	_reset_joystick()
	if is_instance_valid(player):
		player.can_control = false
	_refresh_adventure_panel()


func _close_adventure_panel():
	if is_instance_valid(adventure_panel):
		adventure_panel.visible = false
	if is_instance_valid(player):
		player.can_control = true


func _refresh_adventure_panel():
	if not is_instance_valid(adventure_content_label) or not is_instance_valid(adventure_title_label):
		return
	var inventory_mode = adventure_panel_mode == "inventaire"
	adventure_title_label.text = "INVENTAIRE DE CHK HERO" if inventory_mode else "JOURNAL DE QUÊTES"
	adventure_use_button.visible = inventory_mode
	adventure_sell_button.visible = inventory_mode
	if not is_instance_valid(adventure_progress):
		adventure_content_label.text = "Chargement de la progression…"
		return
	adventure_content_label.text = adventure_progress.get_inventory_text() if inventory_mode else adventure_progress.get_journal_text()


func _use_healing_item():
	if not is_instance_valid(adventure_progress) or not is_instance_valid(player):
		return
	var healing_items = ["Ration de voyage", "Ration de poisson", "Herbe médicinale", "Pain de ferme", "Antidote du marais"]
	for item_name in healing_items:
		if adventure_progress.remove_item(item_name, 1):
			player.health = mini(player.max_health, player.health + 35)
			player.health_changed.emit(player.health, player.max_health)
			_show_message("%s utilisé — vie restaurée." % item_name, 3.0)
			_save_progress()
			return
	_show_message("Aucun soin utilisable dans l'inventaire.", 3.0)


func _sell_inventory_treasure():
	if not is_instance_valid(adventure_progress):
		return
	var result = adventure_progress.sell_first_treasure()
	if bool(result.get("vendu", false)):
		_show_message("%s vendu pour %d pièces." % [result.get("objet", "Trésor"), result.get("valeur", 0)], 3.2)
		_save_progress()
	else:
		_show_message("Tu ne possèdes aucun trésor vendable.", 3.0)


func _build_tutorial_panel(root: Control):
	tutorial_panel = ColorRect.new()
	tutorial_panel.name = "TutorielFrançais"
	tutorial_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	tutorial_panel.position = Vector2(-410.0, -198.0)
	tutorial_panel.size = Vector2(820.0, 136.0)
	tutorial_panel.color = Color(0.006, 0.020, 0.052, 0.96)
	tutorial_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	tutorial_panel.visible = false
	root.add_child(tutorial_panel)

	tutorial_step_label = Label.new()
	tutorial_step_label.position = Vector2(16.0, 10.0)
	tutorial_step_label.size = Vector2(165.0, 28.0)
	tutorial_step_label.add_theme_font_size_override("font_size", 14)
	tutorial_step_label.modulate = Color(0.50, 0.78, 1.0)
	tutorial_panel.add_child(tutorial_step_label)

	tutorial_label = Label.new()
	tutorial_label.position = Vector2(16.0, 38.0)
	tutorial_label.size = Vector2(600.0, 82.0)
	tutorial_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tutorial_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tutorial_label.add_theme_font_size_override("font_size", 18)
	tutorial_panel.add_child(tutorial_label)

	var next_button = Button.new()
	next_button.text = "SUIVANT"
	next_button.position = Vector2(634.0, 18.0)
	next_button.size = Vector2(170.0, 46.0)
	next_button.pressed.connect(_next_tutorial)
	tutorial_panel.add_child(next_button)

	var skip_button = Button.new()
	skip_button.text = "PASSER LE TUTORIEL"
	skip_button.position = Vector2(634.0, 74.0)
	skip_button.size = Vector2(170.0, 46.0)
	skip_button.add_theme_font_size_override("font_size", 12)
	skip_button.pressed.connect(_skip_tutorial)
	tutorial_panel.add_child(skip_button)


func _show_tutorial_if_needed():
	if tutorial_completed or not is_instance_valid(tutorial_panel):
		return
	tutorial_index = clampi(tutorial_index, 0, TUTORIAL_MESSAGES.size() - 1)
	tutorial_panel.visible = true
	_refresh_tutorial()


func _refresh_tutorial():
	if not is_instance_valid(tutorial_label):
		return
	tutorial_step_label.text = "TUTORIEL %d / %d" % [tutorial_index + 1, TUTORIAL_MESSAGES.size()]
	tutorial_label.text = TUTORIAL_MESSAGES[tutorial_index]


func _next_tutorial():
	tutorial_index += 1
	if tutorial_index >= TUTORIAL_MESSAGES.size():
		tutorial_completed = true
		tutorial_panel.visible = false
		_show_message("Tutoriel terminé. Bonne aventure, CHK HERO !", 4.0)
	else:
		_refresh_tutorial()
	_save_progress()


func _skip_tutorial():
	tutorial_completed = true
	tutorial_panel.visible = false
	_show_message("Tutoriel désactivé. Tu peux le réactiver avec une nouvelle partie.", 3.8)
	_save_progress()


func _build_pause_settings_panel(root: Control):
	var pause_button = Button.new()
	pause_button.text = "PAUSE / RÉGLAGES"
	pause_button.position = Vector2(14.0, 378.0)
	pause_button.size = Vector2(286.0, 46.0)
	pause_button.add_theme_font_size_override("font_size", 14)
	pause_button.pressed.connect(_open_pause_settings)
	root.add_child(pause_button)

	pause_panel = ColorRect.new()
	pause_panel.name = "MenuPauseEtRéglages"
	pause_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pause_panel.color = Color(0.004, 0.010, 0.025, 0.985)
	pause_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	pause_panel.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	pause_panel.visible = false
	root.add_child(pause_panel)

	var title = Label.new()
	title.text = "JEU EN PAUSE — RÉGLAGES MOBILE"
	title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title.position = Vector2(-410.0, 28.0)
	title.size = Vector2(820.0, 54.0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_constant_override("outline_size", 7)
	pause_panel.add_child(title)

	quality_status_label = Label.new()
	quality_status_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	quality_status_label.position = Vector2(-360.0, 100.0)
	quality_status_label.size = Vector2(720.0, 46.0)
	quality_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	quality_status_label.add_theme_font_size_override("font_size", 21)
	pause_panel.add_child(quality_status_label)

	var quality_heading = Label.new()
	quality_heading.text = "QUALITÉ GRAPHIQUE"
	quality_heading.set_anchors_preset(Control.PRESET_CENTER_TOP)
	quality_heading.position = Vector2(-300.0, 162.0)
	quality_heading.size = Vector2(600.0, 38.0)
	quality_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	quality_heading.add_theme_font_size_override("font_size", 20)
	pause_panel.add_child(quality_heading)

	for quality_index in range(3):
		var level = ["faible", "moyen", "élevé"][quality_index]
		var quality_button = Button.new()
		quality_button.text = String(level).to_upper()
		quality_button.set_anchors_preset(Control.PRESET_CENTER_TOP)
		quality_button.position = Vector2(-330.0 + quality_index * 225.0, 210.0)
		quality_button.size = Vector2(210.0, 54.0)
		quality_button.pressed.connect(_select_graphics_quality.bind(level))
		pause_panel.add_child(quality_button)

	var save_button = Button.new()
	save_button.text = "SAUVEGARDER MAINTENANT"
	save_button.set_anchors_preset(Control.PRESET_CENTER)
	save_button.position = Vector2(-330.0, -40.0)
	save_button.size = Vector2(310.0, 56.0)
	save_button.pressed.connect(_manual_save)
	pause_panel.add_child(save_button)

	var unstuck_button = Button.new()
	unstuck_button.text = "DÉBLOQUER CHK HERO"
	unstuck_button.set_anchors_preset(Control.PRESET_CENTER)
	unstuck_button.position = Vector2(20.0, -40.0)
	unstuck_button.size = Vector2(310.0, 56.0)
	unstuck_button.pressed.connect(_unstuck_player)
	pause_panel.add_child(unstuck_button)

	var resume_button = Button.new()
	resume_button.text = "REPRENDRE L'AVENTURE"
	resume_button.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	resume_button.position = Vector2(-330.0, -150.0)
	resume_button.size = Vector2(310.0, 58.0)
	resume_button.pressed.connect(_close_pause_settings)
	pause_panel.add_child(resume_button)

	var menu_button = Button.new()
	menu_button.text = "RETOUR À L'ACCUEIL"
	menu_button.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	menu_button.position = Vector2(20.0, -150.0)
	menu_button.size = Vector2(310.0, 58.0)
	menu_button.pressed.connect(_return_to_title)
	pause_panel.add_child(menu_button)


func _build_title_panel(root: Control):
	title_panel = ColorRect.new()
	title_panel.name = "ÉcranAccueil"
	title_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	title_panel.color = Color(0.003, 0.009, 0.025, 0.99)
	title_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	title_panel.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	title_panel.visible = false
	root.add_child(title_panel)

	var hero_image = TextureRect.new()
	hero_image.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	hero_image.position = Vector2(105.0, -280.0)
	hero_image.size = Vector2(360.0, 560.0)
	if ResourceLoader.exists(HERO_FALLBACK):
		hero_image.texture = load(HERO_FALLBACK)
	hero_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hero_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hero_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_panel.add_child(hero_image)

	var game_title = Label.new()
	game_title.text = "LES CHRONIQUES\nDE SKYPIEA"
	game_title.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	game_title.position = Vector2(-670.0, -220.0)
	game_title.size = Vector2(600.0, 145.0)
	game_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	game_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	game_title.add_theme_font_size_override("font_size", 42)
	game_title.add_theme_constant_override("outline_size", 9)
	title_panel.add_child(game_title)

	var hero_title = Label.new()
	hero_title.text = "CHK HERO — CHEVALIER DES DIX RÉGIONS"
	hero_title.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	hero_title.position = Vector2(-670.0, -66.0)
	hero_title.size = Vector2(600.0, 46.0)
	hero_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hero_title.add_theme_font_size_override("font_size", 19)
	hero_title.modulate = Color(0.62, 0.82, 1.0)
	title_panel.add_child(hero_title)

	var continue_button = Button.new()
	continue_button.text = "CONTINUER"
	continue_button.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	continue_button.position = Vector2(-560.0, 20.0)
	continue_button.size = Vector2(380.0, 62.0)
	continue_button.add_theme_font_size_override("font_size", 22)
	continue_button.pressed.connect(_continue_game)
	title_panel.add_child(continue_button)

	var new_game_button = Button.new()
	new_game_button.text = "NOUVELLE PARTIE"
	new_game_button.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	new_game_button.position = Vector2(-560.0, 98.0)
	new_game_button.size = Vector2(380.0, 62.0)
	new_game_button.add_theme_font_size_override("font_size", 20)
	new_game_button.pressed.connect(_start_new_game)
	title_panel.add_child(new_game_button)

	var subtitle = Label.new()
	subtitle.text = "Monde ouvert • aventure • exploration • entièrement en français"
	subtitle.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	subtitle.position = Vector2(-670.0, 190.0)
	subtitle.size = Vector2(600.0, 45.0)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 16)
	subtitle.modulate = Color(0.70, 0.75, 0.82)
	title_panel.add_child(subtitle)


func _open_pause_settings():
	if is_instance_valid(title_panel) and title_panel.visible:
		return
	if is_instance_valid(map_panel):
		map_panel.visible = false
	if is_instance_valid(adventure_panel):
		adventure_panel.visible = false
	if is_instance_valid(dialogue_panel):
		dialogue_panel.visible = false
	virtual_move = Vector2.ZERO
	_reset_joystick()
	if is_instance_valid(player):
		player.can_control = false
	pause_panel.visible = true
	_update_quality_label("Jeu en pause. La progression est conservée.")
	get_tree().paused = true


func _close_pause_settings():
	get_tree().paused = false
	if is_instance_valid(pause_panel):
		pause_panel.visible = false
	if is_instance_valid(player):
		player.can_control = true


func _manual_save():
	_save_progress()
	_update_quality_label("Sauvegarde terminée • qualité %s" % graphics_quality.to_upper())


func _unstuck_player():
	get_tree().paused = false
	if is_instance_valid(controlled_boat) and controlled_boat.boarded:
		controlled_boat.disembark()
	var center = ZONE_CENTERS[current_zone]
	var safe_position = Vector3(center.x, _terrain_world_height(current_zone, center.x, center.z) + 0.72, center.z)
	player.global_position = safe_position
	player.velocity = Vector3.ZERO
	player.set_spawn(safe_position)
	pause_panel.visible = false
	player.can_control = true
	_show_message("CHK HERO a été replacé au centre de la région.", 3.6)
	_save_progress()


func _return_to_title():
	_save_progress()
	get_tree().paused = false
	pause_panel.visible = false
	_show_title_screen()


func _show_title_screen():
	if not is_instance_valid(title_panel):
		return
	title_panel.visible = true
	if is_instance_valid(player):
		player.can_control = false
	get_tree().paused = true


func _continue_game():
	get_tree().paused = false
	if is_instance_valid(title_panel):
		title_panel.visible = false
	if is_instance_valid(player):
		player.can_control = true
	_show_tutorial_if_needed()


func _start_new_game():
	get_tree().paused = false
	for save_path in [SAVE_PATH, SAVE_BACKUP_PATH, SAVE_TEMP_PATH]:
		var absolute_save_path = ProjectSettings.globalize_path(save_path)
		if FileAccess.file_exists(absolute_save_path):
			DirAccess.remove_absolute(absolute_save_path)
	get_tree().reload_current_scene()


func _select_graphics_quality(level: String):
	graphics_quality = level if level in ["faible", "moyen", "élevé"] else "moyen"
	_apply_graphics_quality(true)
	_update_quality_label("Qualité %s appliquée et sauvegardée." % graphics_quality.to_upper())


func _apply_graphics_quality(save_after: bool = false):
	Engine.max_fps = 30 if graphics_quality == "faible" else 60
	var viewport = get_viewport()
	if is_instance_valid(viewport):
		viewport.msaa_3d = Viewport.MSAA_DISABLED if graphics_quality == "faible" else (Viewport.MSAA_4X if graphics_quality == "élevé" else Viewport.MSAA_2X)
	if is_instance_valid(sun_light):
		sun_light.shadow_enabled = graphics_quality != "faible"
	if is_instance_valid(world_clock):
		world_clock.set_quality(graphics_quality)
	if is_instance_valid(wildlife_manager):
		wildlife_manager.set_quality(graphics_quality)
	_update_region_streaming()
	_update_quality_label("Qualité actuelle : %s • cible %d IPS" % [graphics_quality.to_upper(), Engine.max_fps])
	if save_after:
		_save_progress()


func _update_quality_label(prefix: String = ""):
	if not is_instance_valid(quality_status_label):
		return
	quality_status_label.text = prefix if not prefix.is_empty() else "Qualité actuelle : %s • cible %d IPS" % [graphics_quality.to_upper(), Engine.max_fps]


func _is_ci_mode() -> bool:
	for argument in OS.get_cmdline_user_args():
		if String(argument).begins_with("--ci-"):
			return true
	return false


func get_open_world_debug() -> Dictionary:
	var wildlife_counts = {"terrestres": 0, "marins": 0}
	if is_instance_valid(wildlife_manager):
		wildlife_counts = wildlife_manager.get_active_counts()
	return {
		"regions": zone_roots.size(),
		"region_area": TERRAIN_SIZE.x * TERRAIN_SIZE.y,
		"baseline_area": 46.0 * 42.0,
		"population_profiles": population_manager.get_population_count() if is_instance_valid(population_manager) else 0,
		"active_npcs": population_manager.active_npcs.size() if is_instance_valid(population_manager) else 0,
		"wildlife": wildlife_counts,
		"boats": player_boats.size(),
		"autonomous_boats": autonomous_boats.size(),
		"quests": adventure_progress.quests.size() if is_instance_valid(adventure_progress) else 0,
		"collectibles": collectible_nodes.size(),
		"points_of_interest": point_of_interest_nodes.size(),
		"puzzle_switches": ancient_switches.size(),
		"clock_ready": is_instance_valid(world_clock),
		"sound_ready": ambient_audio_manager.is_ready() if is_instance_valid(ambient_audio_manager) else false,
		"dialogue_ready": is_instance_valid(dialogue_panel),
		"inventory_ready": is_instance_valid(adventure_panel),
		"pause_ready": is_instance_valid(pause_panel),
		"title_ready": is_instance_valid(title_panel),
		"quality": graphics_quality
	}


func _build_hud():
	var canvas = CanvasLayer.new()
	canvas.layer = 20
	add_child(canvas)

	var root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(root)

	var bar = ColorRect.new()
	bar.color = Color(0.012, 0.025, 0.055, 0.88)
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar.offset_bottom = 78.0
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bar)

	health_label = Label.new()
	health_label.position = Vector2(18.0, 8.0)
	health_label.size = Vector2(250.0, 30.0)
	health_label.add_theme_font_size_override("font_size", 21)
	bar.add_child(health_label)

	zone_label = Label.new()
	zone_label.position = Vector2(18.0, 39.0)
	zone_label.size = Vector2(480.0, 30.0)
	zone_label.add_theme_font_size_override("font_size", 18)
	bar.add_child(zone_label)

	objective_label = Label.new()
	objective_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	objective_label.position = Vector2(-500.0, 10.0)
	objective_label.size = Vector2(390.0, 55.0)
	objective_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	objective_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	objective_label.add_theme_font_size_override("font_size", 16)
	bar.add_child(objective_label)

	map_button = Button.new()
	map_button.text = "CARTE"
	map_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	map_button.position = Vector2(-102.0, 10.0)
	map_button.size = Vector2(88.0, 54.0)
	map_button.add_theme_font_size_override("font_size", 17)
	map_button.pressed.connect(_toggle_map)
	bar.add_child(map_button)

	message_label = Label.new()
	message_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	message_label.position = Vector2(-410.0, 86.0)
	message_label.size = Vector2(820.0, 52.0)
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	message_label.add_theme_font_size_override("font_size", 23)
	message_label.add_theme_constant_override("outline_size", 7)
	root.add_child(message_label)

	zone_banner = Label.new()
	zone_banner.set_anchors_preset(Control.PRESET_CENTER)
	zone_banner.position = Vector2(-470.0, -92.0)
	zone_banner.size = Vector2(940.0, 90.0)
	zone_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	zone_banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	zone_banner.add_theme_font_size_override("font_size", 32)
	zone_banner.add_theme_constant_override("outline_size", 10)
	zone_banner.visible = false
	root.add_child(zone_banner)

	_build_joystick(root)
	_build_action_buttons(root)
	_build_map_panel(root)


func _build_joystick(root):
	var joystick = ColorRect.new()
	joystick.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	joystick.position = Vector2(28.0, -190.0)
	joystick.size = Vector2(160.0, 160.0)
	joystick.color = Color(0.10, 0.26, 0.48, 0.54)
	joystick.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(joystick)

	joystick_knob = ColorRect.new()
	joystick_knob.position = Vector2(54.0, 54.0)
	joystick_knob.size = Vector2(52.0, 52.0)
	joystick_knob.color = Color(0.64, 0.84, 1.0, 0.84)
	joystick_knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	joystick.add_child(joystick_knob)


func _build_action_buttons(root):
	var attack_button = _make_button(root, "ATTAQUE", Vector2(-126.0, -116.0), Vector2(108.0, 54.0))
	attack_button.pressed.connect(_attack_button_pressed)

	var jump_button = _make_button(root, "SAUT", Vector2(-244.0, -116.0), Vector2(108.0, 54.0))
	jump_button.pressed.connect(_jump_button_pressed)

	var dodge_button = _make_button(root, "ESQUIVE", Vector2(-244.0, -58.0), Vector2(108.0, 48.0))
	dodge_button.pressed.connect(_dodge_button_pressed)

	var action_button = _make_button(root, "ACTION", Vector2(-126.0, -58.0), Vector2(108.0, 48.0))
	action_button.pressed.connect(_action_button_pressed)

	var dive_button = _make_button(root, "PLONGER", Vector2(-362.0, -58.0), Vector2(108.0, 48.0))
	dive_button.pressed.connect(_dive_button_pressed)


func _make_button(parent, text, position, size):
	var button = Button.new()
	button.text = text
	button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	button.position = position
	button.size = size
	button.add_theme_font_size_override("font_size", 14)
	parent.add_child(button)
	return button


func _build_map_panel(root):
	map_panel = ColorRect.new()
	map_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	map_panel.color = Color(0.005, 0.012, 0.03, 0.96)
	map_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	map_panel.visible = false
	root.add_child(map_panel)

	var title = Label.new()
	title.text = "CARTE DU MONDE — 10 ZONES"
	title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title.position = Vector2(-300.0, 6.0)
	title.size = Vector2(600.0, 40.0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	map_panel.add_child(title)

	map_frame = Control.new()
	map_frame.set_anchors_preset(Control.PRESET_CENTER)
	map_frame.position = Vector2(-225.0, -128.0)
	map_frame.size = Vector2(450.0, 300.0)
	map_panel.add_child(map_frame)

	var map_texture = TextureRect.new()
	map_texture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if ResourceLoader.exists(WORLD_MAP_PATH):
		map_texture.texture = load(WORLD_MAP_PATH)
	map_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	map_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	map_frame.add_child(map_texture)

	map_player_marker = Label.new()
	map_player_marker.text = "●\nVOUS"
	map_player_marker.size = Vector2(76.0, 44.0)
	map_player_marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	map_player_marker.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	map_player_marker.modulate = Color(1.0, 0.18, 0.12)
	map_player_marker.add_theme_font_size_override("font_size", 15)
	map_player_marker.add_theme_constant_override("outline_size", 7)
	map_frame.add_child(map_player_marker)

	map_zone_label = Label.new()
	map_zone_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	map_zone_label.position = Vector2(-260.0, 134.0)
	map_zone_label.size = Vector2(520.0, 36.0)
	map_zone_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	map_zone_label.add_theme_font_size_override("font_size", 18)
	map_panel.add_child(map_zone_label)

	map_status_label = Label.new()
	map_status_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	map_status_label.position = Vector2(-300.0, 167.0)
	map_status_label.size = Vector2(600.0, 34.0)
	map_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	map_status_label.add_theme_font_size_override("font_size", 15)
	map_panel.add_child(map_status_label)

	var close_button = Button.new()
	close_button.text = "FERMER"
	close_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	close_button.position = Vector2(-112.0, 9.0)
	close_button.size = Vector2(98.0, 42.0)
	close_button.pressed.connect(_toggle_map)
	map_panel.add_child(close_button)


func _toggle_map():
	if not is_instance_valid(map_panel):
		return
	if is_instance_valid(adventure_panel) and adventure_panel.visible:
		adventure_panel.visible = false
	map_panel.visible = not map_panel.visible
	virtual_move = Vector2.ZERO
	move_touch_id = -1
	look_touch_id = -1
	_reset_joystick()
	if is_instance_valid(player):
		player.can_control = not map_panel.visible
	_update_map_marker()


func _update_map_marker():
	if not is_instance_valid(map_player_marker) or not is_instance_valid(map_frame):
		return

	var marker = MAP_MARKERS[current_zone]
	map_player_marker.position = Vector2(marker.x * map_frame.size.x - 38.0, marker.y * map_frame.size.y - 22.0)
	map_zone_label.text = "VOUS ÊTES EN ZONE %d — %s" % [current_zone + 1, ZONE_NAMES[current_zone]]

	var completed_count = 0
	for zone_index in range(zone_completed.size()):
		if bool(zone_completed[zone_index]):
			completed_count += 1
	map_status_label.text = "Régions libérées : %d / 10 — Touchez FERMER pour reprendre" % completed_count


func _show_zone_banner():
	if not is_instance_valid(zone_banner):
		return
	zone_banner_token += 1
	var token = zone_banner_token
	zone_banner.text = "ZONE %d\n%s" % [current_zone + 1, ZONE_NAMES[current_zone]]
	zone_banner.modulate = ZONE_ACCENT_COLORS[current_zone]
	zone_banner.visible = true
	await get_tree().create_timer(2.8).timeout
	if token == zone_banner_token and is_instance_valid(zone_banner):
		zone_banner.visible = false


func _attack_button_pressed():
	if is_instance_valid(player):
		player.attack()


func _jump_button_pressed():
	if not is_instance_valid(player):
		return
	if player.is_swimming:
		player.ascend()
	elif player.is_on_floor():
		player.velocity.y = player.jump_velocity


func _dodge_button_pressed():
	if is_instance_valid(player):
		player.dodge()


func _action_button_pressed():
	if is_instance_valid(player):
		player.interact()


func _dive_button_pressed():
	if is_instance_valid(player):
		player.dive()


func _update_joystick(position):
	var offset = (position - move_origin).limit_length(64.0)
	virtual_move = offset / 64.0
	if is_instance_valid(joystick_knob):
		joystick_knob.position = Vector2(54.0, 54.0) + offset


func _reset_joystick():
	if is_instance_valid(joystick_knob):
		joystick_knob.position = Vector2(54.0, 54.0)


func _on_health_changed(current, maximum):
	if is_instance_valid(health_label):
		health_label.text = "PV %d / %d" % [current, maximum]


func _update_hud():
	if is_instance_valid(player) and is_instance_valid(health_label):
		health_label.text = "PV %d / %d" % [player.health, player.max_health]

	if is_instance_valid(zone_label):
		zone_label.text = "ZONE %d / 10 — %s" % [current_zone + 1, ZONE_NAMES[current_zone]]
		zone_label.modulate = ZONE_ACCENT_COLORS[current_zone]

	if is_instance_valid(objective_label):
		if game_complete:
			objective_label.text = "MONDE LIBÉRÉ\n%d gardiens vaincus" % total_defeated
		elif current_zone == START_ZONE:
			objective_label.text = "Objectif : ouvre CARTE\net choisis ta destination"
		elif int(zone_remaining[current_zone]) > 0:
			objective_label.text = "Gardiens : %d / %d\nCarte disponible" % [zone_remaining[current_zone], zone_total[current_zone]]
		else:
			objective_label.text = "ZONE LIBÉRÉE\nExplore une autre région"


func _show_message(text, duration):
	if not is_instance_valid(message_label):
		return
	message_token += 1
	var token = message_token
	message_label.text = text
	await get_tree().create_timer(duration).timeout
	if token == message_token and is_instance_valid(message_label):
		message_label.text = ""


func _play_music(path):
	if not ResourceLoader.exists(path):
		return
	if not is_instance_valid(music_player):
		music_player = AudioStreamPlayer.new()
		music_player.volume_db = -9.0
		music_player.finished.connect(_replay_music)
		add_child(music_player)
	music_player.stream = load(path)
	music_player.play()


func _replay_music():
	if is_instance_valid(music_player):
		music_player.play()


func _update_battle_music():
	var nearby = false
	for enemy in enemies:
		if is_instance_valid(enemy) and enemy.health > 0:
			if enemy.global_position.distance_to(player.global_position) < 14.0:
				nearby = true
				break

	if nearby != battle_music_active:
		battle_music_active = nearby
		_play_music(MUSIC_BATTLE_PATH if nearby else MUSIC_WORLD_PATH)


func _add_zone_title(zone_index):
	var center = ZONE_CENTERS[zone_index]
	var local_z = -TERRAIN_SIZE.y * 0.36
	var world_y = _terrain_world_height(zone_index, center.x, center.z + local_z) + 4.2
	var anchor = Node3D.new()
	anchor.position = Vector3(center.x, world_y, center.z + local_z)
	_attach_world_node(anchor)
	_add_world_label(anchor, "ZONE %d — %s" % [zone_index + 1, ZONE_NAMES[zone_index]], Vector3.ZERO, ZONE_ACCENT_COLORS[zone_index])


func _add_world_label(parent, text, position, color):
	var label = Label3D.new()
	label.text = text
	label.position = position
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 38
	label.outline_size = 9
	label.modulate = color
	label.visibility_range_end = 145.0
	parent.add_child(label)


func _configure_geometry_lod(node: Node, distance: float):
	if node is GeometryInstance3D:
		var geometry = node as GeometryInstance3D
		geometry.visibility_range_end = distance
		geometry.lod_bias = 0.72
	for child in node.get_children():
		_configure_geometry_lod(child, distance)


func _place_model(path, zone_index, offset, scale, rotation):
	if not ResourceLoader.exists(path):
		return null
	var resource = load(path)
	if not (resource is PackedScene):
		return null

	var instance = resource.instantiate()
	if not (instance is Node3D):
		instance.queue_free()
		return null

	offset = _scaled_region_offset(offset)
	var center = ZONE_CENTERS[zone_index]
	var world_x = center.x + offset.x
	var world_z = center.z + offset.z
	instance.position = Vector3(world_x, _terrain_world_height(zone_index, world_x, world_z) + offset.y, world_z)
	instance.scale = scale
	instance.rotation = rotation
	_add_model_collision(instance, path)
	_configure_geometry_lod(instance, 230.0)
	_attach_world_node(instance)
	return instance


func _add_model_collision(instance: Node3D, path: String) -> void:
	var body = StaticBody3D.new()
	body.name = "CollisionDécor"
	var collision = CollisionShape3D.new()
	if path == TREE_MODEL:
		var capsule = CapsuleShape3D.new()
		capsule.radius = 0.34
		capsule.height = 2.8
		collision.position.y = 1.4
		collision.shape = capsule
	elif path == HOUSE_MODEL:
		var house_box = BoxShape3D.new()
		house_box.size = Vector3(4.5, 2.9, 3.5)
		collision.position.y = 1.45
		collision.shape = house_box
	elif path == RUIN_MODEL:
		var ruin_box = BoxShape3D.new()
		ruin_box.size = Vector3(5.4, 4.5, 1.4)
		collision.position.y = 2.25
		collision.shape = ruin_box
	elif path == BOAT_MODEL:
		var boat_box = BoxShape3D.new()
		boat_box.size = Vector3(2.5, 1.1, 5.8)
		collision.position.y = 0.65
		collision.shape = boat_box
	else:
		return
	body.add_child(collision)
	instance.add_child(body)


func _add_rock(zone_index, offset, scale_value, color):
	offset = _scaled_region_offset(offset)
	var center = ZONE_CENTERS[zone_index]
	var world_x = center.x + offset.x
	var world_z = center.z + offset.z
	var rock = MeshInstance3D.new()
	var mesh = SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 1.7
	mesh.material = _material(color)
	rock.mesh = mesh
	rock.position = Vector3(world_x, _terrain_world_height(zone_index, world_x, world_z) + offset.y + scale_value.y * 0.42, world_z)
	rock.scale = scale_value
	rock.rotation = Vector3(offset.z * 0.04, offset.x * 0.08, offset.x * 0.03)
	_configure_geometry_lod(rock, 185.0)
	_attach_world_node(rock)
	return rock


func _add_crystal(zone_index, offset, size_value, color):
	offset = _scaled_region_offset(offset)
	var center = ZONE_CENTERS[zone_index]
	var world_x = center.x + offset.x
	var world_z = center.z + offset.z
	var crystal = MeshInstance3D.new()
	var mesh = PrismMesh.new()
	mesh.size = Vector3(size_value * 0.55, size_value * 2.2, size_value * 0.55)
	mesh.material = _material(color, color)
	crystal.mesh = mesh
	crystal.position = Vector3(world_x, _terrain_world_height(zone_index, world_x, world_z) + offset.y + size_value, world_z)
	crystal.rotation.y = offset.x * 0.11
	_configure_geometry_lod(crystal, 190.0)
	_attach_world_node(crystal)
	return crystal


func _add_water_patch(zone_index, offset, patch_size, color, emission = Color(0.0, 0.0, 0.0, 1.0)):
	offset = _scaled_region_offset(offset)
	patch_size *= REGION_LAYOUT_SCALE
	var center = ZONE_CENTERS[zone_index]
	var world_x = center.x + offset.x
	var world_z = center.z + offset.z
	var y_value = _terrain_world_height(zone_index, world_x, world_z) + offset.y + 0.10
	return _visual_box("WaterPatch", Vector3(patch_size.x, 0.08, patch_size.y), Vector3(world_x, y_value, world_z), color, emission)


func _add_waterfall(zone_index, offset, waterfall_size):
	offset = _scaled_region_offset(offset)
	waterfall_size = Vector2(waterfall_size.x * REGION_LAYOUT_SCALE, waterfall_size.y * 1.45)
	var center = ZONE_CENTERS[zone_index]
	var world_x = center.x + offset.x
	var world_z = center.z + offset.z
	var waterfall = _visual_box("Waterfall", Vector3(waterfall_size.x, waterfall_size.y, 0.12), Vector3(world_x, center.y + offset.y, world_z), Color(0.46, 0.82, 0.98, 0.72), Color(0.08, 0.30, 0.48))
	waterfall.rotation.y = PI * 0.5


func _add_disc(position, radius, color, emission):
	var mesh_instance = MeshInstance3D.new()
	var mesh = CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = 0.14
	mesh.material = _material(color, emission)
	mesh_instance.mesh = mesh
	mesh_instance.position = position
	_attach_world_node(mesh_instance)
	return mesh_instance


func _add_colossus(zone_index, offset):
	offset = _scaled_region_offset(offset)
	var center = ZONE_CENTERS[zone_index]
	var world_x = center.x + offset.x
	var world_z = center.z + offset.z
	var ground_y = _terrain_world_height(zone_index, world_x, world_z)
	var anchor = Node3D.new()
	anchor.position = Vector3(world_x, ground_y, world_z)
	_attach_world_node(anchor)

	var stone = Color(0.42, 0.34, 0.23)
	var torso = _mesh_box(Vector3(2.8, 4.8, 1.9), stone)
	torso.position.y = 4.0
	anchor.add_child(torso)

	var head = MeshInstance3D.new()
	var head_mesh = SphereMesh.new()
	head_mesh.radius = 1.15
	head_mesh.height = 2.2
	head_mesh.material = _material(stone)
	head.mesh = head_mesh
	head.position.y = 7.1
	anchor.add_child(head)

	for side in [-1.0, 1.0]:
		var arm = _mesh_box(Vector3(1.0, 4.6, 1.0), stone)
		arm.position = Vector3(side * 2.1, 4.1, 0.0)
		arm.rotation.z = side * 0.12
		anchor.add_child(arm)

		var leg = _mesh_box(Vector3(1.1, 3.7, 1.2), stone)
		leg.position = Vector3(side * 0.8, 1.85, 0.0)
		anchor.add_child(leg)


func _add_pyramid(zone_index, offset, size_value):
	offset = _scaled_region_offset(offset)
	var center = ZONE_CENTERS[zone_index]
	var world_x = center.x + offset.x
	var world_z = center.z + offset.z
	var pyramid = MeshInstance3D.new()
	var mesh = PrismMesh.new()
	mesh.size = Vector3(size_value, size_value * 0.82, size_value)
	mesh.material = _material(Color(0.72, 0.56, 0.30))
	pyramid.mesh = mesh
	pyramid.position = Vector3(world_x, _terrain_world_height(zone_index, world_x, world_z) + size_value * 0.41, world_z)
	pyramid.rotation.x = PI * 0.5
	_attach_world_node(pyramid)


func _add_column(zone_index, offset, height_value):
	offset = _scaled_region_offset(offset)
	var center = ZONE_CENTERS[zone_index]
	var world_x = center.x + offset.x
	var world_z = center.z + offset.z
	var column = MeshInstance3D.new()
	var mesh = CylinderMesh.new()
	mesh.top_radius = 0.65
	mesh.bottom_radius = 0.78
	mesh.height = height_value
	mesh.material = _material(Color(0.68, 0.58, 0.38))
	column.mesh = mesh
	column.position = Vector3(world_x, _terrain_world_height(zone_index, world_x, world_z) + height_value * 0.5, world_z)
	_attach_world_node(column)


func _add_tower(zone_index, offset, height_value):
	offset = _scaled_region_offset(offset)
	var center = ZONE_CENTERS[zone_index]
	var world_x = center.x + offset.x
	var world_z = center.z + offset.z
	var y_value = _terrain_world_height(zone_index, world_x, world_z) + height_value * 0.5
	return _static_box("CapitalTower", Vector3(4.5, height_value, 4.5), Vector3(world_x, y_value, world_z), Color(0.20, 0.19, 0.22))


func _add_wall(zone_index, offset, size_value):
	offset = _scaled_region_offset(offset)
	var center = ZONE_CENTERS[zone_index]
	var world_x = center.x + offset.x
	var world_z = center.z + offset.z
	var y_value = _terrain_world_height(zone_index, world_x, world_z) + size_value.y * 0.5
	return _static_box("CapitalWall", size_value, Vector3(world_x, y_value, world_z), Color(0.18, 0.17, 0.20))


func _add_path(zone_index, offset, size_value, rotation_y):
	offset = _scaled_region_offset(offset)
	size_value = Vector3(size_value.x, size_value.y, size_value.z * REGION_LAYOUT_SCALE)
	var center = ZONE_CENTERS[zone_index]
	var world_x = center.x + offset.x
	var world_z = center.z + offset.z
	var y_value = _terrain_world_height(zone_index, world_x, world_z) + offset.y
	var path = _visual_box("ZonePath", size_value, Vector3(world_x, y_value, world_z), Color(0.48, 0.34, 0.20))
	path.rotation.y = rotation_y
	return path


func _static_box(name, size_value, position, color, emission = Color(0.0, 0.0, 0.0, 1.0)):
	var body = StaticBody3D.new()
	body.name = name
	body.position = position

	var visual = MeshInstance3D.new()
	var mesh = BoxMesh.new()
	mesh.size = size_value
	mesh.material = _material(color, emission)
	visual.mesh = mesh
	_configure_geometry_lod(visual, 230.0)
	body.add_child(visual)

	var collision = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = size_value
	collision.shape = shape
	body.add_child(collision)
	_attach_world_node(body)
	return body


func _visual_box(name, size_value, position, color, emission = Color(0.0, 0.0, 0.0, 1.0)):
	var visual = MeshInstance3D.new()
	visual.name = name
	var mesh = BoxMesh.new()
	mesh.size = size_value
	mesh.material = _material(color, emission)
	visual.mesh = mesh
	visual.position = position
	_configure_geometry_lod(visual, 220.0)
	_attach_world_node(visual)
	return visual


func _scaled_region_offset(offset: Vector3) -> Vector3:
	return Vector3(offset.x * REGION_LAYOUT_SCALE, offset.y, offset.z * REGION_LAYOUT_SCALE)


func _region_surface_position(zone_index: int, offset: Vector3, lift: float = 0.0) -> Vector3:
	var scaled = _scaled_region_offset(offset)
	var center = ZONE_CENTERS[zone_index]
	var world_x = center.x + scaled.x
	var world_z = center.z + scaled.z
	return Vector3(world_x, _terrain_world_height(zone_index, world_x, world_z) + scaled.y + lift, world_z)


func _attach_world_node(node: Node) -> void:
	if is_instance_valid(active_build_parent):
		active_build_parent.add_child(node)
	else:
		add_child(node)


func _mesh_box(size_value, color):
	var visual = MeshInstance3D.new()
	var mesh = BoxMesh.new()
	mesh.size = size_value
	mesh.material = _material(color)
	visual.mesh = mesh
	return visual


func _material(color, emission = Color(0.0, 0.0, 0.0, 1.0)):
	var material = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.68
	if color.a < 0.99:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if emission.r + emission.g + emission.b > 0.01:
		material.emission_enabled = true
		material.emission = emission
		material.emission_energy_multiplier = 2.4
	return material


func _save_progress():
	if not is_instance_valid(player):
		return

	var config = ConfigFile.new()
	config.set_value("world", "remaining", zone_remaining)
	config.set_value("world", "completed", zone_completed)
	config.set_value("world", "total_defeated", total_defeated)
	config.set_value("world", "complete", game_complete)
	config.set_value("player", "position", player.global_position)
	config.set_value("player", "health", player.health)
	if is_instance_valid(world_clock):
		var world_state = world_clock.get_save_state()
		config.set_value("time_weather", "minutes", world_state.get("minutes", 480.0))
		config.set_value("time_weather", "weather", world_state.get("weather", "clair"))
		config.set_value("time_weather", "weather_remaining", world_state.get("weather_remaining", 110.0))
	if is_instance_valid(adventure_progress):
		var adventure_state = adventure_progress.get_save_state()
		config.set_value("adventure", "inventory", adventure_state.get("inventory", {}))
		config.set_value("adventure", "quests", adventure_state.get("quests", []))
		config.set_value("adventure", "discovered_points", adventure_state.get("discovered_points", {}))
		config.set_value("adventure", "collected_objects", adventure_state.get("collected_objects", {}))
		config.set_value("adventure", "gold", adventure_state.get("gold", 0))
		config.set_value("adventure", "reputation", adventure_state.get("reputation", []))
		config.set_value("adventure", "world_flags", adventure_state.get("world_flags", {}))
	config.set_value("settings", "graphics_quality", graphics_quality)
	config.set_value("tutorial", "completed", tutorial_completed)
	config.set_value("tutorial", "index", tutorial_index)
	_safe_write_config(config)


func _load_progress():
	var config = ConfigFile.new()
	var load_error = config.load(SAVE_PATH)
	if load_error != OK:
		load_error = config.load(SAVE_BACKUP_PATH)
		if load_error != OK:
			return
		_show_message("La sauvegarde principale était illisible : la copie de secours a été restaurée.", 5.0)

	total_defeated = int(config.get_value("world", "total_defeated", 0))
	game_complete = bool(config.get_value("world", "complete", false))

	var saved_remaining = config.get_value("world", "remaining", zone_remaining)
	if saved_remaining is Array and saved_remaining.size() == zone_remaining.size():
		for zone_index in range(zone_remaining.size()):
			zone_remaining[zone_index] = int(saved_remaining[zone_index])

	var saved_completed = config.get_value("world", "completed", zone_completed)
	if saved_completed is Array and saved_completed.size() == zone_completed.size():
		for zone_index in range(zone_completed.size()):
			zone_completed[zone_index] = bool(saved_completed[zone_index])

	for enemy in enemies.duplicate():
		if not is_instance_valid(enemy):
			continue
		var enemy_zone = int(enemy.get_meta("zone_index", -1))
		if enemy_zone >= 0 and enemy_zone < zone_completed.size() and bool(zone_completed[enemy_zone]):
			enemies.erase(enemy)
			enemy.queue_free()

	var saved_position = config.get_value("player", "position", player.global_position)
	if saved_position is Vector3:
		player.global_position = saved_position
		player.set_spawn(saved_position)
	player.health = clamp(int(config.get_value("player", "health", player.max_health)), 1, player.max_health)
	player.health_changed.emit(player.health, player.max_health)
	if is_instance_valid(world_clock):
		world_clock.load_save_state({
			"minutes": config.get_value("time_weather", "minutes", 480.0),
			"weather": config.get_value("time_weather", "weather", "clair"),
			"weather_remaining": config.get_value("time_weather", "weather_remaining", 110.0)
		})
	if is_instance_valid(adventure_progress):
		adventure_progress.load_save_state({
			"inventory": config.get_value("adventure", "inventory", {}),
			"quests": config.get_value("adventure", "quests", []),
			"discovered_points": config.get_value("adventure", "discovered_points", {}),
			"collected_objects": config.get_value("adventure", "collected_objects", {}),
			"gold": config.get_value("adventure", "gold", 0),
			"reputation": config.get_value("adventure", "reputation", []),
			"world_flags": config.get_value("adventure", "world_flags", {})
		})
		_apply_ancient_puzzle_state()
		_apply_collected_object_state()
		_refresh_adventure_panel()
	graphics_quality = String(config.get_value("settings", "graphics_quality", graphics_quality))
	if not graphics_quality in ["faible", "moyen", "élevé"]:
		graphics_quality = "moyen"
	tutorial_completed = bool(config.get_value("tutorial", "completed", false))
	tutorial_index = clampi(int(config.get_value("tutorial", "index", 0)), 0, TUTORIAL_MESSAGES.size() - 1)
	_apply_graphics_quality(false)


func _safe_write_config(config: ConfigFile) -> void:
	if config.save(SAVE_TEMP_PATH) != OK:
		push_warning("Impossible d'écrire la sauvegarde temporaire.")
		return
	var absolute_main = ProjectSettings.globalize_path(SAVE_PATH)
	var absolute_backup = ProjectSettings.globalize_path(SAVE_BACKUP_PATH)
	var absolute_temp = ProjectSettings.globalize_path(SAVE_TEMP_PATH)
	if FileAccess.file_exists(absolute_main):
		DirAccess.copy_absolute(absolute_main, absolute_backup)
		DirAccess.remove_absolute(absolute_main)
	if DirAccess.rename_absolute(absolute_temp, absolute_main) != OK:
		DirAccess.copy_absolute(absolute_temp, absolute_main)
		DirAccess.remove_absolute(absolute_temp)
