class_name LivingNpc
extends CharacterBody3D

var profile: Dictionary
var player: Node3D
var world_clock: WorldClockWeather
var home_position: Vector3
var work_position: Vector3
var leisure_position: Vector3
var current_weather: String = "clair"
var routine_state: String = "maison"

var _target_position: Vector3
var _gravity: float = 22.0
var _routine_timer: float = 0.0
var _pause_timer: float = 0.0
var _danger_timer: float = 0.0
var _visual: Node3D
var _left_arm: Node3D
var _right_arm: Node3D
var _left_leg: Node3D
var _right_leg: Node3D
var _walk_phase: float = 0.0


func setup(data: Dictionary, player_node: Node3D, clock: WorldClockWeather, home: Vector3, work: Vector3, leisure: Vector3) -> void:
	profile = data.duplicate(true)
	player = player_node
	world_clock = clock
	home_position = home
	work_position = work
	leisure_position = leisure
	global_position = home_position + Vector3(0.0, 0.45, 0.0)
	_target_position = global_position
	_gravity = float(ProjectSettings.get_setting("physics/3d/default_gravity", 22.0))
	_build_character()
	_update_routine(true)


func _physics_process(delta: float) -> void:
	_routine_timer -= delta
	_pause_timer = maxf(0.0, _pause_timer - delta)
	_danger_timer = maxf(0.0, _danger_timer - delta)
	if _routine_timer <= 0.0:
		_routine_timer = 1.5
		_update_routine(false)

	if not is_on_floor():
		velocity.y -= _gravity * delta

	var flat_delta = _target_position - global_position
	flat_delta.y = 0.0
	var should_move = flat_delta.length() > 0.9 and _pause_timer <= 0.0
	if should_move:
		var direction = flat_delta.normalized()
		var speed = 4.4 if _danger_timer > 0.0 else 2.25
		velocity.x = move_toward(velocity.x, direction.x * speed, 8.0 * delta)
		velocity.z = move_toward(velocity.z, direction.z * speed, 8.0 * delta)
		if is_instance_valid(_visual):
			_visual.rotation.y = lerp_angle(_visual.rotation.y, atan2(-direction.x, -direction.z), minf(1.0, delta * 7.0))
	else:
		velocity.x = move_toward(velocity.x, 0.0, 10.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 10.0 * delta)
		if flat_delta.length() <= 0.9 and _pause_timer <= 0.0:
			_pause_timer = 1.5 + float(int(profile.get("index", 0)) % 5) * 0.45

	move_and_slide()
	_animate_character(delta, Vector2(velocity.x, velocity.z).length())
	if global_position.y < -8.0:
		global_position = home_position + Vector3(0.0, 0.6, 0.0)
		velocity = Vector3.ZERO


func set_weather(weather_id: String) -> void:
	current_weather = weather_id
	_update_routine(true)


func react_to_danger(danger_position: Vector3) -> void:
	var away = global_position - danger_position
	away.y = 0.0
	if away.length_squared() < 0.01:
		away = Vector3.RIGHT
	_target_position = global_position + away.normalized() * 16.0
	_danger_timer = 7.0
	routine_state = "fuite"


func get_dialogue() -> Dictionary:
	var first_name = String(profile.get("nom_complet", profile.get("prénom", "Habitant")))
	var job = String(profile.get("métier", "habitant"))
	var personality = String(profile.get("personnalité", "calme"))
	var region = String(profile.get("région", "cette région"))
	var lines: Array[String] = []
	lines.append("Bonjour, je m'appelle %s. Je suis %s à %s." % [first_name, job, region])
	lines.append(_regional_line(region))
	var hour = world_clock.game_minutes / 60.0 if is_instance_valid(world_clock) else 12.0
	if hour < 6.5:
		lines.append("La nuit est encore profonde. Les gardes veillent pendant que le village dort.")
	elif hour < 11.5:
		lines.append("La matinée commence : chacun rejoint son travail et les commerces ouvrent leurs portes.")
	elif hour < 19.0:
		lines.append("La journée est bien avancée. Je terminerai mon travail avant le repas du soir.")
	else:
		lines.append("Le soir tombe. Je vais bientôt rentrer chez moi avant l'allumage des lanternes.")
	if current_weather in ["pluie", "forte_pluie", "orage", "neige", "blizzard", "cendres"]:
		lines.append("Avec cette météo — %s — je vais bientôt me mettre à l'abri." % current_weather.replace("_", " "))
	else:
		lines.append("Je profite du calme pour suivre ma routine de %s." % personality)
	return {
		"nom": first_name,
		"métier": job,
		"personnalité": personality,
		"lignes": lines,
		"choix": ["Parle-moi de la région", "As-tu besoin d'aide ?", "Quitter"]
	}


func _update_routine(force: bool) -> void:
	if _danger_timer > 0.0:
		return
	var hour = 12.0
	if is_instance_valid(world_clock):
		hour = world_clock.game_minutes / 60.0

	var shelter_weather = current_weather in ["forte_pluie", "orage", "blizzard", "cendres"]
	var next_state = "maison"
	var next_target = home_position
	if not shelter_weather and hour >= 7.0 and hour < 12.5:
		next_state = "travail"
		next_target = work_position
	elif not shelter_weather and hour >= 12.5 and hour < 14.0:
		next_state = "repas"
		next_target = leisure_position
	elif not shelter_weather and hour >= 14.0 and hour < 19.0:
		next_state = "travail"
		next_target = work_position
	elif not shelter_weather and hour >= 19.0 and hour < 21.5:
		next_state = "détente"
		next_target = leisure_position
	elif hour >= 21.5 or hour < 6.5:
		next_state = "sommeil"
		next_target = home_position

	if force or next_state != routine_state:
		routine_state = next_state
		_target_position = next_target


func _build_character() -> void:
	var collider = CollisionShape3D.new()
	var capsule = CapsuleShape3D.new()
	capsule.radius = 0.32
	capsule.height = 1.72
	collider.shape = capsule
	collider.position.y = 0.86
	add_child(collider)

	_visual = Node3D.new()
	_visual.name = "ApparencePNJ"
	add_child(_visual)

	var palette = _job_palette(String(profile.get("métier", "habitant")))
	var cloth = _material(palette[0])
	var accent = _material(palette[1])
	var skin = _material(Color(0.24 + float(int(profile.get("index", 0)) % 5) * 0.035, 0.12, 0.065))

	var torso = MeshInstance3D.new()
	var torso_mesh = CapsuleMesh.new()
	torso_mesh.radius = 0.29
	torso_mesh.height = 0.92
	torso_mesh.material = cloth
	torso.mesh = torso_mesh
	torso.position.y = 1.18
	_visual.add_child(torso)

	var belt = MeshInstance3D.new()
	var belt_mesh = BoxMesh.new()
	belt_mesh.size = Vector3(0.58, 0.12, 0.34)
	belt_mesh.material = accent
	belt.mesh = belt_mesh
	belt.position.y = 0.91
	_visual.add_child(belt)

	var head = MeshInstance3D.new()
	var head_mesh = SphereMesh.new()
	head_mesh.radius = 0.22
	head_mesh.height = 0.44
	head_mesh.material = skin
	head.mesh = head_mesh
	head.position.y = 1.83
	_visual.add_child(head)

	_left_arm = _limb("BrasGauche", Vector3(-0.37, 1.28, 0.0), cloth, 0.10, 0.62)
	_right_arm = _limb("BrasDroit", Vector3(0.37, 1.28, 0.0), cloth, 0.10, 0.62)
	_left_leg = _limb("JambeGauche", Vector3(-0.16, 0.62, 0.0), accent, 0.12, 0.72)
	_right_leg = _limb("JambeDroite", Vector3(0.16, 0.62, 0.0), accent, 0.12, 0.72)

	var name_label = Label3D.new()
	name_label.text = "%s\n%s" % [String(profile.get("nom_complet", profile.get("prénom", "Habitant"))), String(profile.get("métier", "habitant"))]
	name_label.position = Vector3(0.0, 2.28, 0.0)
	name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	name_label.font_size = 24
	name_label.outline_size = 6
	_visual.add_child(name_label)


func _limb(node_name: String, position: Vector3, material: StandardMaterial3D, radius: float, length: float) -> Node3D:
	var pivot = Node3D.new()
	pivot.name = node_name
	pivot.position = position
	_visual.add_child(pivot)
	var mesh_instance = MeshInstance3D.new()
	var mesh = CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = length
	mesh.material = material
	mesh_instance.mesh = mesh
	mesh_instance.position.y = -length * 0.34
	pivot.add_child(mesh_instance)
	return pivot


func _animate_character(delta: float, speed: float) -> void:
	if speed > 0.15:
		_walk_phase += delta * (5.0 + speed)
		var swing = sin(_walk_phase) * 0.58
		_left_arm.rotation.x = swing
		_right_arm.rotation.x = -swing
		_left_leg.rotation.x = -swing * 0.72
		_right_leg.rotation.x = swing * 0.72
		_visual.position.y = abs(sin(_walk_phase * 2.0)) * 0.025
	else:
		_left_arm.rotation.x = lerpf(_left_arm.rotation.x, 0.0, minf(1.0, delta * 6.0))
		_right_arm.rotation.x = lerpf(_right_arm.rotation.x, 0.0, minf(1.0, delta * 6.0))
		_left_leg.rotation.x = lerpf(_left_leg.rotation.x, 0.0, minf(1.0, delta * 6.0))
		_right_leg.rotation.x = lerpf(_right_leg.rotation.x, 0.0, minf(1.0, delta * 6.0))
		_visual.position.y = sin(Time.get_ticks_msec() * 0.002 + float(int(profile.get("index", 0)))) * 0.012


func _job_palette(job: String) -> Array[Color]:
	if job in ["garde", "soldat", "guide"]:
		return [Color(0.10, 0.22, 0.50), Color(0.62, 0.42, 0.08)]
	if job in ["pêcheur", "marin", "docker"]:
		return [Color(0.08, 0.36, 0.50), Color(0.18, 0.10, 0.055)]
	if job in ["agriculteur", "éleveur", "meunier"]:
		return [Color(0.30, 0.46, 0.12), Color(0.30, 0.17, 0.06)]
	if job in ["guérisseur", "historien", "explorateur"]:
		return [Color(0.34, 0.16, 0.46), Color(0.64, 0.56, 0.28)]
	return [Color(0.42, 0.18, 0.10), Color(0.16, 0.09, 0.045)]


func _material(color: Color) -> StandardMaterial3D:
	var result = StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = 0.78
	return result


func _regional_line(region: String) -> String:
	match region:
		"Village côtier":
			return "Le phare et les grottes marines protègent notre baie depuis des générations."
		"Grande forêt":
			return "Les clairières paraissent paisibles, mais les ruines cachent encore des passages."
		"Montagnes rocheuses":
			return "Les ponts suspendus raccourcissent la route, à condition de supporter le vide."
		"Plaines agricoles":
			return "Chaque ferme cultive une terre différente ; rien ne pousse au même rythme."
		"Région volcanique":
			return "Quand les cendres rougissent, il faut quitter les rivières de lave sans attendre."
		"Marais brumeux":
			return "Reste sur les pontons : certaines boues ralentissent jusqu'à immobiliser les voyageurs."
		"Désert de cendres":
			return "Les tempêtes effacent les traces, mais révèlent parfois l'entrée d'un canyon."
		"Grand port commercial":
			return "Ici, pêcheurs, marchands et dockers font vivre les quais du lever au coucher du soleil."
		"Ruines antiques":
			return "Les inscriptions parlent d'un peuple qui maîtrisait les mécanismes sous la pierre."
		"Montagnes enneigées":
			return "Le blizzard masque les crevasses ; suis les balises jusqu'au sommet."
	return "Chaque chemin de cette région a une histoire."
