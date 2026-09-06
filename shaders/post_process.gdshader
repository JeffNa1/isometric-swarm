shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;

// 1. Shockwave Distortion Uniforms (2:1 Isometric)
uniform vec2 shockwave_center = vec2(0.5, 0.5); // Normalized screen UV
uniform float shockwave_progress : hint_range(0.0, 1.0) = 0.0;
uniform float shockwave_force = 0.045;
uniform float shockwave_size = 0.12;

// 2. Chromatic Aberration Uniforms
uniform float chromatic_aberration_intensity : hint_range(0.0, 0.06) = 0.0;

// 3. Impact Damage Vignette Uniforms
uniform vec4 damage_vignette_color : source_color = vec4(0.85, 0.05, 0.05, 1.0);
uniform float damage_vignette_intensity : hint_range(0.0, 1.0) = 0.0;

// 4. CRT Scanlines & Subtle Phosphor Glow
uniform bool crt_enabled = true;
uniform float scanline_intensity : hint_range(0.0, 0.15) = 0.020;

// 5. Cinematic Color Grading (Cyberpunk Teal & Amber)
uniform bool color_grading_enabled = true;
uniform float color_grade_mix : hint_range(0.0, 1.0) = 0.25;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 aspect_ratio = vec2(1.7778, 1.0);

	// --- A. SHOCKWAVE DISTORTION (2:1 Isometric Warp) ---
	if (shockwave_progress > 0.0 && shockwave_progress < 1.0) {
		vec2 diff = (uv - shockwave_center) * aspect_ratio;
		diff.y *= 2.0; // Isometric diamond/ellipse distortion
		float dist = length(diff);

		float current_radius = shockwave_progress * 1.3;
		if (dist <= current_radius + shockwave_size && dist >= current_radius - shockwave_size) {
			float wave_dist = (dist - current_radius) / shockwave_size;
			float wave_amp = (1.0 - cos(wave_dist * PI)) * 0.5;
			float fade = 1.0 - shockwave_progress;
			vec2 displace_dir = normalize(diff);
			uv -= displace_dir * wave_amp * shockwave_force * fade;
		}
	}

	// --- B. CHROMATIC ABERRATION PULSE ---
	vec4 col;
	if (chromatic_aberration_intensity > 0.0001) {
		vec2 shift = (uv - 0.5) * chromatic_aberration_intensity;
		float r = texture(screen_texture, uv - shift).r;
		float g = texture(screen_texture, uv).g;
		float b = texture(screen_texture, uv + shift).b;
		col = vec4(r, g, b, 1.0);
	} else {
		col = texture(screen_texture, uv);
	}

	// --- C. CONTACT AMBIENT OCCLUSION (Micro-Edge Contrast) ---
	vec2 px_step = vec2(1.0 / 1280.0, 1.0 / 720.0);
	vec3 sample_u = texture(screen_texture, uv + vec2(0.0, -px_step.y)).rgb;
	vec3 sample_d = texture(screen_texture, uv + vec2(0.0, px_step.y)).rgb;
	vec3 sample_l = texture(screen_texture, uv + vec2(-px_step.x, 0.0)).rgb;
	vec3 sample_r = texture(screen_texture, uv + vec2(px_step.x, 0.0)).rgb;
	float lum_center = dot(col.rgb, vec3(0.299, 0.587, 0.114));
	float lum_avg = (dot(sample_u, vec3(0.299, 0.587, 0.114)) +
	                 dot(sample_d, vec3(0.299, 0.587, 0.114)) +
	                 dot(sample_l, vec3(0.299, 0.587, 0.114)) +
	                 dot(sample_r, vec3(0.299, 0.587, 0.114))) * 0.25;
	float edge_diff = clamp(lum_avg - lum_center, 0.0, 1.0);
	col.rgb -= vec3(edge_diff * 0.15); // Subtle contact shadowing

	// --- D. CYBERPUNK COLOR GRADING (Teal Shadows, Amber Highlights) ---
	if (color_grading_enabled) {
		float luma = clamp(lum_center, 0.0, 1.0);
		// Cool deep cyan in darks
		vec3 shadows_tint = vec3(0.02, 0.07, 0.12);
		// Warm vibrant gold in highlights
		vec3 highlights_tint = vec3(1.08, 1.02, 0.94);
		vec3 graded = mix(col.rgb + shadows_tint * (1.0 - luma), col.rgb * highlights_tint, luma);
		col.rgb = mix(col.rgb, graded, color_grade_mix);
	}

	// --- E. CRT SCANLINES ---
	if (crt_enabled) {
		float scanline = sin(uv.y * 720.0 * PI) * scanline_intensity;
		col.rgb -= scanline;
	}

	// --- F. IMPACT DAMAGE VIGNETTE ---
	if (damage_vignette_intensity > 0.001) {
		vec2 v_uv = (uv - 0.5) * aspect_ratio;
		float d = length(v_uv);
		float vig = smoothstep(0.38, 0.95, d) * damage_vignette_intensity;
		col.rgb = mix(col.rgb, damage_vignette_color.rgb, vig * damage_vignette_color.a);
	}

	COLOR = col;
}
