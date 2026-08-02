extends "res://scripts/procedural_animator.gd"

# La V8 synchronise l'animation avec la physique du personnage. Cela évite
# qu'une pose importée ou une frame de rendu tardive remette les pivots à zéro
# après le déplacement, notamment sur les appareils mobiles à fréquence variable.


func bind_model(model_root: Node3D) -> void:
	super.bind_model(model_root)
	set_process(false)
	set_physics_process(true)


func _process(_delta: float) -> void:
	# L'animation est volontairement avancée dans _physics_process.
	pass


func _physics_process(delta: float) -> void:
	super._process(delta)


func _animate_airborne() -> void:
	# Une pose aérienne fixe donnait l'impression que les membres étaient figés
	# pendant un saut, une chute ou le vol de secours au-dessus de l'eau.
	var move_blend: float = clampf(_move_ratio, 0.0, 1.0)
	var phase: float = _time * lerpf(4.8, 8.4, move_blend)
	var arm_wave: float = sin(phase) * lerpf(0.10, 0.28, move_blend)
	var leg_wave: float = sin(phase + PI * 0.5) * lerpf(0.08, 0.24, move_blend)
	var lift: float = absf(sin(phase * 0.5)) * 0.035

	_model_root.position.y += lift
	_model_root.rotation.x -= 0.08 + sin(phase * 0.5) * 0.025
	_model_root.rotation.z += sin(phase * 0.35) * 0.025

	if is_instance_valid(_arm_left):
		_arm_left.rotation.x -= 0.72 + arm_wave
		_arm_left.rotation.z -= 0.28 + sin(phase * 0.7) * 0.035
	if is_instance_valid(_arm_right):
		_arm_right.rotation.x -= 0.72 - arm_wave
		_arm_right.rotation.z += 0.28 + sin(phase * 0.7) * 0.035
	if is_instance_valid(_leg_left):
		_leg_left.rotation.x += 0.42 + leg_wave
	if is_instance_valid(_leg_right):
		_leg_right.rotation.x -= 0.28 + leg_wave
	if is_instance_valid(_torso):
		_torso.rotation.x -= 0.14
		_torso.rotation.y += sin(phase * 0.5) * 0.035
	if is_instance_valid(_cape):
		_cape.rotation.x += 0.40 + absf(sin(phase)) * 0.10
