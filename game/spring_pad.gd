extends StaticBody3D

const Props = preload("res://game/props.gd")
const SINK_TIME := .13
const RELEASE_TIME := .21
const MAX_STROKE := .27
const RIM_HEIGHT := .14
const CLOTH_STEPS := 20
const COIL_HEIGHT := .77

var loading := false
var impulse := Vector3.ZERO
var trigger_radius: float
var destination: Vector3
var elapsed := 0.
var stroke := 0.
var plate := Node3D.new()
var hit := CollisionShape3D.new()
var flex := MeshInstance3D.new()
var cloth_shapes: Array[ConcavePolygonShape3D] = []

func build(art: Props, target: Vector3, bed: bool) -> void:
	destination=target
	trigger_radius=.27 if bed else .215
	add_child(plate)
	add_child(hit)
	add_child(flex)
	if bed: build_bed(art)
	else: build_coil(art)
	art.rim(plate,Vector3.UP*.012,trigger_radius,.043,"ffc553")
	art.cone(plate,Vector3.UP*.012,.018,.063,.063,"fcdf87",16)
	set_depth(0.)

func build_bed(art: Props) -> void:
	var cloth:=SurfaceTool.new()
	cloth.begin(Mesh.PRIMITIVE_TRIANGLES)
	cloth.set_material(art.material("345f64"))
	for i in 32:
		var a:=Vector3(cos(i*TAU/32.),0,sin(i*TAU/32.))
		var b:=Vector3(cos((i+1)*TAU/32.),0,sin((i+1)*TAU/32.))
		var inner:=a*.58
		var next:=b*.58
		var rim:=a*.93+Vector3.UP*RIM_HEIGHT
		var rim_next:=b*.93+Vector3.UP*RIM_HEIGHT
		for vertex: Vector3 in [Vector3.ZERO,inner,next,inner,rim,rim_next,inner,rim_next,next]:
			cloth.set_normal(Vector3.UP)
			cloth.add_vertex(vertex)
	flex.mesh=cloth.commit()
	# Precompute the collision poses once. The visible fabric uses the same
	# depth, with its outer seam pinned to the frame through the whole stroke.
	for step in CLOTH_STEPS+1:
		var depth:=MAX_STROKE*step/CLOTH_STEPS
		var faces:=flex.mesh.get_faces()
		for i in faces.size():
			faces[i].y-=depth*(1.-faces[i].y/RIM_HEIGHT)
		var shape:=ConcavePolygonShape3D.new()
		shape.set_faces(faces)
		cloth_shapes.append(shape)
	art.rim(self,Vector3.UP*RIM_HEIGHT,.98,.073,"e9ac42")
	for i in 4:
		var leg:=Vector3(cos(i*PI/2),0,sin(i*PI/2))*.75
		art.tube(self,leg+Vector3.UP*.11,leg+Vector3.DOWN*.55,.055,"678782")

func build_coil(art: Props) -> void:
	var forward:=global_position.direction_to(destination).slide(Vector3.UP).normalized()
	quaternion=Quaternion(Vector3.UP,(Vector3.UP+forward*tan(deg_to_rad(10))).normalized())
	art.cone(plate,Vector3.DOWN*.055,.11,.52,.52,"b4c8bf",32)
	var cap:=CylinderShape3D.new()
	cap.radius=.52
	cap.height=.11
	hit.shape=cap
	art.box(self,Vector3.DOWN*.95,Vector3(.95,.16,.95),"5a6d6c")
	# One wound steel rod, fixed to the base at the bottom.
	var wire:=SurfaceTool.new()
	wire.begin(Mesh.PRIMITIVE_TRIANGLES)
	wire.set_material(art.material("c45b39"))
	const SEGMENTS := 88
	const SIDES := 8
	var previous:=PackedVector3Array()
	for i in SEGMENTS+1:
		var t:=float(i)/SEGMENTS
		var angle:=t*5.5*TAU
		var radial:=Vector3(cos(angle),0,sin(angle))
		var center:=radial*.35+Vector3.UP*(COIL_HEIGHT*t)
		var tangent:=Vector3(-sin(angle),COIL_HEIGHT/(5.5*TAU*.35),cos(angle)).normalized()
		var up:=tangent.cross(radial)
		var ring:=PackedVector3Array()
		for side in SIDES:
			var phi:=TAU*side/SIDES
			ring.append(center+.042*(radial*cos(phi)+up*sin(phi)))
		if not previous.is_empty():
			for side in SIDES:
				var next:=(side+1)%SIDES
				for v: Vector3 in [previous[side],ring[side],ring[next],previous[side],ring[next],previous[next]]:
					wire.add_vertex(v)
		previous=ring
	wire.generate_normals()
	wire.index()
	flex.mesh=wire.commit()
	flex.position.y=-.87

func start_stroke(foot: Vector3, incoming: Vector3, gravity: float) -> bool:
	var local:=to_local(foot)
	if loading or Vector2(local.x,local.z).length()>trigger_radius: return false
	var impact:=-incoming.dot(global_basis.y)
	if impact<.7: return false
	stroke=clampf(.12+.018*impact,.13,MAX_STROKE)
	# A preloaded launcher has a fixed heading. A harder landing gives a
	# little more lift, and some of the approach momentum survives takeoff.
	var offset:=destination-global_position
	var launch_speed:=9.3
	var flight:=(launch_speed+sqrt(launch_speed*launch_speed-2.*gravity*offset.y))/gravity
	var strength:=clampf(.96+.009*impact,.97,1.04)
	impulse=Vector3(offset.x/flight,launch_speed,offset.z/flight)*strength
	impulse+=incoming.slide(Vector3.UP).limit_length(5.)*.10
	elapsed=0.
	loading=true
	return true

func advance(delta: float) -> void:
	if not loading: return
	elapsed+=delta
	if elapsed>=RELEASE_TIME:
		# Let the character solve the restored surface before firing. On a
		# pitched cap, overlap recovery can otherwise register a second floor.
		if is_zero_approx(plate.position.y): loading=false
		else: set_depth(0.)
	elif elapsed<SINK_TIME:
		set_depth(stroke*sin(.5*PI*elapsed/SINK_TIME))
	else:
		set_depth(stroke*cos(.5*PI*(elapsed-SINK_TIME)/(RELEASE_TIME-SINK_TIME)))

func reset() -> void:
	loading=false
	elapsed=0.
	stroke=0.
	impulse=Vector3.ZERO
	set_depth(0.)

func load_fraction() -> float:
	return clampf(-plate.position.y/stroke,0.,1.) if stroke>0. else 0.

func set_depth(depth: float) -> void:
	if cloth_shapes.is_empty():
		hit.position.y=-.055-depth
		flex.scale.y=1.-depth/COIL_HEIGHT
	else:
		var step:=roundi(depth/MAX_STROKE*CLOTH_STEPS)
		depth=MAX_STROKE*step/CLOTH_STEPS
		hit.shape=cloth_shapes[step]
		flex.position.y=-depth
		flex.scale.y=1.+depth/RIM_HEIGHT
	plate.position.y=-depth
