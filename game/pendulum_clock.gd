extends AnimatableBody3D

const Props = preload("res://game/props.gd")
const LENGTH := 3.55
const RADIUS := .67
const PERIOD := 5.6
const ANGLE := PI*.30
const DIAL_RADIUS := 1.12
const CASE_DEPTH := 1.02

var low_point: Vector3
var hanger:=Node3D.new()
var second_hands: Array[Node3D]=[]
var time:=0.

func build(art: Props, housing: StaticBody3D) -> void:
	low_point=position
	# The round crown under the player's shoes is the top of the brass bob.
	disc(art,self,Vector3.DOWN*RADIUS,RADIUS,.85,"cc994d",true)
	var brass:=StandardMaterial3D.new()
	brass.albedo_color=Color("e8b65e")
	brass.metallic=.5
	brass.roughness=.30
	for side: float in [-1.,1.]:
		var lens:=SphereMesh.new()
		lens.radius=.56
		lens.height=1.12
		lens.radial_segments=32
		lens.rings=12
		var dome:=art.piece(self,lens,Vector3(0,-RADIUS,side*.42),"e8b65e")
		dome.scale.z=.20
		dome.material_override=brass
		var lip:=art.rim(self,Vector3(0,-RADIUS,side*.428),.625,.047,"d2a265")
		lip.rotation.x=PI/2
		lip.material_override=brass
	art.cone(self,Vector3.DOWN*1.42,.16,.098,.105,"8c6734",12)
	art.add_child(hanger)
	hanger.position=low_point+Vector3(0,LENGTH-RADIUS,-.49)
	art.tube(hanger,Vector3.ZERO,Vector3.DOWN*LENGTH,.052,"bd873c")
	art.tube(hanger,Vector3.DOWN*LENGTH,Vector3(0,-LENGTH,.49),.095,"80562e")
	build_dial(art,housing)
	reset()

func disc(art: Props, parent: Node3D, p: Vector3, radius: float, depth: float, color: String, solid: bool) -> void:
	var mesh:=art.cone(parent,p,depth,radius,radius,color,48)
	mesh.rotation.x=PI/2
	if solid:
		var hit:=CollisionShape3D.new()
		var cylinder:=CylinderShape3D.new()
		cylinder.radius=radius
		cylinder.height=depth
		hit.shape=cylinder
		parent.add_child(hit)
		hit.transform=mesh.transform

func build_dial(art: Props, housing: StaticBody3D) -> void:
	var centre:=Vector3.DOWN*DIAL_RADIUS
	disc(art,housing,centre,DIAL_RADIUS,CASE_DEPTH,"6d4034",true)
	art.tube(housing,housing.to_local(hanger.global_position),centre,.09,"996b37")
	for side: float in [-1.,1.]:
		var face:=Node3D.new()
		housing.add_child(face)
		face.position=centre+Vector3.BACK*side*(CASE_DEPTH*.5+.01)
		if side<0:face.rotation.y=PI
		disc(art,face,Vector3.ZERO,1.03,.07,"be8d49",false)
		disc(art,face,Vector3.BACK*.04,.965,.055,"f2dec0",false)
		for i in 12:
			var angle:=TAU*i/12.
			var length:=.19 if i%3==0 else .10
			var mark:=art.box(face,Vector3(sin(angle)*.80,cos(angle)*.80,.075),Vector3(.063,length,.02),"38534d",.01)
			mark.rotation.z=-angle
		for i in 4:
			var angle:=PI*.5*i
			art.label(face,Vector3(sin(angle)*.64,cos(angle)*.64,.088),["12","3","6","9"][i],.20,"334d49")
		art.tube(face,Vector3.BACK*.105,Vector3(-.34,.29,.105),.055,"303e40")
		art.tube(face,Vector3.BACK*.12,Vector3(.51,.39,.12),.038,"303e40")
		disc(art,face,Vector3.BACK*.15,.078,.04,"b96642",false)
		var hand:=Node3D.new()
		face.add_child(hand)
		hand.position.z=.145
		art.box(hand,Vector3(0,.26,0),Vector3(.032,.77,.022),"c95236",.009)
		second_hands.append(hand)

func bob_at(angle: float) -> Vector3:
	return low_point+Vector3(sin(angle),1.-cos(angle),0)*LENGTH

func reset() -> void:
	time=0.
	advance(0.)

func advance(delta: float) -> void:
	time+=delta
	var angle:=-ANGLE*cos(TAU*time/PERIOD)
	hanger.rotation.z=angle
	position=bob_at(angle)
	for hand in second_hands: hand.rotation.z=-TAU*fmod(time,60.)/60.
