shader_type spatial;
render_mode unshaded;
varying vec2 map_pos;
void vertex() {
	map_pos = (MODEL_MATRIX*vec4(VERTEX,1.)).xz;
}
void fragment() {
	// End the paved quay just beyond the outer ring of road tiles.
	vec2 outside = abs(map_pos-vec2(0.,-7.))-vec2(52.5,52.5);
	float shore = max(outside.x,outside.y);
	vec3 colour = vec3(.37,.43,.43);
	if (shore > .0) {
		float head = dot(map_pos,vec2(-.82,-.57));
		float across = dot(map_pos,vec2(.57,-.82));
		float path = smoothstep(18.,85.,head)*(1.-smoothstep(0.,24.,abs(across)));
		float phase = map_pos.y*2.7 + sin(map_pos.x*.73)*1.3;
		float wave = smoothstep(.56,.94,sin(phase))*(1.-smoothstep(.25,2.,fwidth(phase)));
		colour = mix(vec3(.22,.43,.48),vec3(.73,.62,.51),path);
		colour += (.028+.09*path)*wave;
		colour = mix(vec3(.47,.48,.43),colour,smoothstep(.8,1.5,shore));
	}
	ALBEDO = colour;
}
