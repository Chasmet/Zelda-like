class_name PopulationManager
extends Node3D

signal dialogue_requested(dialogue: Dictionary)

const NPC_SCRIPT = preload("res://scripts/world/living_npc.gd")

const FIRST_NAMES = [
	"Awa", "Malo", "Inès", "Yanis", "Nora", "Samba", "Lina", "Ilyes", "Maëlle", "Noam",
	"Fatou", "Élias", "Salomé", "Idriss", "Louna", "Amadou", "Éva", "Nassim", "Mina", "Théo",
	"Khadija", "Léo", "Aminata", "Sohan", "Jade", "Ousmane", "Aya", "Mathis", "Mariama", "Nolan",
	"Sira", "Raphaël", "Ndeye", "Youssef", "Lou", "Moussa", "Ambre", "Adam", "Coumba", "Naël"
]

const FAMILY_NAMES = [
	"Ndiaye", "Martin", "Diallo", "Bernard", "Sow", "Moreau", "Ba", "Laurent", "Faye", "Simon",
	"Fall", "Michel", "Camara", "Leroy", "Diop", "Roux", "Gueye", "Fournier", "Sy", "Girard"
]

const PERSONALITIES = ["calme", "curieuse", "prudente", "courageux", "généreuse", "méfiante", "travailleur", "rêveuse"]

const REGION_JOBS = [
	["pêcheur", "marin", "marchand", "garde", "cuisinier", "artisan"],
	["chasseur", "guérisseur", "guide", "artisan", "explorateur", "garde"],
	["mineur", "guide", "garde", "forgeron", "explorateur", "marchand"],
	["agriculteur", "éleveur", "meunier", "marchand", "cuisinier", "garde"],
	["mineur", "forgeron", "garde", "guérisseur", "explorateur", "artisan"],
	["guide", "guérisseur", "chasseur", "artisan", "explorateur", "garde"],
	["explorateur", "garde", "marchand", "chasseur", "guide", "artisan"],
	["docker", "marin", "marchand", "garde", "cuisinier", "pêcheur"],
	["historien", "explorateur", "garde", "guide", "artisan", "marchand"],
	["guide", "chasseur", "garde", "guérisseur", "explorateur", "artisan"]
]

var profiles: Array[Dictionary] = []
var active_npcs: Array[LivingNpc] = []
var active_region: int = -1
var player: Node3D
var world_clock: WorldClockWeather
var zone_names: Array
var zone_centers: Array
var terrain_height: Callable


func setup(player_node: Node3D, clock: WorldClockWeather, names: Array, centers: Array, height_callable: Callable) -> void:
	player = player_node
	world_clock = clock
	zone_names = names
	zone_centers = centers
	terrain_height = height_callable
	_build_profiles()
	if is_instance_valid(world_clock):
		world_clock.weather_changed.connect(_on_weather_changed)


func activate_region(region_index: int) -> void:
	var next_region = clampi(region_index, 0, zone_centers.size() - 1)
	if next_region == active_region and active_npcs.size() == 20:
		return
	_clear_active_population()
	active_region = next_region
	for profile in profiles:
		if int(profile.get("région_index", -1)) != active_region:
			continue
		var npc = NPC_SCRIPT.new() as LivingNpc
		npc.name = "PNJ_%03d_%s" % [int(profile.get("index", 0)) + 1, String(profile.get("prénom", "Habitant"))]
		add_child(npc)
		var home = _world_position(active_region, profile.get("maison", Vector2.ZERO))
		var work = _world_position(active_region, profile.get("travail", Vector2.ZERO))
		var leisure = _world_position(active_region, profile.get("repos", Vector2.ZERO))
		npc.setup(profile, player, world_clock, home, work, leisure)
		npc.set_weather(world_clock.current_weather if is_instance_valid(world_clock) else "clair")
		active_npcs.append(npc)


func try_interact(max_distance: float = 3.6) -> bool:
	if not is_instance_valid(player):
		return false
	var nearest: LivingNpc
	var nearest_distance = max_distance
	for npc in active_npcs:
		if not is_instance_valid(npc):
			continue
		var distance = npc.global_position.distance_to(player.global_position)
		if distance < nearest_distance:
			nearest = npc
			nearest_distance = distance
	if not is_instance_valid(nearest):
		return false
	dialogue_requested.emit(nearest.get_dialogue())
	return true


func alert_nearby(danger_position: Vector3, radius: float = 14.0) -> void:
	for npc in active_npcs:
		if is_instance_valid(npc) and npc.global_position.distance_to(danger_position) <= radius:
			npc.react_to_danger(danger_position)


func get_population_count() -> int:
	return profiles.size()


func _build_profiles() -> void:
	profiles.clear()
	for region_index in range(zone_names.size()):
		for resident_index in range(20):
			var global_index = region_index * 20 + resident_index
			var first_name = FIRST_NAMES[global_index % FIRST_NAMES.size()]
			var family_name = FAMILY_NAMES[(global_index * 7 + region_index) % FAMILY_NAMES.size()]
			var home_grid = Vector2(-18.0 + float(resident_index % 5) * 9.0, -15.0 + float(resident_index / 5) * 10.0)
			var work_angle = TAU * float(resident_index) / 20.0
			var work_offset = Vector2(cos(work_angle) * (8.0 + float(resident_index % 4) * 3.0), sin(work_angle) * (8.0 + float(resident_index % 4) * 3.0))
			var rest_offset = Vector2(-6.0 + float(resident_index % 4) * 4.0, -3.0 + float(resident_index % 3) * 3.0)
			profiles.append({
				"index": global_index,
				"prénom": first_name,
				"nom": family_name,
				"nom_complet": "%s %s" % [first_name, family_name],
				"métier": REGION_JOBS[region_index][resident_index % REGION_JOBS[region_index].size()],
				"personnalité": PERSONALITIES[(resident_index + region_index) % PERSONALITIES.size()],
				"région": zone_names[region_index],
				"région_index": region_index,
				"maison": home_grid,
				"travail": work_offset,
				"repos": rest_offset
			})


func _world_position(region_index: int, offset_value: Variant) -> Vector3:
	var offset: Vector2 = offset_value
	var center: Vector3 = zone_centers[region_index]
	var world_x = center.x + offset.x * 3.30
	var world_z = center.z + offset.y * 3.30
	var world_y = center.y + 0.5
	if terrain_height.is_valid():
		world_y = float(terrain_height.call(region_index, world_x, world_z)) + 0.48
	return Vector3(world_x, world_y, world_z)


func _on_weather_changed(weather_id: String) -> void:
	for npc in active_npcs:
		if is_instance_valid(npc):
			npc.set_weather(weather_id)


func _clear_active_population() -> void:
	for npc in active_npcs:
		if is_instance_valid(npc):
			npc.queue_free()
	active_npcs.clear()
