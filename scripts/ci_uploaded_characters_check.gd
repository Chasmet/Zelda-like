extends Node

const MAX_WAIT_SECONDS := 120.0


func _ready() -> void:
	if "--ci-uploaded-characters" not in OS.get_cmdline_user_args():
		return
	call_deferred("_run_check")


func _run_check() -> void:
	var game := get_parent()
	var started_at := Time.get_ticks_msec()
	var player: Node = null
	var soldier: Node = null
	var witch: Node = null

	while Time.get_ticks_msec() - started_at < int(MAX_WAIT_SECONDS * 1000.0):
		await get_tree().process_frame
		player = game.get("player")
		soldier = game.get_node_or_null("SoldatIle1")
		witch = game.get_node_or_null("GrandeSorciereCauchemars")
		var loading_screen = game.get("loading_screen")
		if (
			is_instance_valid(player)
			and is_instance_valid(soldier)
			and is_instance_valid(witch)
			and (not is_instance_valid(loading_screen) or not loading_screen.visible)
		):
			break

	if not is_instance_valid(player) or not is_instance_valid(soldier) or not is_instance_valid(witch):
		_fail("Yvane, le soldat ou la sorcière n'a pas été créé", 41)
		return

	var yvane_model := player.get_node_or_null("Visual/ImportedHeroModel/HeroBlenderAsset")
	var soldier_model := soldier.get_node_or_null("Visual/ImportedEnemyModel/EnemyBlenderAsset")
	var witch_model := witch.get_node_or_null("Visual/ImportedEnemyModel/EnemyBlenderAsset")
	if not is_instance_valid(yvane_model):
		_fail("le vrai modèle GLB de Yvane n'est pas actif", 42)
		return
	if not is_instance_valid(soldier_model) or not is_instance_valid(witch_model):
		_fail("les représentations 3D du soldat ou de la sorcière sont absentes", 43)
		return

	var animator: Node = player.get("_model_animator")
	if not is_instance_valid(animator) or not animator.has_method("is_animation_ready"):
		_fail("le système d'animation de Yvane est absent", 44)
		return
	if not bool(animator.call("is_animation_ready")):
		_fail("les animations de Yvane ne sont pas prêtes", 45)
		return

	var start_position: Vector3 = player.global_position
	var pose_before: Vector4 = animator.call("get_animation_signature")
	player.call("set_virtual_move", Vector2(0.0, -1.0))
	await get_tree().create_timer(0.72).timeout
	var moved_position: Vector3 = player.global_position
	var pose_after: Vector4 = animator.call("get_animation_signature")
	player.call("set_virtual_move", Vector2.ZERO)

	var travelled := start_position.distance_to(moved_position)
	var pose_delta := (pose_after - pose_before).length()
	if travelled < 1.25:
		_fail("Yvane ne se déplace pas correctement: %.3f m" % travelled, 46)
		return
	if pose_delta < 0.01:
		_fail("Yvane se déplace mais son animation reste figée", 47)
		return

	var soldier_start: Vector3 = soldier.global_position
	var witch_start: Vector3 = witch.global_position
	await get_tree().create_timer(1.1).timeout
	var soldier_motion := soldier_start.distance_to(soldier.global_position)
	var witch_motion := witch_start.distance_to(witch.global_position)
	if soldier_motion < 0.08:
		_fail("le soldat ne réagit pas au joueur", 48)
		return
	if witch_motion < 0.08:
		_fail("la sorcière ne réagit pas au joueur", 49)
		return

	var health_before: int = int(soldier.get("health"))
	player.call("attack")
	await get_tree().create_timer(0.25).timeout
	if int(soldier.get("health")) > health_before:
		_fail("la vie du soldat a une valeur incohérente après l'attaque", 50)
		return

	print(
		"CI UPLOADED CHARACTERS OK: yvane_move=%.3f yvane_pose=%.3f soldier_move=%.3f witch_move=%.3f" % [
			travelled, pose_delta, soldier_motion, witch_motion
		]
	)
	get_tree().quit()


func _fail(message: String, code: int) -> void:
	push_error("CI UPLOADED CHARACTERS: %s" % message)
	get_tree().quit(code)
