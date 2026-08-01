extends "res://scripts/main_mobile_ui_polish_v8_3.gd"

# V8.4 : la place du village et le héros utilisaient exactement les mêmes
# coordonnées. CHK Hero apparaissait donc à l'intérieur du puits. Le nouveau
# point de départ reste sur la place, mais à distance du puits et des bancs.

const V84_VERSION: String = "0.8.4-spawn-securise"
const V84_SAFE_SPAWN_LOCAL := Vector2(31.0, 3.0)
const V84_WELL_LOCAL := Vector2(24.0, 10.0)
const V84_MIN_WELL_DISTANCE := 5.5

var spawn_safety_applied: bool = false
var spawn_well_distance: float = 0.0


func _spawn_player() -> void:
	super._spawn_player()
	_apply_safe_spawn_v84(true)


func _finish_loading() -> void:
	super._finish_loading()
	call_deferred("_repair_loaded_spawn_v84")


func _repair_loaded_spawn_v84() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	_apply_safe_spawn_v84(false)


func _apply_safe_spawn_v84(force_new_spawn: bool) -> void:
	if not is_instance_valid(player):
		return
	var center: Vector3 = ZONE_CENTERS[START_ZONE]
	var well_world := Vector3(center.x + V84_WELL_LOCAL.x, player.global_position.y, center.z + V84_WELL_LOCAL.y)
	var current_horizontal := Vector2(player.global_position.x - well_world.x, player.global_position.z - well_world.z)
	var inside_well_or_bench_ring: bool = current_horizontal.length() < V84_MIN_WELL_DISTANCE
	if force_new_spawn or inside_well_or_bench_ring:
		var spawn_x: float = center.x + V84_SAFE_SPAWN_LOCAL.x
		var spawn_z: float = center.z + V84_SAFE_SPAWN_LOCAL.y
		var safe_position := Vector3(spawn_x, _terrain_world_height(START_ZONE, spawn_x, spawn_z) + 0.62, spawn_z)
		player.global_position = safe_position
		player.velocity = Vector3.ZERO
		player.set_spawn(safe_position)
		v6_start_position = safe_position
		if not force_new_spawn:
			_save_progress()
	var final_horizontal := Vector2(player.global_position.x - well_world.x, player.global_position.z - well_world.z)
	spawn_well_distance = final_horizontal.length()
	spawn_safety_applied = spawn_well_distance >= V84_MIN_WELL_DISTANCE


func get_spawn_safety_debug() -> Dictionary:
	return {
		"version": V84_VERSION,
		"spawn_safety_applied": spawn_safety_applied,
		"well_distance": spawn_well_distance,
		"minimum_distance": V84_MIN_WELL_DISTANCE,
		"player_position": player.global_position if is_instance_valid(player) else Vector3.ZERO
	}
