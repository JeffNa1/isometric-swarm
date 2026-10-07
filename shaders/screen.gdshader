shader_type canvas_item;
// Light screen-space finish: soft vignette plus a red edge when hurt.
// Deliberately restrained - no chromatic aberration, no warping.

uniform float hurt = 0.0;
uniform float low_hp = 0.0;
uniform float flash = 0.0;

void fragment() {
	vec2 uv = SCREEN_UV - 0.5;
	uv.x *= SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	float r = length(uv);
	float vig = smoothstep(0.45, 1.05, r) * 0.55;
	float pulse = 0.6 + 0.4 * sin(TIME * 5.0);
	float red = smoothstep(0.3, 0.95, r) * (hurt * 0.45 + low_hp * 0.25 * pulse);
	vec3 col = mix(vec3(0.0), vec3(0.85, 0.05, 0.12), red / max(vig + red, 0.001));
	float a = clamp(vig + red, 0.0, 1.0);
	col = mix(col, vec3(1.0), flash);
	a = max(a, flash);
	COLOR = vec4(col, a);
}
