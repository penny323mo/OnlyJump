shader_type spatial;
uniform sampler2D concrete_scan : repeat_enable, filter_linear_mipmap_anisotropic;
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
	vec3 stone=texture(concrete_scan,p/3.84+vec2(.19,.34)).rgb;
	float tile=grain(floor((p+vec2(.3,.2))/1.28+.5));
	vec3 concrete=mix(vec3(.29,.32,.30),vec3(.54,.55,.48),stone.r)*(.94+.08*tile);
	ALBEDO=mix(concrete,vec3(.24,.27,.25),seam*.60);
	vec3 relief=vec3(stone.g*2.-1.,0.,1.-stone.b*2.);
	NORMAL=normalize(NORMAL+.45*mat3(VIEW_MATRIX)*MODEL_NORMAL_MATRIX*relief);
	ROUGHNESS=.95;
	SPECULAR=.15;
}
