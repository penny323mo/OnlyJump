shader_type sky;

void sky() {
	vec3 ray = EYEDIR;
	vec3 horizon = vec3(0.96, 0.81, 0.69);
	vec3 dusk = vec3(0.37, 0.60, 0.75);
	vec3 color = mix(horizon, dusk, smoothstep(0.02, 0.58, ray.y));
	color = mix(color, vec3(0.78, 0.58, 0.53), smoothstep(0.03, 0.45, -ray.y));
	vec3 sun = normalize(vec3(0.085, 0.12, -1.0));
	// A few long wind-sheared cloud bands break the flat horizon.
	float bend = sin(ray.x * 7.0 + ray.z * 2.0) * 0.013;
	float band = abs(ray.y - 0.20 - bend);
	float wisp = (1.0-smoothstep(0.002,0.014,band)) * smoothstep(0.12,0.85,sin(ray.x*10.0+1.0));
	color = mix(color, vec3(1.0,0.86,0.72), wisp*0.37);
	float dist = distance(sun, ray);
	color += vec3(0.14, 0.095, 0.035) * exp(-dist * 8.0);
	color = mix(color, vec3(1., 0.94, 0.73), 1.0 - smoothstep(0.064, 0.066, dist));
	COLOR = color;
}
