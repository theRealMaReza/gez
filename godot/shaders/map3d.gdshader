shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque;

// Phase 17: the 3D map. The same look as the old 2D map shader (terrain picture,
// map-mode tint, borders, water, selection, paper grain), painted onto a
// terrain mesh lifted by the elevation data. Borders are measured in screen
// pixels through screen-space derivatives, so they keep the same width when
// the camera tilts.
//
// Colours are worked out in sRGB like the 2D shader and converted to linear
// at the very end when the renderer needs it, so the straight-down view looks
// exactly as before.

uniform vec2 map_size = vec2(3936.0, 2384.0);
uniform float zoom = 1.0;
uniform float time_sec = 0.0;
uniform int selected = 0;
uniform float tint = 0.65;
uniform int mode = 0;
uniform int selected_sea = 0;
uniform float height_max = 34.0;
uniform float relief_light = 0.0;   // 0 = flat look (top-down), up to ~0.5 tilted
// Phase 20 part 8: the painted-chart look when zoomed out (0 = off, 1 = full):
// parchment land washed with the map colours, drawn mountains, a pale sea
// with ripple lines along the coasts, blank parchment for unknown lands.
uniform float chart = 0.0;

uniform sampler2D id_tex : filter_nearest, repeat_disable;
uniform sampler2D terrain_tex : filter_linear, repeat_disable;
uniform sampler2D sea_tex : filter_nearest, repeat_disable;
uniform sampler2D style_tex : filter_nearest, repeat_disable;
uniform sampler2D height_tex : filter_linear, repeat_disable;

varying vec2 map_uv;

float height_from_tex(vec2 uv) {
	float v = textureLod(height_tex, uv, 0.0).r;
	return v * v * height_max;
}

void vertex() {
	map_uv = VERTEX.xz / map_size;
	VERTEX.y = height_from_tex(clamp(map_uv, vec2(0.0), vec2(1.0)));
}

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

vec3 paper(vec2 m) {
	float n = noise2(m * 0.012) * 0.6 + noise2(m * 0.05) * 0.3 + noise2(m * 0.21) * 0.1;
	return vec3(0.94, 0.88, 0.73) * (0.90 + 0.12 * n);
}

// Old-map mountains: little ink peaks on high ground, staggered in rows,
// shaded on the right-hand side. Returns ink strength 0..1.
float mountain_ink(vec2 m, float px) {
	float cell = 42.0;
	vec2 g = m / cell;
	float row = floor(g.y);
	float shift = mod(row, 2.0) * 0.5;
	g.x += shift;
	vec2 cid = floor(g);
	vec2 f = fract(g) - 0.5;
	vec2 centre = (vec2(cid.x - shift, cid.y) + 0.5) * cell;
	float h = textureLod(height_tex, centre / map_size, 0.0).r;
	float j = hash2(cid);
	// only the high ground, and not every cell: a scattering of peaks
	if (h < 0.55 || j < 0.35) {
		return 0.0;
	}
	f -= vec2(j - 0.5, hash2(cid + 7.1) - 0.5) * 0.18;
	float s = clamp((h - 0.40) * 1.1, 0.18, 0.44) * (0.85 + 0.3 * j);
	// peak at (0, -s), base from (-s, 0.55 s) to (s, 0.55 s)
	float base_y = s * 0.55;
	if (f.y > base_y || f.y < -s) {
		return 0.0;
	}
	float hw = (f.y + s) / (s + base_y) * s;      // half width at this height
	float line_w = 1.3 * px / cell;
	float edge = abs(abs(f.x) - hw);
	float ink = 1.0 - smoothstep(line_w * 0.5, line_w * 1.4, edge);
	if (abs(f.x) < hw && f.x > 0.0) {
		// hatch the shaded side
		float hatch = step(0.62, fract((f.x - f.y * 0.6) / (line_w * 4.5)));
		ink = max(ink, hatch * 0.4);
	}
	return ink;
}

float luminance(vec3 c) {
	return dot(c, vec3(0.299, 0.587, 0.114));
}

vec3 srgb_to_linear(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}

void fragment() {
	vec2 screen = FRAGCOORD.xy;
	vec2 m = map_uv * map_size;
	// Map pixels per screen pixel here (bigger far away when tilted).
	float px_per_screen = max(max(length(dFdx(m)), length(dFdy(m))), 0.02);

	vec3 color;
	if (m.x < 0.0 || m.y < 0.0 || m.x >= map_size.x || m.y >= map_size.y) {
		color = vec3(0.16, 0.25, 0.33);
	} else {
		int id = id_at(id_tex, m, map_size);
		vec3 base = texture(terrain_tex, map_uv).rgb;
		vec4 s_color = style_color(id);
		ivec2 s_keys = style_keys(id);
		int s_owner = s_keys.x;
		int s_state = s_keys.y;

		if (id == 0) {
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

			int zone = id_at(sea_tex, m, map_size);
			if (zone == 0) {
				// land outside the map's provinces: blank parchment (terra incognita)
				color = mix(color, paper(m) * 0.97, max(chart, 0.85));
			} else if (chart > 0.01) {
				// a pale painted sea with ripple lines following the coasts
				vec3 sea_wash = vec3(0.64, 0.75, 0.74) * (0.94 + 0.10 * noise2(m * 0.02));
				int first = 6;
				for (int ring = 1; ring <= 5; ring++) {
					float rr = float(ring) * 3.5 * px_per_screen;
					if (id_at(id_tex, m + vec2(rr, 0.0), map_size) != 0 || id_at(id_tex, m - vec2(rr, 0.0), map_size) != 0
						|| id_at(id_tex, m + vec2(0.0, rr), map_size) != 0 || id_at(id_tex, m - vec2(0.0, rr), map_size) != 0) {
						first = ring;
						break;
					}
				}
				if (first == 2 || first == 4) {
					sea_wash *= 0.80;
				}
				color = mix(color, sea_wash, chart * 0.9);
			}
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
			if (chart > 0.01) {
				// hand-coloured chart: the terrain fades into parchment, the map
				// colours are washed over it (below)
				base = mix(base, paper(m) * (0.80 + 0.28 * luminance(base)), chart * 0.85);
			}
			color = base;
			if (s_color.a > 0.0) {
				float lum = luminance(base);
				vec3 tinted = s_color.rgb * (0.55 + 0.75 * lum);
				color = mix(base, tinted, tint * s_color.a);
			}
			if (s_owner == -3) {
				color = mix(color, vec3(luminance(color)), 0.5) * 0.78;
				float hatch = step(0.85, fract((m.x + m.y) * 0.12));
				color *= 1.0 - hatch * 0.12;
			}

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
				vec3 band = s_color.rgb * (0.55 + 0.5 * luminance(base));
				color = mix(color, band, smoothstep(0.1, 0.7, country_edge) * 0.5);
				edge_color = s_color.rgb * 0.35;
			}
			color = mix(color, edge_color, step(0.99, country_edge) * 0.8);
			color = mix(color, color * 0.62, state_edge * 0.7);
			float province_alpha = clamp((zoom - 0.25) * 1.0, 0.0, 0.4);
			color = mix(color, color * 0.75, province_edge * province_alpha);

			// Relief light from the real slope (only when tilted; the baked
			// terrain picture already has north-west hill shading).
			if (relief_light > 0.0) {
				vec2 texel = 1.0 / vec2(textureSize(height_tex, 0));
				vec2 world_per_texel = map_size * texel;
				float hl = height_from_tex(map_uv - vec2(texel.x, 0.0));
				float hr = height_from_tex(map_uv + vec2(texel.x, 0.0));
				float hu = height_from_tex(map_uv - vec2(0.0, texel.y));
				float hd = height_from_tex(map_uv + vec2(0.0, texel.y));
				vec3 n = normalize(vec3((hl - hr) / (2.0 * world_per_texel.x), 1.0, (hu - hd) / (2.0 * world_per_texel.y)));
				vec3 light_dir = normalize(vec3(-0.55, 0.75, -0.45));
				float lambert = dot(n, light_dir) / light_dir.y;
				color *= mix(1.0, clamp(lambert, 0.45, 1.35), relief_light);
			}

			if (chart > 0.01) {
				color = mix(color, vec3(0.24, 0.16, 0.09), mountain_ink(m, px_per_screen) * chart * 0.85);
			}

			if (id == selected && selected != 0) {
				float pulse = 0.5 + 0.5 * sin(time_sec * 3.0);
				color = mix(color, vec3(1.0, 0.97, 0.85), 0.18 + 0.08 * pulse);
				if (province_edge > 0.0 || state_edge > 0.0 || country_edge > 0.99) {
					color = vec3(1.0, 0.95, 0.7);
				}
			}
		}
	}

	float grain = hash2(floor(screen)) * 0.035 - 0.0175;
	color += grain;
	vec2 q = screen / VIEWPORT_SIZE - 0.5;
	color *= 1.0 - dot(q, q) * 0.35;
	color = clamp(color, 0.0, 1.0);
	// Forward+ (Mac, Windows) works in linear light; Compatibility (CI
	// screenshots, old GPUs) writes sRGB directly.
	ALBEDO = OUTPUT_IS_SRGB ? color : srgb_to_linear(color);
}
