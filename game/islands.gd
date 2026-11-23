extends "res://game/props.gd"

# Position is the crown or usable centre of each object. Lower rises and
# shorter approaches on narrow objects fit the standing and running arcs.
const ROUTE := [
	Vector3(0,0,0),Vector3(2.2,.62,-4.45),Vector3(-.80,1.34,-7.48),
	Vector3(-4.63,2.10,-5.63),Vector3(-6.86,2.94,-9.40),Vector3(-3.47,3.78,-12.04),
	Vector3(.57,4.68,-11.13),Vector3(3.90,5.52,-13.85),Vector3(2.09,6.46,-17.87),
	Vector3(-2.12,7.35,-17.33),Vector3(-4.70,8.26,-20.42),Vector3(-1.72,9.22,-23.25),
	Vector3(2.42,10.16,-22.70),Vector3(5.12,11.03,-19.68),Vector3(8.00,11.88,-21.25),
	Vector3(10.95,12.80,-18.56),Vector3(9.42,13.72,-14.90),Vector3(5.62,14.64,-15.55),
	Vector3(3.04,15.55,-12.38),Vector3(-.65,16.38,-10.65),Vector3(-3.95,17.16,-8.72),
	Vector3(-7.0,18.06,-10.52),Vector3(-10.27,18.87,-8.46),Vector3(-10.62,19.72,-4.90),
	Vector3(-7.22,20.65,-3.00)
]
const Branches = preload("res://game/branch_routes.gd")
var branches := Branches.new()
var pickups := preload("res://game/pickups.gd").new()
var aerial: MeshInstance3D
var platter:=preload("res://game/record_platter.gd").new()
const LAUNDRY_START := 18
const PREVIOUS_HEIGHTS := [0.,1.35,3.05,4.95,7.05,9.1,11.25,13.5,15.75,17.95,20.25,22.65,25.,27.1,29.25,31.45,33.65,35.85,38.]
const NAMES := ["士多天台","絲絨梳化","木茶几","膽機電視","皮喼","波鞋鞋底","錄音帶","手提音響","黑膠唱盤","電子琴","古董相機","滑板","玩具跑車","碼頭繫纜柱","貨櫃","橫放電纜轆","吊臂鋼樑","三角形郵筒紙盒","失物招領枱","熨衫板","木衣夾","滾筒洗衣機","晾衫架","鋁摺梯","天台太陽傘"]
const SOFA = preload("res://assets/props/sofa.glb")
const SHOE = preload("res://assets/props/sneaker.glb")
const STEREO = preload("res://assets/props/boombox.glb")
const CAMERA = preload("res://assets/props/camera.glb")
const CAR = preload("res://assets/props/car.glb")
const CITY := [preload("res://assets/city/building-small-a.glb"),preload("res://assets/city/building-small-c.glb"),preload("res://assets/city/building-small-d.glb"),preload("res://assets/city/building-garage.glb")]
const ROAD = preload("res://assets/city/road-straight-lightposts.glb")
const CROSSING = preload("res://assets/city/road-intersection.glb")

func _ready() -> void:
	var laundry := preload("res://game/laundry.gd").new(self)
	for index in ROUTE.size():
		var body := StaticBody3D.new()
		body.set_meta("ledge",index)
		add_child(body)
		body.position = ROUTE[index]
		match index:
			0: rooftop(body)
			1: model_prop(body,SOFA,4.25,Vector3(0,-80,0))
			2: coffee_table(body)
			3:
				television(body)
				var base:=Vector3(.22,.02,-.76)
				box(body,base,Vector3(.44,.08,.22),"484e52")
				for x: float in [-.14,.14]:
					tube(body,base+Vector3.RIGHT*x,base+Vector3(x*.6,1.39,-.14),.027,"adbac0")
				aerial=rim(body,base+Vector3(0,1.63,-.14),.29,.068,"e4a842")
				aerial.rotation.x=PI/2
			4: suitcase(body)
			5: model_prop(body,SHOE,4.22,Vector3(0,10,180))
			6: cassette(body)
			7: model_prop(body,STEREO,3.8,Vector3(0,-85,0))
			8:
				turntable(body)
				body.add_child(platter)
				platter.build(self)
			9: keyboard(body)
			10: model_prop(body,CAMERA,3.1,Vector3(0,30,0))
			11: skateboard(body)
			12: model_prop(body,CAR,4.05,Vector3(0,28,0))
			13: bollard(body)
			14: container(body)
			15:
				body.rotation.y=deg_to_rad(70)
				cable_reel(body)
			16: girder(body)
			17: parcel(body)
			18: finish_counter(body)
			19:
				body.rotation.y=deg_to_rad(26)
				laundry.ironing_board(body)
			20:
				body.rotation.y=deg_to_rad(18)
				laundry.clothes_peg(body)
			21:
				body.rotation.y=deg_to_rad(28)
				laundry.washer(body)
			22:
				body.rotation.y=deg_to_rad(-22)
				laundry.drying_rack(body)
			23:
				body.rotation.y=deg_to_rad(-30)
				laundry.folding_ladder(body)
			24: laundry.parasol(body)
	branches.build(self,ROUTE)
	pickups.build(self,branches.bodies)
	city()
	crane()
	skyline()

func stage(id: int) -> int:
	return Branches.STOPS[id][2] if Branches.STOPS.has(id) else id

func stop_name(id: int) -> String:
	return Branches.STOPS[id][0] if Branches.STOPS.has(id) else NAMES[id]

func landing_sound(id: int) -> AudioStream:
	match id:
		1,4,5,19,24,Branches.BED,Branches.AWNING,Branches.SHEET:
			return preload("res://audio/land-fabric.wav")
		2,11,18,20,Branches.DRAWER,Branches.BOARD,Branches.LIFT,Branches.CLOCK_CASE:
			return preload("res://audio/land-wood.wav")
		12,13,14,16,21,22,23,Branches.FAN,Branches.POLE,Branches.COIL,Branches.PENDULUM,Branches.LEVEL,Branches.TAPE:
			return preload("res://audio/land-metal.wav")
	return preload("res://audio/land.wav")

func destination(id: int, alternate: bool) -> int:
	if alternate and Branches.FORKS.has(id): return Branches.FORKS[id]
	if Branches.STOPS.has(id): return Branches.STOPS[id][3]
	return id+1 if id+1<ROUTE.size() else -1

func stop_position(id: int) -> Vector3:
	if id==8: return platter.global_position+Vector3.UP*platter.TOP
	return branches.target(id) if Branches.STOPS.has(id) else ROUTE[id]

func model_prop(body: StaticBody3D, scene: PackedScene, span: float, angles: Vector3) -> void:
	var pivot := Node3D.new()
	body.add_child(pivot)
	var model: Node3D = scene.instantiate()
	for kind in ["Camera3D","Light3D"]:
		for extra in model.find_children("*",kind,true,false): extra.free()
	pivot.add_child(model)
	pivot.rotation_degrees = angles
	var triangles := PackedVector3Array()
	var bounds := AABB()
	for node: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		var relative := body.global_transform.affine_inverse()*node.global_transform
		var points := relative*node.mesh.get_faces()
		for p in points:
			if triangles.is_empty(): bounds = AABB(p,Vector3.ZERO)
			else: bounds = bounds.expand(p)
			triangles.append(p)
	var factor := span / maxf(bounds.size.x,bounds.size.z)
	for i in triangles.size(): triangles[i] *= factor
	var center := bounds.get_center()*factor
	var ray := Vector3(center.x,bounds.end.y*factor+1.0,center.z)
	var top := -INF
	for i in range(0,triangles.size(),3):
		var hit = Geometry3D.ray_intersects_triangle(ray,Vector3.DOWN,triangles[i],triangles[i+1],triangles[i+2])
		if hit == null:
			hit = Geometry3D.ray_intersects_triangle(ray,Vector3.DOWN,triangles[i+2],triangles[i+1],triangles[i])
		if hit != null: top = maxf(top,hit.y)
	if not is_finite(top): top = bounds.end.y*factor
	pivot.scale = Vector3.ONE*factor
	pivot.position = -Vector3(center.x,top,center.z)
	for i in triangles.size():
		triangles[i] += pivot.position
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(triangles)
	shape.backface_collision = true
	var hit := CollisionShape3D.new()
	hit.shape = shape
	body.add_child(hit)

func rooftop(b: StaticBody3D) -> void:
	var roof := solid(b,Vector3.DOWN*.18,Vector3(7.65,.36,5.36),"91a49b")
	var concrete := ShaderMaterial.new()
	concrete.shader=preload("res://game/rooftop.gdshader")
	roof.material_override=concrete
	# A flush drain and hazard paint leave the entire takeoff lane usable.
	box(b,Vector3(2.81,.01,.89),Vector3(.64,.023,.78),"485758")
	for i in 7:
		box(b,Vector3(2.81,.027,.59+i*.10),Vector3(.55,.017,.039),"8c9990")
	for i in 7:
		box(b,Vector3(.40+i*.405,.015,-2.36),Vector3(.13,.016,.40),"ddad60").rotation.y=-.48
	box(b,Vector3(0,-5.17,0),Vector3(7.38,9.8,5.10),"c39272",.10)
	for j in 4:
		for i in 4:
			var p := Vector3((i-1.5)*1.66,-1.51-j*2.1,2.56)
			box(b,p,Vector3(1.16,1.38,.08),"e1c7a2")
			box(b,p+Vector3.BACK*.06,Vector3(.97,1.18,.08),"55777c")
			box(b,p+Vector3.BACK*.12,Vector3(.05,1.15,.03),"b9c2ac")
	# End the parapet before the trampoline frame, clear of the sagging fabric.
	solid(b,Vector3(-3.53,.22,.5),Vector3(.25,.44,3.97),"c3b59b")
	for i in 9:
		box(b,Vector3((i-4)*.72,-2.41,3.0),Vector3(.73,.13,1.20),"b95843" if i%2==0 else "e5cd9f").rotation.x=.20
	box(b,Vector3(-.11,-.93,2.66),Vector3(5.90,.85,.18),"245d61")
	label(b,Vector3(-.11,-.91,2.77),"LOST PROPERTY",.52,"ffdea4")
	# Printed loading-bay markings give the starting roof a sense of scale.
	for i in 5:
		box(b,Vector3(-2.55+i*1.14,.009,1.99),Vector3(.78,.016,.10),"d9c992")
	label(b,Vector3(-1.98,.013,.16),"DEPOT",.41,"e8ddb9",true).rotation.y=PI/2

func finish_counter(b: StaticBody3D) -> void:
	deck(b,Vector3(3.55,.27,2.45),"a46f49")
	box(b,Vector3(0,-.84,0),Vector3(3.27,1.49,2.18),"2f6264")
	box(b,Vector3(0,-.81,1.103),Vector3(2.60,.72,.08),"e0c99e")
	label(b,Vector3(0,-.81,1.151),"LOST & FOUND",.30,"30595a")
	var p := Vector3(.97,.07,-.61)
	cone(b,p,.12,.48,.48,"3f4441")
	var dome := SphereMesh.new()
	dome.radius=.38
	dome.height=.76
	piece(b,dome,p+Vector3.UP*.06,"d5a24e").scale.y=.77
	cone(b,p+Vector3.UP*.40,.11,.09,.09,"e7bc69")
	label(b,Vector3(-.60,.015,-.36),"ARRIVALS",.22,"f6dfb6",true)

# Batch repeated scenery by mesh, so a whole street of the same building
# costs one draw per material instead of one per address.
func streetscape(scene: PackedScene, instances: Array[Transform3D]) -> void:
	if instances.is_empty(): return
	var template: Node3D = scene.instantiate()
	add_child(template)
	for part: MeshInstance3D in template.find_children("*","MeshInstance3D",true,false):
		var batch := MultiMesh.new()
		batch.transform_format=MultiMesh.TRANSFORM_3D
		batch.mesh=part.mesh
		batch.instance_count=instances.size()
		for i in instances.size(): batch.set_instance_transform(i,instances[i]*part.global_transform)
		var node := MultiMeshInstance3D.new()
		node.multimesh=batch
		var source := part.mesh.surface_get_material(0) as StandardMaterial3D
		if source and part.mesh.get_surface_count()==1:
			var faded := source.duplicate() as StandardMaterial3D
			faded.albedo_color *= Color("a7a9ad")
			node.material_override = faded
		node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(node)
	template.free()

func city() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed=10296
	var streets: Array[Transform3D]=[]
	var crossings: Array[Transform3D]=[]
	var blocks := [[],[],[],[]]
	# Road GLBs have upward-facing asphalt at local Y=0. Leave real depth
	# clearance to the backing plane across the entire tiled district.
	box(self,Vector3(0,-12.38,-13),Vector3(310,.4,310),"889697")
	for x in range(-7,8):
		for z in range(-8,7):
			var p := Vector3(x*7.0,-11.9,z*7.0)
			var road_x := posmod(x,3)==1
			var road_z := posmod(z,3)==1
			var angle := 0.0
			if road_x or road_z:
				if road_z and not road_x: angle=PI/2
				var floor_tile := Transform3D(Basis(Vector3.UP,angle).scaled(Vector3.ONE*7.0),p)
				if road_x and road_z: crossings.append(floor_tile)
				else: streets.append(floor_tile)
			else:
				if x==0 and z==0: continue
				var kind := rng.randi_range(0,3)
				if abs(x)<=2 and z>=-5 and z<=0: kind=0 if kind==1 else kind
				var scale_y := rng.randf_range(0.82,1.26)
				if absi(x)>3 or z<-5: scale_y *= rng.randf_range(1.0,1.8)
				var basis := Basis(Vector3.UP,rng.randi_range(0,3)*PI/2).scaled(Vector3(6.72,6.3*scale_y,6.72))
				blocks[kind].append(Transform3D(basis,p))
	streetscape(ROAD,streets)
	streetscape(CROSSING,crossings)
	for i in CITY.size():
		var transforms: Array[Transform3D]=[]
		transforms.assign(blocks[i])
		streetscape(CITY[i],transforms)

func crane() -> void:
	var p := Vector3(22,-10,-35)
	var steel := "bf8453"
	for x in [-.60,.60]:
		for z in [-.60,.60]: tube(self,p+Vector3(x,0,z),p+Vector3(x,38,z),.095,steel)
	for i in 19:
		var a := p+Vector3(-.60,2*i,.60)
		tube(self,a,a+Vector3(1.2,2,0),.06,steel)
		tube(self,a+Vector3(1.2,0,-1.2),a+Vector3(1.2,2,0),.06,steel)
	for z in [-.54,.54]:
		tube(self,p+Vector3(-12,37,z),p+Vector3(4,37,z),.12,steel)
		tube(self,p+Vector3(-12,38,z),p+Vector3(4,38,z),.10,steel)
		for i in 8:
			tube(self,p+Vector3(-12+i*2,37,z),p+Vector3(-11+i*2,38,z),.063,steel)
			tube(self,p+Vector3(-11+i*2,38,z),p+Vector3(-10+i*2,37,z),.063,steel)
	tube(self,p+Vector3(-10,37,0),p+Vector3(-10,31,0),.034,"50616b")
	box(self,p+Vector3(3,36.5,0),Vector3(2.6,1.6,1.8),"78918d",.12)

func skyline() -> void:
	var towers: Array[Transform3D] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 3871
	for i in 120:
		var angle := i*TAU/120
		var radius := rng.randf_range(52,90)
		var x := cos(angle)*radius
		var z := sin(angle)*radius-12
		var h := rng.randf_range(8,29)
		var width := rng.randf_range(3.2,6.3)
		towers.append(Transform3D(Basis().scaled(Vector3(width,h,width*.83)),Vector3(x,h/2-11.9,z)))
		if i%3==0: towers.append(Transform3D(Basis().scaled(Vector3(width*.7,3.1,width*.62)),Vector3(x,h-10.4,z)))
	var batch := MultiMesh.new()
	batch.transform_format=MultiMesh.TRANSFORM_3D
	batch.mesh=BoxMesh.new()
	batch.instance_count=towers.size()
	for i in towers.size(): batch.set_instance_transform(i,towers[i])
	var blocks := MultiMeshInstance3D.new()
	blocks.multimesh=batch
	var glass := ShaderMaterial.new()
	glass.shader=preload("res://game/skyline.gdshader")
	blocks.material_override=glass
	blocks.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(blocks)
