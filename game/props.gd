extends Node3D

# The upper face of each load-bearing deck sits at local y=0. Smaller fittings
# are visual. Imported props get their collision directly from their visible mesh.
var materials := {}
var bevel_meshes := {}

func material(tint: String) -> StandardMaterial3D:
	if not materials.has(tint):
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(tint)
		mat.roughness = 0.78
		materials[tint] = mat
	return materials[tint]

func piece(parent: Node3D, mesh: Mesh, pos: Vector3, tint: String) -> MeshInstance3D:
	var item := MeshInstance3D.new()
	item.mesh = mesh
	item.material_override = material(tint)
	parent.add_child(item)
	item.position = pos
	return item

func box(parent: Node3D, pos: Vector3, size: Vector3, tint: String, bevel := 0.035) -> MeshInstance3D:
	var key := Vector4(size.x,size.y,size.z,bevel)
	if not bevel_meshes.has(key):
		bevel_meshes[key] = rounded_box(size,bevel)
	return piece(parent,bevel_meshes[key],pos,tint)

func rounded_box(size: Vector3, radius: float) -> ArrayMesh:
	var half := size / 2
	var r := minf(radius,minf(half.x,minf(half.y,half.z))*0.87)
	var inner := half - Vector3.ONE*r
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for face in 3:
		var u := (face+1)%3
		var v := (face+2)%3
		var us := [-half[u],-inner[u]-r*.55,-inner[u],inner[u],inner[u]+r*.55,half[u]]
		var vs := [-half[v],-inner[v]-r*.55,-inner[v],inner[v],inner[v]+r*.55,half[v]]
		for sign_value in [-1,1]:
			var order := [0,1,3,0,3,2] if sign_value < 0 else [0,3,1,0,2,3]
			for i in 5:
				for j in 5:
					for corner: int in order:
						var p := Vector3.ZERO
						p[face] = sign_value*half[face]
						p[u] = us[i+(corner%2)]
						p[v] = vs[j+(corner>>1)]
						var core := p.clamp(-inner,inner)
						var normal := (p-core).normalized()
						st.set_normal(normal)
						st.add_vertex(core+normal*r)
	st.index()
	return st.commit()

func cone(parent: Node3D, pos: Vector3, h: float, lower: float, upper: float, tint: String, sides := 32) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.height = h
	mesh.bottom_radius = lower
	mesh.top_radius = upper
	mesh.radial_segments = sides
	mesh.rings = 0
	return piece(parent,mesh,pos,tint)

func tube(parent: Node3D, a: Vector3, b: Vector3, radius: float, tint: String) -> void:
	var item := cone(parent,(a+b)/2,a.distance_to(b),radius,radius,tint,12)
	item.quaternion = Quaternion(Vector3.UP,a.direction_to(b))

func rim(parent: Node3D, p: Vector3, radius: float, width: float, tint: String) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = radius-width
	mesh.outer_radius = radius
	mesh.rings = 48
	mesh.ring_segments = 6
	return piece(parent,mesh,p,tint)

func label(parent: Node3D, p: Vector3, words: String, height: float, tint: String, flat := false) -> Label3D:
	var text := Label3D.new()
	text.text = words
	text.font_size = 48
	text.outline_size = 0
	text.pixel_size = height/48
	text.modulate = Color(tint)
	text.double_sided = false
	text.alpha_cut = Label3D.ALPHA_CUT_DISCARD
	parent.add_child(text)
	text.position = p
	if flat: text.rotation.x = -PI/2
	return text

func solid(body: StaticBody3D, p: Vector3, size: Vector3, tint: String, bevel := 0.06, yaw := 0.) -> MeshInstance3D:
	var item := box(body,p,size,tint,bevel)
	item.rotation.y=yaw
	var hit := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	hit.shape = shape
	body.add_child(hit)
	hit.position = p
	hit.rotation.y=yaw
	return item

func deck(body: StaticBody3D, size: Vector3, tint: String, bevel := 0.06) -> void:
	solid(body,Vector3.DOWN*size.y/2,size,tint,bevel)

func wheels(body: Node3D, span: Vector2, y: float, r: float, tint: String) -> void:
	for a in [-1,1]:
		tube(body,Vector3(-span.x,y,a*span.y),Vector3(span.x,y,a*span.y),r*0.25,"797f7c")
		for b in [-1,1]:
			var p := Vector3(b*span.x,y,a*span.y)
			cone(body,p,r*0.85,r,r,tint,20).rotation.z = PI/2
			cone(body,p+Vector3.RIGHT*b*r*0.44,0.025,r*0.43,r*0.43,"49535a",16).rotation.z = PI/2

func footstool(b: StaticBody3D) -> void:
	# One upholstered cushion, with a darker piping seam and four tapered feet.
	deck(b,Vector3(3.14,.33,2.34),"339487",.16)
	box(b,Vector3.DOWN*.35,Vector3(3.04,.14,2.24),"215e58",.065)
	box(b,Vector3.DOWN*.46,Vector3(2.87,.21,2.09),"347c71",.095)
	for x: float in [-1.19,1.19]:
		for z: float in [-.82,.82]:
			cone(b,Vector3(x,-.70,z),.34,.092,.14,"9c714a",16)
	for x: float in [-.74,0.,.74]:
		for z: float in [-.49,.49]:
			cone(b,Vector3(x,.003,z),.012,.046,.038,"276e65",16)

func coffee_table(b: StaticBody3D) -> void:
	deck(b,Vector3(3.12,.19,2.87),"95613f",.095)
	box(b,Vector3(0,-.17,0),Vector3(2.98,.15,2.68),"533d32")
	# The pull-out tray beneath the far edge still catches a missed lift.
	solid(b,Vector3(.74,-.17,-1.79),Vector3(1.60,.13,.86),"bd8352",.045)
	for x in [-1,1]:
		for z in [-1,1]:
			tube(b,Vector3(x*1.19,-.18,z*1.05),Vector3(x*1.40,-1.36,z*1.23),.085,"6c4435")
	box(b,Vector3(-1.14,0.039,0.48),Vector3(0.69,0.066,0.83),"d45c44").rotation.y = -0.16
	label(b,Vector3(-1.13,0.077,0.49),"FORM",0.16,"fff0c7",true).rotation.y = -0.16

func television(b: StaticBody3D) -> void:
	deck(b,Vector3(3.15,2.05,1.91),"af7250",0.15)
	box(b,Vector3(0,-1.02,0.91),Vector3(3.0,1.91,0.28),"393e42",0.13)
	box(b,Vector3(-0.28,-1.0,1.055),Vector3(2.14,1.48,0.18),"93b5aa",0.17)
	for j in 12:
		box(b,Vector3(-0.28,-0.4-j*0.108,1.15),Vector3(1.90,0.012,0.008),"779d99")
	for j in 2:
		cone(b,Vector3(1.13,-0.51-j*0.46,1.08),0.15,0.14,0.14,"c0b696",20).rotation.x=PI/2
	for j in 6:
		box(b,Vector3(1.11,-1.39-j*0.056,1.06),Vector3(0.43,0.022,0.025),"a5997e")
	for j in 8:
		box(b,Vector3(0.94+j*0.063,0.007,-0.39),Vector3(0.028,0.012,0.63),"614f46")

func suitcase(b: StaticBody3D) -> void:
	deck(b,Vector3(3.7,0.87,2.50),"ad653e",0.16)
	box(b,Vector3(0,-0.39,0),Vector3(3.72,0.055,2.52),"6a4332",0.14)
	for x in [-1,1]:
		box(b,Vector3(x*1.11,-0.421,0),Vector3(0.20,0.90,2.53),"664535",0.065)
		box(b,Vector3(x*1.11,-0.32,1.29),Vector3(0.25,0.22,0.07),"e3b565")
	tube(b,Vector3(-0.34,-0.51,1.26),Vector3(-0.34,-0.51,1.48),0.059,"5c4034")
	tube(b,Vector3(0.34,-0.51,1.26),Vector3(0.34,-0.51,1.48),0.059,"5c4034")
	tube(b,Vector3(-0.34,-0.51,1.48),Vector3(0.34,-0.51,1.48),0.078,"523b32")
	box(b,Vector3(-0.44,0.011,0.42),Vector3(0.94,0.016,.52),"e3c58b").rotation.y=-.16
	label(b,Vector3(-0.44,0.026,0.42),"MACAU",0.20,"586369",true).rotation.y=-.16

func cassette(b: StaticBody3D) -> void:
	deck(b,Vector3(3.80,0.31,2.22),"343940",0.13)
	box(b,Vector3(0,0.016,-0.10),Vector3(3.30,0.037,1.66),"e7d7ac")
	box(b,Vector3(0,0.045,-0.56),Vector3(3.23,0.023,0.29),"cb664c")
	box(b,Vector3(0,0.044,0.08),Vector3(2.53,0.03,0.68),"4e5350",0.08)
	for x in [-0.88,0.88]:
		cone(b,Vector3(x,0.069,0.08),0.03,.268,.268,"e1d5af")
		cone(b,Vector3(x,0.092,0.08),0.028,.13,.13,"323c42",8)
	label(b,Vector3(0,0.065,-0.57),"SIDE A    /    60",0.18,"fff0c9",true)

func speaker(b: StaticBody3D, top: Vector3) -> void:
	solid(b,top+Vector3.DOWN*.73,Vector3(2.48,1.46,2.40),"a36842",.085)
	box(b,top+Vector3(0,-.75,1.19),Vector3(2.31,1.30,.08),"383e3c",.045)
	for x: float in [-.55,.55]:
		var face:=top+Vector3(x,-.76,1.25)
		cone(b,face,.08,.48,.48,"232d30",28).rotation.x=PI/2
		cone(b,face+Vector3.BACK*.056,.07,.36,.22,"536264",24).rotation.x=PI/2
		cone(b,face+Vector3.BACK*.10,.06,.15,.11,"d2a75d",20).rotation.x=PI/2

func turntable(b: StaticBody3D) -> void:
	deck(b,Vector3(3.65,0.42,2.85),"a4513e",0.11)
	box(b,Vector3(0,-0.04,0),Vector3(3.5,0.11,2.67),"d1b994")
	tube(b,Vector3(1.40,.23,-0.91),Vector3(1.32,.24,0.52),.047,"b7c5c0")
	tube(b,Vector3(1.32,.24,0.52),Vector3(0.78,.18,0.77),.05,"bcc7c1")
	box(b,Vector3(.77,.16,.77),Vector3(.22,.12,.16),"403e3f")
	cone(b,Vector3(1.43,.05,1.03),.12,.105,.105,"554a43")

func skateboard(b: StaticBody3D) -> void:
	deck(b,Vector3(1.65,0.16,4.05),"b98452",0.19)
	box(b,Vector3(0,.010,0),Vector3(1.58,.040,3.95),"455253",0.18)
	for z in [-1,1]:
		box(b,Vector3(0,.133,z*1.98),Vector3(1.58,.15,.56),"cb7d46",0.17).rotation.x=-z*.42
		for x in [-.22,.22]: cone(b,Vector3(x,.038,z*1.18),.019,.045,.045,"c1bfab",12)
	wheels(b,Vector2(.65,1.16),-.35,.244,"dbab63")

func bollard(b: StaticBody3D) -> void:
	# A narrow cap, with a flared lip wide enough for one foot.
	cone(b,Vector3.DOWN*.12,.24,.53,.54,"b68142")
	cone(b,Vector3.DOWN*1.11,1.9,.39,.33,"365c61")
	cone(b,Vector3.DOWN*2.12,.20,.66,.55,"ac814f")
	for j in 3: rim(b,Vector3.DOWN*(.45+j*.13),.40,.075,"a18865")
	var hit := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.height=.25
	cylinder.radius=.54
	hit.shape=cylinder
	b.add_child(hit)
	hit.position.y=-.125

func container(b: StaticBody3D) -> void:
	deck(b,Vector3(4.17,1.76,2.21),"367477")
	for j in 16:
		for z in [-1,1]: box(b,Vector3((j-7.5)*.244,-.88,z*1.105),Vector3(.07,1.6,.08),"4f8989")
		box(b,Vector3((j-7.5)*.244,0.016,0),Vector3(.065,.034,2.02),"5f9290")
	box(b,Vector3(-.87,-.80,1.16),Vector3(1.9,.61,.05),"315e62")
	label(b,Vector3(-.87,-.80,1.2),"PORT  07",.27,"e5d4aa")

func reel_section(body: StaticBody3D, center: Vector3, radius: float, length: float, tint: String) -> void:
	var wheel := cone(body,center,length,radius,radius,tint,48)
	wheel.rotation.z=PI/2
	var shape := CylinderShape3D.new()
	shape.radius=radius
	shape.height=length
	var collider := CollisionShape3D.new()
	collider.shape=shape
	body.add_child(collider)
	collider.transform=wheel.transform

func cable_reel(b: StaticBody3D) -> void:
	var axle := Vector3.DOWN*1.08
	reel_section(b,axle,1.08,2.48,"435457")
	for side in [-1,1]:
		reel_section(b,axle+Vector3.RIGHT*side*1.23,1.24,.17,"b38a5d")
		cone(b,axle+Vector3.RIGHT*side*1.33,.06,.22,.22,"77614e").rotation.z=PI/2
	for i in 10:
		rim(b,axle+Vector3.RIGHT*(i-4.5)*.22,1.09,.043,"5c6c6b").rotation.z=PI/2

func girder(b: StaticBody3D) -> void:
	deck(b,Vector3(4.55,.16,.76),"ca6b40")
	box(b,Vector3(0,-.54,0),Vector3(4.52,.83,.17),"ad5134")
	box(b,Vector3(0,-.98,0),Vector3(4.55,.16,.76),"cb7949")
	for x in [-1.82,-1.36,1.36,1.82]:
		for z in [-.23,.23]: cone(b,Vector3(x,.025,z),.05,.087,.087,"735444",6)

func parcel(b: StaticBody3D) -> void:
	# A triangular cardboard mailing tube. Both visible slopes and its ridge
	# come from the same vertices used to build its convex collision hull.
	var points := PackedVector3Array([
		Vector3(-1.70,-.68,-1.15),Vector3(-1.70,0,0),Vector3(-1.70,-.68,1.15),
		Vector3(1.70,-.68,-1.15),Vector3(1.70,0,0),Vector3(1.70,-.68,1.15)])
	var faces := [[0,2,1],[3,4,5],[0,1,4],[0,4,3],[1,2,5],[1,5,4],[2,0,3],[2,3,5]]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var inside := Vector3(0,-.45,0)
	for face in faces:
		var a := points[face[0]]
		var c := points[face[1]]
		var d := points[face[2]]
		var n := (d-a).cross(c-a).normalized()
		if n.dot((a+c+d)/3-inside)<0.0:
			var tmp:=d
			d=c
			c=tmp
			n=-n
		for vertex in [a,c,d]:
			st.set_normal(n)
			st.add_vertex(vertex)
	piece(b,st.commit(),Vector3.ZERO,"cda477")
	var hull := ConvexPolygonShape3D.new()
	hull.points=points
	var hit := CollisionShape3D.new()
	hit.shape=hull
	b.add_child(hit)
	var slope := atan(.68/1.15)
	for side in [-1,1]:
		var band := box(b,Vector3(.62,-.327,side*.575),Vector3(.23,.018,1.33),"ad8552",.004)
		band.rotation.x=side*slope
	var tag := box(b,Vector3(-.64,-.286,.52),Vector3(.88,.02,.47),"e9dbbf",.008)
	tag.rotation.x=slope
	label(tag,Vector3(0,.012,0),"AIR MAIL",.145,"825440",true)
