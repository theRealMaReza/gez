shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, blend_mix;

// Phase 20.6: musket and cannon smoke in the battle view. One camera-facing
// quad per puff (MultiMesh). INSTANCE_CUSTOM.w is the puff's moment in its
// loop: it swells, drifts up and with the wind, and fades, then starts again,
// so the battle view never rebuilds smoke between syncs.

uniform float cycle = 2.6;        // seconds per puff
uniform vec3 wind = vec3(6.0, 7.0, -3.0);   // field units drifted over one cycle

varying float v_life;
varying float v_seed;

void vertex() {
	float t = fract(TIME / cycle + INSTANCE_CUSTOM.w);
	v_life = t;
	v_seed = INSTANCE_CUSTOM.w;
	float size = length(MODEL_MATRIX[0].xyz) * (0.45 + 0.9 * sqrt(t));
	vec3 centre = MODEL_MATRIX[3].xyz + wind * t;
	vec3 cam_right = INV_VIEW_MATRIX[0].xyz;
	vec3 cam_up = INV_VIEW_MATRIX[1].xyz;
	vec3 world = centre + (cam_right * VERTEX.x + cam_up * VERTEX.y) * size;
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(world, 1.0);
}

void fragment() {
	vec2 d = UV - vec2(0.5);
	float r = length(d) * 2.0;
	// soft round puff with a little lumpiness
	float lump = 0.12 * sin(atan(d.y, d.x) * 5.0 + v_seed * 20.0);
	float shape = smoothstep(1.0, 0.35, r + lump * r);
	float fade = smoothstep(0.0, 0.08, v_life) * (1.0 - smoothstep(0.45, 1.0, v_life));
	ALBEDO = COLOR.rgb;
	ALPHA = shape * fade * COLOR.a;
}
