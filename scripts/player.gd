class_name PlayerController
extends CharacterBody3D

signal health_changed(current: int, maximum: int)
signal died
signal attack_requested
signal interact_requested
signal water_state_changed(swimming: bool)

const MODEL_ANIMATOR_SCRIPT = preload("res://scripts/procedural_animator.gd")

@export var move_speed: float = 6.0
@export var sprint_speed: float = 9.0
@export var acceleration: float = 24.0
@export var jump_velocity: float = 8.5
@export var max_health: int = 100
@export var water_level: float = -0.92
@export var swim_speed: float = 4.6
@export var swim_vertical_speed: float = 3.4

var health: int = 100
var virtual_move: Vector2 = Vector2.ZERO
var can_control: bool = true
var attack_cooldown: float = 0.0
var dodge_cooldown: float = 0.0
var invulnerability: float = 0.0
var spawn_position: Vector3 = Vector3.ZERO
var is_swimming: bool = false
var swim_depth: float = 0.0

var _camera_pivot: Node3D
var _camera: Camera3D
var _visual: Node3D
var _sword: Node3D
var _model_animator: ProceduralCharacterAnimator
var _pitch: float = -0.22
var _gravity: float = 22.0
var _swim_vertical_intent: float = 0.0
var _swim_intent_timer: float = 0.0

var _physics_tick_count: int = 0
var _last_input_vector: Vector2 = Vector2.ZERO
var _last_direction: Vector3 = Vector3.ZERO
var _last_target_velocity: Vector3 = Vector3.ZERO
var _last_position_before_slide: Vector3 = Vector3.ZERO
var _last_position_after_slide: Vector3 = Vector3.ZERO
var _last_slide_count: int = 0


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
	_physics_tick_count += 1
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	dodge_cooldown = maxf(0.0, dodge_cooldown - delta)
	invulnerability = maxf(0.0, invulnerability - delta)
	_swim_intent_timer = maxf(0.0, _swim_intent_timer - delta)
	_update_water_state()
	if not is_on_floor() and not is_swimming:
		velocity.y -= _gravity * delta

	var input_vector: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if virtual_move.length() > 0.08:
		input_vector = virtual_move.limit_length(1.0)
	_last_input_vector = input_vector
	_last_direction = Vector3.ZERO
	_last_target_velocity = Vector3.ZERO

	if can_control:
		var forward: Vector3 = Vector3.FORWARD
		var right: Vector3 = Vector3.RIGHT
		if is_instance_valid(_camera):
			forward = -_camera.global_transform.basis.z
			right = _camera.global_transform.basis.x
		forward.y = 0.0
		right.y = 0.0
		if forward.length_squared() < 0.0001:
			forward = Vector3.FORWARD
		else:
			forward = forward.normalized()
		if right.length_squared() < 0.0001:
			right = Vector3.RIGHT
		else:
			right = right.normalized()

		var direction: Vector3 = right * input_vector.x + forward * -input_vector.y
		if direction.length_squared() > 0.0001:
			direction = direction.normalized()
		_last_direction = direction
		var speed: float = swim_speed if is_swimming else (sprint_speed if Input.is_action_pressed("sprint") else move_speed)
		_last_target_velocity = Vector3(direction.x * speed, velocity.y, direction.z * speed)

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
		elif Input.is_action_just_pressed("jump") and is_swimming:
			ascend()
		if Input.is_action_just_pressed("attack"):
			attack()
		if Input.is_action_just_pressed("dodge") and is_swimming:
			dive()
		elif Input.is_action_just_pressed("dodge"):
			dodge()
		if Input.is_action_just_pressed("interact"):
			interact()

	if is_swimming:
		var desired_vertical = _swim_vertical_intent * swim_vertical_speed if _swim_intent_timer > 0.0 else 0.0
		velocity.y = move_toward(velocity.y, desired_vertical, 5.5 * delta)
		swim_depth = maxf(0.0, water_level - global_position.y)
	else:
		swim_depth = 0.0

	_last_position_before_slide = global_position
	move_and_slide()
	_last_position_after_slide = global_position
	_last_slide_count = get_slide_collision_count()
	_update_model_animation()
	if global_position.y < -31.0:
		_respawn()


func get_movement_debug() -> Dictionary:
	var collisions: Array[String] = []
	for collision_index in range(get_slide_collision_count()):
		var collision := get_slide_collision(collision_index)
		if collision != null:
			collisions.append("normal=%s travel=%s collider=%s" % [collision.get_normal(), collision.get_travel(), collision.get_collider()])
	return {
		"physics_ticks": _physics_tick_count,
		"can_control": can_control,
		"virtual_move": virtual_move,
		"input_vector": _last_input_vector,
		"direction": _last_direction,
		"target_velocity": _last_target_velocity,
		"velocity": velocity,
		"position": global_position,
		"frame_motion": _last_position_after_slide - _last_position_before_slide,
		"is_on_floor": is_on_floor(),
		"is_on_wall": is_on_wall(),
		"floor_normal": get_floor_normal(),
		"slide_count": _last_slide_count,
		"collisions": collisions,
		"camera_valid": is_instance_valid(_camera),
		"physics_processing": is_physics_processing()
	}


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var motion: InputEventMouseMotion = event as InputEventMouseMotion
		add_camera_look(motion.relative * 0.0025)
	elif event is InputEventKey:
		var key_event: InputEventKey = event as InputEventKey
		if key_event.pressed and key_event.keycode == KEY_ESCAPE:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and not OS.has_feature("mobile"):
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if mouse_event.pressed:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func set_virtual_move(value: Vector2) -> void:
	virtual_move = value.limit_length(1.0)


func ascend() -> void:
	if not is_swimming:
		return
	_swim_vertical_intent = 1.0
	_swim_intent_timer = 0.42


func dive() -> void:
	if not is_swimming:
		return
	_swim_vertical_intent = -1.0
	_swim_intent_timer = 0.42


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
	if is_instance_valid(_model_animator):
		_model_animator.play_attack()
	elif is_instance_valid(_sword):
		var tween: Tween = create_tween()
		tween.set_trans(Tween.TRANS_QUAD)
		tween.set_ease(Tween.EASE_OUT)
		tween.tween_property(_sword, "rotation:z", -1.5, 0.12)
		tween.tween_property(_sword, "rotation:z", 0.25, 0.20)


func dodge() -> void:
	if is_swimming:
		dive()
		return
	if dodge_cooldown > 0.0 or not can_control:
		return
	dodge_cooldown = 0.9
	invulnerability = 0.48
	var direction: Vector3 = -global_transform.basis.z
	if is_instance_valid(_visual):
		direction = -_visual.global_transform.basis.z
	direction.y = 0.0
	velocity += direction.normalized() * 10.0
	if is_instance_valid(_model_animator):
		_model_animator.play_dodge()
	elif is_instance_valid(_visual):
		var tween: Tween = create_tween()
		tween.tween_property(_visual, "rotation:x", TAU, 0.42).as_relative()


func interact() -> void:
	if can_control:
		interact_requested.emit()


func take_damage(amount: int, from_position: Vector3 = Vector3.ZERO) -> void:
	if invulnerability > 0.0 or health <= 0:
		return
	health = maxi(0, health - amount)
	invulnerability = 0.6
	if from_position != Vector3.ZERO:
		var knockback: Vector3 = (global_position - from_position).normalized()
		knockback.y = 0.25
		velocity += knockback * 7.0
	health_changed.emit(health, max_health)
	if is_instance_valid(_model_animator):
		_model_animator.play_hit()
	elif is_instance_valid(_visual):
		var tween: Tween = create_tween()
		tween.tween_property(_visual, "scale", Vector3(1.15, 0.82, 1.15), 0.08)
		tween.tween_property(_visual, "scale", Vector3.ONE, 0.16)
	if health <= 0:
		can_control = false
		died.emit()
		if is_instance_valid(_model_animator):
			_model_animator.play_death()
		await get_tree().create_timer(0.72).timeout
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
	if path.is_empty() or not is_instance_valid(_visual) or not ResourceLoader.exists(path):
		return
	var loaded: Resource = load(path)
	if loaded is PackedScene:
		var packed: PackedScene = loaded as PackedScene
		var scene_instance: Node = packed.instantiate()
		if scene_instance is Node3D:
			_clear_generated_visual(true)
			var animator: ProceduralCharacterAnimator = MODEL_ANIMATOR_SCRIPT.new() as ProceduralCharacterAnimator
			animator.name = "ImportedHeroModel"
			_visual.add_child(animator)
			var node_3d: Node3D = scene_instance as Node3D
			node_3d.name = "HeroBlenderAsset"
			node_3d.rotation.y = PI
			animator.add_child(node_3d)
			animator.bind_model(node_3d)
			_model_animator = animator
	elif loaded is Texture2D:
		var texture: Texture2D = loaded as Texture2D
		_clear_generated_visual(true)
		var sprite: Sprite3D = Sprite3D.new()
		sprite.name = "ImportedHeroSprite"
		sprite.texture = _hero_frame(texture)
		sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		sprite.pixel_size = 0.0022
		sprite.position.y = 1.05
		sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		_visual.add_child(sprite)


func _hero_frame(texture: Texture2D) -> Texture2D:
	# Le portrait CHK Hero est une image complète et non une planche d'animation.
	# Les anciennes planches restent découpées pour préserver leur compatibilité.
	if not texture.resource_path.contains("pack player"):
		return texture
	var width: int = texture.get_width()
	var height: int = texture.get_height()
	if width <= 0 or height <= 0:
		return texture
	var columns: int = 1
	var rows: int = 1
	var ratio: float = float(width) / float(height)
	if ratio > 1.25:
		columns = 3
		rows = 2
	elif ratio < 0.8:
		columns = 2
		rows = 3
	if columns == 1:
		return texture
	var atlas: AtlasTexture = AtlasTexture.new()
	atlas.atlas = texture
	atlas.region = Rect2(0.0, 0.0, float(width) / float(columns), float(height) / float(rows))
	return atlas


func _respawn() -> void:
	can_control = false
	velocity = Vector3.ZERO
	if is_swimming:
		is_swimming = false
		water_state_changed.emit(false)
	global_position = spawn_position
	health = max_health
	health_changed.emit(health, max_health)
	if is_instance_valid(_model_animator):
		_model_animator.reset_pose()
	await get_tree().create_timer(0.35).timeout
	can_control = true


func _build_body() -> void:
	var collider: CollisionShape3D = CollisionShape3D.new()
	var capsule: CapsuleShape3D = CapsuleShape3D.new()
	capsule.radius = 0.42
	capsule.height = 1.85
	collider.shape = capsule
	collider.position.y = 0.93
	add_child(collider)

	_visual = Node3D.new()
	_visual.name = "Visual"
	add_child(_visual)

	var body: MeshInstance3D = MeshInstance3D.new()
	body.name = "GeneratedBody"
	var body_mesh: CapsuleMesh = CapsuleMesh.new()
	body_mesh.radius = 0.42
	body_mesh.height = 1.45
	body_mesh.material = _material(Color(0.08, 0.22, 0.42))
	body.mesh = body_mesh
	body.position.y = 1.0
	_visual.add_child(body)

	var head: MeshInstance3D = MeshInstance3D.new()
	head.name = "GeneratedHead"
	var head_mesh: SphereMesh = SphereMesh.new()
	head_mesh.radius = 0.31
	head_mesh.height = 0.62
	head_mesh.material = _material(Color(0.45, 0.25, 0.13))
	head.mesh = head_mesh
	head.position.y = 1.95
	_visual.add_child(head)

	_sword = Node3D.new()
	_sword.name = "SwordPivot"
	_sword.position = Vector3(0.52, 1.15, 0.0)
	_sword.rotation.z = 0.25
	_visual.add_child(_sword)
	var blade: MeshInstance3D = MeshInstance3D.new()
	var blade_mesh: BoxMesh = BoxMesh.new()
	blade_mesh.size = Vector3(0.08, 1.25, 0.08)
	blade_mesh.material = _material(Color(0.75, 0.86, 0.95))
	blade.mesh = blade_mesh
	blade.position.y = 0.55
	_sword.add_child(blade)


func _build_camera() -> void:
	_camera_pivot = Node3D.new()
	_camera_pivot.name = "CameraPivot"
	_camera_pivot.position = Vector3(0.0, 1.45, 0.0)
	_camera_pivot.rotation.x = _pitch
	add_child(_camera_pivot)
	var arm: SpringArm3D = SpringArm3D.new()
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


func _update_model_animation() -> void:
	if not is_instance_valid(_model_animator):
		return
	var horizontal_speed: float = Vector2(velocity.x, velocity.z).length()
	_model_animator.set_locomotion(horizontal_speed / maxf(sprint_speed, 0.01), not is_on_floor() and not is_swimming)


func _update_water_state() -> void:
	var should_swim = global_position.y <= water_level - 0.30
	if is_swimming and is_on_floor() and global_position.y > water_level - 0.12:
		should_swim = false
	if should_swim == is_swimming:
		return
	is_swimming = should_swim
	velocity.y = 0.0
	_swim_vertical_intent = 0.0
	_swim_intent_timer = 0.0
	water_state_changed.emit(is_swimming)


func _clear_generated_visual(remove_weapon: bool = false) -> void:
	for child: Node in _visual.get_children():
		if child == _sword and not remove_weapon:
			continue
		var child_name: String = String(child.name)
		if child_name.begins_with("Generated") or child_name.begins_with("Imported") or (remove_weapon and child == _sword):
			_visual.remove_child(child)
			child.queue_free()
	if remove_weapon:
		_sword = null
	_model_animator = null


func _material(color: Color) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.62
	return material
