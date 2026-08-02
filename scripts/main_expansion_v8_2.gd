extends "res://scripts/main_expansion_v8_1.gd"


func _build_ocean_physics() -> void:
	super._build_ocean_physics()

	if is_instance_valid(ocean_swim_volume) and ocean_swim_volume.get_child_count() > 0:
		var volume_collision := ocean_swim_volume.get_child(0)
		if volume_collision is CollisionShape3D:
			volume_collision.name = "WaterVolumeCollision"

	if is_instance_valid(ocean_floor):
		for child in ocean_floor.get_children():
			if child is CollisionShape3D:
				child.name = "SeabedCollision"
			elif child is MeshInstance3D:
				child.name = "SeabedVisual"
