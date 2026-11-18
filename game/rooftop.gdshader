shader_type spatial;
varying vec3 slab;
void vertex(){slab=VERTEX;}
float grain(vec2 p){
	vec2 k=fract(p*vec2(0.1031,0.11369));
	k+=dot(k,k.yx+19.19);
	return fract((k.x+k.y)*k.x);
}
void fragment(){
	vec2 p=slab.xz;
	vec2 grid=abs(fract((p+vec2(0.3,0.2))/1.28)-.5)*1.28;
	float seam=1.-smoothstep(.005,.024,min(grid.x,grid.y));
	float grit=grain(floor(p*125.));
	float shade=grain(floor((p+vec2(.3,.2))/1.28+.5));
	vec3 concrete=mix(vec3(.33,.41,.41),vec3(.42,.49,.47),shade*.50+grit*.26);
	ALBEDO=mix(concrete,vec3(.23,.30,.30),seam*.55);
	ROUGHNESS=.92;
}
