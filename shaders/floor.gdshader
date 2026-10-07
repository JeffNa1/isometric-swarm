shader_type canvas_item;
// Calm isometric deck: 2:1 diamond tiles, low-contrast plates, soft seams,
// and the occasional slow energy pulse running along the grid.

uniform float tile = 96.0;
uniform vec4 base_a : source_color = vec4(0.055, 0.075, 0.125, 1.0);
uniform vec4 base_b : source_color = vec4(0.065, 0.088, 0.145, 1.0);
uniform vec4 seam : source_color = vec4(0.02, 0.03, 0.055, 1.0);
uniform vec4 glow : source_color = vec4(0.25, 0.85, 1.0, 1.0);
uniform vec2 player_pos = vec2(0.0);
uniform vec2 offset = vec2(0.0);

varying vec2 world;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy + offset;
}

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void fragment() {
	// isometric basis: rotate 45 deg and squash y by 2
	vec2 iso = vec2(world.x / tile + world.y * 2.0 / tile, -world.x / tile + world.y * 2.0 / tile) * 0.5;
	vec2 cell = floor(iso);
	vec2 f = fract(iso);
	float h = hash(cell);
	float h2 = hash(cell + 17.0);

	// big 3x3 plates make the floor read as panels rather than a checkerboard
	vec2 plate = floor(cell / 3.0);
	float ph = hash(plate + 3.1);

	vec3 col = mix(base_a.rgb, base_b.rgb, ph * 0.8 + h * 0.2);

	// gentle top-left lighting across each tile for depth
	col *= 0.94 + 0.1 * (1.0 - f.x) * (1.0 - f.y);

	// seams: thin between tiles, thicker between plates
	vec2 e = min(f, 1.0 - f);
	float aa = fwidth(iso.x) * 1.2;
	float thin = 1.0 - smoothstep(0.0, aa * 1.2, min(e.x, e.y));
	vec2 pf = fract(cell / 3.0 + f / 3.0);
	vec2 pe = min(pf, 1.0 - pf);
	float thick = 1.0 - smoothstep(0.0, aa * 2.0 / 3.0 + 0.004, min(pe.x, pe.y));
	col = mix(col, seam.rgb, thin * 0.45 + thick * 0.7);

	// rare inset light tiles
	if (h2 > 0.965) {
		float inner = smoothstep(0.18, 0.2, min(e.x, e.y));
		float pulse = 0.5 + 0.5 * sin(TIME * 1.3 + h * 40.0);
		col += glow.rgb * 0.06 * inner * (0.6 + 0.4 * pulse);
		float edge = smoothstep(0.17, 0.185, min(e.x, e.y)) * (1.0 - smoothstep(0.185, 0.2, min(e.x, e.y)));
		col += glow.rgb * 0.12 * edge;
	}

	// slow energy pulse travelling along plate seams
	float wave = sin((plate.x + plate.y) * 0.9 - TIME * 1.1);
	col += glow.rgb * thick * smoothstep(0.92, 1.0, wave) * 0.22;

	// subtle light pool around the player
	float d = length((world - player_pos) * vec2(1.0, 2.0));
	col += glow.rgb * 0.035 * exp(-d * d / 90000.0);

	COLOR = vec4(col, 1.0);
}
