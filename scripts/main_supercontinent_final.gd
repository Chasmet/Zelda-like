extends "res://scripts/main_supercontinent_v10.gd"

# Le village de départ est installé sur une vraie grande plaine stable, et non
# sur la pente de la côte. Cela évite tout glissement involontaire du héros.
func _super_height(world_x: float, world_z: float) -> float:
	var base_height: float = super._super_height(world_x, world_z)
	var village_center: Vector3 = SUPER_ZONE_CENTERS[START_ZONE]
	var distance: float = Vector2(world_x - village_center.x, world_z - village_center.z).length()
	if distance >= 58.0:
		return base_height
	var flat_height := 2.10
	var blend := 1.0 - smoothstep(30.0, 58.0, distance)
	return lerpf(base_height, flat_height, blend)

# Le supercontinent utilise un vrai HeightMapShape3D. Le précédent collider
# concave ne retenait pas correctement le personnage sur cette carte étendue.
func _build_supercontinent_terrain() -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.90
	material.metallic = 0.01
	surface.set_material(material)

	var step_x := CONTINENT_SIZE.x / float(TERRAIN_STEPS_X)
	var step_z := CONTINENT_SIZE.y / float(TERRAIN_STEPS_Z)
	for z_index in range(TERRAIN_STEPS_Z):
		for x_index in range(TERRAIN_STEPS_X):
			var x0 := -CONTINENT_HALF.x + float(x_index) * step_x
			var x1 := x0 + step_x
			var z0 := -CONTINENT_HALF.y + float(z_index) * step_z
			var z1 := z0 + step_z
			var p00 := Vector3(x0, _super_height(x0, z0), z0)
			var p10 := Vector3(x1, _super_height(x1, z0), z0)
			var p01 := Vector3(x0, _super_height(x0, z1), z1)
			var p11 := Vector3(x1, _super_height(x1, z1), z1)
			_add_colored_triangle(surface, p00, p01, p11)
			_add_colored_triangle(surface, p00, p11, p10)

	surface.generate_normals()
	var mesh: ArrayMesh = surface.commit()
	var terrain := StaticBody3D.new()
	terrain.name = "SupercontinentTerrain"
	terrain.collision_layer = 1
	terrain.collision_mask = 1

	var visual := MeshInstance3D.new()
	visual.name = "SupercontinentVisual"
	visual.mesh = mesh
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	terrain.add_child(visual)

	# Une cellule physique représente 2 mètres. La hauteur est divisée par deux,
	# puis le collider reçoit une échelle uniforme ×2 : aucune déformation.
	const COLLISION_STEP := 2.0
	var collision_width := int(round(CONTINENT_SIZE.x / COLLISION_STEP)) + 1
	var collision_depth := int(round(CONTINENT_SIZE.y / COLLISION_STEP)) + 1
	var half_width := float(collision_width - 1) * COLLISION_STEP * 0.5
	var half_depth := float(collision_depth - 1) * COLLISION_STEP * 0.5
	var heights := PackedFloat32Array()
	heights.resize(collision_width * collision_depth)
	var data_index := 0
	for depth_index in range(collision_depth):
		var world_z := -half_depth + float(depth_index) * COLLISION_STEP
		for width_index in range(collision_width):
			var world_x := -half_width + float(width_index) * COLLISION_STEP
			heights[data_index] = _super_height(world_x, world_z) / COLLISION_STEP
			data_index += 1

	var height_shape := HeightMapShape3D.new()
	height_shape.map_width = collision_width
	height_shape.map_depth = collision_depth
	height_shape.map_data = heights
	var collision := CollisionShape3D.new()
	collision.name = "SupercontinentHeightMap"
	collision.shape = height_shape
	collision.scale = Vector3.ONE * COLLISION_STEP
	terrain.add_child(collision)
	add_child(terrain)

# Les grands boss sont déposés au-dessus du relief, puis la physique les pose
# correctement. Cela évite qu'un modèle volumineux naisse à moitié sous le sol.
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

# Tant qu'un doigt tient le joystick, le héros avance normalement. Dès que le
# doigt est relâché, la vitesse résiduelle est supprimée à chaque image. Les
# esquives et les projections restent intactes grâce aux délais de protection.
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

# Sur mobile, le héros doit s'arrêter dès que le joueur relâche le joystick.
func _release_movement_touch() -> void:
	super._release_movement_touch()
	if not is_instance_valid(player):
		return
	player.velocity.x = 0.0
	player.velocity.z = 0.0
