class_name CHKPlayerController
extends "res://scripts/player_water.gd"

const ADAPTIVE_ANIMATOR_SCRIPT = preload("res://scripts/adaptive_character_animator.gd")


func apply_asset(path: String) -> void:
	if path.is_empty() or not is_instance_valid(_visual) or not ResourceLoader.exists(path):
		return

	var loaded: Resource = load(path)
	if not loaded is PackedScene:
		super.apply_asset(path)
		return

	var packed := loaded as PackedScene
	var scene_instance := packed.instantiate()
	if not scene_instance is Node3D:
		return

	_clear_generated_visual(true)
	var animator := ADAPTIVE_ANIMATOR_SCRIPT.new() as ProceduralCharacterAnimator
	animator.name = "ImportedHeroModel"
	_visual.add_child(animator)

	var node_3d := scene_instance as Node3D
	node_3d.name = "HeroBlenderAsset"
	node_3d.rotation.y = PI
	animator.add_child(node_3d)
	animator.bind_model(node_3d)
	_model_animator = animator


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
