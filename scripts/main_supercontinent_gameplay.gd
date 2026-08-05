extends "res://scripts/main_supercontinent_decor.gd"

# Registre direct des quatre boss importés. Il évite de dépendre d'un nom de
# nœud éventuellement ajusté par Godot et permet de contrôler l'asset exact.
var spawned_bosses: Dictionary = {}

func _build_portals() -> void:
	var capital: Vector3 = SUPER_ZONE_CENTERS[8]
	capital_portal_position = Vector3(capital.x + 38.0, _super_height(capital.x + 38.0, capital.z) + 0.4, capital.z)
	_add_portal(capital_portal_position, Color(0.30, 0.72, 1.0), "RACCOURCI VERS LES HAUTS PLATEAUX")
	var highlands: Vector3 = SUPER_ZONE_CENTERS[9]
	sky_portal_position = Vector3(highlands.x - 42.0, _super_height(highlands.x - 42.0, highlands.z) + 0.4, highlands.z)
	_add_portal(sky_portal_position, Color(1.0, 0.78, 0.24), "RETOUR AU ROYAUME CENTRAL")

func _spawn_player() -> void:
	if not ResourceLoader.exists(YVANE_MODEL_PATH):
		push_error("Le modèle GLB de Yvane est absent ou non importable")
		return
	player = YVANE_SCRIPT.new()
	player.name = "YvanePlayer2"
	var center: Vector3 = SUPER_ZONE_CENTERS[START_ZONE]
	var spawn_x := center.x
	var spawn_z := center.z + 9.0
	player.position = Vector3(spawn_x, _super_height(spawn_x, spawn_z) + 0.45, spawn_z)
	add_child(player)
	player.set_spawn(player.global_position)
	player.set_water_profile(WATER_SURFACE_Y, WATER_BOTTOM_Y, SUPER_OCEAN_BOUNDS)
	player.apply_asset(YVANE_MODEL_PATH)
	player.health_changed.connect(_on_health_changed)
	player.attack_requested.connect(_on_player_attack)
	player.interact_requested.connect(_on_interact)

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
		var count := 3 if zone_index in [8, 9] else 2
		zone_remaining[zone_index] = count
		zone_total[zone_index] = count
		for enemy_index in range(count):
			if enemy_index == 0 and BOSS_SPECS.has(zone_index):
				_spawn_imported_boss(zone_index, BOSS_SPECS[zone_index])
			else:
				_spawn_generic_guardian(zone_index, enemy_index)

func _spawn_imported_boss(zone_index: int, spec: Dictionary) -> void:
	var enemy = IMPORTED_ENEMY_SCRIPT.new()
	var boss_id := String(spec["node"])
	var boss_asset := String(spec["asset"])
	enemy.name = boss_id
	enemy.set("visual_height", float(spec["height"]))
	var center: Vector3 = SUPER_ZONE_CENTERS[zone_index]
	var angle := 0.72 + float(zone_index) * 0.61
	var world_x := center.x + cos(angle) * 31.0
	var world_z := center.z + sin(angle) * 31.0
	enemy.position = Vector3(world_x, _super_height(world_x, world_z) + 0.24, world_z)
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
	enemy.aggro_range = 32.0
	enemy.attack_range = 2.55
	enemy.spawn_position = enemy.global_position
	enemy.defeated.connect(_on_enemy_defeated)
	enemies.append(enemy)
	if enemy.has_method("_update_health_label"):
		enemy.call("_update_health_label")
	_add_character_name_label(enemy, String(spec["title"]), float(spec["height"]) + 0.65)
	var aura_color: Color = spec["color"]
	_add_boss_aura(enemy, aura_color)

func _spawn_generic_guardian(zone_index: int, enemy_index: int) -> void:
	var enemy = GENERIC_ENEMY_SCRIPT.new()
	enemy.name = "Zone_%02d_Gardien_%02d" % [zone_index + 1, enemy_index + 1]
	var center: Vector3 = SUPER_ZONE_CENTERS[zone_index]
	var angle := TAU * float(enemy_index + 1) / 3.0 + 0.8 + float(zone_index) * 0.19
	var radius := 26.0 + float(enemy_index % 2) * 12.0
	var world_x := center.x + cos(angle) * radius
	var world_z := center.z + sin(angle) * radius
	enemy.position = Vector3(world_x, _super_height(world_x, world_z) + 0.45, world_z)
	enemy.set_meta("zone_index", zone_index)
	add_child(enemy)
	var model_index := (zone_index + enemy_index) % ENEMY_MODELS.size()
	enemy.setup(player, model_index, ENEMY_MODELS[model_index])
	enemy.spawn_position = enemy.global_position
	enemy.defeated.connect(_on_enemy_defeated)
	enemies.append(enemy)

func _add_boss_aura(enemy: Node3D, color: Color) -> void:
	var light := OmniLight3D.new()
	light.name = "BossAura"
	light.light_color = color
	light.light_energy = 2.1
	light.omni_range = 7.0
	light.position.y = 1.6
	enemy.add_child(light)
	var ring := MeshInstance3D.new()
	ring.name = "BossAuraRing"
	var torus := TorusMesh.new()
	torus.inner_radius = 1.1
	torus.outer_radius = 1.35
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(color.r, color.g, color.b, 0.62)
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 2.4
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	torus.material = material
	ring.mesh = torus
	ring.position.y = 0.08
	enemy.add_child(ring)

func _on_interact() -> void:
	if not is_instance_valid(player):
		return
	if player.global_position.distance_to(capital_portal_position) < 4.0:
		var highlands: Vector3 = SUPER_ZONE_CENTERS[9]
		var target_z := highlands.z + 7.0
		player.global_position = Vector3(highlands.x, _super_height(highlands.x, target_z) + 0.65, target_z)
		player.set_spawn(player.global_position)
		_show_message("Bienvenue dans la Zone 10 — Hauts plateaux célestes", 4.0)
		return
	if player.global_position.distance_to(sky_portal_position) < 4.0:
		var capital: Vector3 = SUPER_ZONE_CENTERS[8]
		var target_z := capital.z + 7.0
		player.global_position = Vector3(capital.x, _super_height(capital.x, target_z) + 0.65, target_z)
		player.set_spawn(player.global_position)
		_show_message("Retour au Royaume Central", 3.0)
		return
	if current_zone == START_ZONE:
		_show_message("Le supercontinent est ouvert : suis les routes ou ouvre CARTE.", 3.0)
	elif zone_remaining[current_zone] > 0:
		_show_message("Zone %d : il reste %d gardien(s)." % [current_zone + 1, zone_remaining[current_zone]], 2.8)
	else:
		_show_message("Zone %d libérée." % (current_zone + 1), 2.5)

func _terrain_world_height(_zone_index, world_x, world_z):
	return _super_height(float(world_x), float(world_z))

func _update_current_zone() -> void:
	if not is_instance_valid(player):
		return
	var nearest_zone := _nearest_super_zone(player.global_position)
	if nearest_zone != current_zone:
		current_zone = nearest_zone
		_update_hud()
		_update_map_marker()
		_show_zone_banner()

func _nearest_zone_for_position(world_position: Vector3) -> int:
	return _nearest_super_zone(world_position)

func get_ci_water_points() -> Dictionary:
	var shore_land := Vector3(-250.0, 0.0, 145.0)
	shore_land.y = _super_height(shore_land.x, shore_land.z) + 0.75
	var shore_water := Vector3(-348.0, WATER_SURFACE_Y - 1.15, 145.0)
	var river_x := 0.0
	var river_z := _river_two_z(river_x)
	var river_water := Vector3(river_x, WATER_SURFACE_Y - 1.15, river_z)
	var deep_water := Vector3(0.0, WATER_SURFACE_Y - 1.15, 305.0)
	return {
		"shore_land": shore_land,
		"shore_water": shore_water,
		"river_water": river_water,
		"deep_water": deep_water
	}
