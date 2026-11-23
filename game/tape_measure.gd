extends StaticBody3D

const Props = preload("res://game/props.gd")
const MOUTH := Vector3(0,0,-.79)
const SLOPE := .27
const REST := 1.02
const FULL := 5.
const EXTEND_TIME := 1.40
const REWIND_AT := 2.55
const END_TIME := 4.40
const WIDTH := .52
const RED_START := 3.55
const RED_END := 4.55
var blade:=AnimatableBody3D.new()
var guide:=Node3D.new()
var strip:=MeshInstance3D.new()
var hit:=CollisionShape3D.new()
var shape:=BoxShape3D.new()
var ink:=ShaderMaterial.new()
var latch: MeshInstance3D
var length_out:=REST
var cycle:=-1.
var armed:=true

func build(art: Props, destination: Vector3) -> void:
	var way:=destination-position
	rotation.y=atan2(-way.x,-way.z)
	art.solid(self,Vector3(0,-.55,0),Vector3(1.46,1.1,1.68),"ec902e",.23)
	art.box(self,Vector3(0,-.99,.02),Vector3(1.52,.25,1.71),"344f50",.11)
	for side: float in [-1.,1.]:
		var panel:=Vector3(side*.726,-.56,.04)
		art.cone(self,panel,.055,.44,.44,"385958",32).rotation.z=PI/2
		if side<0.:
			art.cone(self,panel+Vector3.LEFT*.037,.028,.33,.33,"ffc968",32).rotation.z=PI/2
			art.label(self,panel+Vector3.LEFT*.056,"5 m",.22,"294747").rotation.y=-PI/2.
		else:
			# Folded pocket clip stands proud of the rubber side panel.
			art.box(self,Vector3(.79,-.34,.04),Vector3(.13,.08,.26),"b6c6c3")
			art.box(self,Vector3(.84,-.57,.04),Vector3(.055,.48,.26),"b6c6c3")
			art.box(self,Vector3(.87,-.81,.04),Vector3(.09,.07,.26),"899b9c").rotation.z=.42
		for z: float in [-.59,.59]:
			art.cone(self,Vector3(side*.73,-.78,z),.04,.045,.045,"b5c3bb",10).rotation.z=PI/2
	var strap:=art.rim(self,Vector3(-.55,-.85,.99),.42,.065,"344f50")
	strap.scale=Vector3(.40,.75,1.24)
	strap.rotation=Vector3(.50,-.29,0)
	latch=art.box(self,Vector3(0,.023,.16),Vector3(.49,.08,.42),"a44737",.035)
	for z: float in [-.10,0.,.10]:
		art.box(latch,Vector3(0,.044,z),Vector3(.36,.016,.027),"e78c51",.006)
	art.box(self,Vector3(0,-.075,-.79),Vector3(.75,.13,.14),"394d4d",.025)
	add_child(guide)
	guide.position=MOUTH
	guide.rotation.x=SLOPE
	guide.add_child(blade)
	blade.sync_to_physics=false
	blade.set_meta("mobile_surface",true)
	blade.set_meta("ledge",get_meta("ledge"))
	var metal:=BoxMesh.new()
	metal.size=Vector3(WIDTH,.055,1.)
	ink.shader=preload("res://game/tape_marks.gdshader")
	ink.set_shader_parameter("red_zone",Vector2(RED_START,RED_END))
	strip.mesh=metal
	strip.material_override=ink
	blade.add_child(strip)
	hit.shape=shape
	blade.add_child(hit)
	# The folded steel hook is wider than the strip and supports both feet.
	art.solid(blade,Vector3(0,-.041,.11),Vector3(.70,.062,.30),"d8e1da",.025)
	art.box(blade,Vector3(0,.004,.10),Vector3(.66,.012,.24),"bdcdcd",.006)
	art.box(blade,Vector3(0,-.105,-.025),Vector3(.70,.195,.06),"778c8e",.022)
	for x: float in [-.17,.17]:
		art.cone(blade,Vector3(x,.008,.16),.015,.042,.042,"4c6161",12)
	reset()

func set_extension(exposed: float) -> void:
	length_out=exposed
	blade.position=Vector3.FORWARD*exposed
	# The body travels with the printed marks. Its rear edge stays at the slot.
	var middle:=Vector3(0,-.0275,exposed*.5)
	shape.size=Vector3(WIDTH,.055,exposed)
	hit.position=middle
	strip.position=middle
	strip.scale.z=exposed
	ink.set_shader_parameter("exposed",exposed)

func reset() -> void:
	cycle=-1.
	armed=true
	latch.position.y=.023
	set_extension(REST)

func on_hook(foot: Vector3) -> bool:
	var sole:=blade.to_local(foot)
	return absf(sole.x)<.42 and absf(sole.y)<.18 and sole.z>-.20 and sole.z<.38

func rider_hint(foot: Vector3) -> String:
	if cycle<0.:
		return "退返尺殼，再踩尺頭" if not armed else "踩銀色尺頭，再放開搖桿"
	if not on_hook(foot):return "尺頭收返之後可以再搭"
	if cycle<EXTEND_TIME and length_out<=RED_END:
		return "紅段出緊，推前撳跳" if length_out>=RED_START else "搭住尺頭，準備向前跳"
	return "企定可以搭返尺殼"

func advance(delta: float, occupied: bool, foot: Vector3) -> void:
	if cycle<0.:
		if not occupied or not on_hook(foot):
			armed=true
			return
		if not armed:return
		armed=false
		cycle=0.
		latch.position.y=-.013
	cycle+=delta
	var travel:=smoothstep(0.,EXTEND_TIME,cycle)-smoothstep(REWIND_AT,END_TIME,cycle)
	var exposed:=lerpf(REST,FULL,travel)
	if exposed!=length_out:set_extension(exposed)
	if cycle>=END_TIME:
		cycle=-1.
		latch.position.y=.023
