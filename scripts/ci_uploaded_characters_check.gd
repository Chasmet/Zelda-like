extends Node

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
	call_deferred("_run_check")


func _run_check() -> void:
	var game := get_parent()
	var player: Node = null
	var started_at := Time.get_ticks_msec()
	while Time.get_ticks_msec() - started_at < int(MAX_WAIT_SECONDS * 1000.0):
		await get_tree().process_frame
		player = game.get("player")
		var ready := is_instance_valid(player)
		for node_name in BOSS_ASSETS.keys():
			ready = ready and is_instance_valid(game.get_node_or_null(String(node_name)))
		var boot_layer = game.get("boot_layer")
		if ready and not is_instance_valid(boot_layer):
			break

	if not is_instance_valid(player):
		_fail("Yvane n'a pas été créé", 41)
		return
	for node_name in BOSS_ASSETS.keys():
		if not is_instance_valid(game.get_node_or_null(String(node_name))):
			_fail("boss absent : %s" % String(node_name), 42)
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
	var travelled := start_position.distance_to(moved_position)
	var yvane_pose_delta := (pose_after - pose_before).length()
	if travelled < MIN_YVANE_TRAVEL:
		_fail("Yvane ne reçoit pas un déplacement réel : %.3f m" % travelled, 45)
		return
	if yvane_pose_delta < 0.01:
		_fail("Yvane se déplace mais son animation reste figée", 46)
		return

	var animated_bosses := 0
	for node_name in BOSS_ASSETS.keys():
		var boss: Node = game.get_node(String(node_name))
		var model := boss.get_node_or_null("Visual/ImportedEnemyModel/EnemyBlenderAsset")
		if not is_instance_valid(model):
			_fail("le GLB exact n'est pas affiché pour %s" % String(node_name), 47)
			return
		var expected_asset := String(BOSS_ASSETS[node_name])
		if String(model.get_meta("source_asset", "")) != expected_asset:
			_fail("mauvais GLB utilisé pour %s" % String(node_name), 48)
			return
		var animator: Node = boss.get("_model_animator")
		if not _animator_ready(animator):
			_fail("animation absente pour %s" % String(node_name), 49)
			return

		boss.set_physics_process(false)
		var boss_pose_before: Vector4 = animator.call("get_animation_signature")
		animator.call("set_locomotion", 1.0, false)
		await get_tree().create_timer(0.42).timeout
		var boss_pose_after: Vector4 = animator.call("get_animation_signature")
		var pose_delta := (boss_pose_after - boss_pose_before).length()
		if pose_delta < 0.002:
			animator.call("play_attack")
			await get_tree().create_timer(0.32).timeout
			var attack_pose: Vector4 = animator.call("get_animation_signature")
			pose_delta = (attack_pose - boss_pose_after).length()
		if pose_delta < 0.002:
			_fail("le boss reste figé : %s" % String(node_name), 50)
			return
		animated_bosses += 1

	print(
		"CI UPLOADED CHARACTERS OK: yvane_move=%.3f yvane_pose=%.3f bosses_exact=4 bosses_animated=%d" % [
			travelled, yvane_pose_delta, animated_bosses
		]
	)
	get_tree().quit()


func _animator_ready(animator: Node) -> bool:
	return (
		is_instance_valid(animator)
		and animator.has_method("is_animation_ready")
		and animator.has_method("get_animation_signature")
		and bool(animator.call("is_animation_ready"))
	)


func _fail(message: String, code: int) -> void:
	push_error("CI UPLOADED CHARACTERS: %s" % message)
	get_tree().quit(code)
