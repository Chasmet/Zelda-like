extends "res://scripts/main_water_portrait_polish_v8_1.gd"

# La capture réelle V8.1 a montré que le modèle 3D du sous-viewport présentait
# son dos. Le portrait officiel, déjà intégré au projet, montre correctement
# CHK Hero en chevalier de face et reste lisible sur les petits écrans Android.

const V82_VERSION: String = "0.8.2-portrait-face"
var portrait_front_applied: bool = false


func _restore_critical_hud_v8() -> void:
	await super._restore_critical_hud_v8()
	await get_tree().process_frame
	if is_instance_valid(v8_portrait_texture):
		v8_portrait_texture.texture = CHK_HERO_PORTRAIT
		v8_portrait_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		v8_portrait_texture.visible = true
		v8_portrait_texture.modulate = Color.WHITE
		portrait_front_applied = v8_portrait_texture.texture == CHK_HERO_PORTRAIT


func get_portrait_front_debug() -> Dictionary:
	return {
		"version": V82_VERSION,
		"portrait_front_applied": portrait_front_applied,
		"portrait_is_official": is_instance_valid(v8_portrait_texture) and v8_portrait_texture.texture == CHK_HERO_PORTRAIT,
		"portrait_visible": v8_portrait_texture.visible if is_instance_valid(v8_portrait_texture) else false
	}
