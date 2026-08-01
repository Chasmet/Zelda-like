class_name WorldClockWeather
extends Node

signal status_changed(time_text: String, weather_text: String)
signal weather_changed(weather_id: String)

const WEATHER_LABELS = {
	"clair": "Ciel clair",
	"nuageux": "Nuages",
	"couvert": "Ciel couvert",
	"pluie": "Pluie légère",
	"forte_pluie": "Forte pluie",
	"orage": "Orage",
	"brouillard": "Brouillard",
	"vent": "Vent soutenu",
	"neige": "Neige",
	"blizzard": "Blizzard",
	"cendres": "Tempête de cendres"
}

const REGION_WEATHER = [
	["clair", "nuageux", "pluie", "vent", "brouillard"],
	["pluie", "forte_pluie", "brouillard", "couvert", "clair"],
	["clair", "nuageux", "vent", "brouillard", "couvert"],
	["clair", "nuageux", "vent", "pluie", "couvert"],
	["clair", "nuageux", "cendres", "vent", "couvert"],
	["brouillard", "pluie", "couvert", "forte_pluie", "orage"],
	["clair", "couvert", "cendres", "vent", "nuageux"],
	["clair", "nuageux", "pluie", "vent", "orage"],
	["clair", "nuageux", "brouillard", "vent", "couvert"],
	["neige", "blizzard", "couvert", "clair", "vent"]
]

var game_minutes: float = 8.0 * 60.0
var minutes_per_real_second: float = 1.35
var current_region: int = 0
var current_weather: String = "clair"
var weather_remaining: float = 110.0

var _environment: Environment
var _sun: DirectionalLight3D
var _ocean: MeshInstance3D
var _player: Node3D
var _particles: GPUParticles3D
var _particle_material: ParticleProcessMaterial
var _particle_quad: QuadMesh
var _rng := RandomNumberGenerator.new()
var _status_timer: float = 0.0
var _base_ocean_y: float = -0.92
var _underwater: bool = false
var _underwater_depth: float = 0.0
var _quality_level: String = "moyen"


func setup(environment: Environment, sun: DirectionalLight3D, ocean: MeshInstance3D, player: Node3D, region_index: int) -> void:
	_environment = environment
	_sun = sun
	_ocean = ocean
	_player = player
	current_region = clampi(region_index, 0, REGION_WEATHER.size() - 1)
	_rng.seed = 20260801
	if is_instance_valid(_ocean):
		_base_ocean_y = _ocean.position.y
	_build_particles()
	_apply_weather(true)
	_apply_time_of_day()
	_emit_status()


func _process(delta: float) -> void:
	game_minutes = fmod(game_minutes + delta * minutes_per_real_second, 1440.0)
	weather_remaining -= delta
	_status_timer -= delta

	if weather_remaining <= 0.0:
		_select_next_weather()
	if _status_timer <= 0.0:
		_status_timer = 1.0
		_apply_time_of_day()
		_emit_status()

	_update_particles_position()
	_animate_ocean()


func set_region(region_index: int) -> void:
	var next_region = clampi(region_index, 0, REGION_WEATHER.size() - 1)
	if next_region == current_region:
		return
	current_region = next_region
	if not current_weather in REGION_WEATHER[current_region]:
		_select_next_weather()
	else:
		_apply_weather(false)
	_emit_status()


func set_underwater(enabled: bool, depth: float = 0.0) -> void:
	var next_depth = maxf(0.0, depth)
	if enabled == _underwater and absf(next_depth - _underwater_depth) < 0.30:
		return
	_underwater = enabled
	_underwater_depth = next_depth
	if _underwater:
		_environment.fog_enabled = true
		_environment.fog_density = clampf(0.026 + _underwater_depth * 0.0028, 0.026, 0.072)
		_environment.fog_light_color = Color(0.015, 0.18, 0.25).lerp(Color(0.005, 0.025, 0.06), clampf(_underwater_depth / 18.0, 0.0, 1.0))
		if is_instance_valid(_particles):
			_particles.emitting = false
	else:
		_apply_weather(true)


func get_save_state() -> Dictionary:
	return {
		"minutes": game_minutes,
		"weather": current_weather,
		"weather_remaining": weather_remaining
	}


func load_save_state(state: Dictionary) -> void:
	game_minutes = clampf(float(state.get("minutes", game_minutes)), 0.0, 1439.99)
	var saved_weather = String(state.get("weather", current_weather))
	if WEATHER_LABELS.has(saved_weather) and saved_weather in REGION_WEATHER[current_region]:
		current_weather = saved_weather
	weather_remaining = clampf(float(state.get("weather_remaining", weather_remaining)), 12.0, 240.0)
	_apply_weather(true)
	_apply_time_of_day()
	_emit_status()


func set_quality(level: String) -> void:
	if not is_instance_valid(_particles):
		return
	_quality_level = level if level in ["faible", "moyen", "élevé"] else "moyen"
	match level:
		"faible":
			_particles.amount_ratio = 0.58
		"élevé":
			_particles.amount_ratio = 1.0
		_:
			_particles.amount_ratio = 0.80
	_configure_particles()


func _select_next_weather() -> void:
	var choices: Array = REGION_WEATHER[current_region]
	var next_weather = String(choices[_rng.randi_range(0, choices.size() - 1)])
	if next_weather == current_weather and choices.size() > 1:
		var current_index = choices.find(current_weather)
		next_weather = String(choices[(current_index + 1 + _rng.randi_range(0, choices.size() - 2)) % choices.size()])
	current_weather = next_weather
	weather_remaining = _rng.randf_range(85.0, 185.0)
	_apply_weather(false)
	weather_changed.emit(current_weather)


func _apply_time_of_day() -> void:
	if not is_instance_valid(_sun) or not is_instance_valid(_environment):
		return
	var hour = game_minutes / 60.0
	var sun_height = sin((hour - 6.0) / 24.0 * TAU)
	var daylight = smoothstep(-0.12, 0.22, sun_height)
	var twilight = 1.0 - clampf(abs(sun_height) * 4.0, 0.0, 1.0)

	_sun.rotation_degrees = Vector3(-12.0 - maxf(0.0, sun_height) * 66.0, hour * 15.0 - 180.0, 0.0)
	_sun.light_energy = lerpf(0.035, 1.48, daylight)
	_sun.light_color = Color(1.0, 0.58, 0.32).lerp(Color(1.0, 0.96, 0.87), clampf(daylight + twilight * 0.25, 0.0, 1.0))
	_environment.ambient_light_energy = lerpf(0.12, 0.88, daylight)

	if _environment.sky != null and _environment.sky.sky_material is ProceduralSkyMaterial:
		var sky_material = _environment.sky.sky_material as ProceduralSkyMaterial
		var night_top = Color(0.005, 0.012, 0.055)
		var day_top = Color(0.02, 0.16, 0.42)
		var night_horizon = Color(0.035, 0.055, 0.12)
		var day_horizon = Color(0.64, 0.82, 0.96)
		sky_material.sky_top_color = night_top.lerp(day_top, daylight)
		sky_material.sky_horizon_color = night_horizon.lerp(day_horizon, daylight).lerp(Color(0.95, 0.36, 0.15), twilight * 0.34)


func _apply_weather(immediate: bool) -> void:
	if not is_instance_valid(_environment):
		return
	var fog_density = 0.0018
	var fog_color = Color(0.64, 0.76, 0.88)
	match current_weather:
		"nuageux":
			fog_density = 0.0030
			fog_color = Color(0.50, 0.57, 0.64)
		"couvert":
			fog_density = 0.0048
			fog_color = Color(0.41, 0.45, 0.49)
		"pluie":
			fog_density = 0.0065
			fog_color = Color(0.35, 0.43, 0.50)
		"forte_pluie", "orage":
			fog_density = 0.011
			fog_color = Color(0.20, 0.25, 0.30)
		"brouillard":
			fog_density = 0.025
			fog_color = Color(0.58, 0.64, 0.63)
		"neige":
			fog_density = 0.009
			fog_color = Color(0.78, 0.86, 0.91)
		"blizzard":
			fog_density = 0.030
			fog_color = Color(0.72, 0.79, 0.84)
		"cendres":
			fog_density = 0.022
			fog_color = Color(0.30, 0.27, 0.24)

	_environment.fog_enabled = true
	_environment.fog_density = fog_density
	_environment.fog_light_color = fog_color
	_configure_particles()
	if _underwater:
		_environment.fog_density = clampf(0.026 + _underwater_depth * 0.0028, 0.026, 0.072)
		_environment.fog_light_color = Color(0.015, 0.18, 0.25).lerp(Color(0.005, 0.025, 0.06), clampf(_underwater_depth / 18.0, 0.0, 1.0))
		_particles.emitting = false
	if immediate:
		_update_particles_position()


func _build_particles() -> void:
	_particles = GPUParticles3D.new()
	_particles.name = "MétéoLocale"
	_particles.amount = 260
	_particles.lifetime = 1.8
	_particles.visibility_aabb = AABB(Vector3(-26.0, -20.0, -26.0), Vector3(52.0, 40.0, 52.0))
	_particles.emitting = false

	_particle_material = ParticleProcessMaterial.new()
	_particle_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	_particle_material.emission_box_extents = Vector3(22.0, 1.0, 22.0)
	_particle_material.direction = Vector3(0.0, -1.0, 0.0)
	_particle_material.spread = 7.0
	_particle_material.gravity = Vector3(0.0, -9.0, 0.0)
	_particles.process_material = _particle_material

	_particle_quad = QuadMesh.new()
	var particle_surface = StandardMaterial3D.new()
	particle_surface.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	particle_surface.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	particle_surface.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	particle_surface.albedo_color = Color(0.62, 0.82, 1.0, 0.72)
	_particle_quad.material = particle_surface
	_particle_quad.size = Vector2(0.035, 0.75)
	_particles.draw_pass_1 = _particle_quad
	add_child(_particles)


func _configure_particles() -> void:
	if not is_instance_valid(_particles):
		return
	_particles.emitting = current_weather in ["pluie", "forte_pluie", "orage", "neige", "blizzard", "cendres"]
	var surface = _particle_quad.material as StandardMaterial3D
	if current_weather in ["neige", "blizzard"]:
		_particles.amount = 190 if current_weather == "neige" else 310
		_particles.lifetime = 3.2
		_particle_material.direction = Vector3(0.35 if current_weather == "blizzard" else 0.08, -1.0, 0.12)
		_particle_material.initial_velocity_min = 2.0
		_particle_material.initial_velocity_max = 5.0
		_particle_material.gravity = Vector3(0.0, -1.2, 0.0)
		_particle_quad.size = Vector2(0.14, 0.14)
		surface.albedo_color = Color(0.94, 0.98, 1.0, 0.88)
	elif current_weather == "cendres":
		_particles.amount = 250
		_particles.lifetime = 3.6
		_particle_material.direction = Vector3(0.48, -0.45, 0.20)
		_particle_material.initial_velocity_min = 3.0
		_particle_material.initial_velocity_max = 7.0
		_particle_material.gravity = Vector3(0.0, -0.7, 0.0)
		_particle_quad.size = Vector2(0.10, 0.10)
		surface.albedo_color = Color(0.25, 0.22, 0.19, 0.82)
	else:
		_particles.amount = 150 if current_weather == "pluie" else 310
		_particles.lifetime = 1.25
		_particle_material.direction = Vector3(0.10, -1.0, 0.03)
		_particle_material.initial_velocity_min = 15.0
		_particle_material.initial_velocity_max = 22.0
		_particle_material.gravity = Vector3(0.0, -12.0, 0.0)
		_particle_quad.size = Vector2(0.035, 0.82)
		surface.albedo_color = Color(0.56, 0.78, 1.0, 0.68)


func _update_particles_position() -> void:
	if is_instance_valid(_particles) and is_instance_valid(_player):
		_particles.global_position = _player.global_position + Vector3(0.0, 17.0, 0.0)


func _animate_ocean() -> void:
	if not is_instance_valid(_ocean):
		return
	var seconds = Time.get_ticks_msec() * 0.001
	var amplitude = 0.035
	if current_weather in ["forte_pluie", "orage", "blizzard", "cendres"]:
		amplitude = 0.11
	if _ocean.material_override is ShaderMaterial:
		(_ocean.material_override as ShaderMaterial).set_shader_parameter("force_vagues", amplitude * 3.8)
	elif _ocean.mesh != null and _ocean.mesh.surface_get_material(0) is ShaderMaterial:
		(_ocean.mesh.surface_get_material(0) as ShaderMaterial).set_shader_parameter("force_vagues", amplitude * 3.8)
	_ocean.position.y = _base_ocean_y + sin(seconds * 0.72) * amplitude
	_ocean.rotation.z = sin(seconds * 0.18) * amplitude * 0.018


func _emit_status() -> void:
	var total_minutes = int(game_minutes)
	var hours = total_minutes / 60
	var minutes = total_minutes % 60
	status_changed.emit("%02d:%02d" % [hours, minutes], String(WEATHER_LABELS.get(current_weather, current_weather)))
