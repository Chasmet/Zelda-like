class_name YvanePlayerController
extends "res://scripts/player_chk.gd"

# Le contrôle mobile doit s'arrêter rapidement dès que le doigt quitte le
# joystick. Une accélération plus franche réduit aussi l'inertie au relâchement.
func _ready() -> void:
	acceleration = 64.0
	super._ready()

# Détecte précisément le passage d'un joystick actif à un joystick relâché.
# L'arrêt ne modifie pas les commandes clavier, les attaques ou les esquives.
func set_virtual_move(value: Vector2) -> void:
	var was_active := virtual_move.length() > 0.08
	super.set_virtual_move(value)
	if was_active and virtual_move.length() <= 0.08:
		velocity.x = 0.0
		velocity.z = 0.0

# Caméra troisième personne rapprochée : le personnage reste entier à l'écran,
# mais il est nettement plus proche que dans les versions précédentes.
func _build_camera() -> void:
	_camera_pivot = Node3D.new()
	_camera_pivot.name = "CameraPivot"
	_camera_pivot.position = Vector3(0.0, 1.52, 0.0)
	_camera_pivot.rotation.x = _pitch
	add_child(_camera_pivot)

	var arm := SpringArm3D.new()
	arm.name = "SpringArm"
	arm.spring_length = 4.0
	arm.margin = 0.18
	arm.collision_mask = 1
	_camera_pivot.add_child(arm)

	_camera = Camera3D.new()
	_camera.name = "Camera"
	_camera.current = true
	_camera.fov = 65.0
	_camera.position = Vector3(0.20, 0.10, 0.0)
	arm.add_child(_camera)
