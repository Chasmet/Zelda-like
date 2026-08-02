extends Node3D

const NPCS_PER_REGION := 20
const COLLECTIBLES_PER_REGION := 3

var world
var player
var region_centers: Array
var region_names: Array
var accent_colors: Array

var npc_regions: Array = []
var poi_entries: Array = []
var collectible_entries: Array = []
var collected_count := 0

var _tick := 0.0
var _clock := 0.0

const DIALOGUES = [
	["La marée est calme aujourd'hui.", "Le phare protège tous les pêcheurs.", "Bienvenue au village côtier."],
	["Écoute les oiseaux, ils annoncent la pluie.", "La forêt change quand la nuit tombe.", "Reste sur les sentiers balisés."],
	["Le vent devient dangereux près des falaises.", "Les cristaux brillent avant l'orage.", "Le col est plus sûr au lever du jour."],
	["Nos récoltes nourrissent toutes les régions.", "Le moulin tourne mieux avec le vent d'ouest.", "Attention aux charrettes sur la route."],
	["La lave monte quand le ciel devient rouge.", "La forge utilise la chaleur du volcan.", "Ne marche pas sur les fissures lumineuses."],
	["La brume cache parfois les chemins.", "Les roseaux indiquent les zones profondes.", "On entend des voix près de l'eau la nuit."],
	["Les cendres recouvrent tout après les tempêtes.", "Les nomades connaissent chaque passage.", "Garde de l'eau pour traverser le canyon."],
	["Les navires arrivent de toutes les régions.", "Le marché ouvre au lever du soleil.", "La capitainerie cherche de nouveaux marins."],
	["Ces pierres sont plus anciennes que le royaume.", "Le temple renferme encore des mécanismes.", "La porte solaire s'ouvre à midi."],
	["La neige efface les traces très rapidement.", "Le refuge est ouvert aux voyageurs.", "Le sommet offre une vue sur tout le monde."]
]

const POI_NAMES = [
	["Le vieux phare", "Le marché aux poissons"],
	["Le chêne millénaire", "La clairière des lucioles"],
	["Le col des aigles", "La grotte de cristal"],
	["Le grand moulin", "Les champs dorés"],
	["Le cratère rouge", "La forge de basalte"],
	["La cabane engloutie", "Le cercle des brumes"],
	["Le canyon noir", "Le camp des nomades"],
	["La capitainerie", "Le quai des marchands"],
	["Le temple brisé", "La porte solaire"],
	["Le refuge gelé", "L'autel des neiges"]
]


func setup(
	world_ref,
	player_ref,
	centers: Array,
	names: Array,
	accents: Array
) -> void:
	world = world_ref
	player = player_ref
	region_centers = centers
	region_names = names
	accent_colors = accents
	_build_population()
	_build_points_of_interest()
	_build_collectibles()


func update_simulation(delta: float, current_region: int) -> void:
	if not is_instance_valid(player):
		return

	_tick += delta
	_clock += delta
	if _tick >= 0.10:
		_tick = 0.0
		_update_population(current_region)

	_update_collectibles(current_region)


func try_interact(current_region: int) -> bool:
	if _try_talk_to_nearest_npc(current_region):
		return true
	return _try_interact_with_poi(current_region)


func get_collected_count() -> int:
	return collected_count


func set_collected_count(value: int) -> void:
	collected_count = clampi(value, 0, region_centers.size() * COLLECTIBLES_PER_REGION)
	var remaining := collected_count
	for index in range(collectible_entries.size()):
		var item: Dictionary = collectible_entries[index]
		var collected := remaining > 0
		item["collected"] = collected
		var node: MeshInstance3D = item["node"]
		node.visible = not collected
		collectible_entries[index] = item
		if collected:
			remaining -= 1


func _build_population() -> void:
	npc_regions.clear()
	for region_index in range(region_centers.size()):
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = _create_npc_mesh(region_index)
		multimesh.instance_count = NPCS_PER_REGION
		multimesh.visible_instance_count = NPCS_PER_REGION

		var people: Array = []
		for npc_index in range(NPCS_PER_REGION):
			var angle := TAU * float(npc_index) / float(NPCS_PER_REGION) + float(region_index) * 0.23
			var radius := 12.0 + float((npc_index * 13 + region_index * 7) % 46)
			var home := Vector3(
				region_centers[region_index].x + cos(angle) * radius,
				0.0,
				region_centers[region_index].z + sin(angle) * radius * 0.82
			)
			home.y = world._expanded_height(region_index, home.x, home.z) + 1.0
			var person := {
				"home": home,
				"position": home,
				"phase": float(npc_index) * 0.71 + float(region_index),
				"name": _npc_name(region_index, npc_index),
				"dialogue": DIALOGUES[region_index][npc_index % DIALOGUES[region_index].size()]
			}
			people.append(person)
			multimesh.set_instance_transform(npc_index, Transform3D(Basis.IDENTITY, home))

		var visual := MultiMeshInstance3D.new()
		visual.name = "PNJ_Region_%02d" % (region_index + 1)
		visual.multimesh = multimesh
		visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		visual.visibility_range_end = 175.0
		add_child(visual)
		npc_regions.append({"visual": visual, "people": people})


func _create_npc_mesh(region_index: int) -> CapsuleMesh:
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.42
	mesh.height = 1.85
	var material := StandardMaterial3D.new()
	material.albedo_color = accent_colors[region_index].lerp(Color.WHITE, 0.18)
	material.roughness = 0.72
	mesh.material = material
	return mesh


func _npc_name(region_index: int, npc_index: int) -> String:
	var jobs := [
		["Pêcheur", "Gardienne du phare", "Marchande"],
		["Bûcheron", "Herboriste", "Éclaireuse"],
		["Guide", "Mineur", "Alpiniste"],
		["Fermière", "Meunier", "Charretier"],
		["Forgeron", "Veilleuse", "Mineuse"],
		["Pêcheuse des marais", "Guérisseur", "Éclaireur"],
		["Nomade", "Pisteuse", "Marchand d'eau"],
		["Docker", "Capitaine", "Négociante"],
		["Archéologue", "Gardien des ruines", "Scribe"],
		["Montagnarde", "Gardien du refuge", "Chasseuse"]
	]
	return "%s %02d" % [jobs[region_index][npc_index % 3], npc_index + 1]


func _update_population(current_region: int) -> void:
	for region_index in range(npc_regions.size()):
		var entry: Dictionary = npc_regions[region_index]
		var visual: MultiMeshInstance3D = entry["visual"]
		var people: Array = entry["people"]
		var close_region := (
			region_index == current_region
			or region_centers[region_index].distance_to(player.global_position) < 195.0
		)
		visual.visible = close_region

		if not close_region:
			continue

		for npc_index in range(people.size()):
			var person: Dictionary = people[npc_index]
			var phase := float(person["phase"])
			var home: Vector3 = person["home"]
			var routine_radius := 3.5 + float(npc_index % 5)
			var position := Vector3(
				home.x + cos(_clock * (0.22 + float(npc_index % 3) * 0.04) + phase) * routine_radius,
				home.y,
				home.z + sin(_clock * (0.19 + float(npc_index % 4) * 0.03) + phase) * routine_radius
			)
			position.y = world._expanded_height(region_index, position.x, position.z) + 1.0
			person["position"] = position
			people[npc_index] = person
			visual.multimesh.set_instance_transform(
				npc_index,
				Transform3D(Basis(Vector3.UP, phase + _clock * 0.12), position)
			)

		entry["people"] = people
		npc_regions[region_index] = entry


func _build_points_of_interest() -> void:
	poi_entries.clear()
	for region_index in range(region_centers.size()):
		for poi_index in range(2):
			var angle := float(poi_index) * PI + 0.72 + float(region_index) * 0.13
			var position := region_centers[region_index] + Vector3(
				cos(angle) * 39.0,
				0.0,
				sin(angle) * 34.0
			)
			position.y = world._expanded_height(region_index, position.x, position.z) + 2.5

			var beacon := MeshInstance3D.new()
			beacon.name = "POI_%02d_%02d" % [region_index + 1, poi_index + 1]
			var mesh := CylinderMesh.new()
			mesh.top_radius = 0.60
			mesh.bottom_radius = 1.05
			mesh.height = 5.0
			var material := StandardMaterial3D.new()
			material.albedo_color = accent_colors[region_index]
			material.emission_enabled = true
			material.emission = accent_colors[region_index] * 1.6
			mesh.material = material
			beacon.mesh = mesh
			beacon.position = position
			add_child(beacon)

			poi_entries.append({
				"position": position,
				"name": POI_NAMES[region_index][poi_index],
				"region": region_index
			})


func _build_collectibles() -> void:
	collectible_entries.clear()
	for region_index in range(region_centers.size()):
		for item_index in range(COLLECTIBLES_PER_REGION):
			var angle := float(item_index) * TAU / float(COLLECTIBLES_PER_REGION) + float(region_index) * 0.41
			var position := region_centers[region_index] + Vector3(
				cos(angle) * (22.0 + item_index * 13.0),
				0.0,
				sin(angle) * (20.0 + item_index * 11.0)
			)
			position.y = world._expanded_height(region_index, position.x, position.z) + 1.4

			var crystal := MeshInstance3D.new()
			crystal.name = "Cristal_%02d_%02d" % [region_index + 1, item_index + 1]
			var mesh := SphereMesh.new()
			mesh.radius = 0.62
			mesh.height = 1.25
			var material := StandardMaterial3D.new()
			material.albedo_color = accent_colors[region_index]
			material.emission_enabled = true
			material.emission = accent_colors[region_index] * 2.2
			mesh.material = material
			crystal.mesh = mesh
			crystal.position = position
			add_child(crystal)

			collectible_entries.append({
				"node": crystal,
				"position": position,
				"collected": false,
				"region": region_index
			})


func _update_collectibles(current_region: int) -> void:
	for index in range(collectible_entries.size()):
		var item: Dictionary = collectible_entries[index]
		if bool(item["collected"]) or int(item["region"]) != current_region:
			continue

		var node: MeshInstance3D = item["node"]
		node.rotation.y += 0.025
		if player.global_position.distance_to(item["position"]) < 1.8:
			item["collected"] = true
			node.visible = false
			collected_count += 1
			collectible_entries[index] = item
			world._show_message("Cristal trouvé ! %d / 30" % collected_count, 2.4)
			world._update_hud()


func _try_talk_to_nearest_npc(current_region: int) -> bool:
	if current_region < 0 or current_region >= npc_regions.size():
		return false

	var people: Array = npc_regions[current_region]["people"]
	var best_distance := 4.8
	var selected: Dictionary = {}
	for person in people:
		var distance := player.global_position.distance_to(person["position"])
		if distance < best_distance:
			best_distance = distance
			selected = person

	if selected.is_empty():
		return false

	world._show_message("%s : %s" % [selected["name"], selected["dialogue"]], 4.5)
	return true


func _try_interact_with_poi(current_region: int) -> bool:
	var best_distance := 6.0
	var selected: Dictionary = {}
	for poi in poi_entries:
		if int(poi["region"]) != current_region:
			continue
		var distance := player.global_position.distance_to(poi["position"])
		if distance < best_distance:
			best_distance = distance
			selected = poi

	if selected.is_empty():
		return false

	world._show_message("Point d'intérêt découvert : %s" % selected["name"], 4.0)
	return true
