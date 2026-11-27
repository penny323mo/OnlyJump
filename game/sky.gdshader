shader_type sky;

void sky() {
	vec3 ray = EYEDIR;
	vec3 horizon = vec3(0.99, 0.76, 0.60);
	vec3 dusk = vec3(0.18, 0.58, 0.83);
	vec3 color = mix(horizon, dusk, smoothstep(0.02, 0.58, ray.y));
	color = mix(color, vec3(0.78, 0.58, 0.53), smoothstep(0.03, 0.45, -ray.y));
	vec3 sun = normalize(vec3(-0.654, 0.602, -0.458));
	// A few long wind-sheared cloud bands break the flat horizon.
	float bend = sin(ray.x * 7.0 + ray.z * 2.0) * 0.013;
	float band = abs(ray.y - 0.20 - bend);
	float wisp = (1.0-smoothstep(0.002,0.014,band)) * smoothstep(0.12,0.85,sin(ray.x*10.0+1.0));
	color = mix(color, vec3(1.0,0.86,0.72), wisp*0.37);
	float dist = distance(sun, ray);
	color += vec3(0.14, 0.095, 0.035) * exp(-dist * 8.0);
	color = mix(color, vec3(1., 0.94, 0.73), 1.0 - smoothstep(0.034, 0.038, dist));
	// Silhouettes are a direction-only sky layer, so orbit and zoom reveal
	// distant hills without streaming another mesh behind the district.
	float ridge = .023*sin(ray.x*12.+ray.z*7.)+.015*sin(ray.z*22.-ray.x*5.);
	float hills = 1.-smoothstep(.036+ridge,.043+ridge,ray.y);
	color = mix(color,vec3(.50,.54,.60),hills*.76);
	COLOR = color;
}
