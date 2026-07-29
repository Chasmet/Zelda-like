extends "res://scripts/main_rpg3d.gd"

func _spawn_enemies() -> void:
	var spawn_zones: Array[int] = [1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 8, 10]
	for index: int in range(spawn_zones.size()):
		var zone_number: int = spawn_zones[index]
		var center: Vector3 = zone_centers[zone_number - 1]
		var angle: float = TAU * float(index % 5) / 5.0 + float(zone_number) * 0.42
		var distance: float = 14.0 + float(index % 3) * 7.0
		var spawn_point: Vector3 = center + Vector3(cos(angle) * distance, 0.4, sin(angle) * distance)
		var enemy: Enemy3D = ENEMY_SCRIPT.new() as Enemy3D
		enemy.name = "Enemy3D_%02d" % (index + 1)
		enemy.target = hero
		enemy.variant = index % 7
		enemy.home_position = spawn_point
		enemy.position = spawn_point
		enemy.max_health = 48 + enemy.variant * 16
		enemy.health = enemy.max_health
		enemy.move_speed = 2.8 + float(enemy.variant % 3) * 0.55
		enemy.damage = 8 + enemy.variant * 3
		add_child(enemy)
		enemy.defeated.connect(_on_enemy_defeated)
		enemies.append(enemy)
