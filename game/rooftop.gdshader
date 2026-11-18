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
	vec2 pixel=max(fwidth(p),vec2(.0001));
	vec2 seamCoverage=1.-smoothstep(vec2(.014)-pixel*.5,vec2(.014)+pixel*.5,grid);
	float seam=max(seamCoverage.x,seamCoverage.y);
	float grit=mix(grain(floor(p*125.)),.5,smoothstep(.25,1.,max(pixel.x,pixel.y)*125.));
	float shade=grain(floor((p+vec2(.3,.2))/1.28+.5));
	vec3 concrete=mix(vec3(.33,.41,.41),vec3(.42,.49,.47),shade*.50+grit*.26);
	ALBEDO=mix(concrete,vec3(.23,.30,.30),seam*.55);
	ROUGHNESS=.92;
}
