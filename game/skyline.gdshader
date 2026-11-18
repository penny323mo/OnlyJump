shader_type spatial;
render_mode unshaded;
varying vec3 location;
varying vec3 facing;
void vertex(){
	location=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;
	facing=normalize(MODEL_NORMAL_MATRIX*NORMAL);
}
void fragment(){
	vec2 p=vec2(abs(facing.x)>.5?location.z:location.x,location.y);
	vec2 uv=p/vec2(.98,1.35);
	vec2 footprint=max(fwidth(uv),vec2(.0001));
	vec2 edge=vec2(.26,.235)-abs(fract(uv)-vec2(.50,.555));
	vec2 coverage=smoothstep(-.5*footprint,.5*footprint,edge);
	float detail=1.-smoothstep(.30,.85,max(footprint.x,footprint.y));
	float windows=coverage.x*coverage.y;
	float light=fract(sin(dot(floor(p/vec2(.98,1.35)),vec2(19.5,72.8)))*13271.);
	vec3 wall=mix(vec3(.44,.48,.52),vec3(.54,.54,.56),max(0.,facing.x));
	ALBEDO=mix(wall,mix(vec3(.42,.47,.50),vec3(.65,.63,.58),light),windows*detail*(1.-abs(facing.y)));
}
