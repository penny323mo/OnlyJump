extends StaticBody3D

const Props = preload("res://game/props.gd")
const LENGTH := 6.10
const SLICES := 32
const MAX_SPEED := 7.4
const LANES := [-1.,-.94,-.78,-.5,-.25,0.,.25,.5,.78,.94,1.]
const THICKNESS := .11

func across_track(t: float) -> Vector3:
	var exit_turn:=maxf(0.,(t-.48)/.52)
	return Vector3(-.92*PI*cos(PI*t)-.76+1.8*exit_turn/.52,0,LENGTH).normalized()

func surface(t: float, lane: float) -> Vector3:
	var dip:=(t-.58)/(.58 if t<.58 else .42)
	var height:=-1.58+dip*dip*(1.58 if t<.58 else 1.26)
	var exit_turn:=maxf(0.,(t-.48)/.52)
	var bend:=-.92*sin(PI*t)-.76*t+.9*exit_turn*exit_turn
	var width:=lerpf(1.31,.94,smoothstep(.44,.94,t))
	return Vector3(-LENGTH*t,height,bend)+across_track(t)*(lane*width)+Vector3.UP*(.37*pow(absf(lane),3.))

func panel(mesh: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, tint: String) -> void:
	mesh.set_color(Color(tint).srgb_to_linear())
	mesh.set_normal((c-a).cross(b-a).normalized())
	for point in [a,b,c,a,c,d]:mesh.add_vertex(point)

func build(art: Props) -> void:
	var ribbon:=SurfaceTool.new()
	ribbon.begin(Mesh.PRIMITIVE_TRIANGLES)
	var plastic:=StandardMaterial3D.new()
	plastic.vertex_color_use_as_albedo=true
	plastic.roughness=.46
	ribbon.set_material(plastic)
	var under:=Vector3.DOWN*THICKNESS
	for i in SLICES:
		var t:=float(i)/SLICES
		var next:=float(i+1)/SLICES
		for j in LANES.size()-1:
			var a:=surface(t,LANES[j])
			var b:=surface(t,LANES[j+1])
			var c:=surface(next,LANES[j+1])
			var d:=surface(next,LANES[j])
			var tint:="ff852c"
			if j==0 or j==LANES.size()-2:tint="ffd489"
			elif i in [26,27]:tint="fff0cf" if (i+j)%2==0 else "264550"
			panel(ribbon,a,b,c,d,tint)
			panel(ribbon,d+under,c+under,b+under,a+under,"c65027")
			if j==0:panel(ribbon,a,d,d+under,a+under,"ec6626")
			if j==LANES.size()-2:panel(ribbon,c,b,b+under,c+under,"ec6626")
			if i==0:panel(ribbon,b,a,a+under,b+under,"f49c49")
			if i==SLICES-1:panel(ribbon,d,c,c+under,d+under,"f49c49")
	ribbon.index()
	var mesh:=ribbon.commit()
	var shell:=MeshInstance3D.new()
	shell.mesh=mesh
	add_child(shell)
	var hit:=CollisionShape3D.new()
	hit.shape=mesh.create_trimesh_shape()
	add_child(hit)
	# Injection-moulded blue trestles clip underneath the orange track.
	for t: float in [.12,.54,.90]:
		var left:=surface(t,-.73)+under
		var right:=surface(t,.73)+under
		var foot:=(left+right)*.5+Vector3.DOWN*(.90+.35*absf(t-.54))
		art.tube(self,left,foot-Vector3.RIGHT*.16,.078,"27758c")
		art.tube(self,right,foot+Vector3.RIGHT*.16,.078,"27758c")
		art.box(self,foot,Vector3(.75,.13,1.12),"225d77",.05)
		for lane: float in [-1.,1.]:
			var clasp:=art.box(self,surface(t,lane)+Vector3.DOWN*.105,Vector3(.22,.18,.12),"337d95",.035)
			clasp.rotation.y=atan2(surface(t+.001,lane).z-surface(t,lane).z,.001*LENGTH)

# Project gravity and steering onto the actual face under the runner. The
# speed at the lip comes from the descent and the player's push.
func slide_step(foot: Vector3, current: Vector3, normal: Vector3, move: Vector2, run: bool, gravity: float, top_speed: float, delta: float) -> Vector3:
	var along:=current.slide(normal)
	along+=Vector3.DOWN.slide(normal)*gravity*delta
	along=along.move_toward(Vector3.ZERO,1.05*delta)
	# The moulded channel resists sideways skid more than downhill travel.
	var t:=clampf(-to_local(foot).x/LENGTH,0.,1.)
	var front:=across_track(t).cross(normal).normalized()
	var crosswise:=along-front*along.dot(front)
	along-=crosswise.limit_length(7.*delta)
	if not move.is_zero_approx():
		var toward:=Vector3(move.x,0,move.y).slide(normal).normalized()
		along=along.move_toward(toward*top_speed*move.length(),(15. if run else 11.)*delta*move.length())
	return along.limit_length(MAX_SPEED)
