extends Node


func _ready() -> void:
	call_deferred("_adjust_portrait")


func _adjust_portrait() -> void:
	var game := get_parent()
	for _frame in range(900):
		await get_tree().process_frame
		var portrait_model = game.get("portrait_model")
		var portrait_viewport = game.get("portrait_viewport")
		if not is_instance_valid(portrait_model) or not is_instance_valid(portrait_viewport):
			continue

		portrait_model.scale = Vector3.ONE * 1.12
		portrait_model.position = Vector3(0.0, -0.05, 0.0)

		var portrait_camera: Camera3D = portrait_viewport.get_camera_3d()
		if is_instance_valid(portrait_camera):
			portrait_camera.position = Vector3(0.0, 1.28, -2.95)
			portrait_camera.look_at(Vector3(0.0, 1.22, 0.0), Vector3.UP)
		return
