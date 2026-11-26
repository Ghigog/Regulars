shader_type spatial;
// A peg's head: the cel shading of every other solid, plus a band of colour from the
// forehead (top) and one from the chin (bottom) for what the guest feels. Heights are
// read from the mesh's own y, so the bands follow the head however the peg turns.
uniform vec3 skin : source_color = vec3(1.0);
uniform vec3 top_col : source_color = vec3(0.88, 0.27, 0.23);
uniform float top_amount = 0.0;
uniform float top_y = -1.0;   // the colour covers the head above this height
uniform vec3 bottom_col : source_color = vec3(0.5, 0.77, 0.34);
uniform float bottom_amount = 0.0;
uniform float bottom_y = 1.0; // and this one everything below it
uniform float line = 0.006;   // half the width of the soft line between, in metres
uniform float rough = 0.55;
varying float local_y;

void vertex() {
	local_y = VERTEX.y;
}

void fragment() {
	float over_top = smoothstep(top_y - line, top_y + line, local_y);
	float under_bottom = 1.0 - smoothstep(bottom_y - line, bottom_y + line, local_y);
	vec3 col = mix(skin, top_col, over_top * top_amount);
	col = mix(col, bottom_col, under_bottom * bottom_amount);
	ALBEDO = col;
	ROUGHNESS = rough;
	SPECULAR = 0.35;
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float steps = 0.50 * smoothstep(-0.03, 0.14, ndl)
			+ 0.23 * smoothstep(0.30, 0.50, ndl)
			+ 0.13 * smoothstep(0.68, 0.86, ndl);
	float ramp = mix(steps, 0.86 * smoothstep(-0.2, 0.9, ndl), 0.62);
	DIFFUSE_LIGHT += ramp * ATTENUATION * LIGHT_COLOR / PI;
	vec3 h = normalize(LIGHT + VIEW);
	float spec = smoothstep(0.90, 0.97, dot(NORMAL, h)) * (1.0 - rough) * 0.35;
	SPECULAR_LIGHT += spec * ATTENUATION * LIGHT_COLOR / PI;
}
