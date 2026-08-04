class_name UploadedEnemyController
extends EnemyController

const ADAPTIVE_ANIMATOR_SCRIPT = preload("res://scripts/adaptive_character_animator.gd")

# Hauteur visuelle cible. La mise à l'échelle reste strictement uniforme :
# les proportions, les matériaux et tous les détails du GLB sont conservés.
@export var visual_height: float = 3.2


func apply_asset(path: String) -> void:
	if path.is_empty() or not is_instance_valid(_visual) or not ResourceLoader.exists(path):
		push_warning("GLB de boss absent ou non importable : %s" % path)
		return

	var loaded: Resource = load(path)
	if not (loaded is PackedScene):
		super.apply_asset(path)
		return

	var scene_instance := (loaded as PackedScene).instantiate()
	if not (scene_instance is Node3D):
		return

	_clear_generated_visual()
	var animator := ADAPTIVE_ANIMATOR_SCRIPT.new() as ProceduralCharacterAnimator
	animator.name = "ImportedEnemyModel"
	_visual.add_child(animator)

	var model := scene_instance as Node3D
	model.name = "EnemyBlenderAsset"
	model.set_meta("source_asset", path)
	model.rotation.y = PI
	animator.add_child(model)
	_fit_model_uniformly(model, maxf(1.4, visual_height))
	animator.bind_model(model)
	_model_animator = animator


func _fit_model_uniformly(model: Node3D, target_height: float) -> void:
	var bounds := _combined_model_aabb(model)
	if bounds.size.y <= 0.001:
		return
	var uniform_scale := clampf(target_height / bounds.size.y, 0.02, 25.0)
	model.scale *= Vector3.ONE * uniform_scale
	model.position.y -= bounds.position.y * uniform_scale


func _combined_model_aabb(root: Node3D) -> AABB:
	var points: Array[Vector3] = []
	_collect_mesh_corners(root, root, points)
	if points.is_empty():
		return AABB(Vector3.ZERO, Vector3.ONE)
	var minimum := points[0]
	var maximum := points[0]
	for point in points:
		minimum = Vector3(minf(minimum.x, point.x), minf(minimum.y, point.y), minf(minimum.z, point.z))
		maximum = Vector3(maxf(maximum.x, point.x), maxf(maximum.y, point.y), maxf(maximum.z, point.z))
	return AABB(minimum, maximum - minimum)


func _collect_mesh_corners(node: Node, root: Node3D, points: Array[Vector3]) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh != null:
			var bounds := mesh_instance.mesh.get_aabb()
			var relative_transform := root.global_transform.affine_inverse() * mesh_instance.global_transform
			for corner_index in range(8):
				var corner := bounds.position + Vector3(
					bounds.size.x if (corner_index & 1) != 0 else 0.0,
					bounds.size.y if (corner_index & 2) != 0 else 0.0,
					bounds.size.z if (corner_index & 4) != 0 else 0.0
				)
				points.append(relative_transform * corner)
	for child in node.get_children():
		_collect_mesh_corners(child, root, points)
