extends "res://scripts/main_critical_fixes_v8.gd"

# V8.1 : finition visuelle après contrôle des captures réelles.
# Cette couche ne remplace aucun système V8 : elle améliore uniquement
# les normales de l'eau, ses reflets et la lisibilité du panneau CHK HERO.

const V81_VERSION: String = "0.8.1-eau-portrait-polish"
var v81_health_label_ready: bool = false


func _apply_ocean_material_v8() -> void:
	if not is_instance_valid(ocean_surface):
		return
	var material: ShaderMaterial = ShaderMaterial.new()
	var shader: Shader = Shader.new()
	shader.code = """
shader_type spatial;
render_mode blend_mix, depth_prepass_alpha, cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform vec4 eau_cotiere : source_color = vec4(0.018, 0.42, 0.52, 0.63);
uniform vec4 eau_profonde : source_color = vec4(0.004, 0.055, 0.16, 0.82);
uniform vec4 reflet_ciel : source_color = vec4(0.30, 0.67, 0.88, 1.0);
uniform vec4 ecume : source_color = vec4(0.88, 0.98, 1.0, 1.0);
uniform float amplitude = 0.16;
varying float vague;
varying vec3 position_monde;

void vertex() {
	float grande = sin(VERTEX.x * 0.035 + TIME * 0.72);
	float croisee = cos(VERTEX.z * 0.052 - TIME * 0.56);
	float courte = sin((VERTEX.x + VERTEX.z) * 0.115 + TIME * 1.08);
	vague = grande * 0.52 + croisee * 0.31 + courte * 0.17;
	VERTEX.y += vague * amplitude;
	position_monde = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float ride_a = sin(UV.x * 165.0 + TIME * 1.35) * 0.5 + 0.5;
	float ride_b = cos(UV.y * 138.0 - TIME * 1.02) * 0.5 + 0.5;
	float ride_c = sin((UV.x + UV.y) * 92.0 + TIME * 0.76) * 0.5 + 0.5;
	vec2 pente = vec2(
		(ride_a - 0.5) * 0.24 + (ride_c - 0.5) * 0.12,
		(ride_b - 0.5) * 0.22 - (ride_c - 0.5) * 0.10
	);
	NORMAL_MAP = vec3(0.5 + pente.x, 0.5 + pente.y, 1.0);
	NORMAL_MAP_DEPTH = 0.72;

	float fresnel = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 3.2);
	float variation = clamp((ride_a + ride_b + ride_c) / 3.0, 0.0, 1.0);
	float profondeur_visuelle = clamp(0.20 + fresnel * 0.70 + (variation - 0.5) * 0.08, 0.0, 1.0);
	vec3 couleur_eau = mix(eau_cotiere.rgb, eau_profonde.rgb, profondeur_visuelle);
	couleur_eau = mix(couleur_eau, reflet_ciel.rgb, fresnel * 0.36);

	float crete = smoothstep(0.70, 0.98, vague + (variation - 0.5) * 0.28);
	float micro_mousse = smoothstep(0.88, 1.0, variation) * 0.16;
	float mousse = clamp(crete * 0.38 + micro_mousse, 0.0, 0.42);
	ALBEDO = mix(couleur_eau, ecume.rgb, mousse);
	ROUGHNESS = mix(0.22, 0.055, fresnel);
	METALLIC = 0.03;
	SPECULAR = 0.94;
	EMISSION = ecume.rgb * mousse * 0.045;
	ALPHA = mix(eau_cotiere.a, eau_profonde.a, fresnel * 0.82);
}
"""
	material.shader = shader
	ocean_surface.material_override = material
	ocean_surface.position.y = OCEAN_LEVEL_V8
	v8_water_material_applied = true


func _restore_critical_hud_v8() -> void:
	await super._restore_critical_hud_v8()
	await get_tree().process_frame
	if is_instance_valid(v8_health_bar):
		var background: StyleBoxFlat = StyleBoxFlat.new()
		background.bg_color = Color(0.035, 0.055, 0.075, 0.96)
		background.border_color = Color(0.55, 0.72, 0.92, 0.90)
		background.set_border_width_all(1)
		background.corner_radius_top_left = 5
		background.corner_radius_top_right = 5
		background.corner_radius_bottom_left = 5
		background.corner_radius_bottom_right = 5
		var fill: StyleBoxFlat = StyleBoxFlat.new()
		fill.bg_color = Color(0.12, 0.82, 0.38, 0.98)
		fill.corner_radius_top_left = 4
		fill.corner_radius_top_right = 4
		fill.corner_radius_bottom_left = 4
		fill.corner_radius_bottom_right = 4
		v8_health_bar.add_theme_stylebox_override("background", background)
		v8_health_bar.add_theme_stylebox_override("fill", fill)
		v8_health_bar.value = float(player.health) if is_instance_valid(player) else 100.0
		v8_health_bar.visible = true
		v81_health_label_ready = true

	if is_instance_valid(portrait_viewport):
		for child in portrait_viewport.get_children():
			if child is Camera3D:
				var portrait_camera := child as Camera3D
				portrait_camera.position = Vector3(0.0, 1.28, 3.05)
				portrait_camera.look_at(Vector3(0.0, 1.20, 0.0), Vector3.UP)
				break


func _process(delta: float) -> void:
	super._process(delta)
	if is_instance_valid(hero_status_label) and is_instance_valid(player):
		hero_status_label.text = "CHK HERO • %d/%d" % [player.health, player.max_health]


func get_water_portrait_polish_debug() -> Dictionary:
	return {
		"version": V81_VERSION,
		"water_material": v8_water_material_applied,
		"portrait_restored": v8_portrait_restored,
		"health_bar_styled": v81_health_label_ready
	}
