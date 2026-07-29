class_name PlayerController
extends CharacterBody3D

signal health_changed(current: int, maximum: int)
signal died
signal attack_requested
signal interact_requested

@export var move_speed := 6.0
@export var sprint_speed := 9.0
@export var acceleration := 24.0
@export var jump_velocity := 8.5
@export var max_health := 100

var health := 100
var virtual_move := Vector2.ZERO
var can_control := true
var attack_cooldown := 0.0
var dodge_cooldown := 0.0
var invulnerability := 0.0
var spawn_position := Vector3.ZERO

var _camera_pivot: Node3D
var _camera: Camera3D
var _visual: Node3D
var _sword: Node3D
var _pitch := -0.22
var _gravity := 22.0

func _ready() -> void:
	_gravity = float(ProjectSettings.get_setting("physics/3d/default_gravity", 22.0))
	spawn_position = global_position
	_build_body()
	_build_camera()
	health = max_health
	health_changed.emit(health, max_health)
	if not OS.has_feature("mobile"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _physics_process(delta: float) -> void:
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	dodge_cooldown = maxf(0.0, dodge_cooldown - delta)
	invulnerability = maxf(0.0, invulnerability - delta)

	if not is_on_floor():
		velocity.y -= _gravity * delta

	var input_vector := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if virtual_move.length() > 0.08:
		input_vector = virtual_move.limit_length(1.0)

	if can_control:
		var forward := -_camera.global_transform.basis.z
		var right := _camera.global_transform.basis.x
		forward.y = 0.0
		right.y = 0.0
		forward = forward.normalized()
		right = right.normalized()
		var direction := (right * input_vector.x + forward * -input_vector.y).normalized()
		var speed := sprint_speed if Input.is_action_pressed("sprint") else move_speed

		if direction.length_squared() > 0.01:
			velocity.x = move_toward(velocity.x, direction.x * speed, acceleration * delta)
			velocity.z = move_toward(velocity.z, direction.z * speed, acceleration * delta)
			if is_instance_valid(_visual):
				_visual.rotation.y = lerp_angle(_visual.rotation.y, atan2(-direction.x, -direction.z), minf(1.0, 12.0 * delta))
		else:
			velocity.x = move_toward(velocity.x, 0.0, acceleration * delta)
			velocity.z = move_toward(velocity.z, 0.0, acceleration * delta)

		if Input.is_action_just_pressed("jump") and is_on_floor():
			velocity.y = jump_velocity
		if Input.is_action_just_pressed("attack"):
			attack()
		if Input.is_action_just_pressed("dodge"):
			dodge()
		if Input.is_action_just_pressed("interact"):
			interact()

	move_and_slide()

	if global_position.y < -12.0:
		_respawn()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		add_camera_look(event.relative * 0.0025)
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and event.pressed and not OS.has_feature("mobile"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func set_virtual_move(value: Vector2) -> void:
	virtual_move = value

func add_camera_look(value: Vector2) -> void:
	if not is_instance_valid(_camera_pivot):
		return
	_camera_pivot.rotation.y -= value.x
	_pitch = clampf(_pitch - value.y, -1.15, 0.35)
	_camera_pivot.rotation.x = _pitch

func attack() -> void:
	if attack_cooldown > 0.0 or not can_control:
		return
	attack_cooldown = 0.48
	attack_requested.emit()
	if is_instance_valid(_sword):
		var tween := create_tween()
		tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(_sword, "rotation:z", -1.5, 0.12)
		tween.tween_property(_sword, "rotation:z", 0.25, 0.2)

func dodge() -> void:
	if dodge_cooldown > 0.0 or not can_control:
		return
	dodge_cooldown = 0.9
	invulnerability = 0.48
	var direction := -_visual.global_transform.basis.z if is_instance_valid(_visual) else -global_transform.basis.z
	direction.y = 0.0
	velocity += direction.normalized() * 10.0
	if is_instance_valid(_visual):
		var tween := create_tween()
		tween.tween_property(_visual, "rotation:x", TAU, 0.42).as_relative()

func interact() -> void:
	if can_control:
		interact_requested.emit()

func take_damage(amount: int, from_position := Vector3.ZERO) -> void:
	if invulnerability > 0.0 or health <= 0:
		return
	health = maxi(0, health - amount)
	invulnerability = 0.6
	if from_position != Vector3.ZERO:
		var knockback := (global_position - from_position).normalized()
		knockback.y = 0.25
		velocity += knockback * 7.0
	health_changed.emit(health, max_health)
	if is_instance_valid(_visual):
		var tween := create_tween()
		tween.tween_property(_visual, "scale", Vector3(1.15, 0.82, 1.15), 0.08)
		tween.tween_property(_visual, "scale", Vector3.ONE, 0.16)
	if health <= 0:
		died.emit()
		_respawn()

func heal(amount: int) -> void:
	health = mini(max_health, health + amount)
	health_changed.emit(health, max_health)

func get_forward() -> Vector3:
	if is_instance_valid(_visual):
		return -_visual.global_transform.basis.z.normalized()
	return -global_transform.basis.z.normalized()

func set_spawn(point: Vector3) -> void:
	spawn_position = point

func apply_asset(path: String) -> void:
	if path.is_empty() or not is_instance_valid(_visual):
		return
	var resource := load(path)
	if resource is PackedScene:
		_clear_generated_visual()
		var instance := resource.instantiate()
		instance.name = "ImportedHero"
		_visual.add_child(instance)
		_normalize_imported(instance, 2.1)
	elif resource is Texture2D:
		_clear_generated_visual()
		var sprite := Sprite3D.new()
		sprite.name = "ImportedHeroSprite"
		sprite.texture = _hero_frame(resource)
		sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		sprite.pixel_size = 0.0022
		sprite.position.y = 1.05
		sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		_visual.add_child(sprite)

func _hero_frame(texture: Texture2D) -> Texture2D:
	var width := texture.get_width()
	var height := texture.get_height()
	if width <= 0 or height <= 0:
		return texture
	var columns := 1
	var rows := 1
	var ratio := float(width) / float(height)
	if ratio > 1.25:
		columns = 3
		rows = 2
	elif ratio < 0.8:
		columns = 2
		rows = 3
	if columns == 1:
		return texture
	var atlas := AtlasTexture.new()
	atlas.atlas = texture
	atlas.region = Rect2(0, 0, float(width) / columns, float(height) / rows)
	return atlas

func _respawn() -> void:
	can_control = false
	velocity = Vector3.ZERO
	global_position = spawn_position
	health = max_health
	health_changed.emit(health, max_health)
	await get_tree().create_timer(0.35).timeout
	can_control = true

func _build_body() -> void:
	var collider := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.42
	capsule.height = 1.85
	collider.shape = capsule
	collider.position.y = 0.93
	add_child(collider)

	_visual = Node3D.new()
	_visual.name = "Visual"
	add_child(_visual)

	var body := MeshInstance3D.new()
	body.name = "GeneratedBody"
	var body_mesh := CapsuleMesh.new()
	body_mesh.radius = 0.42
	body_mesh.height = 1.45
	body_mesh.material = _material(Color(0.08, 0.22, 0.42), Color(0.02, 0.08, 0.16))
	body.mesh = body_mesh
	body.position.y = 1.0
	_visual.add_child(body)

	var head := MeshInstance3D.new()
	head.name = "GeneratedHead"
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.31
	head_mesh.height = 0.62
	head_mesh.material = _material(Color(0.45, 0.25, 0.13))
	head.mesh = head_mesh
	head.position.y = 1.95
	_visual.add_child(head)

	var hood := MeshInstance3D.new()
	hood.name = "GeneratedHood"
	var hood_mesh := SphereMesh.new()
	hood_mesh.radius = 0.37
	hood_mesh.height = 0.7
	hood_mesh.material = _material(Color(0.035, 0.05, 0.08))
	hood.mesh = hood_mesh
	hood.position = Vector3(0, 2.02, 0.05)
	_visual.add_child(hood)

	_sword = Node3D.new()
	_sword.name = "SwordPivot"
	_sword.position = Vector3(0.52, 1.15, 0.0)
	_sword.rotation.z = 0.25
	_visual.add_child(_sword)
	var blade := MeshInstance3D.new()
	var blade_mesh := BoxMesh.new()
	blade_mesh.size = Vector3(0.08, 1.25, 0.08)
	blade_mesh.material = _material(Color(0.75, 0.86, 0.95), Color(0.2, 0.35, 0.5))
	blade.mesh = blade_mesh
	blade.position.y = 0.55
	_sword.add_child(blade)

func _build_camera() -> void:
	_camera_pivot = Node3D.new()
	_camera_pivot.name = "CameraPivot"
	_camera_pivot.position = Vector3(0, 1.45, 0)
	_camera_pivot.rotation.x = _pitch
	add_child(_camera_pivot)

	var arm := SpringArm3D.new()
	arm.name = "SpringArm"
	arm.spring_length = 6.2
	arm.margin = 0.2
	arm.collision_mask = 1
	_camera_pivot.add_child(arm)

	_camera = Camera3D.new()
	_camera.name = "Camera"
	_camera.current = true
	_camera.fov = 68.0
	arm.add_child(_camera)

func _clear_generated_visual() -> void:
	for child in _visual.get_children():
		if child == _sword:
			continue
		if String(child.name).begins_with("Generated") or String(child.name).begins_with("Imported"):
			child.queue_free()

func _normalize_imported(node: Node3D, target_height: float) -> void:
	await get_tree().process_frame
	var aabb := _combined_aabb(node)
	if aabb.size.y > 0.01:
		var factor := target_height / aabb.size.y
		node.scale = Vector3.ONE * clampf(factor, 0.01, 10.0)
		node.position.y = -aabb.position.y * factor

func _combined_aabb(root: Node) -> AABB:
	var found := false
	var result := AABB()
	for child in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := child as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		var box := mesh_instance.mesh.get_aabb()
		box = mesh_instance.transform * box
		if not found:
			result = box
			found = true
		else:
			result = result.merge(box)
	return result

func _material(color: Color, emission := Color(0, 0, 0, 1)) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.62
	if emission.r + emission.g + emission.b > 0.01:
		material.emission_enabled = true
		material.emission = emission
		material.emission_energy_multiplier = 1.6
	return material
