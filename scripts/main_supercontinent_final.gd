extends "res://scripts/main_supercontinent_v10.gd"

# Le village de départ est installé sur une vraie grande plaine stable, et non
# sur la pente de la côte. Cela évite tout glissement involontaire du héros.
func _super_height(world_x: float, world_z: float) -> float:
	var base_height: float = super._super_height(world_x, world_z)
	var village_center: Vector3 = SUPER_ZONE_CENTERS[START_ZONE]
	var distance: float = Vector2(world_x - village_center.x, world_z - village_center.z).length()
	if distance >= 58.0:
		return base_height
	var flat_height := 2.10
	var blend := 1.0 - smoothstep(30.0, 58.0, distance)
	return lerpf(base_height, flat_height, blend)

# Sur mobile, le héros doit s'arrêter dès que le joueur relâche le joystick.
func _release_movement_touch() -> void:
	super._release_movement_touch()
	if not is_instance_valid(player):
		return
	player.velocity.x = 0.0
	player.velocity.z = 0.0
