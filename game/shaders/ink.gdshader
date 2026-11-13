shader_type spatial;
render_mode unshaded, cull_front, world_vertex_coords, shadows_disabled, fog_disabled;
// The ink line: each solid drawn again, slightly swollen and inside out, so a
// thin dark rim shows around it. Tinted by the surface so it never reads black.
uniform vec3 albedo : source_color = vec3(1.0);
uniform float width = 0.011;

void vertex() {
	VERTEX += NORMAL * width;
}

void fragment() {
	ALBEDO = mix(vec3(0.24, 0.16, 0.12), albedo * 0.5, 0.6);
}
