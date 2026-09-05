shader_type canvas_item;

uniform vec4 bg_color : source_color = vec4(0.03, 0.045, 0.08, 1.0);
uniform vec4 grid_color : source_color = vec4(0.08, 0.16, 0.32, 0.45);
uniform vec4 pulse_line_color : source_color = vec4(0.1, 0.85, 1.4, 0.95);
uniform float grid_scale = 56.0;

// Simple hash for procedural fog
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

void fragment() {
	vec2 uv = UV;
	vec2 screen_pixel = uv * vec2(1280.0, 720.0);

	// Isometric 2:1 projection with slow ambient drift
	vec2 drift = vec2(TIME * 12.0, TIME * 6.0);
	vec2 iso_pos = screen_pixel + drift;
	float u = (iso_pos.x * 0.5 + iso_pos.y) / grid_scale;
	float v = (iso_pos.x * 0.5 - iso_pos.y) / grid_scale;

	// Grid lines
	vec2 grid_uv = abs(fract(vec2(u, v) - 0.5) - 0.5) / fwidth(vec2(u, v));
	float line_intensity = 1.0 - min(min(grid_uv.x, grid_uv.y), 1.0);

	// Major power lines every 6 tiles
	vec2 major_uv = abs(fract(vec2(u / 6.0, v / 6.0) - 0.5) - 0.5) / fwidth(vec2(u / 6.0, v / 6.0));
	float major_intensity = 1.0 - min(min(major_uv.x, major_uv.y), 1.0);

	// Animated energy pulse wave
	float pulse = sin(TIME * 2.2 + (u + v) * 0.4) * 0.5 + 0.5;

	// Background color mix
	vec4 col = bg_color;
	col = mix(col, grid_color, line_intensity * 0.5);
	col = mix(col, pulse_line_color * pulse, major_intensity * 0.85);

	// Drifting cyber fog
	float fog = noise(uv * 4.0 + vec2(TIME * 0.05, TIME * 0.02));
	col += vec4(0.02, 0.08, 0.18, 0.0) * (fog * 0.35);

	// CRT Scanlines
	float scanline = sin(screen_pixel.y * 1.5) * 0.04;
	col.rgb -= scanline;

	// Vignette (darken edges)
	float vignette = uv.x * (1.0 - uv.x) * uv.y * (1.0 - uv.y) * 16.0;
	col.rgb *= clamp(pow(vignette, 0.35), 0.2, 1.0);

	COLOR = col;
}
