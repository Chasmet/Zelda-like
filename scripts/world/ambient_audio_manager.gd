class_name AmbientAudioManager
extends Node

const REGION_STREAMS = [
	"res://assets/audio/generated/region_01_cote.ogg",
	"res://assets/audio/generated/region_02_foret.ogg",
	"res://assets/audio/generated/region_03_montagnes.ogg",
	"res://assets/audio/generated/region_04_plaines.ogg",
	"res://assets/audio/generated/region_05_volcan.ogg",
	"res://assets/audio/generated/region_06_marais.ogg",
	"res://assets/audio/generated/region_07_cendres.ogg",
	"res://assets/audio/generated/region_08_port.ogg",
	"res://assets/audio/generated/region_09_ruines.ogg",
	"res://assets/audio/generated/region_10_neige.ogg"
]

const WEATHER_STREAMS = {
	"pluie": "res://assets/audio/generated/meteo_pluie.ogg",
	"forte_pluie": "res://assets/audio/generated/meteo_pluie.ogg",
	"orage": "res://assets/audio/generated/meteo_pluie.ogg",
	"vent": "res://assets/audio/generated/meteo_vent.ogg",
	"neige": "res://assets/audio/generated/meteo_neige.ogg",
	"blizzard": "res://assets/audio/generated/meteo_neige.ogg",
	"cendres": "res://assets/audio/generated/meteo_cendres.ogg"
}

const UNDERWATER_STREAM = "res://assets/audio/generated/sous_marin.ogg"

var _clock: WorldClockWeather
var _region_player: AudioStreamPlayer
var _weather_player: AudioStreamPlayer
var _underwater_player: AudioStreamPlayer
var _current_region: int = -1
var _current_weather_stream: String = ""
var _underwater: bool = false


func setup(clock: WorldClockWeather, region_index: int) -> void:
	_clock = clock
	_region_player = _create_player("AmbianceRégion", -23.0)
	_weather_player = _create_player("AmbianceMétéo", -21.0)
	_underwater_player = _create_player("AmbianceSousMarine", -80.0)
	_underwater_player.stream = _load_loop(UNDERWATER_STREAM)
	if _underwater_player.stream != null:
		_underwater_player.play()
	if is_instance_valid(_clock):
		_clock.weather_changed.connect(set_weather)
	set_region(region_index)
	set_weather(_clock.current_weather if is_instance_valid(_clock) else "clair")


func set_region(region_index: int) -> void:
	var next_region = clampi(region_index, 0, REGION_STREAMS.size() - 1)
	if next_region == _current_region:
		return
	_current_region = next_region
	_region_player.stream = _load_loop(REGION_STREAMS[_current_region])
	if _region_player.stream != null:
		_region_player.play()
	_region_player.volume_db = -38.0 if _underwater else -23.0


func set_weather(weather_id: String) -> void:
	var next_path = String(WEATHER_STREAMS.get(weather_id, ""))
	if next_path == _current_weather_stream:
		return
	_current_weather_stream = next_path
	if next_path.is_empty():
		_weather_player.stop()
		_weather_player.stream = null
		return
	_weather_player.stream = _load_loop(next_path)
	if _weather_player.stream != null:
		_weather_player.play()
	_weather_player.volume_db = -42.0 if _underwater else -21.0


func set_underwater(enabled: bool, depth: float = 0.0) -> void:
	if enabled == _underwater:
		if enabled and is_instance_valid(_underwater_player):
			_underwater_player.volume_db = lerpf(-21.0, -13.0, clampf(depth / 22.0, 0.0, 1.0))
		return
	_underwater = enabled
	if _underwater:
		_region_player.volume_db = -38.0
		_weather_player.volume_db = -42.0
		_underwater_player.volume_db = -19.0
	else:
		_region_player.volume_db = -23.0
		_weather_player.volume_db = -21.0
		_underwater_player.volume_db = -80.0


func is_ready() -> bool:
	return is_instance_valid(_region_player) and _region_player.stream != null and is_instance_valid(_underwater_player) and _underwater_player.stream != null


func _exit_tree() -> void:
	shutdown()


func shutdown() -> void:
	for audio_player in [_region_player, _weather_player, _underwater_player]:
		if is_instance_valid(audio_player):
			audio_player.stop()
			audio_player.stream = null


func _create_player(node_name: String, volume: float) -> AudioStreamPlayer:
	var result = AudioStreamPlayer.new()
	result.name = node_name
	result.volume_db = volume
	add_child(result)
	return result


func _load_loop(path: String) -> AudioStream:
	if not ResourceLoader.exists(path):
		return null
	var stream = load(path)
	if stream is AudioStreamOggVorbis:
		stream.loop = true
	return stream
