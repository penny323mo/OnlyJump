extends RefCounted

const Props = preload("res://game/props.gd")
const NAMES := {"courier":"天台速遞員","bun":"菠蘿油俠","fish":"鹹魚仔","cone":"雪糕筒工頭","dino":"短手暴龍"}
var key := "courier"
var mounts: Array[BoneAttachment3D] = []
var parts: Dictionary = {}
var art: Props
var rig: Skeleton3D
var model: Node3D

func setup(world_art: Props, skeleton: Skeleton3D, character_model: Node3D) -> void:
	art=world_art
	rig=skeleton
	model=character_model
	for mesh in rig.find_children("*","MeshInstance3D",true,false): parts[str(mesh.name)]=mesh

func joint(bone: String) -> Node3D:
	var attach := BoneAttachment3D.new()
	attach.bone_name=bone
	rig.add_child(attach)
	mounts.append(attach)
	var mount:=Node3D.new()
	attach.add_child(mount)
	var rest:=model.global_transform.affine_inverse()*rig.global_transform*rig.get_bone_global_rest(rig.find_bone(bone))
	mount.basis=rest.basis.inverse()
	return mount

func oval(parent: Node3D, p: Vector3, size: Vector3, color: String) -> void:
	var mesh:=SphereMesh.new()
	mesh.radius=.5
	mesh.height=1.
	mesh.radial_segments=20
	mesh.rings=10
	art.piece(parent,mesh,p,color).scale=size

func spike(parent: Node3D, a: Vector3, b: Vector3, base: float, tip: float, color: String) -> void:
	var mesh:=art.cone(parent,(a+b)*.5,a.distance_to(b),base,tip,color,10)
	mesh.quaternion=Quaternion(Vector3.UP,a.direction_to(b))

func select(id: String) -> void:
	if not NAMES.has(id) or id==key: return
	for mount in mounts: mount.free()
	mounts.clear()
	key=id
	parts["Head"].visible=id in ["courier","cone"]
	parts["Torso"].visible=id in ["courier","cone"]
	if id=="courier": return
	var head:=joint("Head_2")
	var chest:=joint("Torso_2")
	match id:
		"dino":
			oval(head,Vector3(0,.08,0),Vector3(.64,.50,.55),"26ac81")
			art.box(head,Vector3(0,.046,-.264),Vector3(.48,.21,.41),"40c78e",.09)
			art.box(head,Vector3(0,-.075,-.265),Vector3(.42,.09,.34),"f6d591",.04)
			for side: float in [-1.,1.]:
				oval(head,Vector3(side*.238,.18,-.144),Vector3(.13,.145,.12),"ffe7a3")
				oval(head,Vector3(side*.27,.185,-.19),Vector3(.048,.085,.038),"21383b")
				oval(head,Vector3(side*.125,.147,-.39),Vector3(.041,.018,.051),"276756")
				for z: float in [-.27,-.39]:
					spike(head,Vector3(side*.203,-.014,z),Vector3(side*.204,-.081,z),.028,0,"fff2ca")
			oval(chest,Vector3(0,-.04,.02),Vector3(.52,.57,.46),"259b76")
			oval(chest,Vector3(0,-.06,-.165),Vector3(.34,.38,.12),"efd08a")
			var hip:=joint("Hips")
			spike(hip,Vector3(0,.08,.09),Vector3(.04,.035,.51),.16,.087,"2eac7d")
			spike(hip,Vector3(.04,.035,.51),Vector3(.16,.17,.81),.09,.01,"5cc58c")
			for i in 3:
				var base:=Vector3(0,.20-i*.14,.19)
				spike(chest,base,base+Vector3(0,.095,.135),.070,0,"ef9d3e")
			spike(head,Vector3(0,.28,.10),Vector3(0,.40,.16),.075,0,"ed9740")
		"bun":
			oval(head,Vector3(0,.048,0),Vector3(.72,.53,.62),"bb6c30")
			oval(head,Vector3(0,-.026,-.008),Vector3(.72,.104,.64),"fff0af")
			oval(head,Vector3(0,.11,0),Vector3(.73,.39,.64),"e8a442")
			for x in 3:
				for z in 3:
					var tile:=art.box(head,Vector3((x-1)*.158,.28-(absi(x-1)+absi(z-1))*.025,(z-1)*.141),Vector3(.13,.038,.12),"f7c667",.015)
					tile.rotation.y=.24
			art.box(head,Vector3(.085,.012,-.276),Vector3(.29,.055,.18),"ffcf43")
			for side: float in [-1.,1.]: oval(head,Vector3(side*.105,.092,-.287),Vector3(.045,.062,.035),"533b2c")
			art.box(chest,Vector3(0,-.04,.15),Vector3(.46,.44,.06),"da6445").rotation.x=.16
			oval(chest,Vector3(0,-.03,0),Vector3(.46,.48,.35),"f4b541")
		"fish":
			oval(head,Vector3(0,.035,-.04),Vector3(.48,.52,.76),"4a9aa8")
			oval(head,Vector3(0,-.055,-.13),Vector3(.43,.27,.55),"c3ded6")
			for side: float in [-1.,1.]:
				oval(head,Vector3(side*.196,.10,-.207),Vector3(.135,.15,.14),"fcdf99")
				oval(head,Vector3(side*.247,.108,-.24),Vector3(.053,.083,.055),"20383f")
				spike(chest,Vector3(side*.14,-.04,.04),Vector3(side*.335,-.12,.17),.093,.014,"e7995a")
				spike(head,Vector3(0,.02,.24),Vector3(side*.18,.07,.51),.108,.03,"e79a61")
			spike(head,Vector3(0,.21,.01),Vector3(0,.40,.115),.112,0,"df7c46")
			oval(chest,Vector3(0,-.04,0),Vector3(.43,.52,.42),"5494a1")
		"cone":
			art.box(head,Vector3(0,.22,0),Vector3(.62,.066,.62),"e5622a")
			art.cone(head,Vector3(0,.40,0),.34,.25,.082,"ff6e22",24)
			art.cone(head,Vector3(0,.41,0),.085,.193,.151,"fff0cd",24)
			art.box(chest,Vector3(0,-.075,-.155),Vector3(.38,.26,.080),"ff7f2c")
			art.box(chest,Vector3(0,-.087,-.20),Vector3(.34,.048,.018),"fff0c5")
