extends Node3D

# The Y coordinate marks the landing surface. The route doubles back over
# lower ledges, so a missed jump can cost one ledge or an entire ascent.
const ROUTE := [
	Vector3(0, 0, 0), Vector3(2.4, 1.35, -4.8), Vector3(-1.0, 3.05, -8.1),
	Vector3(-5.3, 4.95, -6.0), Vector3(-7.8, 7.05, -10.2), Vector3(-4.1, 9.1, -13.2),
	Vector3(0.4, 11.25, -12.2), Vector3(4.1, 13.5, -15.2), Vector3(2.1, 15.75, -19.7),
	Vector3(-2.6, 17.95, -19.1), Vector3(-5.5, 20.25, -22.5), Vector3(-2.2, 22.65, -25.7),
	Vector3(2.45, 25.0, -25.15)
]
const SIZES := [
	Vector2(4.1,3.0), Vector2(1.8,1.55), Vector2(1.9,1.6), Vector2(2.15,1.55),
	Vector2(1.6,1.45), Vector2(2.4,1.8), Vector2(1.5,1.45), Vector2(1.85,1.45),
	Vector2(1.55,1.65), Vector2(1.65,1.35), Vector2(1.4,1.45), Vector2(1.55,1.35),
	Vector2(1.95,1.95)
]
var rng := RandomNumberGenerator.new()
var materials := {}
var pennants: Array[Node3D] = []
var birds: Array[Node3D] = []
var elapsed := 0.0

func material(tint: String) -> StandardMaterial3D:
	if not materials.has(tint):
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(tint)
		mat.roughness = 1
		materials[tint] = mat
	return materials[tint]

func piece(parent: Node3D, mesh: Mesh, pos: Vector3, tint: String) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material(tint)
	parent.add_child(node)
	node.position = pos
	return node

func box(parent: Node3D, pos: Vector3, dimensions: Vector3, tint: String) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	return piece(parent, mesh, pos, tint)

func cone(parent: Node3D, pos: Vector3, height: float, lower: float, upper: float, tint: String, sides := 6) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.radial_segments = sides
	mesh.rings = 0
	mesh.height = height
	mesh.bottom_radius = lower
	mesh.top_radius = upper
	return piece(parent, mesh, pos, tint)

func beam(parent: Node3D, a: Vector3, b: Vector3, width: float, tint: String) -> MeshInstance3D:
	var bar := box(parent, (a+b)/2, Vector3(width,a.distance_to(b),width), tint)
	bar.quaternion = Quaternion(Vector3.UP, a.direction_to(b))
	return bar

func _ready() -> void:
	rng.seed = 341207
	for i in ROUTE.size():
		island(ROUTE[i], SIZES[i], i)
	distant_scenery()
	outcrops()

func facet(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, tint: Color) -> void:
	var normal := (c-a).cross(b-a).normalized()
	for v in [a,b,c]:
		st.set_color(tint)
		st.set_normal(normal)
		st.add_vertex(v)

func facet_mesh(st: SurfaceTool, parent: Node3D, unlit := false) -> MeshInstance3D:
	var result := MeshInstance3D.new()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	if unlit:
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	result.mesh = st.commit()
	result.material_override = mat
	parent.add_child(result)
	return result

func island(pos: Vector3, extent: Vector2, index: int) -> void:
	var body := StaticBody3D.new()
	add_child(body)
	body.position = pos
	body.set_meta("ledge", index)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings: Array[PackedVector3Array] = []
	var hull := PackedVector3Array()
	var depth := 1.25 + extent.x * 0.8
	var n := 10
	for j in 4:
		var ring := PackedVector3Array()
		for i in n:
			var angle := TAU*i/n + 0.13
			var p := Vector3(cos(angle)*extent.x,0,sin(angle)*extent.y)
			match j:
				1: p = p*1.025 + Vector3.DOWN*rng.randf_range(0.17,0.30)
				2: p = p*rng.randf_range(0.78,1.04) + Vector3.DOWN*depth*rng.randf_range(0.37,0.6)
				3: p = p*rng.randf_range(0.27,0.63) + Vector3.DOWN*depth*rng.randf_range(0.86,1.18)
			ring.append(p)
			if j <= 1 or j == 3:
				hull.append(p)
		rings.append(ring)
	var tops := ["a69d67","b1a574","b7ab79","afa371"] if index < 5 else ["c6c18a","b9be8a","c2bc86","ccc48f"]
	var sides := [["b08c58","ba965f","b39965"],["926e58","9e775d","876556","ae8466"],["70565a","80605d","87695e","795a56"]]
	for i in n:
		var k := (i+1)%n
		facet(st, Vector3.ZERO, rings[0][i], rings[0][k], Color(tops[rng.randi()%tops.size()]))
		for j in 3:
			var colors: Array = sides[j]
			facet(st,rings[j][i],rings[j+1][i],rings[j+1][k],Color(colors[rng.randi()%colors.size()]))
			facet(st,rings[j][i],rings[j+1][k],rings[j][k],Color(colors[rng.randi()%colors.size()]))
		facet(st,rings[3][i],Vector3(0,-depth*1.29,0),rings[3][k],Color("70545a"))
	facet_mesh(st,body)
	var shape := ConvexPolygonShape3D.new()
	shape.points = hull
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	for i in (9 if index == 0 else 4):
		var a := rng.randf()*TAU
		var p := Vector3(cos(a)*extent.x*0.80, 0, sin(a)*extent.y*0.80)
		tuft(body,p,rng.randf_range(0.18,0.33))
	if index in [0,3,5,8,12]:
		flag(body,Vector3(-extent.x*0.70,0,-extent.y*0.32), 2.8 if index == 0 else 1.8)
	if index in [0,5,12]:
		pine(body,Vector3(extent.x*0.64,0,extent.y*0.12),2.4 if index == 0 else 1.55)
	if index in [2,4,7,9,10,11]:
		cairn(body,Vector3(-extent.x*0.65,0,0.2))
	if index == 12:
		summit_gate(body)

func tuft(parent: Node3D, p: Vector3, size: float) -> void:
	for i in 3:
		var blade := cone(parent,p+Vector3((i-1)*0.065,size*0.45,0),size*(1.25 if i==1 else 1.0),0.045,0,"9b894d",3)
		blade.rotation.z = (i-1)*0.35

func flag(parent: Node3D, p: Vector3, height: float) -> void:
	cone(parent,p+Vector3.UP*height*0.5,height,0.052,0.035,"59463e",6)
	var pivot := Node3D.new()
	parent.add_child(pivot)
	pivot.position = p+Vector3.UP*(height-0.12)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	facet(st,Vector3.ZERO,Vector3(0,-0.6,0),Vector3(0.55,-0.38,0.07),Color("cf5838"))
	facet(st,Vector3.ZERO,Vector3(0.55,-0.38,0.07),Vector3(0.55,-0.06,0.07),Color("e86b40"))
	facet(st,Vector3(0.55,-0.06,0.07),Vector3(0.55,-0.38,0.07),Vector3(1.27,-0.24,-0.07),Color("ef8549"))
	facet_mesh(st,pivot)
	pennants.append(pivot)

func pine(parent: Node3D, p: Vector3, height: float) -> void:
	cone(parent,p+Vector3.UP*height*0.22,height*0.44,height*0.06,height*0.045,"71594d")
	for i in 3:
		var h := height*(0.58-float(i)*0.09)
		cone(parent,p+Vector3.UP*height*(0.43+0.20*i),h,height*(0.25-i*0.048),0,["455d59","53685d","677860"][i],5).rotation.y = i*0.27

func cairn(parent: Node3D, p: Vector3) -> void:
	for i in 3:
		var stone := cone(parent,p+Vector3(0.025*i,0.065+i*0.11,0),0.13-i*0.014,0.22-i*0.044,0.17-i*0.041,["847970","a19680","bbb098"][i],5)
		stone.rotation.y = i
		stone.scale.z = 0.72

func summit_gate(parent: Node3D) -> void:
	var p := Vector3(0,0,-0.75)
	for s in [-1,1]:
		beam(parent,p+Vector3(s*0.84,0,0),p+Vector3(s*0.68,2.65,0),0.17,"65483a")
	box(parent,p+Vector3.UP*2.6,Vector3(2.15,0.19,0.23),"84553d")
	cone(parent,p+Vector3.UP*2.20,0.54,0.26,0.12,"d99c42",8)
	cone(parent,p+Vector3.UP*1.90,0.09,0.31,0.28,"eab75b",8)

func distant_scenery() -> void:
	# Three ranks of folded rock run across the horizon. The mesh uses a
	# fixed world-space silhouette, so parallax follows the moving camera.
	for layer in 3:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var ridge := PackedVector3Array()
		var front := PackedVector3Array()
		var distance_z := -175.0+layer*36.0
		for i in 76:
			var x := (i-38)*6.0
			var y := -4.5 + sin(i*0.37+layer*2)*6 + sin(i*0.71+layer)*3 + rng.randf_range(-2,2) - layer*4
			ridge.append(Vector3(x,y,distance_z+rng.randf_range(-2,2)))
			front.append(Vector3(x+2.0,y-rng.randf_range(7,15),distance_z+8))
		var base := Color(["d6a89b","bd9691","a58485"][layer])
		for i in ridge.size()-1:
			var bottom := Vector3(ridge[i].x,-330,distance_z+17)
			var bottom_next := Vector3(ridge[i+1].x,-330,distance_z+17)
			facet(st,ridge[i],front[i],ridge[i+1],base.lightened(rng.randf_range(0.0,0.12)))
			facet(st,front[i],front[i+1],ridge[i+1],base.darkened(rng.randf_range(0.0,0.09)))
			facet(st,front[i],bottom,bottom_next,base)
			facet(st,front[i],bottom_next,front[i+1],base)
		facet_mesh(st,self,true).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for i in 11:
		var bird := Node3D.new()
		add_child(bird)
		bird.position = Vector3(rng.randf_range(-26,30),rng.randf_range(5,17),rng.randf_range(-55,-34))
		for side in [-1,1]:
			beam(bird,Vector3.ZERO,Vector3(side*0.39,0.13,0.12),0.048,"62585d")
		birds.append(bird)

func _process(delta: float) -> void:
	elapsed += delta
	for i in pennants.size():
		pennants[i].rotation.y = sin(elapsed*2.2+i)*0.17
	for i in birds.size():
		birds[i].position.x += delta*(0.8+0.05*i)
		if birds[i].position.x > 42:
			birds[i].position.x = -42
		birds[i].rotation.z = sin(elapsed*1.8+i)*0.14

func outcrops() -> void:
	# Smaller, desaturated mesas frame the playable amber route.
	for data in [
		[-23,-2,-23,4.4,9.5], [20,0,-28,4.2,10.0], [28,5,-44,5.1,14.0],
		[-30,6,-49,5.8,16.0], [-15,13,-62,3.2,9.4], [11,16,-73,3.5,11.0],
		[-20,21,-82,3.0,10.0], [35,20,-66,4.2,13.0], [-29,-7,0,4.0,8.0]
	]:
		var pivot := Node3D.new()
		add_child(pivot)
		pivot.position = Vector3(data[0],data[1],data[2])
		var w: float = data[3]
		var deep: float = data[4]
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var rim := PackedVector3Array()
		var waist := PackedVector3Array()
		var base := PackedVector3Array()
		for i in 8:
			var angle := TAU*i/8.0 + 0.22
			var radial := Vector3(cos(angle),0,sin(angle)*0.8)*w*rng.randf_range(0.89,1.09)
			rim.append(radial)
			waist.append(radial*rng.randf_range(0.73,1.06)+Vector3.DOWN*deep*rng.randf_range(0.27,0.42))
			base.append(radial*rng.randf_range(0.17,0.38)+Vector3(w*0.12,-deep*0.81,0))
		for i in 8:
			var k := (i+1)%8
			facet(st,Vector3.ZERO,rim[i],rim[k],Color("c5b9a1"))
			facet(st,rim[i],waist[i],rim[k],Color("b39a94").lightened(rng.randf()*0.07))
			facet(st,waist[i],waist[k],rim[k],Color("bca39a"))
			facet(st,waist[i],base[i],waist[k],Color("a78d8d"))
			facet(st,base[i],base[k],waist[k],Color("b19793"))
			facet(st,base[i],Vector3(w*0.08,-deep,0),base[k],Color("a28b8d"))
		facet_mesh(st,pivot,true)
		for i in 4:
			var offset := Vector3(rng.randf_range(-0.55,0.55)*w,0.17,rng.randf_range(-0.54,0.54)*w)
			var tall := rng.randf_range(1.0,2.5)
			var tree := cone(pivot,offset+Vector3.UP*tall*0.5,tall,tall*0.22,0.0,"9a9c89",5)
			tree.material_override.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
