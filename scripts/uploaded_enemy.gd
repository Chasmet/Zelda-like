class_name UploadedEnemyController
extends EnemyController

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

	_clear_generated_visual()
	var animator := ADAPTIVE_ANIMATOR_SCRIPT.new() as ProceduralCharacterAnimator
	animator.name = "ImportedEnemyModel"
	_visual.add_child(animator)

	var node_3d := scene_instance as Node3D
	node_3d.name = "EnemyBlenderAsset"
	node_3d.rotation.y = PI
	animator.add_child(node_3d)
	animator.bind_model(node_3d)
	_model_animator = animator
