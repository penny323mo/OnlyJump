shader_type spatial;
render_mode unshaded, depth_draw_never, shadows_disabled, fog_disabled;

uniform vec4 contact;
uniform float strength;
varying vec3 offset;
varying float facing_up;

void vertex() {
	offset = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz - contact.xyz;
	facing_up = normalize(MODEL_NORMAL_MATRIX * NORMAL).y;
}

void fragment() {
	float radial = length(offset.xz) / contact.w;
	float edge = 1.0 - smoothstep(0.23, 1.0, radial);
	float surface = smoothstep(0.12, 0.60, facing_up);
	float depth = 1.0 - smoothstep(0.23, 0.36, abs(offset.y));
	ALBEDO = vec3(0.055, 0.062, 0.056);
	ALPHA = strength * edge * surface * depth;
}
