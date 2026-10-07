shader_type canvas_item;
// Faceted XP crystals and pickups that bob and glint.
// INSTANCE_CUSTOM: x = kind (0 gem, 1 heart, 2 magnet, 3 bomb, 4 chest), y = phase

varying vec4 tint;
varying vec4 data;

void vertex() {
	tint = COLOR;
	data = INSTANCE_CUSTOM;
}

float sd_box(vec2 p, vec2 b) { vec2 d = abs(p) - b; return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0); }

void fragment() {
	vec2 p = (UV - 0.5) * 2.0 * 1.6;
	float t = TIME + data.y * 6.28;
	int kind = int(data.x + 0.5);
	float bob = sin(t * 3.0) * 0.12;
	float aa = fwidth(p.x) * 1.3;

	// shadow stays on the ground while the item bobs
	float sh = (1.0 - smoothstep(0.2, 0.7, length((p - vec2(0.0, 0.85)) * vec2(1.0, 2.6)))) * 0.45;
	vec2 q = p + vec2(0.0, 0.2 + bob);
	vec3 col = tint.rgb;
	float d;
	vec3 c;

	if (kind == 0) {
		// diamond crystal with two-tone facets
		d = (abs(q.x) * 1.0 + abs(q.y) * 0.72) - 0.72;
		float facet = q.x < 0.0 ? 1.15 : 0.75;
		facet *= q.y < 0.0 ? 1.1 : 0.85;
		c = col * facet;
		c += vec3(1.0) * smoothstep(0.25, 0.0, length(q - vec2(-0.18, -0.3))) * 0.8;
	} else if (kind == 1) {
		// heart (iq), flipped so it points down in canvas space
		vec2 h = vec2(abs(q.x), -q.y + 0.6) * 1.05;
		if (h.y + h.x > 1.0) {
			d = length(h - vec2(0.25, 0.75)) - 0.35355;
		} else {
			vec2 m = h - 0.5 * max(h.x + h.y, 0.0);
			d = sqrt(min(dot(h - vec2(0.0, 1.0), h - vec2(0.0, 1.0)), dot(m, m))) * sign(h.x - h.y);
		}
		d /= 1.05;
		c = col * (1.15 - (q.y + 0.4) * 0.35);
	} else if (kind == 2) {
		// magnet: horseshoe
		float ring = abs(length(q - vec2(0.0, -0.1)) - 0.45) - 0.16;
		ring = max(ring, q.y - 0.05 - 0.1);
		float legs = sd_box(vec2(abs(q.x) - 0.45, q.y - 0.25), vec2(0.16, 0.25));
		d = min(ring, legs);
		c = q.y > 0.3 ? vec3(0.9) : col;
	} else if (kind == 3) {
		// bomb: orb with a lit fuse
		d = length(q - vec2(0.0, 0.1)) - 0.58;
		c = vec3(0.16, 0.16, 0.22) * (1.2 - q.y * 0.5);
		float fuse = length(q - vec2(0.3, -0.62)) - 0.12;
		c = mix(c, col * 2.0, 1.0 - smoothstep(-aa, aa, fuse));
		d = min(d, fuse);
	} else {
		// chest: chunky crate with gold band
		d = sd_box(q, vec2(0.75, 0.55)) - 0.08;
		c = vec3(0.2, 0.24, 0.36);
		float band = step(abs(q.x), 0.12) + step(abs(q.y + 0.05), 0.08);
		c = mix(c, col, clamp(band, 0.0, 1.0));
		c *= 1.2 - (q.y + 0.6) * 0.4;
	}

	float inside = 1.0 - smoothstep(-aa, aa, d);
	float edge = smoothstep(-0.14, 0.0, d) * inside;
	c = mix(c, c * 0.45, edge * 0.7);
	float glint = pow(max(0.0, sin(t * 1.7)), 30.0);
	c += vec3(1.0) * glint * 0.5 * inside;
	float halo = exp(-max(d, 0.0) * 6.0) * (1.0 - inside) * 0.55;

	vec4 outc = vec4(0.0, 0.0, 0.02, sh);
	outc = mix(outc, vec4(col * 1.2, 1.0), halo);
	outc.a = max(outc.a, halo);
	outc = mix(outc, vec4(c, 1.0), inside);
	COLOR = vec4(outc.rgb, outc.a * tint.a);
}
