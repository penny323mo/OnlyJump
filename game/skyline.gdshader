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
	vec2 cell=fract(p/vec2(.98,1.35));
	float windows=step(.24,cell.x)*step(cell.x,.76)*step(.32,cell.y)*step(cell.y,.79);
	float light=fract(sin(dot(floor(p/vec2(.98,1.35)),vec2(19.5,72.8)))*13271.);
	vec3 wall=mix(vec3(.44,.48,.52),vec3(.54,.54,.56),max(0.,facing.x));
	ALBEDO=mix(wall,mix(vec3(.42,.47,.50),vec3(.65,.63,.58),light),windows*(1.-abs(facing.y)));
}
