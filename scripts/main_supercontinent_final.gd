extends "res://scripts/main_supercontinent_v10.gd"

const V61_PLAYER_SCRIPT = preload("res://scripts/player_yvane_v61.gd")

# Positions choisies à la main pour répartir les gardiens dans les grandes zones.
const V61_GUARDIAN_OFFSETS = {
	0: [Vector2(-92.0, 72.0), Vector2(118.0, -82.0)],
	1: [Vector2(-125.0, 82.0), Vector2(132.0, 96.0)],
	2: [Vector2(-118.0, 78.0), Vector2(128.0, -70.0)],
	3: [Vector2(-105.0, 92.0), Vector2(132.0, 72.0)],
	4: [Vector2(-132.0, -82.0), Vector2(118.0, 105.0)],
	5: [Vector2(-120.0, -88.0), Vector2(128.0, 92.0)],
	6: [Vector2(-110.0, 92.0), Vector2(125.0, -85.0)],
	8: [Vector2(-132.0, -92.0), Vector2(125.0, -75.0), Vector2(18.0, 128.0)],
	9: [Vector2(-128.0, 88.0), Vector2(132.0, -72.0), Vector2(12.0, 132.0)]
}


func _spawn_player() -> void:
	if not ResourceLoader.exists(YVANE_MODEL_PATH):
		push_error("Le modèle GLB de Yvane est absent ou non importable")
		return
	player = V61_PLAYER_SCRIPT.new()
	player.name = "YvanePlayer2V61"
	var center: Vector3 = SUPER_ZONE_CENTERS[START_ZONE]
	var spawn_x := center.x
	var spawn_z := center.z + 24.0
	player.position = Vector3(spawn_x, _super_height(spawn_x, spawn_z) + 0.55, spawn_z)
	add_child(player)
	player.set_spawn(player.global_position)
	player.set_water_profile(WATER_SURFACE_Y, WATER_BOTTOM_Y, SUPER_OCEAN_BOUNDS)
	player.apply_asset(YVANE_MODEL_PATH)
	player.health_changed.connect(_on_health_changed)
	player.attack_requested.connect(_on_player_attack)
	player.interact_requested.connect(_on_interact)


func _build_portals() -> void:
	var capital: Vector3 = SUPER_ZONE_CENTERS[8]
	capital_portal_position = Vector3(capital.x + 132.0, _super_height(capital.x + 132.0, capital.z) + 0.5, capital.z)
	_add_portal(capital_portal_position, Color(0.30, 0.72, 1.0), "RACCOURCI VERS LES HAUTS PLATEAUX")
	var highlands: Vector3 = SUPER_ZONE_CENTERS[9]
	sky_portal_position = Vector3(highlands.x - 138.0, _super_height(highlands.x - 138.0, highlands.z) + 0.5, highlands.z)
	_add_portal(sky_portal_position, Color(1.0, 0.78, 0.24), "RETOUR AU ROYAUME CENTRAL")


func _spawn_guardians() -> void:
	spawned_bosses.clear()
	zone_remaining.resize(SUPER_ZONE_CENTERS.size())
	zone_total.resize(SUPER_ZONE_CENTERS.size())
	zone_completed.resize(SUPER_ZONE_CENTERS.size())
	for zone_index in range(SUPER_ZONE_CENTERS.size()):
		zone_remaining[zone_index] = 0
		zone_total[zone_index] = 0
		zone_completed[zone_index] = false
	zone_completed[START_ZONE] = true

	for zone_index in range(SUPER_ZONE_CENTERS.size()):
		if zone_index == START_ZONE:
			continue
		var offsets: Array = V61_GUARDIAN_OFFSETS.get(zone_index, [])
		zone_remaining[zone_index] = offsets.size()
		zone_total[zone_index] = offsets.size()
		for enemy_index in range(offsets.size()):
			if enemy_index == 0 and BOSS_SPECS.has(zone_index):
				_spawn_imported_boss(zone_index, BOSS_SPECS[zone_index], offsets[enemy_index])
			else:
				_spawn_generic_guardian_v61(zone_index, enemy_index, offsets[enemy_index])


func _spawn_imported_boss(zone_index: int, spec: Dictionary, offset: Vector2 = Vector2.ZERO) -> void:
	var enemy = IMPORTED_ENEMY_SCRIPT.new()
	var boss_id := String(spec["node"])
	var boss_asset := String(spec["asset"])
	enemy.name = boss_id
	enemy.set("visual_height", float(spec["height"]))
	var center: Vector3 = SUPER_ZONE_CENTERS[zone_index]
	var world_x := center.x + offset.x
	var world_z := center.z + offset.y
	enemy.position = Vector3(world_x, _super_height(world_x, world_z) + 1.10, world_z)
	enemy.set_meta("zone_index", zone_index)
	enemy.set_meta("boss_id", boss_id)
	enemy.set_meta("boss_asset", boss_asset)
	add_child(enemy)
	spawned_bosses[boss_id] = enemy
	enemy.setup(player, zone_index + 2, boss_asset)
	enemy.max_health = int(spec["health"])
	enemy.health = enemy.max_health
	enemy.damage = int(spec["damage"])
	enemy.move_speed = float(spec["speed"])
	enemy.aggro_range = 46.0
	enemy.attack_range = 2.55
	enemy.spawn_position = enemy.global_position
	enemy.defeated.connect(_on_enemy_defeated)
	enemies.append(enemy)
	if enemy.has_method("_update_health_label"):
		enemy.call("_update_health_label")
	_add_character_name_label(enemy, String(spec["title"]), float(spec["height"]) + 0.65)
	_add_boss_aura(enemy, spec["color"])


func _spawn_generic_guardian_v61(zone_index: int, enemy_index: int, offset: Vector2) -> void:
	var enemy = GENERIC_ENEMY_SCRIPT.new()
	enemy.name = "Zone_%02d_Gardien_%02d" % [zone_index + 1, enemy_index + 1]
	var center: Vector3 = SUPER_ZONE_CENTERS[zone_index]
	var world_x := center.x + offset.x
	var world_z := center.z + offset.y
	enemy.position = Vector3(world_x, _super_height(world_x, world_z) + 0.55, world_z)
	enemy.set_meta("zone_index", zone_index)
	add_child(enemy)
	var model_index := (zone_index + enemy_index) % ENEMY_MODELS.size()
	enemy.setup(player, model_index, ENEMY_MODELS[model_index])
	enemy.aggro_range = 40.0
	enemy.spawn_position = enemy.global_position
	enemy.defeated.connect(_on_enemy_defeated)
	enemies.append(enemy)


func get_ci_water_points() -> Dictionary:
	var shore_land := Vector3(-785.0, 0.0, 0.0)
	shore_land.y = _super_height(shore_land.x, shore_land.z) + 0.80
	var shore_water := Vector3(-965.0, WATER_SURFACE_Y - 1.15, 0.0)
	var river_x := 40.0
	var river_z := _river_two_z(river_x)
	var river_water := Vector3(river_x, WATER_SURFACE_Y - 1.15, river_z)
	var deep_water := Vector3(0.0, WATER_SURFACE_Y - 1.15, 690.0)
	return {
		"shore_land": shore_land,
		"shore_water": shore_water,
		"river_water": river_water,
		"deep_water": deep_water
	}


# Tant qu'un doigt tient le joystick, le héros avance normalement. Dès que le
# doigt est relâché, la vitesse résiduelle est supprimée à chaque image.
func _process(delta: float) -> void:
	super._process(delta)
	if not is_instance_valid(player):
		return
	if move_touch_id >= 0 or virtual_move.length() > 0.08:
		return
	if Input.is_action_pressed("move_forward") or Input.is_action_pressed("move_back"):
		return
	if Input.is_action_pressed("move_left") or Input.is_action_pressed("move_right"):
		return
	if float(player.get("dodge_cooldown")) > 0.02 or float(player.get("invulnerability")) > 0.02:
		return
	player.velocity.x = 0.0
	player.velocity.z = 0.0


func _release_movement_touch() -> void:
	super._release_movement_touch()
	if not is_instance_valid(player):
		return
	player.velocity.x = 0.0
	player.velocity.z = 0.0
