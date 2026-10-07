shader_type canvas_item;
render_mode blend_add;
// Additive soft glow sprite: a hot white core inside a coloured halo.
// Stretch the instance transform to get bolts and streaks.
// INSTANCE_CUSTOM.x = core size (0..1), .y = halo strength

varying vec4 tint;
varying vec4 data;

void vertex() {
	tint = COLOR;
	data = INSTANCE_CUSTOM;
}

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float r = length(p);
	float core_sz = data.x <= 0.0 ? 0.35 : data.x;
	float core = 1.0 - smoothstep(core_sz * 0.55, core_sz, r);
	float halo = exp(-r * r * 4.5) * (data.y <= 0.0 ? 0.7 : data.y);
	halo *= 1.0 - smoothstep(0.8, 1.0, r);
	vec3 col = tint.rgb * halo + mix(tint.rgb, vec3(1.0), 0.75) * core;
	COLOR = vec4(col * tint.a, 1.0);
}
