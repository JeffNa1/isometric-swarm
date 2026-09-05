shader_type canvas_item;

uniform vec4 bg_color : source_color = vec4(0.06, 0.07, 0.10, 1.0);
uniform vec4 line_color : source_color = vec4(0.12, 0.16, 0.24, 0.7);
uniform vec4 major_line_color : source_color = vec4(0.22, 0.30, 0.45, 0.9);
uniform vec4 border_color : source_color = vec4(0.3, 0.7, 1.0, 0.9);
uniform float grid_scale : hint_range(16.0, 256.0) = 64.0;
uniform vec2 arena_size = vec2(10000.0, 10000.0);

varying vec2 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	// 2:1 isometric coordinates
	// u = (x / 2.0 + y) / grid_scale
	// v = (x / 2.0 - y) / grid_scale
	float u = (world_pos.x * 0.5 + world_pos.y) / grid_scale;
	float v = (world_pos.x * 0.5 - world_pos.y) / grid_scale;

	// Grid line thickness calculation
	vec2 grid_uv = abs(fract(vec2(u, v) - 0.5) - 0.5) / fwidth(vec2(u, v));
	float line_intensity = 1.0 - min(min(grid_uv.x, grid_uv.y), 1.0);

	// Major lines every 8 tiles
	vec2 major_uv = abs(fract(vec2(u / 8.0, v / 8.0) - 0.5) - 0.5) / fwidth(vec2(u / 8.0, v / 8.0));
	float major_intensity = 1.0 - min(min(major_uv.x, major_uv.y), 1.0);

	vec4 color = bg_color;
	color = mix(color, line_color, line_intensity * 0.6);
	color = mix(color, major_line_color, major_intensity * 0.9);

	// Outer border warning glow
	vec2 half_arena = arena_size * 0.5;
	vec2 dist_to_border = half_arena - abs(world_pos);
	float min_dist = min(dist_to_border.x, dist_to_border.y);
	if (min_dist < 60.0) {
		float border_factor = 1.0 - clamp(min_dist / 60.0, 0.0, 1.0);
		color = mix(color, border_color, border_factor * 0.85);
	}

	COLOR = color;
}
