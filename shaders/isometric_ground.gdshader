shader_type canvas_item;

uniform vec4 bg_color : source_color = vec4(0.04, 0.05, 0.08, 1.0);
uniform vec4 line_color : source_color = vec4(0.10, 0.16, 0.28, 0.6);
uniform vec4 major_line_color : source_color = vec4(0.20, 0.45, 0.90, 1.2); // HDR Blue
uniform vec4 border_color : source_color = vec4(0.3, 0.8, 1.5, 1.5);      // HDR Border
uniform float grid_scale : hint_range(16.0, 256.0) = 64.0;
uniform vec2 arena_size = vec2(10000.0, 10000.0);

varying vec2 world_pos;

// Hash for procedural fog
float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i + vec2(0.0, 0.0)), hash(i + vec2(1.0, 0.0)), u.x),
	           mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float val = 0.0;
	float amp = 0.5;
	for (int i = 0; i < 3; i++) {
		val += amp * noise(p);
		p *= 2.02;
		amp *= 0.5;
	}
	return val;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	// 2:1 isometric coordinates
	float u = (world_pos.x * 0.5 + world_pos.y) / grid_scale;
	float v = (world_pos.x * 0.5 - world_pos.y) / grid_scale;

	// Grid line thickness
	vec2 grid_uv = abs(fract(vec2(u, v) - 0.5) - 0.5) / fwidth(vec2(u, v));
	float line_intensity = 1.0 - min(min(grid_uv.x, grid_uv.y), 1.0);

	// Major lines every 8 tiles with animated energy pulse
	vec2 major_uv = abs(fract(vec2(u / 8.0, v / 8.0) - 0.5) - 0.5) / fwidth(vec2(u / 8.0, v / 8.0));
	float major_intensity = 1.0 - min(min(major_uv.x, major_uv.y), 1.0);
	
	// Energy flow pulse along conduits
	float pulse = 0.7 + 0.3 * sin(TIME * 2.5 + (u + v) * 0.25);

	vec4 color = bg_color;
	color = mix(color, line_color, line_intensity * 0.55);
	color = mix(color, major_line_color * pulse, major_intensity * 0.95);

	// Drifting ambient mist / fog
	vec2 fog_uv = world_pos * 0.0015 + vec2(TIME * 0.015, TIME * 0.008);
	float fog = fbm(fog_uv);
	color += vec4(0.05, 0.12, 0.25, 0.0) * (fog * 0.45);

	// Outer border warning glow
	vec2 half_arena = arena_size * 0.5;
	vec2 dist_to_border = half_arena - abs(world_pos);
	float min_dist = min(dist_to_border.x, dist_to_border.y);
	if (min_dist < 80.0) {
		float border_factor = 1.0 - clamp(min_dist / 80.0, 0.0, 1.0);
		color = mix(color, border_color, border_factor * 0.95);
	}

	COLOR = color;
}
