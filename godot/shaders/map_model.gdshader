shader_type spatial;
render_mode world_vertex_coords, cull_disabled, specular_disabled;

// Phase 17: every 3D model on the map and in the battle view.
// Colours are baked into the meshes (sRGB vertex colours) and multiplied by
// the instance colour (owner colour for flags, tunics and sails; white
// otherwise). Each instance carries its group's anchor in INSTANCE_CUSTOM.xyz:
// the whole group (a town, an army) grows or shrinks around that point with
// `model_scale`, so models stay readable at every zoom without rebuilding.
// INSTANCE_CUSTOM.w > 0 makes the instance march (bobbing), with that phase.

uniform float model_scale = 1.0;
uniform float march_speed = 7.0;
uniform float march_height = 0.09;
// Phase 20.6: flags and sails move. Only the cloth materials set cloth_wave
// (> 0); COLOR.a is the baked "may move" weight (0 at the pole or mast, 1
// where the cloth is free) and cloth_axis the cloth's thin side in model
// space, the way it flaps.
uniform float cloth_wave = 0.0;
uniform vec3 cloth_axis = vec3(0.0, 0.0, 1.0);
uniform float cloth_speed = 3.2;

void vertex() {
	if (cloth_wave > 0.0) {
		vec3 o = MODEL_MATRIX[3].xyz;
		float k = max(length(MODEL_MATRIX[0].xyz), 0.0001);
		vec3 ax = normalize((MODEL_MATRIX * vec4(cloth_axis, 0.0)).xyz);
		float along = length(VERTEX - o) / k;
		float seed = fract(sin(dot(o.xz, vec2(12.9898, 78.233))) * 43758.5453) * 6.2832;
		float wave = sin(TIME * cloth_speed - along * 5.0 + seed) + 0.35 * sin(TIME * cloth_speed * 1.9 - along * 9.0 + seed * 1.7);
		VERTEX += ax * (wave * cloth_wave * COLOR.a * k);
	}
	vec3 anchor = INSTANCE_CUSTOM.xyz;
	VERTEX = anchor + (VERTEX - anchor) * model_scale;
	float phase = INSTANCE_CUSTOM.w;
	if (phase > 0.0) {
		VERTEX.y += abs(sin(TIME * march_speed + phase * 6.2832)) * march_height * model_scale;
	}
}

vec3 srgb_to_linear(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}

void fragment() {
	vec3 c = clamp(COLOR.rgb, 0.0, 1.0);
	ALBEDO = OUTPUT_IS_SRGB ? c : srgb_to_linear(c);
	ROUGHNESS = 0.9;
}
