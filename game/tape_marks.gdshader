shader_type spatial;

uniform float exposed = 1.;
uniform vec2 red_zone;
varying vec3 local_pos;

void vertex() {
	local_pos = VERTEX;
}

float tick(float m, float spacing, float width) {
	float d = abs(fract(m / spacing + .5) - .5) * spacing;
	float aa = max(fwidth(m), .002);
	return (1. - smoothstep(width, width + aa, d)) * (1. - smoothstep(spacing * .25, spacing * .5, aa));
}

void fragment() {
	float m = (.5 + local_pos.z) * exposed;
	float edge = .26 - abs(local_pos.x);
	float minor = tick(m, .10, .009) * (1. - smoothstep(.06, .075, edge));
	float major = tick(m, .50, .016) * (1. - smoothstep(.14, .16, edge));
	float red = smoothstep(red_zone.x - .015, red_zone.x, m) * (1. - smoothstep(red_zone.y, red_zone.y + .015, m));
	vec3 steel = mix(vec3(.90,.57,.10), vec3(.78,.095,.055), red);
	ALBEDO = mix(steel, vec3(.09,.105,.10), max(minor,major) * step(.015,local_pos.y));
	ROUGHNESS = .64;
	METALLIC = .18;
}
