shader_type spatial;
// The one material for everything solid: soft, finely stepped cel shading
// (style guide: toy diorama, sheet 1). Cast shadows stay smooth.
uniform vec3 albedo : source_color = vec3(1.0);
uniform float emit = 0.0;
uniform float rough = 0.9;
uniform float grain = 0.0;
varying vec3 local_pos;
varying vec3 local_nrm;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	local_pos = VERTEX;
	local_nrm = NORMAL;
}

void fragment() {
	vec3 col = albedo;
	if (grain > 0.0) {
		// Long, fine streaks running along the piece's longest flat direction.
		vec3 a = abs(local_nrm);
		vec2 uv = a.y > 0.6 ? local_pos.xz : (a.x > a.z ? local_pos.zy : local_pos.xy);
		float g = vnoise(vec2(uv.x * 1.6, uv.y * 46.0)) * 0.6 + vnoise(vec2(uv.x * 4.0, uv.y * 110.0)) * 0.4;
		col *= 1.0 - grain * 0.11 * smoothstep(0.35, 0.8, g);
	}
	ALBEDO = col;
	ROUGHNESS = rough;
	SPECULAR = 0.35;
	EMISSION = albedo * emit;
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	// Three soft-edged steps: core shadow, mid tone, light.
	float steps = 0.50 * smoothstep(-0.03, 0.14, ndl)
			+ 0.23 * smoothstep(0.30, 0.50, ndl)
			+ 0.13 * smoothstep(0.68, 0.86, ndl);
	// Blended with a plain soft falloff, so the steps read as gentle bands.
	float ramp = mix(steps, 0.86 * smoothstep(-0.2, 0.9, ndl), 0.62);
	DIFFUSE_LIGHT += ramp * ATTENUATION * LIGHT_COLOR / PI;
	// A small, soft toy highlight on glossier surfaces.
	vec3 h = normalize(LIGHT + VIEW);
	float spec = smoothstep(0.90, 0.97, dot(NORMAL, h)) * (1.0 - rough) * 0.35;
	SPECULAR_LIGHT += spec * ATTENUATION * LIGHT_COLOR / PI;
}
