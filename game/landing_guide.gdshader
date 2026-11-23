shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;

uniform bool edge_landing = false;

void vertex() {
	vec4 view_pos = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	// Keep the tip readable across small changes in the lip's curvature.
	if (edge_landing) view_pos.xyz -= normalize(view_pos.xyz) * 0.075;
	POSITION = PROJECTION_MATRIX * view_pos;
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	vec2 a = abs(p);
	float edge = max(min(a.x, a.y) - 0.23, max(a.x, a.y) - 0.88);
	vec3 fill = vec3(0.48, 1.0, 0.89);
	if (edge_landing) {
		// Local -Z points onto the supporting surface.
		float head = max(a.x * 0.85 - (p.y + 0.85) * 0.72, p.y - 0.12);
		float stem = max(a.x - 0.24, abs(p.y - 0.40) - 0.40);
		edge = min(head, stem);
		fill = vec3(1.0, 0.68, 0.14);
	}
	if (edge > 0.10) discard;
	float outline = smoothstep(-fwidth(edge), fwidth(edge), edge);
	ALBEDO = mix(fill, vec3(0.015, 0.09, 0.09), outline);
}
