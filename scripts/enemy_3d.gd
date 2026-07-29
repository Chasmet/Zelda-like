class_name Enemy3D
extends CharacterBody3D

signal defeated(enemy: Enemy3D)
signal health_changed(current: int, maximum: int)

var target: Hero3D
var variant: int = 0
var max_health: int = 60
var health: int = 60
var move_speed: float = 3.4
var damage: int = 10
var aggro_range: float = 17.0
var attack_range: float = 1.8
var home_position: Vector3 = Vector3.ZERO

var _gravity: float = 22.0
var _attack_cooldown: float = 0.0
var _stun_timer: float = 0.0
var _anim_clock: float = 0.0
var _model_root: Node3D
var _body_pivot: Node3D
var _left_limb: Node3D
var _right_limb: Node3D
var _health_label: Label3D

func setup(hero: Hero3D, enemy_variant: int, spawn_point: Vector3) -> void:
	target = hero
	variant = enemy_variant % 7
	home_position = spawn_point
	global_position = spawn_point
	max_health = 48 + variant * 16
	health = max_health
	move_speed = 2.8 + float(variant % 3) * 0.55
	damage = 8 + variant * 3

func _ready() -> void:
	_gravity = float(ProjectSettings.get_setting("physics/3d/default_gravity", 22.0))
	if home_position == Vector3.ZERO:
		home_position = global_position
	_build_collision()
	_build_true_3d_variant()
	_build_health_label()

func take_damage(amount: int, from_position: Vector3) -> void:
	if health <= 0:
		return
	health = maxi(0, health - amount)
	_stun_timer = 0.26
	var knockback: Vector3 = global_position - from_position
	knockback.y = 0.18
	if knockback.length_squared() > 0.001:
		velocity += knockback.normalized() * 6.5
	_update_health_label()
	health_changed.emit(health, max_health)
	if health <= 0:
		_die()

func _physics_process(delta: float) -> void:
	_attack_cooldown = maxf(0.0, _attack_cooldown - delta)
	_stun_timer = maxf(0.0, _stun_timer - delta)
	if not is_on_floor():
		velocity.y -= _gravity * delta

	if health <= 0 or not is_instance_valid(target):
		move_and_slide()
		return

	var offset: Vector3 = target.global_position - global_position
	var flat_offset: Vector3 = Vector3(offset.x, 0.0, offset.z)
	var distance: float = flat_offset.length()
	var direction: Vector3 = Vector3.ZERO
	if distance > 0.001:
		direction = flat_offset / distance

	if _stun_timer <= 0.0 and distance <= aggro_range:
		if distance > attack_range:
			velocity.x = move_toward(velocity.x, direction.x * move_speed, 12.0 * delta)
			velocity.z = move_toward(velocity.z, direction.z * move_speed, 12.0 * delta)
			rotation.y = lerp_angle(rotation.y, atan2(-direction.x, -direction.z), 1.0 - exp(-9.0 * delta))
		else:
			velocity.x = move_toward(velocity.x, 0.0, 18.0 * delta)
			velocity.z = move_toward(velocity.z, 0.0, 18.0 * delta)
			_attack_target()
	else:
		var home_offset: Vector3 = home_position - global_position
		home_offset.y = 0.0
		if home_offset.length() > 5.0:
			var home_direction: Vector3 = home_offset.normalized()
			velocity.x = move_toward(velocity.x, home_direction.x * move_speed * 0.6, 8.0 * delta)
			velocity.z = move_toward(velocity.z, home_direction.z * move_speed * 0.6, 8.0 * delta)
		else:
			velocity.x = move_toward(velocity.x, 0.0, 8.0 * delta)
			velocity.z = move_toward(velocity.z, 0.0, 8.0 * delta)

	move_and_slide()
	_update_animation(delta)
	if global_position.y < -20.0:
		global_position = home_position
		velocity = Vector3.ZERO

func _attack_target() -> void:
	if _attack_cooldown > 0.0:
		return
	_attack_cooldown = 1.15 + float(variant % 3) * 0.12
	if target.global_position.distance_to(global_position) <= attack_range + 0.6:
		target.take_damage(damage, global_position)
	var tween: Tween = create_tween()
	tween.tween_property(_body_pivot, "position:z", -0.34, 0.10)
	tween.tween_property(_body_pivot, "position:z", 0.0, 0.18)

func _update_animation(delta: float) -> void:
	var movement_speed: float = Vector2(velocity.x, velocity.z).length()
	var blend: float = clampf(movement_speed / maxf(move_speed, 0.1), 0.0, 1.0)
	_anim_clock += delta * lerpf(3.0, 9.0, blend)
	var stride: float = sin(_anim_clock) * blend
	if is_instance_valid(_left_limb):
		_left_limb.rotation.x = stride * 0.65
	if is_instance_valid(_right_limb):
		_right_limb.rotation.x = -stride * 0.65
	if is_instance_valid(_body_pivot):
		_body_pivot.position.y = absf(sin(_anim_clock * 2.0)) * 0.04 * blend

func _die() -> void:
	collision_layer = 0
	collision_mask = 0
	defeated.emit(self)
	var tween: Tween = create_tween()
	tween.tween_property(_model_root, "scale", Vector3(1.25, 0.08, 1.25), 0.30)
	tween.tween_interval(0.12)
	await tween.finished
	queue_free()

func _build_collision() -> void:
	var collision: CollisionShape3D = CollisionShape3D.new()
	collision.name = "EnemyCollision"
	var capsule: CapsuleShape3D = CapsuleShape3D.new()
	capsule.radius = 0.48 if variant not in [2, 5] else 0.60
	capsule.height = 1.65 if variant not in [2, 5] else 1.15
	collision.shape = capsule
	collision.position.y = 0.85 if variant not in [2, 5] else 0.58
	add_child(collision)

func _build_true_3d_variant() -> void:
	_model_root = Node3D.new()
	_model_root.name = "EnemyTrue3D"
	add_child(_model_root)
	_body_pivot = Node3D.new()
	_body_pivot.name = "BodyPivot"
	_model_root.add_child(_body_pivot)
	match variant:
		0:
			_build_goblin()
		1:
			_build_dark_knight()
		2:
			_build_wolf()
		3:
			_build_golem()
		4:
			_build_mage()
		5:
			_build_scorpion()
		_:
			_build_spectral()

func _build_goblin() -> void:
	var green: StandardMaterial3D = _material(Color("#607d35"), 0.0, 0.82)
	var leather: StandardMaterial3D = _material(Color("#39251b"), 0.02, 0.88)
	var metal: StandardMaterial3D = _material(Color("#7a7d78"), 0.66, 0.30)
	_create_mesh(_body_pivot, _capsule(0.34, 0.82), leather, Vector3(0.0, 1.05, 0.0))
	_create_mesh(_body_pivot, _sphere(0.28, 0.48), green, Vector3(0.0, 1.64, 0.0))
	_create_mesh(_body_pivot, _cone(0.15, 0.0, 0.42, 8), green, Vector3(-0.30, 1.68, 0.0), Vector3(0.0, 0.0, deg_to_rad(82.0)))
	_create_mesh(_body_pivot, _cone(0.15, 0.0, 0.42, 8), green, Vector3(0.30, 1.68, 0.0), Vector3(0.0, 0.0, deg_to_rad(-82.0)))
	_left_limb = _build_humanoid_limb(-0.40, 1.28, green, leather, false)
	_right_limb = _build_humanoid_limb(0.40, 1.28, green, leather, true)
	_create_mesh(_right_limb, _box(Vector3(0.10, 0.64, 0.05)), metal, Vector3(0.0, -0.92, -0.12), Vector3(deg_to_rad(-12.0), 0.0, 0.0))

func _build_dark_knight() -> void:
	var armor: StandardMaterial3D = _material(Color("#262a31"), 0.74, 0.28)
	var purple: StandardMaterial3D = _material(Color("#39285d"), 0.22, 0.44)
	var gold: StandardMaterial3D = _material(Color("#a77b2a"), 0.76, 0.24)
	_create_mesh(_body_pivot, _capsule(0.42, 1.12), armor, Vector3(0.0, 1.18, 0.0))
	_create_mesh(_body_pivot, _sphere(0.31, 0.55), armor, Vector3(0.0, 1.94, 0.0))
	_create_mesh(_body_pivot, _box(Vector3(0.68, 0.12, 0.46)), gold, Vector3(0.0, 1.52, -0.25))
	_create_mesh(_body_pivot, _prism(Vector3(0.86, 1.15, 0.12)), purple, Vector3(0.0, 0.76, 0.20), Vector3(deg_to_rad(90.0), 0.0, 0.0))
	_left_limb = _build_humanoid_limb(-0.48, 1.52, armor, armor, false)
	_right_limb = _build_humanoid_limb(0.48, 1.52, armor, armor, true)
	_create_mesh(_right_limb, _box(Vector3(0.12, 0.95, 0.05)), gold, Vector3(0.0, -1.05, -0.14))
	_create_mesh(_left_limb, _cylinder(0.32, 0.32, 0.12, 16), armor, Vector3(0.0, -0.72, -0.20), Vector3(deg_to_rad(90.0), 0.0, 0.0))

func _build_wolf() -> void:
	var fur: StandardMaterial3D = _material(Color("#3c4650"), 0.02, 0.90)
	var dark: StandardMaterial3D = _material(Color("#171b20"), 0.02, 0.86)
	_create_mesh(_body_pivot, _capsule(0.46, 1.22), fur, Vector3(0.0, 0.72, 0.0), Vector3(deg_to_rad(90.0), 0.0, 0.0))
	_create_mesh(_body_pivot, _capsule(0.30, 0.72), fur, Vector3(0.0, 0.88, -0.78), Vector3(deg_to_rad(70.0), 0.0, 0.0))
	_create_mesh(_body_pivot, _sphere(0.30, 0.50), fur, Vector3(0.0, 1.10, -1.08))
	_create_mesh(_body_pivot, _capsule(0.18, 0.46), dark, Vector3(0.0, 1.04, -1.42), Vector3(deg_to_rad(90.0), 0.0, 0.0))
	_left_limb = _build_animal_leg(Vector3(-0.30, 0.52, -0.48), fur)
	_right_limb = _build_animal_leg(Vector3(0.30, 0.52, -0.48), fur)
	_build_animal_leg(Vector3(-0.30, 0.52, 0.48), fur)
	_build_animal_leg(Vector3(0.30, 0.52, 0.48), fur)
	_create_mesh(_body_pivot, _capsule(0.12, 0.92), fur, Vector3(0.0, 0.78, 0.82), Vector3(deg_to_rad(52.0), 0.0, 0.0))

func _build_golem() -> void:
	var rock: StandardMaterial3D = _material(Color("#53606b"), 0.12, 0.92)
	var crystal: StandardMaterial3D = _emissive_material(Color("#35d5e8"), 2.1)
	_create_mesh(_body_pivot, _box(Vector3(1.15, 1.15, 0.78)), rock, Vector3(0.0, 1.15, 0.0))
	_create_mesh(_body_pivot, _sphere(0.38, 0.64), rock, Vector3(0.0, 1.95, 0.0))
	_create_mesh(_body_pivot, _cone(0.20, 0.0, 0.62, 6), crystal, Vector3(0.0, 1.35, -0.50), Vector3(deg_to_rad(90.0), 0.0, 0.0))
	_left_limb = _build_block_limb(-0.72, rock)
	_right_limb = _build_block_limb(0.72, rock)
	_create_mesh(_body_pivot, _box(Vector3(0.44, 0.70, 0.52)), rock, Vector3(-0.30, 0.35, 0.0))
	_create_mesh(_body_pivot, _box(Vector3(0.44, 0.70, 0.52)), rock, Vector3(0.30, 0.35, 0.0))

func _build_mage() -> void:
	var robe: StandardMaterial3D = _material(Color("#183e45"), 0.12, 0.66)
	var dark: StandardMaterial3D = _material(Color("#0a151b"), 0.02, 0.86)
	var glow: StandardMaterial3D = _emissive_material(Color("#34e9dc"), 2.5)
	_create_mesh(_body_pivot, _cone(0.62, 0.24, 1.55, 14), robe, Vector3(0.0, 0.78, 0.0))
	_create_mesh(_body_pivot, _sphere(0.28, 0.48), dark, Vector3(0.0, 1.78, 0.0))
	_create_mesh(_body_pivot, _cone(0.42, 0.0, 0.78, 12), robe, Vector3(0.0, 2.10, 0.0))
	_left_limb = _build_humanoid_limb(-0.42, 1.36, robe, dark, false)
	_right_limb = _build_humanoid_limb(0.42, 1.36, robe, dark, true)
	_create_mesh(_right_limb, _cylinder(0.045, 0.055, 1.28, 8), dark, Vector3(0.0, -1.05, -0.08))
	_create_mesh(_right_limb, _sphere(0.17, 0.28), glow, Vector3(0.0, -1.72, -0.08))

func _build_scorpion() -> void:
	var shell: StandardMaterial3D = _material(Color("#5a3022"), 0.20, 0.65)
	var ember: StandardMaterial3D = _emissive_material(Color("#f26022"), 1.8)
	_create_mesh(_body_pivot, _sphere(0.62, 0.62), shell, Vector3(0.0, 0.54, 0.0), Vector3.ZERO, Vector3(1.2, 0.68, 1.45))
	_create_mesh(_body_pivot, _sphere(0.42, 0.48), shell, Vector3(0.0, 0.50, -0.70), Vector3.ZERO, Vector3(1.2, 0.70, 1.0))
	for index: int in range(4):
		var z_value: float = -0.52 + float(index) * 0.36
		_build_scorpion_leg(-0.48, z_value, shell, -1.0)
		_build_scorpion_leg(0.48, z_value, shell, 1.0)
	_left_limb = _build_claw(-0.58, shell)
	_right_limb = _build_claw(0.58, shell)
	var tail_root: Node3D = Node3D.new()
	tail_root.position = Vector3(0.0, 0.60, 0.62)
	_body_pivot.add_child(tail_root)
	for segment: int in range(5):
		_create_mesh(tail_root, _sphere(0.18 - float(segment) * 0.018, 0.30), shell, Vector3(0.0, 0.20 + float(segment) * 0.27, 0.14 + float(segment) * 0.16))
	_create_mesh(tail_root, _cone(0.18, 0.0, 0.48, 8), ember, Vector3(0.0, 1.58, 0.92), Vector3(deg_to_rad(45.0), 0.0, 0.0))

func _build_spectral() -> void:
	var robe: StandardMaterial3D = _material(Color("#111c25"), 0.18, 0.52)
	var glow: StandardMaterial3D = _emissive_material(Color("#19d6c6"), 2.8)
	_create_mesh(_body_pivot, _cone(0.62, 0.22, 1.72, 14), robe, Vector3(0.0, 0.86, 0.0))
	_create_mesh(_body_pivot, _sphere(0.29, 0.50), robe, Vector3(0.0, 1.92, 0.0))
	_create_mesh(_body_pivot, _sphere(0.055, 0.10), glow, Vector3(-0.10, 1.96, -0.26))
	_create_mesh(_body_pivot, _sphere(0.055, 0.10), glow, Vector3(0.10, 1.96, -0.26))
	_left_limb = _build_humanoid_limb(-0.46, 1.45, robe, robe, false)
	_right_limb = _build_humanoid_limb(0.46, 1.45, robe, robe, true)
	_create_mesh(_right_limb, _cylinder(0.05, 0.06, 1.22, 8), robe, Vector3(0.0, -1.02, -0.10))
	_create_mesh(_right_limb, _sphere(0.16, 0.28), glow, Vector3(0.0, -1.68, -0.10))

func _build_humanoid_limb(x_position: float, y_position: float, skin_material: Material, armor_material: Material, right_side: bool) -> Node3D:
	var limb: Node3D = Node3D.new()
	limb.position = Vector3(x_position, y_position, 0.0)
	_body_pivot.add_child(limb)
	_create_mesh(limb, _capsule(0.12, 0.52), armor_material, Vector3(0.0, -0.28, 0.0))
	_create_mesh(limb, _capsule(0.10, 0.42), skin_material, Vector3(0.0, -0.62, 0.0))
	_create_mesh(limb, _sphere(0.12, 0.22), skin_material, Vector3(0.0, -0.88, 0.0))
	limb.rotation.z = deg_to_rad(-4.0) if right_side else deg_to_rad(4.0)
	return limb

func _build_block_limb(x_position: float, material: Material) -> Node3D:
	var limb: Node3D = Node3D.new()
	limb.position = Vector3(x_position, 1.48, 0.0)
	_body_pivot.add_child(limb)
	_create_mesh(limb, _box(Vector3(0.50, 0.72, 0.54)), material, Vector3(0.0, -0.32, 0.0))
	_create_mesh(limb, _box(Vector3(0.58, 0.54, 0.64)), material, Vector3(0.0, -0.92, 0.0))
	return limb

func _build_animal_leg(local_position: Vector3, material: Material) -> Node3D:
	var leg: Node3D = Node3D.new()
	leg.position = local_position
	_body_pivot.add_child(leg)
	_create_mesh(leg, _capsule(0.12, 0.62), material, Vector3(0.0, -0.30, 0.0))
	_create_mesh(leg, _capsule(0.09, 0.42), material, Vector3(0.0, -0.64, -0.04))
	return leg

func _build_scorpion_leg(x_position: float, z_position: float, material: Material, side: float) -> void:
	var leg: Node3D = Node3D.new()
	leg.position = Vector3(x_position, 0.48, z_position)
	leg.rotation.z = side * deg_to_rad(58.0)
	_body_pivot.add_child(leg)
	_create_mesh(leg, _capsule(0.07, 0.64), material, Vector3(side * 0.18, -0.16, 0.0), Vector3(0.0, 0.0, side * deg_to_rad(42.0)))

func _build_claw(x_position: float, material: Material) -> Node3D:
	var claw: Node3D = Node3D.new()
	claw.position = Vector3(x_position, 0.62, -0.66)
	_body_pivot.add_child(claw)
	_create_mesh(claw, _capsule(0.10, 0.62), material, Vector3(0.0, -0.10, -0.22), Vector3(deg_to_rad(62.0), 0.0, 0.0))
	_create_mesh(claw, _cone(0.20, 0.02, 0.44, 8), material, Vector3(0.0, -0.08, -0.62), Vector3(deg_to_rad(90.0), 0.0, 0.0))
	return claw

func _build_health_label() -> void:
	_health_label = Label3D.new()
	_health_label.position = Vector3(0.0, 2.55 if variant not in [2, 5] else 1.75, 0.0)
	_health_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_health_label.font_size = 28
	_health_label.outline_size = 7
	_health_label.modulate = Color(1.0, 0.35, 0.25)
	add_child(_health_label)
	_update_health_label()

func _update_health_label() -> void:
	if is_instance_valid(_health_label):
		_health_label.text = "%d/%d" % [health, max_health]

func _create_mesh(parent: Node3D, mesh: Mesh, material: Material, local_position: Vector3, local_rotation: Vector3 = Vector3.ZERO, local_scale: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = local_position
	instance.rotation = local_rotation
	instance.scale = local_scale
	parent.add_child(instance)
	return instance

func _material(color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	return material

func _emissive_material(color: Color, energy: float) -> StandardMaterial3D:
	var material: StandardMaterial3D = _material(color, 0.15, 0.34)
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	return material

func _box(size_value: Vector3) -> BoxMesh:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size_value
	return mesh

func _capsule(radius_value: float, height_value: float) -> CapsuleMesh:
	var mesh: CapsuleMesh = CapsuleMesh.new()
	mesh.radius = radius_value
	mesh.height = height_value
	mesh.radial_segments = 10
	mesh.rings = 5
	return mesh

func _sphere(radius_value: float, height_value: float) -> SphereMesh:
	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius = radius_value
	mesh.height = height_value
	mesh.radial_segments = 10
	mesh.rings = 5
	return mesh

func _cylinder(top_radius: float, bottom_radius: float, height_value: float, segments: int) -> CylinderMesh:
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = top_radius
	mesh.bottom_radius = bottom_radius
	mesh.height = height_value
	mesh.radial_segments = segments
	return mesh

func _cone(bottom_radius: float, top_radius: float, height_value: float, segments: int) -> CylinderMesh:
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.bottom_radius = bottom_radius
	mesh.top_radius = top_radius
	mesh.height = height_value
	mesh.radial_segments = segments
	return mesh

func _prism(size_value: Vector3) -> PrismMesh:
	var mesh: PrismMesh = PrismMesh.new()
	mesh.size = size_value
	return mesh
