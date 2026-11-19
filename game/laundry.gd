extends RefCounted

const Props = preload("res://game/props.gd")
var art: Props

func _init(builder: Props) -> void:
	art = builder

# Build both the rendered surfaces and the walkable mesh from the same faces.
func triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, outside: Vector3) -> void:
	var normal := (c-a).cross(b-a).normalized()
	if normal.dot(outside)<0:
		var swap := b
		b=c
		c=swap
		normal=-normal
	for v: Vector3 in [a,b,c]:
		surface.set_normal(normal)
		surface.add_vertex(v)

func attach_surface(body: StaticBody3D, mesh: ArrayMesh) -> void:
	var model := MeshInstance3D.new()
	model.mesh=mesh
	body.add_child(model)
	var collider := CollisionShape3D.new()
	var shape := mesh.create_trimesh_shape()
	shape.backface_collision = true
	collider.shape=shape
	body.add_child(collider)

func cutout(body: StaticBody3D, outline: PackedVector2Array, thickness: float, tint: String) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_material(art.material(tint))
	var corners := Geometry2D.triangulate_polygon(outline)
	var upper := PackedVector3Array()
	for v in outline: upper.append(Vector3(v.x,0,v.y))
	var down := Vector3.DOWN*thickness
	for i in range(0,corners.size(),3):
		var a := upper[corners[i]]
		var b := upper[corners[i+1]]
		var c := upper[corners[i+2]]
		triangle(surface,a,b,c,Vector3.UP)
		triangle(surface,a+down,b+down,c+down,Vector3.DOWN)
	var winding := -1. if Geometry2D.is_polygon_clockwise(outline) else 1.
	for i in upper.size():
		var a := upper[i]
		var b := upper[(i+1)%upper.size()]
		var outside := Vector3(b.z-a.z,0,a.x-b.x)*winding
		triangle(surface,a,b,b+down,outside)
		triangle(surface,a,b+down,a+down,outside)
	attach_surface(body,surface.commit())

func ironing_board(body: StaticBody3D) -> void:
	var outline := PackedVector2Array([
		Vector2(-2.2,-.16),Vector2(-1.99,-.42),Vector2(-1.28,-.69),Vector2(-.4,-.78),
		Vector2(1.68,-.78),Vector2(1.91,-.63),Vector2(1.91,.63),Vector2(1.68,.78),
		Vector2(-.4,.78),Vector2(-1.28,.69),Vector2(-1.99,.42),Vector2(-2.2,.16)])
	cutout(body,outline,.13,"71aeb1")
	for x in [.75,.91,1.07]:
		art.box(body,Vector3(x,.003,0),Vector3(.055,.007,1.51),"efe0bb",.003)
	for side: float in [-1,1]:
		var z := side*.39
		art.tube(body,Vector3(-1.15,-.14,z),Vector3(1.19,-1.80,z),.065,"c7ccbb")
		art.tube(body,Vector3(1.22,-.14,z),Vector3(-1.23,-1.80,z),.065,"a8b9b2")
		art.tube(body,Vector3(side*1.21,-1.80,-.58),Vector3(side*1.21,-1.80,.58),.082,"374e50")
	art.tube(body,Vector3(1.89,-.14,-.54),Vector3(2.28,-.14,-.54),.043,"aebcb8")
	art.tube(body,Vector3(1.89,-.14,.54),Vector3(2.28,-.14,.54),.043,"aebcb8")
	art.tube(body,Vector3(2.28,-.14,-.54),Vector3(2.28,-.14,.54),.043,"aebcb8")

func clothes_peg(body: StaticBody3D) -> void:
	# The two wooden halves have a V-shaped opening at the handle end.
	var half := PackedVector2Array([
		Vector2(-2.05,.015),Vector2(-1.42,.015),Vector2(-1.18,.19),Vector2(-.94,.035),
		Vector2(-.28,.045),Vector2(-.04,.24),Vector2(.18,.22),Vector2(1.84,.47),
		Vector2(2.02,.59),Vector2(1.98,.78),Vector2(.28,.58),Vector2(-.60,.45),Vector2(-2.05,.29)])
	for side: float in [-1,1]:
		var outline := PackedVector2Array()
		for v in half: outline.append(Vector2(v.x,v.y*side))
		cutout(body,outline,.39,"ce945c" if side>0 else "e0ac70")
		art.box(body,Vector3(-1.60,.004,side*.16),Vector3(.47,.008,.026),"b68555",.002)
	for turn in 3:
		var ring := art.rim(body,Vector3(0,-.32+turn*.105,0),.24,.065,"626d69")
		ring.scale.x=.88
	for side: float in [-1,1]:
		art.tube(body,Vector3(.06,.022,side*.18),Vector3(.48,.022,side*.46),.040,"707a73")

func washer(body: StaticBody3D) -> void:
	art.deck(body,Vector3(2.72,2.63,2.34),"e4dbbe",.12)
	var front := 1.19
	var door := Vector3(0,-1.45,front)
	art.cone(body,door,.14,.90,.90,"4e605d",48).rotation.x=PI/2
	art.cone(body,door+Vector3.BACK*.10,.12,.76,.74,"46666b",48).rotation.x=PI/2
	art.rim(body,door+Vector3.BACK*.17,.82,.10,"aab7af").rotation.x=PI/2
	art.box(body,door+Vector3(.71,0,.19),Vector3(.13,.39,.12),"d3d6c6")
	art.box(body,Vector3(-.70,-.31,front),Vector3(.95,.30,.07),"b7c2b5")
	art.box(body,Vector3(-.70,-.24,front+.041),Vector3(.74,.07,.025),"62716c")
	art.box(body,Vector3(.39,-.31,front),Vector3(.58,.21,.07),"425758")
	art.label(body,Vector3(.39,-.31,front+.046),"0:24",.115,"b6e5cf")
	art.cone(body,Vector3(.99,-.32,front+.05),.15,.19,.17,"929f97",24).rotation.x=PI/2
	for side: float in [-1,1]:
		art.box(body,Vector3(side*.96,-2.68,.86),Vector3(.39,.14,.38),"626c63")

func drying_rack(body: StaticBody3D) -> void:
	# The bare rails have real gaps. The towel spans only the central rails.
	for i in range(-2,3):
		art.solid(body,Vector3(0,-.10,i*.39),Vector3(3.42,.075,.075),"b8c6c0",.034)
	for side: float in [-1,1]:
		art.solid(body,Vector3(side*1.71,-.10,0),Vector3(.105,.105,1.74),"79a2a4")
		art.tube(body,Vector3(-1.30,-.14,side*.58),Vector3(1.32,-1.82,side*.58),.053,"8aaba9")
		art.tube(body,Vector3(1.30,-.14,side*.58),Vector3(-1.32,-1.82,side*.58),.053,"b1c4bd")
	art.deck(body,Vector3(1.05,.075,.87),"ce765c")
	for side: float in [-1,1]:
		var drop := .68 if side>0 else .43
		art.solid(body,Vector3(0,-drop*.5,side*.42),Vector3(1.05,drop,.045),"bd6855",.018)
		for stripe: float in [.08,.16]:
			art.box(body,Vector3(0,-drop+stripe,side*.446),Vector3(1.03,.038,.012),"f5d69c",.005)

func folding_ladder(body: StaticBody3D) -> void:
	art.deck(body,Vector3(1.63,.14,.72),"d0a34c")
	for rung in range(1,5):
		var depth := rung*.255
		art.solid(body,Vector3(0,-rung*.56,depth),Vector3(1.50,.11,.27),"abb9b6")
		art.tube(body,Vector3(-.70,-rung*.56,-depth),Vector3(.70,-rung*.56,-depth),.045,"899e99")
	for side: float in [-1,1]:
		for spread: float in [-1,1]:
			var top := Vector3(side*.71,-.07,spread*.16)
			var foot := Vector3(side*.88,-2.77,spread*1.30)
			art.tube(body,top,foot,.081,"9dafa9")
			art.box(body,foot,Vector3(.23,.19,.24),"434f4a")
		art.tube(body,Vector3(side*.79,-1.25,-.66),Vector3(side*.79,-1.25,.66),.046,"bd8e41")
		art.cone(body,Vector3(side*.82,-.19,0),.09,.12,.12,"9e783d",16).rotation.z=PI/2

func parasol(body: StaticBody3D) -> void:
	var mesh := ArrayMesh.new()
	for stripe in 2:
		var cloth := SurfaceTool.new()
		cloth.begin(Mesh.PRIMITIVE_TRIANGLES)
		var fabric := art.material("ce6958" if stripe==0 else "f3dcab").duplicate() as StandardMaterial3D
		fabric.cull_mode=BaseMaterial3D.CULL_DISABLED
		cloth.set_material(fabric)
		for sector in range(stripe,8,2):
			for half in 2:
				var i := sector*2+half
				var a := Vector3(cos(i*TAU/16),0,sin(i*TAU/16))
				var b := Vector3(cos((i+1)*TAU/16),0,sin((i+1)*TAU/16))
				var mid_a := a*1.18+Vector3.DOWN*.24
				var mid_b := b*1.18+Vector3.DOWN*.24
				var edge_a := a*(2.35 if i%2==0 else 2.16)+Vector3.DOWN*.76
				var edge_b := b*(2.16 if i%2==0 else 2.35)+Vector3.DOWN*.76
				triangle(cloth,Vector3.ZERO,mid_a,mid_b,Vector3.UP)
				triangle(cloth,mid_a,edge_a,edge_b,Vector3.UP)
				triangle(cloth,mid_a,edge_b,mid_b,Vector3.UP)
				var hem_a := edge_a+Vector3.DOWN*(.07 if i%2==0 else .22)
				var hem_b := edge_b+Vector3.DOWN*(.22 if i%2==0 else .07)
				triangle(cloth,edge_a,hem_a,hem_b,a+b)
				triangle(cloth,edge_a,hem_b,edge_b,a+b)
		cloth.commit(mesh)
	attach_surface(body,mesh)
	art.tube(body,Vector3(0,-.02,0),Vector3(0,-3.40,0),.060,"876a4c")
	art.cone(body,Vector3.UP*.033,.10,.13,.085,"a18153")
	for i in 8:
		var d := Vector3(cos(i*TAU/8),0,sin(i*TAU/8))
		art.tube(body,Vector3.DOWN*.045,d*1.18+Vector3.DOWN*.28,.027,"9e8261")
		art.tube(body,d*1.18+Vector3.DOWN*.28,d*2.35+Vector3.DOWN*.79,.027,"9e8261")
		art.tube(body,Vector3.DOWN*.98,d*1.18+Vector3.DOWN*.28,.025,"ad906b")
