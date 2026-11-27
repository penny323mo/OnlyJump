shader_type spatial;
render_mode unshaded, cull_disabled;

uniform sampler2D palette : source_color, filter_linear, repeat_disable;
uniform sampler2D street_shade : filter_linear_mipmap, repeat_disable;
uniform sampler2D surface_scan : repeat_enable, filter_linear_mipmap;
uniform bool roadway = false;
varying vec3 world;
varying vec3 facade;
varying vec3 wall_normal;
varying float sun;
varying float height_above_street;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 normal_world = normalize(MODEL_NORMAL_MATRIX * NORMAL);
	wall_normal = normal_world;
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
		float grit = texture(surface_scan,world.xz/5.).r;
		paint *= .84+.29*grit;
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
		bool vertical = abs(wall_normal.y)<.4;
		vec2 plane = vertical ? vec2(abs(wall_normal.x)>.5 ? world.z : world.x,world.y) : world.xz;
		float skin = texture(surface_scan,plane*vec2(.27,vertical ? -.27 : .27)).r;
		bool wall_finish = stripe>=8. || (stripe==3. && UV.y<.75);
		// Glass and sill stone keep their own finishes beside the masonry.
		paint *= 1.+(skin-.53)*(wall_finish ? .43 : .17);
		if (vertical && wall_finish) {
			// Deep frames and cool glazing break up the broad, blank end walls.
			vec2 facade_uv=vec2(plane.x/1.85,(height_above_street-.35)/2.75);
			vec2 pane=abs(fract(facade_uv)-.5);
			vec2 blur=max(fwidth(facade_uv),vec2(.002));
			vec2 frame=1.-smoothstep(vec2(.24,.26)-blur,vec2(.24,.26)+blur,pane);
			vec2 glass=1.-smoothstep(vec2(.19,.21)-blur,vec2(.19,.21)+blur,pane);
			float visibility=(1.-smoothstep(.13,.42,max(blur.x,blur.y)))*smoothstep(1.8,2.5,height_above_street);
			vec3 reflection=mix(vec3(.19,.28,.30),vec3(.46,.56,.55),fract(facade_uv.y));
			paint=mix(paint,paint*.65,frame.x*frame.y*visibility);
			paint=mix(paint,reflection,glass.x*glass.y*visibility*.82);
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
