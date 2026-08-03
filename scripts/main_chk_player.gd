extends "res://scripts/main_water_final.gd"

const CHK_PLAYER_SCRIPT = preload("res://scripts/player_chk.gd")
const CHK_HERO_MODEL = "res://scenes/chk_player_model.tscn"


func _spawn_player() -> void:
	if not ResourceLoader.exists(CHK_HERO_MODEL):
		push_error("Le modèle joueur 1 chk.glb est absent ou non importable")
		return

	player = CHK_PLAYER_SCRIPT.new()
	player.name = "CheikhHeroCHK"
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
	player.apply_asset(CHK_HERO_MODEL)
	player.health_changed.connect(_on_health_changed)
	player.attack_requested.connect(_on_player_attack)
	player.interact_requested.connect(_on_interact)
