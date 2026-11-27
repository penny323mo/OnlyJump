extends Node3D

# Background props share one vertex-colour material. No collision or live shadows.
var paint := StandardMaterial3D.new()
var box_mesh := BoxMesh.new()
var route := Curve3D.new()
var buses: MultiMesh

func _init() -> void:
	paint.vertex_color_use_as_albedo = true
	paint.vertex_color_is_srgb = true
	paint.roughness = .85

func add_box(surface: SurfaceTool, centre: Vector3, size: Vector3, colour: Color, pitch := 0.) -> void:
	var arrays := box_mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var rotation := Basis(Vector3.RIGHT,pitch)
	for index in arrays[Mesh.ARRAY_INDEX]:
		surface.set_color(colour)
		surface.set_normal(rotation*normals[index])
		surface.add_vertex(centre+rotation*(vertices[index]*size))

func instances(surface: SurfaceTool, placements: Array[Transform3D]) -> MultiMesh:
	surface.index()
	var group := MultiMesh.new()
	group.transform_format = MultiMesh.TRANSFORM_3D
	group.mesh = surface.commit()
	group.instance_count = placements.size()
	for i in placements.size(): group.set_instance_transform(i,placements[i])
	var batch := MultiMeshInstance3D.new()
	batch.multimesh = group
	batch.material_override = paint
	batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(batch)
	return group

func storefront(placements: Array[Transform3D], fabric: Color) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	add_box(surface,Vector3(0,.87,0),Vector3(2.70,1.50,.12),Color("28555b"))
	for i in 3:
		add_box(surface,Vector3((i-1)*.85,.91,.072),Vector3(.70,.95,.03),Color("dfaa62"))
	for i in 7:
		var tint := fabric if i%2==0 else Color("ffe5b6")
		var x := (i-3)*.44
		add_box(surface,Vector3(x,1.78,.31),Vector3(.44,.09,.82),tint,.23)
		add_box(surface,Vector3(x,1.61,.70),Vector3(.44,.18,.06),tint)
	instances(surface,placements)

# Each sign sits on its building roof; its two feet reach below the parapet.
func roof_sign(roof: Vector3, hotel: bool) -> void:
	var dock := Node3D.new()
	add_child(dock)
	dock.position = roof
	dock.rotation.y = -.36 if hotel else .22
	var size := Vector2(1.15,4.25) if hotel else Vector2(4.25,1.95)
	var legs := SurfaceTool.new()
	legs.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side in [-1,1]:
		add_box(legs,Vector3(side*size.x*.32,-.05,0),Vector3(.10,1.25,.13),Color("474b48"))
	add_box(legs,Vector3(0,.46+size.y*.5,0),Vector3(size.x,size.y,.14),Color("573e37"))
	# The frame and printed face share the same local axes.
	instances(legs,[dock.transform])
	var face := MeshInstance3D.new()
	var panel := QuadMesh.new()
	panel.size = size
	face.mesh = panel
	var enamel := StandardMaterial3D.new()
	enamel.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	enamel.albedo_texture = preload("res://assets/city/hotel-blade.svg") if hotel else preload("res://assets/city/tea-house.svg")
	enamel.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	face.material_override = enamel
	face.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	dock.add_child(face)
	face.position = Vector3(0,.46+size.y*.5,.082)

func build_shops() -> void:
	var jade: Array[Transform3D] = []
	var red: Array[Transform3D] = []
	for x in range(-4,5):
		for z in range(-5,4):
			if (x==0 and z==0) or posmod(x,3)==1 or posmod(z,3)==1: continue
			var face := Vector3.RIGHT if posmod(x,3)==0 else Vector3.LEFT
			if posmod(x+z,2)==0: face = Vector3.BACK if posmod(z,3)==0 else Vector3.FORWARD
			var door := Vector3(x*7.,-11.55,z*7.)+face*2.89
			var sit := Transform3D(Basis(Vector3.UP,atan2(face.x,face.z)),door)
			if posmod(x+2*z,4)<2: jade.append(sit)
			else: red.append(sit)
	storefront(jade,Color("208d85"))
	storefront(red,Color("c5523d"))

func build_trees() -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	add_box(surface,Vector3(0,.62,0),Vector3(.22,1.30,.22),Color("765a43"))
	add_box(surface,Vector3(0,.10,0),Vector3(1.12,.20,1.12),Color("a39e86"))
	var crown := SphereMesh.new()
	crown.radial_segments = 7
	crown.rings = 3
	var mesh := crown.surface_get_arrays(0)
	var vertices: PackedVector3Array = mesh[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = mesh[Mesh.ARRAY_NORMAL]
	for centre: Vector3 in [Vector3(-.28,1.67,0),Vector3(.33,1.94,.10),Vector3(0,2.48,0)]:
		var leaf := Color("509578") if centre.y > 2. else Color("397863")
		for i in mesh[Mesh.ARRAY_INDEX]:
			surface.set_color(leaf)
			surface.set_normal(normals[i])
			surface.add_vertex(centre+vertices[i]*Vector3(1.35,1.06,1.25))
	var planters: Array[Transform3D] = []
	for x in range(-4,5,3):
		for z in range(-6,5,3):
			var p := Vector3(x*7.-2.95,-11.56,z*7.+2.84)
			planters.append(Transform3D(Basis(Vector3.UP,float(x-z)),p))
	instances(surface,planters)

func build_buses() -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	add_box(surface,Vector3(0,.70,0),Vector3(1.04,1.17,2.76),Color("be4933"))
	add_box(surface,Vector3(0,1.30,0),Vector3(1.06,.09,2.80),Color("f8dd9d"))
	add_box(surface,Vector3(0,.79,0),Vector3(1.06,.09,2.79),Color("eab66a"))
	for side in [-1,1]:
		for j in 4:
			for y: float in [.58,1.03]:
				add_box(surface,Vector3(side*.524,y,(j-1.5)*.65),Vector3(.025,.29,.55),Color("214858"))
		for z: float in [-.89,.89]:
			add_box(surface,Vector3(side*.49,.19,z),Vector3(.12,.32,.40),Color("273638"))
	for z: float in [-1.39,1.39]:
		add_box(surface,Vector3(0,1.02,z),Vector3(.85,.33,.03),Color("28505b"))
		add_box(surface,Vector3(0,.62,z),Vector3(.83,.27,.03),Color("42626a"))
	for side in [-1,1]:
		add_box(surface,Vector3(side*.38,.34,-1.40),Vector3(.16,.10,.035),Color("ffdd87"))
	# Two parallel avenue crossings and rounded bends, all at street level.
	var corners := [Vector3(-15.1,-11.82,-36.1),Vector3(8.1,-11.82,-36.1),
		Vector3(8.1,-11.82,8.1),Vector3(-15.1,-11.82,8.1)]
	for i in 4:
		var corner: Vector3 = corners[i]
		var incoming: Vector3 = corners[(i+3)%4].direction_to(corner)
		var outgoing: Vector3 = corner.direction_to(corners[(i+1)%4])
		route.add_point(corner-incoming*2.,Vector3.ZERO,incoming*1.10)
		route.add_point(corner+outgoing*2.,-outgoing*1.10,Vector3.ZERO)
	route.add_point(route.get_point_position(0))
	var placements: Array[Transform3D] = [Transform3D.IDENTITY,Transform3D.IDENTITY,Transform3D.IDENTITY]
	buses = instances(surface,placements)
	advance(0.)

func advance(time: float) -> void:
	var length := route.get_baked_length()
	for i in buses.instance_count:
		var at := fposmod(10.+time*2.4+i*length/3.,length)
		var pose := route.sample_baked_with_rotation(at,true)
		buses.set_instance_transform(i,pose)

func _ready() -> void:
	build_shops()
	build_trees()
	build_buses()
