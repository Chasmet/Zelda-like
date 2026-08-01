class_name WildlifeManager
extends Node3D

const ANIMAL_SCRIPT = preload("res://scripts/world/wildlife_agent.gd")

const REGION_SPECIES = [
	[["lapin", "terrestre"], ["mouette", "aérien"], ["crabe", "terrestre"]],
	[["cerf", "terrestre"], ["sanglier", "terrestre"], ["renard", "terrestre"], ["hibou", "aérien"]],
	[["chèvre", "terrestre"], ["loup", "terrestre"], ["aigle", "aérien"]],
	[["vache", "terrestre"], ["mouton", "terrestre"], ["cheval", "terrestre"], ["poule", "terrestre"]],
	[["lézard", "terrestre"], ["corbeau", "aérien"]],
	[["grenouille", "terrestre"], ["hibou", "aérien"], ["lézard", "terrestre"]],
	[["renard", "terrestre"], ["lézard", "terrestre"], ["corbeau", "aérien"]],
	[["mouette", "aérien"], ["crabe", "terrestre"], ["poule", "terrestre"]],
	[["corbeau", "aérien"], ["hibou", "aérien"], ["lézard", "terrestre"]],
	[["ours", "terrestre"], ["chèvre", "terrestre"], ["loup", "terrestre"], ["aigle", "aérien"]]
]

const MARINE_SPECIES = ["poisson côtier", "poisson tropical", "tortue", "raie", "méduse", "dauphin", "requin", "poisson abyssal"]

const MARINE_OFFSETS = [
	Vector3(0.0, -7.0, 104.0),
	Vector3(-104.0, -7.0, 0.0),
	Vector3(0.0, -7.0, -104.0),
	Vector3(0.0, -7.0, 104.0),
	Vector3(-104.0, -7.0, 0.0),
	Vector3(104.0, -7.0, 0.0),
	Vector3(104.0, -7.0, 0.0),
	Vector3(-104.0, -7.0, 0.0),
	Vector3(104.0, -7.0, 0.0),
	Vector3(0.0, -7.0, -104.0)
]

var player: Node3D
var world_clock: WorldClockWeather
var zone_centers: Array
var terrain_height: Callable
var active_region: int = -1
var active_animals: Array[WildlifeAgent] = []
var quality_level: String = "moyen"


func setup(player_node: Node3D, clock: WorldClockWeather, centers: Array, height_callable: Callable) -> void:
	player = player_node
	world_clock = clock
	zone_centers = centers
	terrain_height = height_callable
	if is_instance_valid(world_clock):
		world_clock.weather_changed.connect(_on_weather_changed)


func activate_region(region_index: int) -> void:
	var next_region = clampi(region_index, 0, zone_centers.size() - 1)
	if next_region == active_region and not active_animals.is_empty():
		return
	_clear_animals()
	active_region = next_region
	var center: Vector3 = zone_centers[active_region]
	var species_table: Array = REGION_SPECIES[active_region]
	var land_target = 7 if quality_level == "faible" else (14 if quality_level == "élevé" else 11)
	var marine_target = 8 if quality_level == "faible" else (18 if quality_level == "élevé" else 13)
	for animal_index in range(land_target):
		var definition: Array = species_table[animal_index % species_table.size()]
		_spawn_animal(String(definition[0]), String(definition[1]), center, 58.0, animal_index)

	var marine_center = center + MARINE_OFFSETS[active_region]
	for marine_index in range(marine_target):
		var marine_species = MARINE_SPECIES[(marine_index + active_region) % MARINE_SPECIES.size()]
		_spawn_animal(marine_species, "marin", marine_center, 38.0, marine_index + 40)
	_update_time_visibility()


func _process(_delta: float) -> void:
	_update_time_visibility()


func get_active_counts() -> Dictionary:
	var marine_count = 0
	var land_count = 0
	for animal in active_animals:
		if is_instance_valid(animal) and animal.habitat == "marin":
			marine_count += 1
		else:
			land_count += 1
	return {"terrestres": land_count, "marins": marine_count}


func set_quality(level: String) -> void:
	quality_level = level if level in ["faible", "moyen", "élevé"] else "moyen"
	var region_to_reload = active_region
	_clear_animals()
	active_region = -1
	if region_to_reload >= 0:
		activate_region(region_to_reload)


func _spawn_animal(species: String, habitat: String, center: Vector3, radius: float, spawn_index: int) -> void:
	var animal = ANIMAL_SCRIPT.new() as WildlifeAgent
	animal.name = "Faune_%s_%02d" % [species.replace(" ", "_"), spawn_index]
	add_child(animal)
	animal.setup(species, habitat, player, center, radius, active_region, terrain_height, spawn_index)
	animal.set_weather(world_clock.current_weather if is_instance_valid(world_clock) else "clair")
	active_animals.append(animal)


func _update_time_visibility() -> void:
	var hour = world_clock.game_minutes / 60.0 if is_instance_valid(world_clock) else 12.0
	var night = hour >= 20.0 or hour < 6.0
	for animal in active_animals:
		if not is_instance_valid(animal):
			continue
		var should_be_active = night if animal.nocturnal else true
		animal.visible = should_be_active
		animal.process_mode = Node.PROCESS_MODE_INHERIT if should_be_active else Node.PROCESS_MODE_DISABLED


func _on_weather_changed(weather_id: String) -> void:
	for animal in active_animals:
		if is_instance_valid(animal):
			animal.set_weather(weather_id)


func _clear_animals() -> void:
	for animal in active_animals:
		if is_instance_valid(animal):
			animal.queue_free()
	active_animals.clear()
