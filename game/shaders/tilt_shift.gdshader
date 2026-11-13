shader_type canvas_item;
// Tilt-shift as a lens does it on a photo of a model: blur grows with distance
// up or down the screen from a sharp band, the same across each row. It does
// not depend on scene depth, so nothing blurs "by object".
uniform sampler2D screen : hint_screen_texture, filter_linear, repeat_disable;
uniform float focus_y = 0.47;   // centre of the sharp band, 0 top to 1 bottom
uniform float band = 0.2;       // half-height of the fully sharp band
uniform float falloff = 0.3;    // distance over which the blur reaches full strength
uniform float radius = 0.007;   // full blur radius, as a fraction of screen height

void fragment() {
	float d = abs(SCREEN_UV.y - focus_y);
	float k = smoothstep(band, band + falloff, d);
	vec3 base = texture(screen, SCREEN_UV).rgb;
	if (k <= 0.001) {
		COLOR = vec4(base, 1.0);
	} else {
		vec2 px = vec2(SCREEN_PIXEL_SIZE.x / SCREEN_PIXEL_SIZE.y, 1.0) * radius * k;
		vec3 sum = base;
		float total = 1.0;
		for (int i = 1; i <= 32; i++) {   // golden-angle disc
			float fi = float(i);
			float r = sqrt(fi / 32.0);
			float a = fi * 2.39996;
			sum += texture(screen, SCREEN_UV + vec2(cos(a), sin(a)) * r * px).rgb;
			total += 1.0;
		}
		COLOR = vec4(sum / total, 1.0);
	}
}
