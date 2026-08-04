extends "res://scripts/main_supercontinent_v10.gd"

# Sur mobile, le héros doit s'arrêter dès que le joueur relâche le joystick.
# Cette correction ne touche ni aux esquives, ni aux chocs, ni à la nage.
func _release_movement_touch() -> void:
	super._release_movement_touch()
	if not is_instance_valid(player):
		return
	var swimming := bool(player.get("in_water"))
	if swimming:
		return
	player.velocity.x = 0.0
	player.velocity.z = 0.0
