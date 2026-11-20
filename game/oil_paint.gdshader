shader_type canvas_item;
render_mode unshaded, blend_disabled;

uniform sampler2D scene : hint_screen_texture, repeat_disable, filter_linear;
const vec3 LUMA = vec3(0.299, 0.587, 0.114);

// Choose the most uniform patch along the brush, keeping a silhouette
// separate from the colours behind it. All four patches share nine taps.
vec4 patch(vec3 a, vec3 b, vec3 c, vec3 d) {
	vec3 mean = (a + b + c + d) * 0.25;
	vec3 spread = abs(a - mean) + abs(b - mean) + abs(c - mean) + abs(d - mean);
	return vec4(mean, dot(spread, LUMA));
}

float bristles(vec2 brush) {
	brush.y += 3.2 * sin(brush.x * 0.065 + brush.y * 0.045);
	brush.x += 14.0 * sin(floor(brush.y / 5.4) * 7.13);
	vec2 tile = brush / vec2(22.0, 5.4);
	vec2 tip = fract(tile) * 2.0 - 1.0;
	float dab = 1.0 - smoothstep(0.42, 1.05, dot(tip, tip));
	float variation = sin(dot(floor(tile), vec2(18.71, 7.13)));
	return dab * (variation + 0.36 * sin(brush.y * 2.1 + variation));
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 pixel = SCREEN_PIXEL_SIZE;
	float scale = clamp(1.0 / (pixel.y * 550.0), 0.85, 2.8);
	vec2 paper = uv / (pixel * scale);
	float slant = -0.45 + 0.32 * sin(paper.y * 0.037 + sin(paper.x * 0.022));
	vec2 along = vec2(1.0, slant) * pixel * scale * 4.1;
	vec2 across = vec2(-slant, 1.0) * pixel * scale * 2.1;
	vec3 center = texture(scene, uv).rgb;
	vec3 left = texture(scene, uv - along).rgb;
	vec3 right = texture(scene, uv + along).rgb;
	vec3 up = texture(scene, uv - across).rgb;
	vec3 down = texture(scene, uv + across).rgb;
	vec4 best = patch(center, left, up, texture(scene, uv - along - across).rgb);
	vec4 sample_b = patch(center, right, up, texture(scene, uv + along - across).rgb);
	vec4 sample_c = patch(center, left, down, texture(scene, uv - along + across).rgb);
	vec4 sample_d = patch(center, right, down, texture(scene, uv + along + across).rgb);
	if (sample_b.a < best.a) { best = sample_b; }
	if (sample_c.a < best.a) { best = sample_c; }
	if (sample_d.a < best.a) { best = sample_d; }
	vec3 pigment = mix(center, best.rgb, 0.74);
	float light = dot(pigment, LUMA);
	float value = light - sin(light * 12.0 * 6.2832) * 0.007;
	pigment = vec3(value) + (pigment - light) * 1.21;
	pigment += mix(vec3(-0.034, -0.008, 0.037), vec3(0.084, 0.036, -0.046), smoothstep(0.16, 0.84, light));
	// Cross-laid strokes change direction between warm and cool pigment.
	// Keep the weave fixed on the canvas and ease it off across fine detail.
	float warm = smoothstep(-0.10, 0.14, pigment.r - pigment.b);
	float strokes = mix(bristles(vec2(paper.y, paper.x - 0.46 * paper.y)),
		bristles(vec2(paper.x, paper.y + 0.32 * paper.x)), warm);
	float edge = dot(abs(left - right) + abs(up - down), LUMA);
	pigment += strokes * vec3(0.047, 0.041, 0.034) * (1.0 - 0.62 * smoothstep(0.05, 0.32, edge));
	COLOR = vec4(clamp(pigment, vec3(0.0), vec3(1.0)), 1.0);
}
