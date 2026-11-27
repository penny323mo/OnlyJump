shader_type spatial;
render_mode unshaded;
varying vec3 location;
varying vec3 facing;
varying float block;
void vertex(){
	block=fract(dot(MODEL_MATRIX[3].xz,vec2(.179,.213)));
	location=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;
	facing=normalize(MODEL_NORMAL_MATRIX*NORMAL);
}
void fragment(){
	vec2 p=vec2(abs(facing.x)>.5?location.z:location.x,location.y);
	vec2 uv=p/vec2(.98,1.35);
	vec2 footprint=max(fwidth(uv),vec2(.0001));
	vec2 edge=vec2(.26,.235)-abs(fract(uv)-vec2(.50,.555));
	vec2 coverage=smoothstep(-.75*footprint,.75*footprint,edge);
	float detail=1.-smoothstep(.19,.62,max(footprint.x,footprint.y));
	float windows=coverage.x*coverage.y;
	float light=fract(sin(dot(floor(p/vec2(.98,1.35)),vec2(19.5,72.8)))*13271.);
	vec3 stone=mix(vec3(.33,.44,.51),vec3(.63,.48,.43),block);
	float sun=max(0.,dot(facing,vec3(-.654,.602,-.458)));
	vec3 wall=stone*mix(vec3(.77,.85,.98),vec3(1.30,1.14,.94),sun);
	float reflection=smoothstep(-4.,18.,location.y)*(.28+.32*block);
	vec3 glass=mix(vec3(.26,.41,.50),vec3(.86,.66,.48),reflection*sun);
	glass=mix(glass,vec3(.98,.76,.46),smoothstep(.90,.975,light)*.43);
	ALBEDO=mix(wall,glass,windows*detail*(1.-abs(facing.y)));
}
