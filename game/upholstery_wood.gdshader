shader_type spatial;

// R is measured surface tone, GB are tangent-space normal X and Y.
uniform sampler2D scan : repeat_enable, filter_linear_mipmap_anisotropic;
uniform vec4 dye : source_color;
uniform float metres_per_tile = 1.;
uniform float relief = .38;
uniform float matte = .87;
uniform bool buttoned = false;
varying vec3 piece;
varying vec3 facing;

void vertex() {
	piece = VERTEX;
	facing = NORMAL;
}

void fragment() {
	vec3 n = normalize(facing);
	vec3 dominant = abs(n);
	vec3 u = dominant.x > max(dominant.y,dominant.z) ? vec3(0.,0.,1.) : vec3(1.,0.,0.);
	vec3 v = normalize(cross(n,u));
	u = normalize(cross(v,n));
	// Project along the face, so the grain stays attached as a drawer moves.
	vec2 plane = dominant.y >= max(dominant.x,dominant.z) ? vec2(piece.x,-piece.z*sign(n.y)) :
	             dominant.x > dominant.z ? vec2(piece.z,-piece.y*sign(n.x)) : vec2(piece.x,piece.y*sign(n.z));
	vec3 fibre = texture(scan,plane/metres_per_tile).rgb;
	vec2 slope = (fibre.gb*2.-1.)*relief;
	float shade = mix(.62,1.34,fibre.r);
	if (buttoned && n.y > .7) {
		vec2 pin = clamp(round(piece.xz/vec2(.74,.98)-vec2(0.,.5)),vec2(-1.,-1.),vec2(1.,0.));
		vec2 offset = piece.xz-(pin+vec2(0.,.5))*vec2(.74,.98);
		float d = length(offset);
		float hollow = 1.-smoothstep(.03,.33,d);
		// Shallow radiating creases in the upholstery around the six real studs.
		float crease = exp(-24.*abs(abs(offset.x)-abs(offset.y)*.67))*hollow;
		shade *= 1.-.18*hollow-.10*crease;
		slope += vec2(-offset.x,offset.y)*hollow*2.6;
	}
	NORMAL = normalize(NORMAL + mat3(VIEW_MATRIX)*MODEL_NORMAL_MATRIX*(u*slope.x+v*slope.y));
	vec3 colour = dye.rgb;
	if (buttoned) {
		// Two woven selvedge lines follow each long side of the seat.
		float edge = abs(piece.z);
		float pixel = max(fwidth(edge),.002);
		float wide = 1.-smoothstep(.022-pixel,.022+pixel,abs(edge-.91));
		float thin = 1.-smoothstep(.009-pixel,.009+pixel,abs(edge-.85));
		colour = mix(colour,vec3(.69,.66,.45),(.52*wide+.42*thin)*smoothstep(.45,.9,n.y));
	}
	ALBEDO = colour*shade;
	ROUGHNESS = clamp(matte+.12*(.5-fibre.r),.5,1.);
	SPECULAR = .22;
}
