extends "res://scripts/main_water_final.gd"

const YVANE_PLAYER_SCRIPT = preload("res://scripts/player_yvane.gd")
const UPLOADED_ENEMY_SCRIPT = preload("res://scripts/uploaded_enemy.gd")

const YVANE_PLAYER_MODEL = "res://scenes/characters/yvane_player_2_model.tscn"
const SOLDIER_ISLAND_1_MODEL = "res://scenes/characters/soldat_ile_1_model.tscn"
const NIGHTMARE_WITCH_MODEL = "res://scenes/characters/sorciere_cauchemars_boss_model.tscn"

var _uploaded_showcase_spawned: bool = false


func _spawn_player() -> void:
	if not ResourceLoader.exists(YVANE_PLAYER_MODEL):
		push_error("Le modèle joueur 2 Yvane est absent ou non importable")
		return

	player = YVANE_PLAYER_SCRIPT.new()
	player.name = "YvanePlayer2"
	var center: Vector3 = ZONE_CENTERS[START_ZONE]
	var spawn_x: float = center.x
	var spawn_z: float = center.z + 4.0
	player.position = Vector3(
		spawn_x,
		_terrain_world_height(START_ZONE, spawn_x, spawn_z) + 0.45,
		spawn_z
	)
	add_child(player)
	player.set_spawn(player.global_position)
	player.set_water_profile(OCEAN_SURFACE_Y, OCEAN_BOTTOM_Y, OCEAN_BOUNDS)
	player.apply_asset(YVANE_PLAYER_MODEL)
	player.health_changed.connect(_on_health_changed)
	player.attack_requested.connect(_on_player_attack)
	player.interact_requested.connect(_on_interact)

	if not _is_ci_validation():
		call_deferred("_spawn_uploaded_character_showcase")


func _spawn_uploaded_character_showcase() -> void:
	if _uploaded_showcase_spawned or not is_instance_valid(player):
		return
	_uploaded_showcase_spawned = true

	_spawn_uploaded_enemy(
		"SoldatIle1",
		"Soldat de l’île 1",
		SOLDIER_ISLAND_1_MODEL,
		Vector3(7.5, 0.0, -4.5),
		1,
		false
	)
	_spawn_uploaded_enemy(
		"GrandeSorciereCauchemars",
		"Grande sorcière des cauchemars",
		NIGHTMARE_WITCH_MODEL,
		Vector3(-12.0, 0.0, -8.0),
		6,
		true
	)


func _spawn_uploaded_enemy(
	node_name: String,
	display_name: String,
	asset_path: String,
	offset: Vector3,
	variant: int,
	boss: bool
) -> void:
	if not ResourceLoader.exists(asset_path):
		push_warning("Asset de démonstration absent : %s" % asset_path)
		return

	var enemy = UPLOADED_ENEMY_SCRIPT.new()
	enemy.name = node_name
	var spawn_x := player.global_position.x + offset.x
	var spawn_z := player.global_position.z + offset.z
	enemy.position = Vector3(
		spawn_x,
		_terrain_world_height(START_ZONE, spawn_x, spawn_z) + 0.18,
		spawn_z
	)
	add_child(enemy)
	enemy.setup(player, variant, asset_path)
	enemy.spawn_position = enemy.global_position

	if boss:
		enemy.max_health = 360
		enemy.health = 360
		enemy.move_speed = 2.55
		enemy.damage = 22
		enemy.aggro_range = 24.0
		enemy.attack_range = 2.65
	else:
		enemy.max_health = 95
		enemy.health = 95
		enemy.move_speed = 3.45
		enemy.damage = 11
		enemy.aggro_range = 16.0
		enemy.attack_range = 1.8

	if enemy.has_method("_update_health_label"):
		enemy.call("_update_health_label")
	_add_character_name_label(enemy, display_name, 3.45 if boss else 2.55)


func _add_character_name_label(character: Node3D, title: String, height: float) -> void:
	var label := Label3D.new()
	label.name = "CharacterName"
	label.text = title
	label.position = Vector3(0.0, height, 0.0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 30
	label.outline_size = 8
	label.modulate = Color(1.0, 0.92, 0.68) if title.contains("sorcière") else Color(0.78, 0.9, 1.0)
	character.add_child(label)


func _is_ci_validation() -> bool:
	var arguments := OS.get_cmdline_user_args()
	var ci_flags: Array[String] = [
		"--ci-walk-check",
		"--ci-full-playthrough",
		"--ci-water-physics",
		"--ci-hud-shot"
	]
	for flag in ci_flags:
		if flag in arguments:
			return true
	return false


func _build_character_portrait(root) -> void:
	super._build_character_portrait(root)
	if not is_instance_valid(portrait_viewport):
		return
	if is_instance_valid(portrait_model):
		portrait_model.queue_free()
		portrait_model = null
	if not ResourceLoader.exists(YVANE_PLAYER_MODEL):
		return

	var hero_resource: Resource = load(YVANE_PLAYER_MODEL)
	if hero_resource is PackedScene:
		portrait_model = (hero_resource as PackedScene).instantiate()
		portrait_model.rotation.y = PI
		portrait_model.position = Vector3.ZERO
		portrait_viewport.add_child(portrait_model)
		_play_portrait_idle(portrait_model)


func _play_portrait_idle(root: Node) -> void:
	if root is AnimationPlayer:
		var animation_player := root as AnimationPlayer
		for animation_name in animation_player.get_animation_list():
			var lowered := String(animation_name).to_lower()
			if lowered == "idle" or lowered.ends_with("/idle"):
				animation_player.play(animation_name)
				return
	for child in root.get_children():
		_play_portrait_idle(child)
