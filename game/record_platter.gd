extends AnimatableBody3D

const Props = preload("res://game/props.gd")
const SPEED := 1.35
const RADIUS := 1.15
const OUTER := 1.30
const TOP := .10
const BASE := -.022
const SIDES := 64

func build(art: Props) -> void:
	sync_to_physics=false
	set_meta("ledge",get_parent().get_meta("ledge"))
	set_meta("mobile_surface",true)
	position.x=-.33
	# The sloping silver platter meets the cabinet below its top. A runner
	# can walk onto the vinyl from the wood or step back off without jumping.
	art.cone(self,Vector3.UP*(TOP+BASE)*.5,TOP-BASE,OUTER,RADIUS,"879590",SIDES)
	var faces:=PackedVector3Array()
	for i in SIDES:
		var a:=Vector3(sin(TAU*i/SIDES),0,cos(TAU*i/SIDES))
		var b:=Vector3(sin(TAU*(i+1)/SIDES),0,cos(TAU*(i+1)/SIDES))
		var upper:=a*RADIUS+Vector3.UP*TOP
		var next:=b*RADIUS+Vector3.UP*TOP
		var lower:=a*OUTER+Vector3.UP*BASE
		var end:=b*OUTER+Vector3.UP*BASE
		faces.append_array(PackedVector3Array([upper,next,end,upper,end,lower]))
	var bevel:=CollisionShape3D.new()
	var slope:=ConcavePolygonShape3D.new()
	slope.set_faces(faces)
	bevel.shape=slope
	add_child(bevel)
	var floor_shape:=CylinderShape3D.new()
	floor_shape.radius=RADIUS
	floor_shape.height=TOP-BASE
	var hit:=CollisionShape3D.new()
	hit.shape=floor_shape
	add_child(hit)
	hit.position.y=(TOP+BASE)*.5
	var surface:=Vector3.UP*TOP
	art.cone(self,surface,.014,RADIUS,RADIUS,"33383d",SIDES)
	for i in 5: art.rim(self,surface+Vector3.UP*.009,1.09-i*.11,.012,"50595e")
	art.cone(self,surface+Vector3.UP*.013,.014,.35,.35,"db9551")
	art.cone(self,surface+Vector3.UP*.034,.045,.035,.035,"d5d5ca")
	# Two paper marks make the speed readable from the gameplay camera.
	art.box(self,surface+Vector3(.94,.020,0),Vector3(.30,.015,.10),"f5dfac",.006)
	art.box(self,surface+Vector3(.91,.020,.105),Vector3(.18,.015,.045),"e99855",.006)
	art.box(self,surface+Vector3(-.18,.024,0),Vector3(.13,.009,.076),"794634",.004)

func turn(time: float) -> void:
	rotation.y=fmod(-time*SPEED,TAU)
