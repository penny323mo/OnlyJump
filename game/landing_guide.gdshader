shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;

// A light cross with a dark border stays readable on pale wood and dark steel.
void fragment() {
	vec2 p = abs(UV * 2.0 - 1.0);
	float edge = max(min(p.x, p.y) - 0.23, max(p.x, p.y) - 0.88);
	if (edge > 0.10) discard;
	float outline = smoothstep(-fwidth(edge), fwidth(edge), edge);
	ALBEDO = mix(vec3(0.48, 1.0, 0.89), vec3(0.015, 0.09, 0.09), outline);
}
