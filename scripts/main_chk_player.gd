extends "res://scripts/main_water_final.gd"

const YVANE_PLAYER_SCRIPT = preload("res://scripts/player_yvane.gd")
const UPLOADED_ENEMY_SCRIPT = preload("res://scripts/uploaded_enemy.gd")

const YVANE_PLAYER_MODEL = "res://scenes/characters/yvane_player_2_model.tscn"
const SOLDIER_ISLAND_1_MODEL = "res://scenes/characters/soldat_ile_1_model.tscn"
const NIGHTMARE_WITCH_MODEL = "res://scenes/characters/sorciere_cauchemars_boss_model.tscn"

const COMBO_DAMAGE: Array[int] = [34, 42, 54]
const COMBO_RANGE: Array[float] = [3.55, 3.85, 4.15]
const COMBO_IMPACT_DELAY: Array[float] = [0.13, 0.12, 0.16]
const COMBO_MAX_TARGETS: Array[int] = [2, 2, 3]
const COMBO_RESET_MSEC := 950

var _uploaded_showcase_spawned: bool = false
var _attack_combo_step: int = 0
var _last_attack_time_msec: int = -10000
var _attack_sequence: int = 0


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
	var spawn_x: float = float(player.global_position.x + offset.x)
	var spawn_z: float = float(player.global_position.z + offset.z)
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

	enemy.set_meta("uploaded_showcase", true)
	enemy.defeated.connect(_on_uploaded_enemy_defeated)
	enemies.append(enemy)

	if enemy.has_method("_update_health_label"):
		enemy.call("_update_health_label")
	_add_character_name_label(enemy, display_name, 3.45 if boss else 2.55)


func _on_player_attack() -> void:
	if not is_instance_valid(player):
		return

	var now_msec: int = Time.get_ticks_msec()
	if now_msec - _last_attack_time_msec > COMBO_RESET_MSEC:
		_attack_combo_step = 0
	else:
		_attack_combo_step = (_attack_combo_step + 1) % COMBO_DAMAGE.size()
	_last_attack_time_msec = now_msec
	_attack_sequence += 1

	var sequence: int = _attack_sequence
	var combo_step: int = _attack_combo_step
	_face_nearest_melee_enemy(float(COMBO_RANGE[combo_step]) + 0.55)

	# Les dégâts sont appliqués au moment où la lame traverse réellement la cible,
	# pas dès que le bouton est pressé.
	await get_tree().create_timer(float(COMBO_IMPACT_DELAY[combo_step])).timeout
	if sequence != _attack_sequence or not is_instance_valid(player):
		return
	_resolve_player_melee_hit(combo_step)


func _resolve_player_melee_hit(combo_step: int) -> void:
	var forward: Vector3 = player.get_forward()
	forward.y = 0.0
	if forward.length_squared() < 0.0001:
		forward = Vector3.FORWARD
	else:
		forward = forward.normalized()

	var attack_range: float = float(COMBO_RANGE[combo_step])
	var damage: int = int(COMBO_DAMAGE[combo_step])
	var maximum_targets: int = int(COMBO_MAX_TARGETS[combo_step])
	var hit_count: int = 0

	for enemy in enemies.duplicate():
		if not _is_living_damageable_enemy(enemy):
			continue

		var offset: Vector3 = enemy.global_position - player.global_position
		if absf(offset.y) > 3.2:
			continue
		var flat_offset := Vector3(offset.x, 0.0, offset.z)
		var distance: float = flat_offset.length()
		if distance <= 0.01 or distance > attack_range:
			continue

		var alignment: float = forward.dot(flat_offset / distance)
		# À très courte distance, le coup touche même si les deux capsules se sont
		# légèrement croisées. Plus loin, la cible doit rester dans le large arc frontal.
		if distance > 2.25 and alignment < -0.35:
			continue

		enemy.take_damage(damage, player.global_position)
		hit_count += 1
		if hit_count >= maximum_targets:
			break


func _face_nearest_melee_enemy(search_range: float) -> void:
	var nearest_enemy: Node3D = null
	var nearest_distance: float = INF
	for enemy in enemies:
		if not _is_living_damageable_enemy(enemy):
			continue
		var offset: Vector3 = enemy.global_position - player.global_position
		var flat_offset := Vector3(offset.x, 0.0, offset.z)
		var distance: float = flat_offset.length()
		if distance > 0.01 and distance <= search_range and distance < nearest_distance:
			nearest_enemy = enemy
			nearest_distance = distance

	if not is_instance_valid(nearest_enemy):
		return
	var visual := player.get_node_or_null("Visual") as Node3D
	if not is_instance_valid(visual):
		return
	var direction: Vector3 = nearest_enemy.global_position - player.global_position
	direction.y = 0.0
	if direction.length_squared() > 0.0001:
		direction = direction.normalized()
		visual.rotation.y = atan2(-direction.x, -direction.z)


func _is_living_damageable_enemy(enemy) -> bool:
	return (
		is_instance_valid(enemy)
		and enemy is Node3D
		and enemy.has_method("take_damage")
		and int(enemy.get("health")) > 0
	)


func _on_uploaded_enemy_defeated(enemy) -> void:
	enemies.erase(enemy)
	if not is_instance_valid(message_label):
		return
	var defeated_name: String = "la grande sorcière" if String(enemy.name).contains("Sorciere") else "le soldat"
	_show_message("Yvane a vaincu %s !" % defeated_name, 3.0)


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
