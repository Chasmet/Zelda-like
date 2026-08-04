extends Node

const SAVE_PATH := "user://skypiea_worldmap_v2.cfg"
const MAX_WAIT_SECONDS := 150.0
const MIN_YVANE_TRAVEL := 0.15
const BOSS_ASSETS = {
	"BaggyBoss": "res://asset_payloads/yvane/baggy boss .glb",
	"BossIle4": "res://asset_payloads/yvane/boss ile 4.glb",
	"BossSorciere": "res://asset_payloads/yvane/boss sorcière.glb",
	"GrandeBossSorciereCauchemars": "res://asset_payloads/yvane/grande boss sorcière des cauchemars.glb"
}


func _ready() -> void:
	if "--ci-uploaded-characters" not in OS.get_cmdline_user_args():
		return
	# Le test doit toujours commencer avec les vingt gardiens d'origine. Une
	# sauvegarde provenant d'un test précédent ne doit pas supprimer un boss.
	_remove_test_save()
	call_deferred("_run_check")


func _run_check() -> void:
	var game := get_parent()
	var player: Node = null
	var resolved_bosses: Dictionary = {}
	var started_at: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - started_at < int(MAX_WAIT_SECONDS * 1000.0):
		await get_tree().process_frame
		player = game.get("player")
		resolved_bosses = _resolve_all_bosses(game)
		var boot_layer = game.get("boot_layer")
		if is_instance_valid(player) and resolved_bosses.size() == BOSS_ASSETS.size() and not is_instance_valid(boot_layer):
			break

	if not is_instance_valid(player):
		_fail("Yvane n'a pas été créé", 41)
		return
	resolved_bosses = _resolve_all_bosses(game)
	if resolved_bosses.size() != BOSS_ASSETS.size():
		_fail("boss manquant(s). État réel : %s" % _boss_debug_state(game), 42)
		return

	var yvane_model := player.get_node_or_null("Visual/ImportedHeroModel/HeroBlenderAsset")
	var yvane_animator: Node = player.get("_model_animator")
	if not is_instance_valid(yvane_model):
		_fail("le vrai modèle GLB de Yvane n'est pas actif", 43)
		return
	if not _animator_ready(yvane_animator):
		_fail("les animations de Yvane ne sont pas prêtes", 44)
		return

	var start_position: Vector3 = player.global_position
	var pose_before: Vector4 = yvane_animator.call("get_animation_signature")
	player.call("set_virtual_move", Vector2(0.0, -1.0))
	await get_tree().create_timer(0.85).timeout
	var moved_position: Vector3 = player.global_position
	var pose_after: Vector4 = yvane_animator.call("get_animation_signature")
	player.call("set_virtual_move", Vector2.ZERO)
	var travelled: float = start_position.distance_to(moved_position)
	var yvane_pose_delta: float = (pose_after - pose_before).length()
	if travelled < MIN_YVANE_TRAVEL:
		_fail("Yvane ne reçoit pas un déplacement réel : %.3f m" % travelled, 45)
		return
	if yvane_pose_delta < 0.01:
		_fail("Yvane se déplace mais son animation reste figée", 46)
		return

	var animated_bosses := 0
	for boss_id_variant in BOSS_ASSETS.keys():
		var boss_id := String(boss_id_variant)
		var boss: Node = resolved_bosses.get(boss_id)
		if not is_instance_valid(boss):
			_fail("référence du boss invalide : %s" % boss_id, 47)
			return
		var model := boss.get_node_or_null("Visual/ImportedEnemyModel/EnemyBlenderAsset")
		if not is_instance_valid(model):
			_fail("le GLB exact n'est pas affiché pour %s" % boss_id, 48)
			return
		var expected_asset := String(BOSS_ASSETS[boss_id])
		if String(boss.get_meta("boss_asset", "")) != expected_asset:
			_fail("métadonnée d'asset incorrecte pour %s" % boss_id, 49)
			return
		if String(model.get_meta("source_asset", "")) != expected_asset:
			_fail("mauvais GLB utilisé pour %s" % boss_id, 50)
			return
		var animator: Node = boss.get("_model_animator")
		if not _animator_ready(animator):
			_fail("animation absente pour %s" % boss_id, 51)
			return

		boss.set_physics_process(false)
		var boss_pose_before: Vector4 = animator.call("get_animation_signature")
		animator.call("set_locomotion", 1.0, false)
		await get_tree().create_timer(0.42).timeout
		var boss_pose_after: Vector4 = animator.call("get_animation_signature")
		var pose_delta: float = (boss_pose_after - boss_pose_before).length()
		if pose_delta < 0.002:
			animator.call("play_attack")
			await get_tree().create_timer(0.32).timeout
			var attack_pose: Vector4 = animator.call("get_animation_signature")
			pose_delta = (attack_pose - boss_pose_after).length()
		if pose_delta < 0.002:
			_fail("le boss reste figé : %s" % boss_id, 52)
			return
		animated_bosses += 1

	print(
		"CI UPLOADED CHARACTERS OK: yvane_move=%.3f yvane_pose=%.3f bosses_exact=4 bosses_animated=%d" % [
			travelled, yvane_pose_delta, animated_bosses
		]
	)
	_remove_test_save()
	get_tree().quit()


func _resolve_all_bosses(game: Node) -> Dictionary:
	var resolved: Dictionary = {}
	var registry = game.get("spawned_bosses")
	if registry is Dictionary:
		for boss_id_variant in BOSS_ASSETS.keys():
			var boss_id := String(boss_id_variant)
			var registered = registry.get(boss_id)
			if is_instance_valid(registered):
				resolved[boss_id] = registered

	var enemy_list = game.get("enemies")
	if enemy_list is Array:
		for enemy in enemy_list:
			if not is_instance_valid(enemy):
				continue
			var asset := String(enemy.get_meta("boss_asset", ""))
			if asset.is_empty():
				continue
			for boss_id_variant in BOSS_ASSETS.keys():
				var boss_id := String(boss_id_variant)
				if String(BOSS_ASSETS[boss_id]) == asset:
					resolved[boss_id] = enemy
	return resolved


func _boss_debug_state(game: Node) -> String:
	var entries: Array[String] = []
	var enemy_list = game.get("enemies")
	if enemy_list is Array:
		for enemy in enemy_list:
			if not is_instance_valid(enemy):
				continue
			entries.append("%s|id=%s|asset=%s|zone=%s" % [
				String(enemy.name),
				String(enemy.get_meta("boss_id", "")),
				String(enemy.get_meta("boss_asset", "")),
				String(enemy.get_meta("zone_index", -1))
			])
	return ", ".join(entries)


func _animator_ready(animator: Node) -> bool:
	return (
		is_instance_valid(animator)
		and animator.has_method("is_animation_ready")
		and animator.has_method("get_animation_signature")
		and bool(animator.call("is_animation_ready"))
	)


func _remove_test_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))


func _fail(message: String, code: int) -> void:
	push_error("CI UPLOADED CHARACTERS: %s" % message)
	_remove_test_save()
	get_tree().quit(code)
