shader_type spatial;
render_mode unshaded, cull_disabled;

uniform sampler2D palette : source_color, filter_linear, repeat_disable;
uniform sampler2D street_shade : filter_linear_mipmap, repeat_disable;
uniform bool roadway = false;
varying vec3 world;
varying vec3 facade;
varying float sun;
varying float height_above_street;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 normal_world = normalize(MODEL_NORMAL_MATRIX * NORMAL);
	sun = max(dot(normal_world, vec3(-0.654,0.602,-0.458)),0.0);
	height_above_street = world.y + 11.9;
	// Stable paint per address, including the side that faces away from camera.
	vec2 block = floor(MODEL_MATRIX[3].xz / 7.0 + 0.5);
	float hue = fract(dot(block,vec2(.38197,.61892)) + block.x*block.y*.071);
	facade = hue < .26 ? vec3(.24,.69,.63) : hue < .53 ? vec3(.87,.43,.32) :
	         hue < .78 ? vec3(.88,.69,.46) : vec3(.34,.58,.74);
}

void fragment() {
	vec3 ink = texture(palette,UV).rgb;
	float stripe = floor(UV.x*16.0);
	vec3 paint = ink;
	if (roadway) {
		float lit = texture(street_shade,world.xz/144.0+.5).r;
		float value = dot(ink,vec3(.24,.58,.18));
		paint = mix(vec3(.12,.20,.25),vec3(.84,.77,.62),value);
		paint *= mix(vec3(.64,.76,.89),vec3(1.14,1.04,.90),lit);
	} else {
		float value = dot(ink,vec3(.24,.58,.18));
		if (stripe >= 8.0 || (stripe == 3.0 && UV.y < .75)) {
			paint = facade * (.63+.42*value);
		} else if (stripe == 1.0) {
			paint = mix(vec3(.12,.26,.32),vec3(.52,.70,.72),value);
		} else {
			paint = mix(vec3(.22,.32,.35),vec3(.88,.81,.69),value);
		}
		// Distant sills are often thinner than one phone pixel. Ease their
		// contrast against the neighbourhood palette as they recede.
		float distant = smoothstep(14.,53.,distance(CAMERA_POSITION_WORLD,world));
		paint = mix(paint,mix(facade,vec3(.56,.59,.60),.60),.37*distant);
		float bounce = smoothstep(0.0,4.0,height_above_street);
		paint *= mix(vec3(.67,.77,.85),vec3(1.18,1.04,.88),sun) * (.84+.16*bounce);
	}
	ALBEDO = paint;
}
