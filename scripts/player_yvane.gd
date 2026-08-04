class_name YvanePlayerController
extends "res://scripts/player_chk.gd"

const ADAPTIVE_ANIMATOR_SCRIPT = preload("res://scripts/adaptive_character_animator.gd")


func apply_asset(path: String) -> void:
	if path.is_empty() or not is_instance_valid(_visual) or not ResourceLoader.exists(path):
		return

	var loaded: Resource = load(path)
	if not loaded is PackedScene:
		super.apply_asset(path)
		return

	var scene_instance := (loaded as PackedScene).instantiate()
	if not scene_instance is Node3D:
		return

	_clear_generated_visual(true)
	var animator := ADAPTIVE_ANIMATOR_SCRIPT.new() as ProceduralCharacterAnimator
	animator.name = "ImportedHeroModel"
	_visual.add_child(animator)

	var model := scene_instance as Node3D
	model.name = "HeroBlenderAsset"
	model.rotation.y = PI
	animator.add_child(model)
	animator.bind_model(model)
	_model_animator = animator
