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

void vertex() {
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
