class_name CHKPlayerController
extends "res://scripts/player_water.gd"


func _update_model_animation() -> void:
	if not is_instance_valid(_model_animator):
		return

	var horizontal_speed: float = Vector2(velocity.x, velocity.z).length()
	_model_animator.set_swimming(in_water, underwater)
	if in_water:
		_model_animator.set_locomotion(
			horizontal_speed / maxf(swim_sprint_speed, 0.01),
			false
		)
	else:
		_model_animator.set_locomotion(
			horizontal_speed / maxf(sprint_speed, 0.01),
			not is_on_floor()
		)
