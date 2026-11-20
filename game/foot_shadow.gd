extends RefCounted

const DEPTH := .36
var material := ShaderMaterial.new()
var receiver: Node3D
var surfaces: Array[Node] = []

func _init() -> void:
	material.shader=preload("res://game/foot_shadow.gdshader")

func hide() -> void:
	for surface: MeshInstance3D in surfaces:
		if surface.material_overlay==material: surface.material_overlay=null
	surfaces.clear()
	receiver=null

func project(foot: Vector3, hit: Dictionary) -> void:
	var body:=hit.get("collider") as Node3D
	var height:=maxf(0.,foot.y-hit.position.y) if body else 0.
	if height>=6.: body=null
	if body!=receiver:
		hide()
		receiver=body
		if receiver: surfaces=receiver.find_children("*","MeshInstance3D",true,false)
	if not receiver: return
	var contact:=Vector3(foot.x,hit.position.y,foot.z)
	var spread:=smoothstep(.12,2.4,height)
	var radius:=lerpf(.32,.48,spread)
	material.set_shader_parameter("contact",Vector4(contact.x,contact.y,contact.z,radius))
	material.set_shader_parameter("strength",lerpf(.45,.15,spread)*(1.-smoothstep(2.4,6.,height)))
	# Only draw on pieces under the sole, including raised seams on the reel.
	var extent:=Vector3(radius,DEPTH,radius)
	var patch:=AABB(contact-extent,2.*extent)
	for surface: MeshInstance3D in surfaces:
		var local_patch:=surface.global_transform.affine_inverse()*patch
		if local_patch.intersects(surface.get_aabb()):
			if not surface.material_overlay: surface.material_overlay=material
		elif surface.material_overlay==material: surface.material_overlay=null
