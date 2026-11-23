extends RefCounted

const Props = preload("res://game/props.gd")
const SpringPad = preload("res://game/spring_pad.gd")
const PendulumClock = preload("res://game/pendulum_clock.gd")
const SpiritLevel = preload("res://game/spirit_level.gd")
const LaundryLift = preload("res://game/laundry_lift.gd")
const TapeMeasure = preload("res://game/tape_measure.gd")
const BED := 100
const DRAWER := 101
const POLE := 102
const LIFT := 103
const BOARD := 104
const SHEET := 105
const COIL := 106
const FAN := 107
const AWNING := 108
const PENDULUM := 109
const CLOCK_CASE := 110
const LEVEL := 111
const TAPE := 112
# Each branch lists its position, equivalent main-route stage and next stop.
const STOPS := {
	TAPE: ["發條捲尺",Vector3(.04,5.49,-7.80),7,9],
	FAN: ["天台大風扇",Vector3(-.75,7.32,-21.55),9,10],
	BED: ["迷你彈床",Vector3(-3.70,.67,-2.55),1,3],
	DRAWER: ["鬆脫抽屜",Vector3(-3.18,3.78,-8.94),5,6],
	AWNING: ["士多布篷",Vector3(-3.34,1.03,-9.64),1,2],
	PENDULUM: ["掛鐘銅擺",Vector3(4.45,11.72,-17.50),14,16],
	CLOCK_CASE: ["舊掛鐘頂",Vector3(4.45,16.17,-18.37),17,18],
	LEVEL: ["翹翹水平尺",Vector3(.70,9.31,-19.66),11,13],
	POLE: ["斜晾衫桿",Vector3(-2.16,16.87,-13.24),19,21],
	LIFT: ["走索吊籃",Vector3(-.35,17.05,-7.42),20,22],
	BOARD: ["裂紋木板",Vector3(-6.94,19.32,-6.78),22,24],
	SHEET: ["接人被單",Vector3(-6.94,17.32,-7.04),20,21],
	COIL: ["斜頭彈簧",Vector3(-4.35,18.02,-5.58),21,23],
}
const FORKS := {0:BED,4:DRAWER,6:TAPE,8:FAN,10:LEVEL,13:PENDULUM,18:POLE,19:LIFT,20:COIL,21:BOARD}
const LIFT_END := Vector3(-8.20,18.20,-5.65)
const DROP_AFTER := {DRAWER:1.6,BOARD:1.15}
var bodies := {}
var springs: Array[SpringPad] = []
var pendulum: PendulumClock
var level: SpiritLevel
var lift: LaundryLift
var tape: TapeMeasure
var timers := {}
var clock := 0.0
var fan_angle := 0.0

func build(art: Props, main: Array) -> void:
	for id: int in STOPS:
		var b: StaticBody3D
		if id in [BED,COIL]:
			b=SpringPad.new()
		elif id==TAPE:
			tape=TapeMeasure.new()
			b=tape
		elif id==PENDULUM:
			pendulum=PendulumClock.new()
			b=pendulum
		elif id==LEVEL:
			level=SpiritLevel.new()
			b=level
		elif id==LIFT:
			lift=LaundryLift.new()
			b=lift
		elif id==FAN:
			b=AnimatableBody3D.new()
		else:
			b=StaticBody3D.new()
		if b is AnimatableBody3D:
			b.sync_to_physics=false
			b.set_meta("mobile_surface",true)
		bodies[id]=b
		b.set_meta("ledge",id)
		art.add_child(b)
		b.position=STOPS[id][1]
		match id:
			TAPE:
				tape.build(art,main[STOPS[id][3]])
			LEVEL:
				level.build(art)
			BED,COIL:
				var spring:=b as SpringPad
				spring.build(art,main[STOPS[id][3]],id==BED)
				springs.append(spring)
			AWNING:
				build_awning(art,b)
			FAN:
				var hub:=art.cone(b,Vector3.DOWN*.08,.16,.46,.44,"e1a735",24)
				var axle:=CollisionShape3D.new()
				var shape:=CylinderShape3D.new()
				shape.radius=.44
				shape.height=.16
				axle.shape=shape
				b.add_child(axle)
				axle.position=hub.position
				art.cone(b,Vector3.DOWN*.45,.58,.25,.30,"45606a",20)
				for wing in 3:
					var yaw:=wing*TAU/3
					var root:=Vector3.RIGHT.rotated(Vector3.UP,yaw)
					art.solid(b,root*1.20+Vector3.DOWN*.072,Vector3(1.97,.13,.72),"319d9d" if wing%2==0 else "e59646",.06,yaw)
					art.box(b,root*1.95,Vector3(.13,.018,.64),"f1d79e",.006).rotation.y=yaw
			POLE:
				var axis := Vector3(-1,.21,.24).normalized()
				var collar := art.cone(b,Vector3.DOWN*.26,5.40,.27,.27,"4b939b",24)
				collar.quaternion=Quaternion(Vector3.UP,axis)
				var hit := CollisionShape3D.new()
				var shape := CylinderShape3D.new()
				shape.radius=.27
				shape.height=5.40
				hit.shape=shape
				b.add_child(hit)
				hit.transform=collar.transform
				for offset: float in [-2.45,-.30,1.95]:
					var band:=art.cone(b,collar.position+axis*offset,.13,.285,.285,"e1b34e",24)
					band.quaternion=collar.quaternion
			DRAWER,BOARD:
				b.set_meta("drop_surface",true)
				var width := 2.22 if id==DRAWER else 1.25
				var length := 1.54 if id==DRAWER else 2.54
				art.deck(b,Vector3(width,.17,length),"be8351" if id==DRAWER else "996445")
				for side: float in [-1,1]:
					if id==DRAWER:
						var panel_length:=length if side<0 else .36
						var panel_z:=0. if side<0 else .55
						art.solid(b,Vector3(side*1.05,.095,panel_z),Vector3(.12,.30,panel_length),"9e5f3d")
					art.box(b,Vector3(side*(width*.5-.14),.013,.28),Vector3(.13,.025,.80),"e4ad38").rotation.y=-.20
				for i in 3:
					art.box(b,Vector3(.04+i*.095,.012,-.41+i*.12),Vector3(.036,.016,.22),"513e31").rotation.y=.6 if i%2 else -.35
				if id==DRAWER:
					art.solid(b,Vector3(0,.045,length*.5),Vector3(width,.31,.14),"975f43")
					art.box(b,Vector3(0,.03,length*.5+.10),Vector3(.52,.09,.12),"c28f45")
				else:
					b.rotation.x=deg_to_rad(-12)
			LIFT:
				lift.build(art,LIFT_END)
			SHEET:
				art.deck(b,Vector3(2.64,.085,2.72),"668eb7")
				for side: float in [-1,1]:
					art.box(b,Vector3(side*1.19,.003,0),Vector3(.085,.012,2.71),"e5d8bd")
	pendulum.build(art,bodies[CLOCK_CASE])

func build_awning(art: Props, body: StaticBody3D) -> void:
	const WIDTH := 2.44
	const DEPTH := 1.70
	const STRIPES := 7
	body.rotation.x=deg_to_rad(12)
	var hit:=CollisionShape3D.new()
	var surface:=BoxShape3D.new()
	surface.size=Vector3(WIDTH,.06,DEPTH)
	hit.shape=surface
	hit.position.y=-surface.size.y*.5
	body.add_child(hit)
	var cloth:=SurfaceTool.new()
	cloth.begin(Mesh.PRIMITIVE_TRIANGLES)
	var fabric:=StandardMaterial3D.new()
	fabric.vertex_color_use_as_albedo=true
	fabric.cull_mode=BaseMaterial3D.CULL_DISABLED
	fabric.roughness=.9
	cloth.set_material(fabric)
	for i in STRIPES:
		cloth.set_color(Color("dc584c" if i%2==0 else "ffe5af").srgb_to_linear())
		var left:=Vector3(WIDTH*(float(i)/STRIPES-.5),0,DEPTH*.5)
		var right:=left+Vector3.RIGHT*(WIDTH/STRIPES)
		var back:=Vector3.FORWARD*DEPTH
		cloth.set_normal(Vector3.UP)
		for p: Vector3 in [left,left+back,right,right,left+back,right+back]: cloth.add_vertex(p)
		cloth.set_normal(Vector3.BACK)
		var mid:=(left+right)*.5+Vector3.DOWN*.24
		for p: Vector3 in [left,right,mid,left,mid,left+Vector3.DOWN*.14,right,right+Vector3.DOWN*.14,mid]: cloth.add_vertex(p)
	var skin:=MeshInstance3D.new()
	skin.mesh=cloth.commit()
	body.add_child(skin)
	art.tube(body,Vector3(-WIDTH*.52,-.06,-DEPTH*.5),Vector3(WIDTH*.52,-.06,-DEPTH*.5),.065,"477777")
	for x: float in [-WIDTH*.45,WIDTH*.45]:
		var hinge:=Vector3(x,-.42,-DEPTH*.5)
		art.tube(body,hinge,Vector3(x,-.055,DEPTH*.47),.034,"477777")
		art.tube(body,hinge,Vector3(x,-.055,-DEPTH*.5),.034,"477777")

func target(id: int) -> Vector3:
	var body: StaticBody3D=bodies[id]
	if id==LEVEL: return level.to_global(SpiritLevel.ENTRY)
	if id==FAN:
		var from_disc:=Vector3(2.84,0,3.68).normalized()
		var best_tip:=Vector3.ZERO
		var closest:=-2.
		for wing in 3:
			var tip:=Vector3.RIGHT.rotated(Vector3.UP,body.rotation.y+wing*TAU/3)
			if tip.dot(from_disc)>closest:
				closest=tip.dot(from_disc)
				best_tip=tip
		return body.position+best_tip*1.35
	if id==POLE: return body.position+Vector3(1.92,-.40,-.46)
	return body.position

func reset() -> void:
	tape.reset()
	pendulum.reset()
	level.reset()
	for spring in springs: spring.reset()
	clock=0
	fan_angle=0
	bodies[FAN].rotation.y=0
	timers.clear()
	for id: int in DROP_AFTER:
		var body: StaticBody3D=bodies[id]
		body.show()
		body.collision_layer=1
		body.position=STOPS[id][1]
		body.rotation=Vector3(deg_to_rad(-12) if id==BOARD else 0.,0,0)
	lift.advance(0.)

func land(id: int) -> void:
	if DROP_AFTER.has(id) and not timers.has(id): timers[id]=0.

func advance(delta: float, occupied: int, foot: Vector3) -> void:
	tape.advance(delta,occupied==TAPE,foot)
	pendulum.advance(delta)
	level.advance(delta,occupied==LEVEL,foot)
	for spring in springs: spring.advance(delta)
	fan_angle=fmod(fan_angle+delta*.50,TAU)
	bodies[FAN].rotation.y=fan_angle
	clock=fmod(clock+delta,LaundryLift.PERIOD)
	lift.advance(clock)
	for id: int in timers.keys():
		var t: float=timers[id]+delta
		var body: StaticBody3D=bodies[id]
		var limit: float=DROP_AFTER[id]
		var home: Vector3=STOPS[id][1]
		if t<limit:
			body.position=home+Vector3.RIGHT*(sin(t*42)*.026)
		elif t<limit+1.1:
			body.collision_layer=0
			var falling:=t-limit
			body.position=home+Vector3.DOWN*8*falling*falling
			if id==DRAWER:
				body.position+=Vector3(-.65,0,1.60)*smoothstep(.04,.63,falling)
			body.rotation.z=falling*.65
		elif t<limit+4.:
			body.hide()
		else:
			body.position=home
			body.rotation.z=0
			body.collision_layer=1
			body.show()
			timers.erase(id)
			continue
		timers[id]=t
