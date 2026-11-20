extends AnimatableBody3D

const Props = preload("res://game/props.gd")
const REST := .135
const LIMIT := .27
const TOP := .32
const ENTRY := Vector3(-2.48,TOP,0)
var angular_speed := 0.
var bubble: MeshInstance3D

func build(art: Props) -> void:
	# The caps, rails and flush sight window share one uninterrupted top face.
	var hit:=CollisionShape3D.new()
	var shell:=BoxShape3D.new()
	shell.size=Vector3(6.,.50,.86)
	hit.shape=shell
	hit.position.y=TOP-.25
	add_child(hit)
	for side: float in [-1.,1.]:
		art.box(self,Vector3(side*2.84,TOP-.25,0),Vector3(.32,.50,.86),"303c3d",.055)
		art.box(self,Vector3(side*1.78,TOP-.26,0),Vector3(1.9,.50,.85),"ed9f24",.07)
		art.box(self,Vector3(0,TOP-.054,side*.37),Vector3(5.36,.107,.12),"d9e0d6",.026)
		art.box(self,Vector3(0,TOP-.45,side*.34),Vector3(5.46,.092,.115),"b5c4bb",.022)
		for i in 5:
			var x:=side*(1.72+i*.17)
			art.box(self,Vector3(x,TOP-.008,-.22),Vector3(.023,.01,.20 if i%2==0 else .115),"374948",.003)
		art.label(self,Vector3(side*1.77,TOP-.24,side*.428),"600 mm",.14,"384747").rotation.y=0. if side>0 else PI
	for x: float in [1.12,1.43]:
		art.box(self,Vector3(x,TOP-.008,0),Vector3(.11,.012,.56),"aa392e",.004).rotation.y=-.23
	art.box(self,Vector3(0,TOP-.37,0),Vector3(1.75,.16,.75),"314546",.06)
	# A clear sight window spans the central vial, flush with the rails.
	var pane:=art.box(self,Vector3(0,TOP-.031,0),Vector3(1.68,.05,.63),"d7f9df",.02)
	var glass:=StandardMaterial3D.new()
	glass.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.albedo_color=Color(.77,1.,.83,.21)
	glass.roughness=.24
	pane.material_override=glass
	var vial:=art.cone(self,Vector3(0,TOP-.18,0),1.38,.135,.135,"b1d844",32)
	vial.rotation.z=PI/2
	for x: float in [-.69,-.20,.20,.69]:
		var band:=art.cone(self,Vector3(x,TOP-.18,0),.075 if absf(x)>.5 else .025,.146,.146,"344e45",24)
		band.rotation.z=PI/2
	var oval:=SphereMesh.new()
	oval.radius=.103
	oval.height=.206
	oval.radial_segments=20
	oval.rings=8
	bubble=art.piece(self,oval,Vector3(0,TOP-.091,0),"f5ffcf")
	bubble.scale=Vector3(1.53,.48,.76)
	# The fixed bracket stays below the beam's sweep.
	var bracket:=StaticBody3D.new()
	bracket.set_meta("ledge",get_meta("ledge"))
	art.add_child(bracket)
	bracket.position=position
	for side: float in [-1.,1.]:
		art.box(bracket,Vector3(0,-.11,side*.455),Vector3(.32,.35,.085),"536c70",.04)
		var axle:=art.cone(bracket,Vector3(0,0,side*.50),.13,.115,.115,"c28642",16)
		axle.rotation.x=PI/2
	art.solid(bracket,Vector3(0,-.25,0),Vector3(.42,.07,.99),"496165",.025)
	reset()

func reset() -> void:
	angular_speed=0.
	rotation.z=REST
	bubble.position.x=REST/LIMIT*.39

func advance(delta: float, occupied: bool, foot: Vector3) -> void:
	# The rider's signed distance from the pivot sets the torque. Inertia gives
	# a running player time to cross the balance point before the far end dips.
	var local_foot:=to_local(foot) if occupied else Vector3.ZERO
	var lever:=local_foot.x if local_foot.y>TOP-.12 else 0.
	angular_speed+=((REST-rotation.z)*3.8-clampf(lever,-3.,3.)*1.12-angular_speed*2.45)*delta
	var tilt:=rotation.z+angular_speed*delta
	rotation.z=clampf(tilt,-LIMIT,LIMIT)
	if tilt>LIMIT or tilt<-LIMIT: angular_speed=0.
	bubble.position.x=lerpf(bubble.position.x,rotation.z/LIMIT*.39,1.-exp(-delta*7.))
