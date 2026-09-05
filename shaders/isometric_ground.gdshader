shader_type canvas_item;

// --- COLOR PALETTE & UNIFORMS ---
uniform vec4 bg_color : source_color = vec4(0.04, 0.05, 0.09, 1.0);
uniform vec4 line_color : source_color = vec4(0.09, 0.15, 0.28, 0.85);
uniform vec4 major_line_color : source_color = vec4(0.20, 0.65, 1.40, 1.4); // HDR Plasma Blue
uniform vec4 border_color : source_color = vec4(0.35, 0.95, 1.80, 1.6);     // HDR Containment Barrier
uniform vec4 accent_neon_color : source_color = vec4(0.15, 0.85, 1.25, 1.3); // HDR Cyan Neon
uniform vec4 hazard_color : source_color = vec4(1.4, 0.95, 0.15, 1.0);       // HDR Caution Amber/Yellow
uniform vec4 vent_glow_color : source_color = vec4(1.6, 0.42, 0.10, 1.2);    // HDR Thermal Orange/Red
uniform vec4 void_nebula_color : source_color = vec4(0.05, 0.02, 0.12, 1.0); // Deep Space Abyss

uniform float grid_scale : hint_range(16.0, 256.0) = 64.0;
uniform vec2 arena_size = vec2(10000.0, 10000.0);

varying vec2 world_pos;

// --- FAST PROCEDURAL HASH & NOISE FUNCTIONS ---
float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float hash2(vec2 p) {
	return fract(sin(dot(p, vec2(269.5, 183.3))) * 43758.5453123);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(hash(i + vec2(0.0, 0.0)), hash(i + vec2(1.0, 0.0)), u.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x),
		u.y
	);
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
	// -------------------------------------------------------------
	// 1. ISOMETRIC 2:1 COORDINATE SYSTEM (True Diamond Tiles)
	// -------------------------------------------------------------
	float u = (world_pos.x * 0.5 + world_pos.y) / grid_scale;
	float v = (world_pos.x * 0.5 - world_pos.y) / grid_scale;
	vec2 iso_coords = vec2(u, v);
	vec2 tile_id = floor(iso_coords);
	vec2 cell_uv = fract(iso_coords); // [0.0, 1.0] within diamond tile

	// Anti-aliased derivatives
	vec2 fw = max(fwidth(iso_coords), vec2(0.001));

	// Distance to tile edges (seams)
	vec2 dist_to_seam = min(cell_uv, 1.0 - cell_uv);
	float min_dist_seam = min(dist_to_seam.x, dist_to_seam.y);

	// Pseudo-random identity for this specific isometric tile
	float t_rand = hash(tile_id);
	float t_rand2 = hash2(tile_id);

	// -------------------------------------------------------------
	// 2. 3D BEVEL LIGHTING & AMBIENT OCCLUSION (Tactile Depth)
	// -------------------------------------------------------------
	// Isometric light direction (Top-Left key light):
	// High bevel highlight on top edges (small u, small v)
	// Ambient shadow on bottom edges (large u, large v)
	float bevel_highlight = smoothstep(0.08, 0.01, cell_uv.x) * 0.16 + smoothstep(0.08, 0.01, cell_uv.y) * 0.16;
	float bevel_shadow = smoothstep(0.92, 0.99, cell_uv.x) * 0.22 + smoothstep(0.92, 0.99, cell_uv.y) * 0.22;

	// Mechanical Corner Rivets/Bolts
	vec2 rivet_uv = abs(cell_uv - 0.5);
	float dist_to_bolt = length(rivet_uv - vec2(0.40, 0.40));
	float bolt_head = smoothstep(0.045, 0.02, dist_to_bolt);
	float bolt_specular = smoothstep(0.025, 0.01, length(rivet_uv - vec2(0.39, 0.39)));

	// Base plate color with subtle metallic grain
	vec4 tile_base_col = bg_color;
	float grain = (hash(floor(world_pos * 0.2)) - 0.5) * 0.035;
	tile_base_col += vec4(grain, grain, grain * 1.4, 0.0);

	// Apply 3D Bevel shading
	tile_base_col.rgb += vec3(bevel_highlight) * 0.7;
	tile_base_col.rgb -= vec3(bevel_shadow) * 0.5;

	// Apply Bolt Head indentations
	if (bolt_head > 0.0) {
		tile_base_col.rgb = mix(tile_base_col.rgb, vec3(0.02, 0.03, 0.05), bolt_head * 0.85);
		tile_base_col.rgb += vec3(0.25, 0.35, 0.45) * bolt_specular;
	}

	// -------------------------------------------------------------
	// 3. PROCEDURAL TILE VARIATIONS
	// -------------------------------------------------------------
	if (t_rand < 0.62) {
		// Type A: Standard Reinforced Armor Deck with Inner Recessed Border
		vec2 inner_seam = abs(cell_uv - 0.5);
		float inner_groove = smoothstep(0.015, 0.0, abs(max(inner_seam.x, inner_seam.y) - 0.32));
		tile_base_col.rgb -= vec3(0.04, 0.05, 0.07) * inner_groove;

		// Tread lines
		if (t_rand > 0.42) {
			float tread = smoothstep(0.1, 0.0, abs(fract((cell_uv.x - cell_uv.y) * 4.0) - 0.5) - 0.35);
			tile_base_col.rgb += vec3(0.02, 0.025, 0.035) * tread;
		}
	} else if (t_rand < 0.78) {
		// Type B: Heavy Ventilation Grate with Thermal Sub-Floor Glow
		float grate_slats = smoothstep(0.12, 0.0, abs(fract(cell_uv.x * 7.0) - 0.5) - 0.28);
		// Thermal glow pulsing under the slats
		float vent_pulse = 0.7 + 0.3 * sin(TIME * 3.5 + t_rand * 6.28);
		vec3 heat_core = vent_glow_color.rgb * vent_pulse;

		// Mask grate within inner panel
		float inner_mask = step(cell_uv.x, 0.88) * step(0.12, cell_uv.x) * step(cell_uv.y, 0.88) * step(0.12, cell_uv.y);
		vec3 grate_col = mix(heat_core, vec3(0.02, 0.03, 0.04), grate_slats);
		tile_base_col.rgb = mix(tile_base_col.rgb, grate_col, inner_mask * 0.9);
	} else if (t_rand < 0.90) {
		// Type C: Cybernetic Circuit Motherboard
		float trace_x = smoothstep(0.035, 0.0, abs(cell_uv.x - 0.5));
		float trace_y = smoothstep(0.035, 0.0, abs(cell_uv.y - 0.5));
		float trace_diag = smoothstep(0.035, 0.0, abs(cell_uv.x + cell_uv.y - 1.0));
		float traces = max(max(trace_x, trace_y), trace_diag * step(0.2, t_rand2));

		float circuit_pulse = 0.8 + 0.4 * sin(TIME * 4.0 + (tile_id.x + tile_id.y) * 1.3);
		vec3 circuit_glow = accent_neon_color.rgb * circuit_pulse;

		// Chip core at center
		float chip = step(length(cell_uv - 0.5), 0.12);
		tile_base_col.rgb = mix(tile_base_col.rgb, vec3(0.03, 0.04, 0.06), chip);
		tile_base_col.rgb = mix(tile_base_col.rgb, circuit_glow, traces * 0.85);
		tile_base_col.rgb += circuit_glow * chip * (0.5 + 0.5 * sin(TIME * 6.0));
	} else if (t_rand < 0.97) {
		// Type D: Hazard Caution Striping (Industrial Safety Chevron)
		float stripe = step(0.5, fract((cell_uv.x + cell_uv.y) * 4.0));
		vec3 hazard_band = mix(vec3(0.04, 0.04, 0.05), hazard_color.rgb, stripe);
		float hazard_mask = step(cell_uv.x, 0.86) * step(0.14, cell_uv.x) * step(cell_uv.y, 0.86) * step(0.14, cell_uv.y);
		tile_base_col.rgb = mix(tile_base_col.rgb, hazard_band, hazard_mask * 0.85);
	} else {
		// Type E: Overheated Reactor Crust (Glowing Energy Fractures)
		float fracture = smoothstep(0.04, 0.0, abs(noise(cell_uv * 8.0 + tile_id) - 0.5));
		vec3 fracture_glow = vec3(1.8, 0.3, 1.2) * (0.8 + 0.4 * sin(TIME * 5.0 + t_rand * 10.0));
		tile_base_col.rgb = mix(tile_base_col.rgb, fracture_glow, fracture * 0.9);
	}

	// -------------------------------------------------------------
	// 4. NEON ENERGY GRID & RECESSED GROOVE CHANNELS
	// -------------------------------------------------------------
	// Deep groove shadow along seams
	float groove_width = 0.065;
	float groove_shadow = smoothstep(groove_width, 0.0, min_dist_seam);
	tile_base_col.rgb = mix(tile_base_col.rgb, vec3(0.015, 0.02, 0.035), groove_shadow * 0.95);

	// Primary Anti-Aliased Grid Line
	vec2 seam_aa = dist_to_seam / fw;
	float line_intensity = 1.0 - clamp(min(seam_aa.x, seam_aa.y), 0.0, 1.0);
	tile_base_col = mix(tile_base_col, line_color, line_intensity * 0.65);

	// Major Energy Superhighways (Every 8 tiles)
	vec2 major_dist = min(fract(iso_coords / 8.0), 1.0 - fract(iso_coords / 8.0));
	vec2 major_aa = major_dist / (fw / 8.0);
	float major_line = 1.0 - clamp(min(major_aa.x, major_aa.y), 0.0, 1.0);

	// Traveling Plasma Pulse along major lines
	float plasma_wave = pow(max(0.0, sin(TIME * 2.8 + (u + v) * 0.4)), 10.0) * 2.6;
	float plasma_ambient = 0.75 + 0.25 * sin(TIME * 2.0 + (u - v) * 0.2);
	vec4 active_major_col = major_line_color * (plasma_ambient + plasma_wave);
	tile_base_col = mix(tile_base_col, active_major_col, major_line * 0.95);

	// Junction Power Nodes at Vertices (where 4 tiles meet)
	float vertex_dist = length(dist_to_seam);
	float vertex_node = smoothstep(0.12, 0.02, vertex_dist);
	if (vertex_node > 0.0) {
		float node_pulse = 0.8 + 0.3 * sin(TIME * 3.5 + (tile_id.x + tile_id.y) * 0.6);
		vec3 node_col = mix(accent_neon_color.rgb, major_line_color.rgb, 0.5) * (node_pulse * 1.3);
		tile_base_col.rgb = mix(tile_base_col.rgb, node_col, vertex_node * 0.92);
	}

	// -------------------------------------------------------------
	// 5. CENTRAL CITADEL REACTOR DECALS (Around Origin)
	// -------------------------------------------------------------
	// Isometric circular reactor rings:
	// In isometric projection, world circles map to ellipse (x * 0.5, y)
	vec2 iso_radial_vec = vec2(world_pos.x * 0.5, world_pos.y);
	float r_iso = length(iso_radial_vec);

	// Concentric Reactor Rings at radius 160, 320, 520, 780
	float ring1 = smoothstep(7.0, 0.0, abs(r_iso - 160.0));
	float ring2 = smoothstep(8.0, 0.0, abs(r_iso - 320.0));
	float ring3 = smoothstep(10.0, 0.0, abs(r_iso - 520.0));
	float ring4 = smoothstep(12.0, 0.0, abs(r_iso - 780.0));
	float all_rings = max(max(ring1, ring2), max(ring3, ring4));

	// Rotating radar beam in central core
	float angle_iso = atan(iso_radial_vec.y, iso_radial_vec.x);
	float radar_sweep = pow(max(0.0, cos(angle_iso - TIME * 1.5)), 12.0) * step(r_iso, 780.0);

	if (all_rings > 0.0 || radar_sweep > 0.0) {
		vec3 reactor_glow = accent_neon_color.rgb * (all_rings * 1.5 + radar_sweep * 0.7);
		tile_base_col.rgb = mix(tile_base_col.rgb, tile_base_col.rgb + reactor_glow, 0.85);
	}

	// -------------------------------------------------------------
	// 6. ATMOSPHERIC ISOMETRIC FOG / STEAM
	// -------------------------------------------------------------
	vec2 fog_coords1 = vec2(u * 0.04 + TIME * 0.012, v * 0.04 + TIME * 0.008);
	vec2 fog_coords2 = vec2(u * 0.08 - TIME * 0.016, v * 0.08 + TIME * 0.014);
	float fog = fbm(fog_coords1) * 0.65 + fbm(fog_coords2) * 0.35;
	tile_base_col.rgb += vec3(0.04, 0.09, 0.18) * (fog * 0.35);

	// -------------------------------------------------------------
	// 7. OUTER VOID CHASM & HOLOGRAPHIC CONTAINMENT BARRIER
	// -------------------------------------------------------------
	vec2 half_arena = arena_size * 0.5;
	vec2 dist_border = half_arena - abs(world_pos);
	float min_dist_border = min(dist_border.x, dist_border.y);

	// Beyond 4650px: The platform breaks into fractured floating fragments
	if (min_dist_border < 350.0) {
		float border_t = 1.0 - clamp(min_dist_border / 350.0, 0.0, 1.0);
		// Fractured platform edge noise
		float crack_noise = fbm(world_pos * 0.006 + vec2(42.0));
		float void_threshold = mix(0.15, 0.85, pow(border_t, 1.6));

		if (crack_noise < void_threshold) {
			// DEEP SPACE ABYSS VOID
			vec2 star_uv = world_pos * 0.002;
			float star = step(0.985, hash(floor(star_uv * 120.0)));
			float twinkle = 0.5 + 0.5 * sin(TIME * 6.0 + hash2(floor(star_uv * 120.0)) * 6.28);

			// Space Nebula cloud
			vec3 nebula = void_nebula_color.rgb * (0.8 + 0.4 * fbm(star_uv * 2.0));
			vec3 space_col = nebula + vec3(1.2, 1.3, 1.5) * (star * twinkle * 1.5);

			// Floating platform edge rim lighting
			tile_base_col.rgb = space_col;
		} else {
			// Edge hazard glow
			tile_base_col.rgb = mix(tile_base_col.rgb, border_color.rgb * 0.6, border_t * 0.45);
		}
	}

	// Holographic Forcefield Laser Barrier right near physical collision border
	if (min_dist_border < 140.0) {
		float barrier_norm = 1.0 - clamp(min_dist_border / 140.0, 0.0, 1.0);
		// Hexagonal / grid scanline pattern
		float scanline = 0.75 + 0.25 * sin(world_pos.x * 0.2 + world_pos.y * 0.2 + TIME * 8.0);
		float electric_spark = pow(max(0.0, sin(TIME * 16.0 + world_pos.x * 0.05)), 16.0) * 1.8;
		vec4 barrier_pulse = border_color * (barrier_norm * scanline + electric_spark);
		tile_base_col = mix(tile_base_col, barrier_pulse, barrier_norm * 0.9);
	}

	COLOR = tile_base_col;
}
