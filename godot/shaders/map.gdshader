shader_type canvas_item;

// Direct port of App/Shared/Map/Metal/MapShaders.metal to Godot 4.7 shading language.
// Every screen pixel works out which map pixel it shows, then combines:
//   terrain texture (baked: elevation shading, biomes, rivers, sea depth)
//   + map-mode tint for the province's owner/state/religion/...
//   + borders (province faint, state medium, country strong band)
//   + animated water, selection glow, paper grain and vignette.

uniform vec2 view_size = vec2(1400.0, 860.0);
uniform vec2 offset = vec2(0.0, 0.0);
uniform float zoom = 1.0;
uniform float time_sec = 0.0;
uniform vec2 map_size = vec2(3936.0, 2384.0);
uniform int selected = 0;
uniform float tint = 0.65;
uniform int mode = 0;
uniform int selected_sea = 0;

uniform sampler2D id_tex : filter_nearest, repeat_disable;
uniform sampler2D terrain_tex : filter_linear, repeat_disable;
uniform sampler2D sea_tex : filter_nearest, repeat_disable;
uniform sampler2D style_tex : filter_nearest, repeat_disable;

int id_at(sampler2D tex, vec2 m, vec2 size) {
	if (m.x < 0.0 || m.y < 0.0 || m.x >= size.x || m.y >= size.y) {
		return 0;
	}
	ivec2 coord = ivec2(int(floor(m.x)), int(floor(m.y)));
	vec4 raw = texelFetch(tex, coord, 0);
	int lo = int(round(raw.r * 255.0));
	int hi = int(round(raw.g * 255.0));
	return lo | (hi << 8);
}

vec4 style_color(int id) {
	return texelFetch(style_tex, ivec2(id, 0), 0);
}

ivec2 style_keys(int id) {
	vec4 raw = texelFetch(style_tex, ivec2(id, 1), 0);
	int o_lo = int(round(raw.r * 255.0));
	int o_hi = int(round(raw.g * 255.0));
	int s_lo = int(round(raw.b * 255.0));
	int s_hi = int(round(raw.a * 255.0));
	int owner = (o_lo | (o_hi << 8)) - 4;
	int state = (s_lo | (s_hi << 8)) - 4;
	return ivec2(owner, state);
}

float hash2(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise2(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float a = hash2(i);
	float b = hash2(i + vec2(1.0, 0.0));
	float c = hash2(i + vec2(0.0, 1.0));
	float d = hash2(i + vec2(1.0, 1.0));
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float luminance(vec3 c) {
	return dot(c, vec3(0.299, 0.587, 0.114));
}

void fragment() {
	vec2 screen = UV * view_size;
	vec2 m = (screen - offset) / zoom;
	vec2 map_uv = m / map_size;
	float px_per_screen = 1.0 / zoom;

	// Outside the map: deep sea.
	if (m.x < 0.0 || m.y < 0.0 || m.x >= map_size.x || m.y >= map_size.y) {
		COLOR = vec4(0.16, 0.25, 0.33, 1.0);
	} else {
		int id = id_at(id_tex, m, map_size);
		vec3 base = texture(terrain_tex, map_uv).rgb;
		vec4 s_color = style_color(id);
		ivec2 s_keys = style_keys(id);
		int s_owner = s_keys.x;
		int s_state = s_keys.y;

		vec3 color;
		if (id == 0) {
			// Water: baked depth colour plus gentle moving waves and coast foam.
			float t = time_sec;
			float w = noise2(m * 0.08 + vec2(t * 0.15, t * 0.07)) * 0.6
				+ noise2(m * 0.21 - vec2(t * 0.1, 0.0)) * 0.4;
			color = base * (0.92 + 0.12 * w);
			float coast = 0.0;
			for (int k = 0; k < 8; k++) {
				float ang = float(k) * 0.785398;
				vec2 dir = vec2(cos(ang), sin(ang));
				if (id_at(id_tex, m + dir * max(2.5 * px_per_screen, 1.2), map_size) != 0) {
					coast = 1.0;
				}
			}
			color = mix(color, vec3(0.82, 0.86, 0.80), coast * 0.35);

			// Faint dotted lines between sea zones.
			int zone = id_at(sea_tex, m, map_size);
			if (zone != 0) {
				float r = 1.2 * px_per_screen;
				int e = id_at(sea_tex, m + vec2(r, 0.0), map_size);
				int s2 = id_at(sea_tex, m + vec2(0.0, r), map_size);
				bool edge = (e != 0 && e != zone) || (s2 != 0 && s2 != zone);
				float dots = step(0.5, fract((screen.x + screen.y) * 0.18));
				if (edge) {
					color = mix(color, vec3(0.80, 0.88, 0.92), 0.35 * dots);
				}
				if (zone == selected_sea) {
					color = mix(color, vec3(0.85, 0.95, 1.0), 0.15);
				}
			}
		} else {
			// Land: terrain with the map-mode colour laid over it.
			color = base;
			if (s_color.a > 0.0) {
				float lum = luminance(base);
				vec3 tinted = s_color.rgb * (0.55 + 0.75 * lum);
				color = mix(base, tinted, tint * s_color.a);
			}
			if (s_owner == -3) {
				// Wasteland: darker, faded, faint diagonal hatching.
				color = mix(color, vec3(luminance(color)), 0.5) * 0.78;
				float hatch = step(0.85, fract((m.x + m.y) * 0.12));
				color *= 1.0 - hatch * 0.12;
			}

			// Borders. Distances are in screen pixels so lines stay the same width at every zoom.
			float country_edge = 0.0;
			float state_edge = 0.0;
			float province_edge = 0.0;
			const float band_radii[4] = { 1.2, 2.5, 4.5, 7.0 };
			const float band_weight[4] = { 1.0, 0.65, 0.35, 0.15 };
			for (int r = 0; r < 4; r++) {
				float rad = band_radii[r] * px_per_screen;
				for (int k = 0; k < 8; k++) {
					float ang = float(k) * 0.785398;
					int other = id_at(id_tex, m + vec2(cos(ang), sin(ang)) * rad, map_size);
					if (other == id) {
						continue;
					}
					ivec2 o_keys = style_keys(other);
					if (o_keys.x != s_owner) {
						country_edge = max(country_edge, band_weight[r]);
					} else if (r == 0) {
						if (o_keys.y != s_state) {
							state_edge = 1.0;
						} else {
							province_edge = 1.0;
						}
					}
				}
			}

			bool show_owners = (mode == 0) && (s_owner >= 0);
			vec3 edge_color = vec3(0.12, 0.10, 0.08);
			if (show_owners) {
				// Coloured band just inside the country edge, and the edge line
				// itself in a deep shade of the country's own colour.
				vec3 band = s_color.rgb * (0.55 + 0.5 * luminance(base));
				color = mix(color, band, smoothstep(0.1, 0.7, country_edge) * 0.5);
				edge_color = s_color.rgb * 0.35;
			}
			color = mix(color, edge_color, step(0.99, country_edge) * 0.8);
			color = mix(color, color * 0.62, state_edge * 0.7);
			float province_alpha = clamp((zoom - 0.25) * 1.0, 0.0, 0.4);
			color = mix(color, color * 0.75, province_edge * province_alpha);

			if (id == selected && selected != 0) {
				float pulse = 0.5 + 0.5 * sin(time_sec * 3.0);
				color = mix(color, vec3(1.0, 0.97, 0.85), 0.18 + 0.08 * pulse);
				if (province_edge > 0.0 || state_edge > 0.0 || country_edge > 0.99) {
					color = vec3(1.0, 0.95, 0.7);
				}
			}
		}

		// Paper grain and a soft vignette tie the look together.
		float grain = hash2(floor(screen)) * 0.035 - 0.0175;
		color += grain;
		vec2 q = screen / view_size - 0.5;
		color *= 1.0 - dot(q, q) * 0.35;
		COLOR = vec4(clamp(color, 0.0, 1.0), 1.0);
	}
}
