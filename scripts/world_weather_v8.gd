extends Node

var world
var player
var environment_node: WorldEnvironment
var sun: DirectionalLight3D

var rain_particles: GPUParticles3D
var snow_particles: GPUParticles3D
var weather_timer: Timer

var weather_state: int = 0
var day_phase: float = 0.22

var ambient_player: AudioStreamPlayer
var ambient_playback: AudioStreamGeneratorPlayback
var ambient_phase: float = 0.0
var ambient_noise_state: int = 1777


func setup(
	world_ref,
	player_ref,
	world_environment: WorldEnvironment,
	sun_light: DirectionalLight3D
) -> void:
	world = world_ref
	player = player_ref
	environment_node = world_environment
	sun = sun_light
	_build_particles()
	_build_timer()
	_build_ambient_audio()
	_apply_weather(0)


func update_system(delta: float, current_region: int) -> void:
	if not is_instance_valid(player):
		return

	day_phase = fmod(day_phase + delta / 480.0, 1.0)
	_update_day_night()
	_update_particle_follow()

	if current_region == 9 and weather_state == 2:
		_apply_weather(3)

	_fill_ambient_audio()


func get_status_text() -> String:
	var names: Array[String] = ["Soleil", "Nuageux", "Pluie", "Neige"]
	var hour: int = int(fmod(day_phase * 24.0 + 6.0, 24.0))
	return "%s  •  %02dh00" % [names[weather_state], hour]


func _build_particles() -> void:
	rain_particles = _create_weather_particles(false)
	snow_particles = _create_weather_particles(true)
	world.add_child(rain_particles)
	world.add_child(snow_particles)


func _build_timer() -> void:
	weather_timer = Timer.new()
	weather_timer.wait_time = 58.0
	weather_timer.one_shot = false
	weather_timer.timeout.connect(_select_next_weather)
	add_child(weather_timer)
	weather_timer.start()


func _create_weather_particles(snow: bool) -> GPUParticles3D:
	var particles := GPUParticles3D.new()
	particles.amount = 360 if snow else 560
	particles.lifetime = 3.2 if snow else 1.8
	particles.visibility_aabb = AABB(
		Vector3(-28.0, -24.0, -28.0),
		Vector3(56.0, 48.0, 56.0)
	)

	var particle_material := ParticleProcessMaterial.new()
	particle_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	particle_material.emission_box_extents = Vector3(24.0, 1.0, 24.0)
	particle_material.direction = Vector3(0.12, -1.0, 0.06)
	particle_material.spread = 8.0 if snow else 3.0
	particle_material.gravity = Vector3(0.0, -1.8 if snow else -17.0, 0.0)
	particle_material.initial_velocity_min = 1.0 if snow else 11.0
	particle_material.initial_velocity_max = 2.2 if snow else 16.0
	particles.process_material = particle_material

	var quad := QuadMesh.new()
	quad.size = Vector2(0.14, 0.14) if snow else Vector2(0.035, 0.75)
	var material := StandardMaterial3D.new()
	material.albedo_color = (
		Color(0.92, 0.97, 1.0, 0.88)
		if snow
		else Color(0.55, 0.76, 0.92, 0.72)
	)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	quad.material = material
	particles.draw_pass_1 = quad
	particles.emitting = false
	return particles


func _select_next_weather() -> void:
	var current_region: int = int(world.current_zone)
	var roll: int = randi() % 100

	if current_region == 9 and roll < 72:
		_apply_weather(3)
	elif current_region in [1, 5] and roll < 55:
		_apply_weather(2)
	elif roll < 38:
		_apply_weather(0)
	elif roll < 68:
		_apply_weather(1)
	elif roll < 90:
		_apply_weather(2)
	else:
		_apply_weather(3)


func _apply_weather(new_state: int) -> void:
	weather_state = new_state

	if is_instance_valid(rain_particles):
		rain_particles.emitting = weather_state == 2
	if is_instance_valid(snow_particles):
		snow_particles.emitting = weather_state == 3

	if not is_instance_valid(environment_node):
		return

	var environment: Environment = environment_node.environment
	environment.fog_density = [0.0016, 0.0035, 0.0068, 0.0048][weather_state]
	environment.fog_light_color = [
		Color(0.58, 0.70, 0.78),
		Color(0.44, 0.49, 0.54),
		Color(0.30, 0.38, 0.44),
		Color(0.76, 0.82, 0.86)
	][weather_state]


func _update_particle_follow() -> void:
	if is_instance_valid(rain_particles):
		rain_particles.global_position = player.global_position + Vector3(0.0, 21.0, 0.0)
	if is_instance_valid(snow_particles):
		snow_particles.global_position = player.global_position + Vector3(0.0, 18.0, 0.0)


func _update_day_night() -> void:
	if not is_instance_valid(sun) or not is_instance_valid(environment_node):
		return

	var sun_angle: float = day_phase * TAU - PI * 0.5
	var daylight: float = clampf(sin(sun_angle) * 0.5 + 0.5, 0.08, 1.0)

	sun.rotation.x = sun_angle
	sun.rotation.y = -0.48
	sun.light_energy = 0.12 + daylight * 1.35
	sun.light_color = Color(1.0, 0.72, 0.48).lerp(
		Color(1.0, 0.97, 0.90),
		daylight
	)

	var environment: Environment = environment_node.environment
	environment.ambient_light_energy = 0.20 + daylight * 0.82
	environment.background_color = Color(0.025, 0.045, 0.10).lerp(
		Color(0.39, 0.66, 0.90),
		daylight
	)


func _build_ambient_audio() -> void:
	ambient_player = AudioStreamPlayer.new()
	ambient_player.name = "ProceduralAmbientSound"
	ambient_player.volume_db = -28.0

	var generator := AudioStreamGenerator.new()
	generator.mix_rate = 22050.0
	generator.buffer_length = 0.35
	ambient_player.stream = generator

	world.add_child(ambient_player)
	ambient_player.play()
	ambient_playback = (
		ambient_player.get_stream_playback()
		as AudioStreamGeneratorPlayback
	)


func _fill_ambient_audio() -> void:
	if not is_instance_valid(ambient_playback):
		return

	var frames: int = ambient_playback.get_frames_available()
	var mix_rate: float = 22050.0
	for _index in range(frames):
		ambient_noise_state = int(
			(ambient_noise_state * 1103515245 + 12345) & 0x7fffffff
		)
		var noise: float = (
			(float(ambient_noise_state % 2000) / 1000.0 - 1.0) * 0.006
		)
		var ocean_tone: float = sin(ambient_phase) * 0.004
		var weather_gain: float = 1.8 if weather_state in [2, 3] else 1.0
		var sample: float = noise * weather_gain + ocean_tone
		ambient_playback.push_frame(Vector2(sample, sample))
		ambient_phase = fmod(ambient_phase + TAU * 72.0 / mix_rate, TAU)
