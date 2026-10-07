shader_type canvas_item;
// Draws every swarm enemy from one MultiMesh using signed distance fields.
// INSTANCE_CUSTOM: x = type, y = facing angle, z = hit flash (0..1), w = anim phase.
// Quad spans PAD body radii, so the body is the unit circle in local space.

const float PAD = 1.7;

varying vec4 tint;
varying vec4 data;

void vertex() {
	tint = COLOR;
	data = INSTANCE_CUSTOM;
}

mat2 rot(float a) { float c = cos(a); float s = sin(a); return mat2(vec2(c, s), vec2(-s, c)); }

float sd_hex(vec2 p, float r) {
	const vec3 k = vec3(-0.866025404, 0.5, 0.577350269);
	p = abs(p);
	p -= 2.0 * min(dot(k.xy, p), 0.0) * k.xy;
	p -= vec2(clamp(p.x, -k.z * r, k.z * r), r);
	return length(p) * sign(p.y);
}

// signed distance to a triangle (iq)
float sd_tri(vec2 p, vec2 p0, vec2 p1, vec2 p2) {
	vec2 e0 = p1 - p0, e1 = p2 - p1, e2 = p0 - p2;
	vec2 v0 = p - p0, v1 = p - p1, v2 = p - p2;
	vec2 pq0 = v0 - e0 * clamp(dot(v0, e0) / dot(e0, e0), 0.0, 1.0);
	vec2 pq1 = v1 - e1 * clamp(dot(v1, e1) / dot(e1, e1), 0.0, 1.0);
	vec2 pq2 = v2 - e2 * clamp(dot(v2, e2) / dot(e2, e2), 0.0, 1.0);
	float sg = sign(e0.x * e2.y - e0.y * e2.x);
	vec2 d = min(min(vec2(dot(pq0, pq0), sg * (v0.x * e0.y - v0.y * e0.x)),
	                 vec2(dot(pq1, pq1), sg * (v1.x * e1.y - v1.y * e1.x))),
	                 vec2(dot(pq2, pq2), sg * (v2.x * e2.y - v2.y * e2.x)));
	return -sqrt(d.x) * sign(d.y);
}

float sd_seg(vec2 p, vec2 a, vec2 b) {
	vec2 pa = p - a, ba = b - a;
	float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
	return length(pa - ba * h);
}

void fragment() {
	vec2 p = (UV - 0.5) * 2.0 * PAD;
	int type = int(data.x + 0.5);
	float ang = data.y;
	float flash = data.z;
	float ph = data.w;
	float t = TIME * 1.0 + ph * 6.2831;
	float aa = fwidth(p.x) * 1.25;

	// drop shadow, offset down-right to sell the isometric light direction
	vec2 sp = (p - vec2(0.12, 0.5)) * vec2(1.0, 1.9);
	float shadow = (1.0 - smoothstep(0.55, 1.0, length(sp))) * 0.42;

	vec2 q = rot(-ang) * p;   // local space, facing +x
	float d = 1.0;            // body sdf
	vec3 base = tint.rgb;
	vec3 emit = vec3(0.0);
	float shade_mul = 1.0;

	if (type == 0 || type == 5) {
		// MITE / ELITE: segmented beetle with skittering legs and glowing eyes
		float wig = sin(t * 22.0) * 0.08;
		vec2 b = q * vec2(1.0, 1.25);
		d = length(b) - 0.86;
		float head = length((q - vec2(0.6, 0.0)) * vec2(1.4, 1.3)) - 0.45;
		d = min(d, head);
		float legs = 1.0;
		for (int i = -1; i <= 1; i++) {
			float x = float(i) * 0.38 + (i == 0 ? wig : -wig);
			legs = min(legs, sd_seg(vec2(q.x, abs(q.y)), vec2(x, 0.45), vec2(x - 0.12 + wig, 0.98)));
		}
		float leg_mask = 1.0 - smoothstep(0.07 - aa, 0.07 + aa, legs);
		float eyes = length(vec2(q.x - 0.72, abs(q.y) - 0.17)) - 0.11;
		emit += vec3(1.0, 0.95, 0.9) * (1.0 - smoothstep(-aa, aa, eyes)) * 1.2;
		// carapace split line
		float split = smoothstep(0.035 + aa, 0.035, abs(q.y)) * step(q.x, 0.25) * step(-0.7, q.x);
		shade_mul -= split * 0.35;
		// legs drawn as darker body colour under the shell
		float body_in = 1.0 - smoothstep(-aa, aa, d);
		if (leg_mask > 0.0 && body_in < 0.5) {
			d = min(d, -0.01);
			shade_mul = 0.55;
		}
		if (type == 5) {
			float ring = abs(length(p) - 1.32 - 0.04 * sin(t * 3.0)) - 0.035;
			emit += tint.rgb * (1.0 - smoothstep(-aa, aa, ring)) * 1.5;
		}
	} else if (type == 1) {
		// DART: notched arrowhead with an exhaust flare
		float outer = sd_tri(q, vec2(1.05, 0.0), vec2(-0.75, 0.68), vec2(-0.75, -0.68));
		float notch = sd_tri(q, vec2(-0.25, 0.0), vec2(-0.9, 0.5), vec2(-0.9, -0.5));
		d = max(outer - 0.04, -notch);
		float flare = length((q - vec2(-0.55, 0.0)) * vec2(1.3, 2.4));
		emit += tint.rgb * exp(-flare * flare * 6.0) * (0.8 + 0.3 * sin(t * 40.0));
		float stripe = smoothstep(0.06 + aa, 0.06, abs(q.y)) * step(-0.1, q.x) * step(q.x, 0.75);
		emit += vec3(1.0, 0.95, 0.8) * stripe * 0.5;
	} else if (type == 2) {
		// BRUTE: armoured hex shell with molten seams
		d = sd_hex(rot(0.2) * q, 0.82) - 0.1;
		float inner = abs(sd_hex(rot(0.2) * q, 0.45)) - 0.03;
		float spokes = 1.0;
		for (int i = 0; i < 3; i++) {
			vec2 r = rot(float(i) * 1.0472 + 0.2) * q;
			spokes = min(spokes, abs(r.y) - 0.02 + step(abs(r.x), 0.45) * 2.0);
		}
		float seams = min(inner, spokes);
		float hot = (1.0 - smoothstep(-aa, aa * 2.0, seams)) * (1.0 - smoothstep(-0.12, -0.04, d));
		emit += mix(tint.rgb, vec3(1.0, 0.85, 0.4), 0.5) * hot * (0.7 + 0.3 * sin(t * 4.0));
		shade_mul -= hot * 0.3;
	} else if (type == 3) {
		// SPITTER: bulbous sac with a glowing acid core and a mouth
		float wob = 0.04 * sin(atan(q.y, q.x) * 5.0 + t * 5.0);
		d = length(q) - 0.84 - wob;
		float core = length(q + vec2(0.12, 0.0)) - 0.4 - 0.05 * sin(t * 6.0);
		emit += vec3(0.8, 1.0, 0.35) * (1.0 - smoothstep(-0.25, 0.05, core)) * 1.1;
		float mouth = length((q - vec2(0.7, 0.0)) * vec2(1.6, 1.0)) - 0.2;
		shade_mul -= (1.0 - smoothstep(-aa, aa, mouth)) * 0.6;
	} else if (type == 4) {
		// BOMBER: spiked mine with a heartbeat core (faster when fusing)
		float a = atan(q.y, q.x);
		d = length(q) - (0.72 + 0.16 * pow(abs(cos(a * 3.0 + t * 0.6)), 10.0));
		float beat = 0.5 + 0.5 * sin(t * (flash > 0.0 ? 30.0 : 6.0));
		float core = length(q) - 0.36;
		emit += vec3(1.0, 0.6, 0.15) * (1.0 - smoothstep(-0.2, 0.08, core)) * (0.6 + 0.9 * beat);
		base *= 0.55;
	}

	float inside = 1.0 - smoothstep(-aa, aa, d);
	// fake dome lighting: sphere normal from local position
	vec2 n2 = clamp(p, -1.0, 1.0);
	vec3 n = normalize(vec3(n2, sqrt(max(0.0, 1.0 - dot(n2, n2))) + 0.25));
	float lit = clamp(dot(n, normalize(vec3(-0.45, -0.7, 0.75))), 0.0, 1.0);
	vec3 col = base * (0.5 + 0.85 * lit) * shade_mul;
	// dark rim for readability against the floor
	float rim = smoothstep(-0.11, -0.01, d);
	col = mix(col, base * 0.3, rim * 0.75);
	// specular glint
	col += vec3(1.0) * pow(lit, 18.0) * 0.35;
	col += emit;
	col = mix(col, vec3(1.0), flash * (type == 4 ? 0.5 : 0.85));

	float glow_a = clamp(length(emit), 0.0, 1.0);
	vec4 body = vec4(col, inside);
	vec4 sh = vec4(0.0, 0.0, 0.02, shadow);
	vec4 outc = mix(sh, body, body.a);
	outc.a = max(body.a, sh.a * (1.0 - body.a));
	// emissive bits outside the body (eyes, flares, rings)
	outc.rgb = mix(outc.rgb, emit, glow_a * (1.0 - inside));
	outc.a = max(outc.a, glow_a * (1.0 - inside));
	COLOR = vec4(outc.rgb, outc.a * tint.a);
}
