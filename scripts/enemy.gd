class_name EnemyController
extends CharacterBody3D

signal defeated(enemy)
signal health_changed(current: int, maximum: int)

const MODEL_ANIMATOR_SCRIPT = preload("res://scripts/procedural_animator.gd")

@export var max_health: int = 70
@export var move_speed: float = 3.2
@export var damage: int = 12
@export var aggro_range: float = 16.0
@export var attack_range: float = 1.7

var health: int = 70
var target: Node3D
var spawn_position: Vector3 = Vector3.ZERO
var attack_timer: float = 0.0
var stun_timer: float = 0.0
var variant: int = 0
var _gravity: float = 22.0
var _visual: Node3D
var _health_label: Label3D
var _model_animator: ProceduralCharacterAnimator

func _ready() -> void:
	_gravity = float(ProjectSettings.get_setting("physics/3d/default_gravity", 22.0))
	spawn_position = global_position
	health = max_health
	_build_body()
	_update_health_label()

func setup(player_node: Node3D, enemy_variant: int, asset_path: String = "") -> void:
	target = player_node
	variant = enemy_variant
	max_health = 55 + variant * 12
	health = max_health
	move_speed = 2.8 + float(variant % 3) * 0.45
	damage = 9 + variant * 2
	if is_inside_tree():
		_recolor_generated()
		if not asset_path.is_empty():
			apply_asset(asset_path)
		_update_health_label()

func _physics_process(delta: float) -> void:
	attack_timer = maxf(0.0, attack_timer - delta)
	stun_timer = maxf(0.0, stun_timer - delta)
	if not is_on_floor():
		velocity.y -= _gravity * delta
	if not is_instance_valid(target) or health <= 0 or stun_timer > 0.0:
		velocity.x = move_toward(velocity.x, 0.0, 10.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 10.0 * delta)
		move_and_slide()
		_update_model_animation()
		return
	var offset: Vector3 = target.global_position - global_position
	var distance: float = offset.length()
	if distance <= aggro_range:
		var direction: Vector3 = Vector3(offset.x, 0.0, offset.z).normalized()
		if distance > attack_range:
			velocity.x = move_toward(velocity.x, direction.x * move_speed, 12.0 * delta)
			velocity.z = move_toward(velocity.z, direction.z * move_speed, 12.0 * delta)
			rotation.y = lerp_angle(rotation.y, atan2(-direction.x, -direction.z), minf(1.0, 8.0 * delta))
		else:
			velocity.x = move_toward(velocity.x, 0.0, 14.0 * delta)
			velocity.z = move_toward(velocity.z, 0.0, 14.0 * delta)
			_attack_player()
	else:
		var home_offset: Vector3 = spawn_position - global_position
		if home_offset.length() > 2.0:
			var home_direction: Vector3 = Vector3(home_offset.x, 0.0, home_offset.z).normalized()
			velocity.x = home_direction.x * move_speed * 0.55
			velocity.z = home_direction.z * move_speed * 0.55
			rotation.y = lerp_angle(rotation.y, atan2(-home_direction.x, -home_direction.z), minf(1.0, 6.0 * delta))
		else:
			velocity.x = move_toward(velocity.x, 0.0, 8.0 * delta)
			velocity.z = move_toward(velocity.z, 0.0, 8.0 * delta)
	move_and_slide()
	_update_model_animation()
	if global_position.y < -10.0:
		global_position = spawn_position

func take_damage(amount: int, from_position: Vector3 = Vector3.ZERO) -> void:
	if health <= 0:
		return
	health = maxi(0, health - amount)
	stun_timer = 0.24
	if from_position != Vector3.ZERO:
		var knockback: Vector3 = (global_position - from_position).normalized()
		knockback.y = 0.18
		velocity += knockback * 6.0
	_update_health_label()
	health_changed.emit(health, max_health)
	if is_instance_valid(_model_animator):
		_model_animator.play_hit()
	elif is_instance_valid(_visual):
		var hit_tween: Tween = create_tween()
		hit_tween.tween_property(_visual, "scale", Vector3(1.22, 0.78, 1.22), 0.07)
		hit_tween.tween_property(_visual, "scale", Vector3.ONE, 0.14)
	if health <= 0:
		collision_layer = 0
		collision_mask = 0
		if is_instance_valid(_model_animator):
			_model_animator.play_death()
		defeated.emit(self)
		var death_tween: Tween = create_tween()
		death_tween.tween_interval(0.36)
		death_tween.tween_property(self, "scale", Vector3.ZERO, 0.28)
		await death_tween.finished
		queue_free()

func apply_asset(path: String) -> void:
	if path.is_empty() or not is_instance_valid(_visual) or not ResourceLoader.exists(path):
		return
	var loaded: Resource = load(path)
	if loaded is PackedScene:
		var packed: PackedScene = loaded as PackedScene
		var scene_instance: Node = packed.instantiate()
		if scene_instance is Node3D:
			_clear_generated_visual()
			var animator: ProceduralCharacterAnimator = MODEL_ANIMATOR_SCRIPT.new() as ProceduralCharacterAnimator
			animator.name = "ImportedEnemyModel"
			_visual.add_child(animator)
			var node_3d: Node3D = scene_instance as Node3D
			node_3d.name = "EnemyBlenderAsset"
			node_3d.rotation.y = PI
			animator.add_child(node_3d)
			animator.bind_model(node_3d)
			_model_animator = animator
	elif loaded is Texture2D:
		var texture: Texture2D = loaded as Texture2D
		_clear_generated_visual()
		var sprite: Sprite3D = Sprite3D.new()
		sprite.name = "ImportedEnemySprite"
		sprite.texture = _enemy_frame(texture)
		sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		sprite.pixel_size = 0.002
		sprite.position.y = 1.0
		sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		_visual.add_child(sprite)

func _enemy_frame(texture: Texture2D) -> Texture2D:
	var width: int = texture.get_width()
	var height: int = texture.get_height()
	if width <= 0 or height <= 0:
		return texture
	var columns: int = 2
	var rows: int = 2
	var ratio: float = float(width) / float(height)
	if ratio > 2.2:
		columns = 4
		rows = 1
	elif ratio < 0.55:
		columns = 1
		rows = 4
	var cell_count: int = columns * rows
	var cell: int = variant % cell_count
	var column: int = cell % columns
	var row: int = cell / columns
	var atlas: AtlasTexture = AtlasTexture.new()
	atlas.atlas = texture
	var cell_width: float = float(width) / float(columns)
	var cell_height: float = float(height) / float(rows)
	atlas.region = Rect2(float(column) * cell_width, float(row) * cell_height, cell_width, cell_height)
	return atlas

func _attack_player() -> void:
	if attack_timer > 0.0:
		return
	attack_timer = 1.15
	if target.has_method("take_damage"):
		target.call("take_damage", damage, global_position)
	if is_instance_valid(_model_animator):
		_model_animator.play_attack()
	elif is_instance_valid(_visual):
		var tween: Tween = create_tween()
		tween.tween_property(_visual, "position:z", -0.35, 0.10)
		tween.tween_property(_visual, "position:z", 0.0, 0.18)

func _build_body() -> void:
	var collider: CollisionShape3D = CollisionShape3D.new()
	var capsule: CapsuleShape3D = CapsuleShape3D.new()
	capsule.radius = 0.5
	capsule.height = 1.6
	collider.shape = capsule
	collider.position.y = 0.8
	add_child(collider)
	_visual = Node3D.new()
	_visual.name = "Visual"
	add_child(_visual)
	var body: MeshInstance3D = MeshInstance3D.new()
	body.name = "GeneratedBody"
	var body_mesh: CapsuleMesh = CapsuleMesh.new()
	body_mesh.radius = 0.48
	body_mesh.height = 1.35
	body_mesh.material = _enemy_material()
	body.mesh = body_mesh
	body.position.y = 0.82
	_visual.add_child(body)
	var left_eye: MeshInstance3D = _make_eye(-0.18)
	var right_eye: MeshInstance3D = _make_eye(0.18)
	_visual.add_child(left_eye)
	_visual.add_child(right_eye)
	_health_label = Label3D.new()
	_health_label.position = Vector3(0.0, 2.15, 0.0)
	_health_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_health_label.font_size = 34
	_health_label.outline_size = 7
	_health_label.modulate = Color(1.0, 0.3, 0.22)
	add_child(_health_label)

func _make_eye(x_position: float) -> MeshInstance3D:
	var eye_node: MeshInstance3D = MeshInstance3D.new()
	eye_node.name = "GeneratedEye"
	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius = 0.07
	mesh.height = 0.14
	var eye_material: StandardMaterial3D = StandardMaterial3D.new()
	eye_material.albedo_color = Color(1.0, 0.9, 0.2)
	eye_material.emission_enabled = true
	eye_material.emission = Color(1.0, 0.18, 0.02)
	eye_material.emission_energy_multiplier = 2.5
	mesh.material = eye_material
	eye_node.mesh = mesh
	eye_node.position = Vector3(x_position, 1.25, -0.43)
	return eye_node

func _update_model_animation() -> void:
	if not is_instance_valid(_model_animator):
		return
	var horizontal_speed: float = Vector2(velocity.x, velocity.z).length()
	_model_animator.set_locomotion(horizontal_speed / maxf(move_speed, 0.01), not is_on_floor())

func _recolor_generated() -> void:
	for child: Node in _visual.get_children():
		if child is MeshInstance3D and String(child.name) == "GeneratedBody":
			var mesh_instance: MeshInstance3D = child as MeshInstance3D
			if mesh_instance.mesh != null:
				mesh_instance.mesh.material = _enemy_material()

func _enemy_material() -> StandardMaterial3D:
	var palette: Array[Color] = [
		Color(0.38, 0.08, 0.08), Color(0.18, 0.34, 0.09),
		Color(0.24, 0.08, 0.40), Color(0.05, 0.30, 0.35),
		Color(0.33, 0.18, 0.08), Color(0.30, 0.32, 0.36),
		Color(0.08, 0.34, 0.48)
	]
	var enemy_material: StandardMaterial3D = StandardMaterial3D.new()
	enemy_material.albedo_color = palette[variant % palette.size()]
	enemy_material.roughness = 0.75
	return enemy_material

func _clear_generated_visual() -> void:
	for child: Node in _visual.get_children():
		var child_name: String = String(child.name)
		if child_name.begins_with("Generated") or child_name.begins_with("Imported"):
			_visual.remove_child(child)
			child.queue_free()
	_model_animator = null

func _update_health_label() -> void:
	if is_instance_valid(_health_label):
		_health_label.text = "%d/%d" % [health, max_health]
