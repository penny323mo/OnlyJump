extends RefCounted

const Props = preload("res://game/props.gd")
const B = preload("res://game/branch_routes.gd")
const ITEMS := {
	"double":["黃鴨仔",B.BED,Vector3(.58,.52,.39)],
	"jet":["發條匙",B.FAN,Vector3(1.67,.53,0)],
	"glide":["飛天襪",B.SHEET,Vector3(.75,.48,.34)],
	"hook":["袖珍飛爪",B.AWNING,Vector3(-.64,.51,.35)],
}
var items := {}
const LABELS := {"double":"二段跳","jet":"噴射器","glide":"緩降","hook":"飛爪"}
const FRAME_TIPS := [Vector3.UP*.52,Vector3.RIGHT*.41,Vector3.DOWN*.42,Vector3.LEFT*.41,Vector3.BACK*.41,Vector3.FORWARD*.41]
var count := 0
var time := 0.

func build(art: Props, bodies: Dictionary) -> void:
	for key: String in ITEMS:
		var obj:=Node3D.new()
		bodies[ITEMS[key][1]].add_child(obj)
		obj.position=ITEMS[key][2]
		items[key]=obj
		# An open-sided, luminous diamond identifies pickups from any camera yaw.
		var glow:=StandardMaterial3D.new()
		glow.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
		glow.albedo_color=Color("8dffe4")
		for ring: Array in [[0,1,2,3],[0,4,2,5]]:
			for i in 4:
				var a: Vector3=FRAME_TIPS[ring[i]]
				var b: Vector3=FRAME_TIPS[ring[(i+1)%4]]
				var wire:=art.cone(obj,(a+b)*.5,a.distance_to(b),.014,.014,"8dffe4",6)
				wire.quaternion=Quaternion(Vector3.UP,a.direction_to(b))
				wire.material_override=glow
				wire.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		match key:
			"double":
				var sphere:=SphereMesh.new()
				sphere.radial_segments=16
				sphere.rings=8
				art.piece(obj,sphere,Vector3.ZERO,"ffbb24").scale=Vector3(.49,.32,.57)
				art.piece(obj,sphere,Vector3(0,.17,-.16),"ffd94c").scale=Vector3(.31,.34,.31)
				art.box(obj,Vector3(0,.13,-.32),Vector3(.18,.071,.14),"f27038")
				for side: float in [-1,1]:
					art.piece(obj,sphere,Vector3(side*.111,.211,-.24),"33424b").scale=Vector3.ONE*.054
			"jet":
				for side: float in [-1,1]:
					art.rim(obj,Vector3(side*.14,.13,0),.165,.058,"ffe791").rotation.x=PI*.5
				art.box(obj,Vector3(0,-.125,0),Vector3(.082,.36,.09),"ffc64e")
				art.box(obj,Vector3(.080,-.245,0),Vector3(.19,.08,.10),"f39b3a")
			"glide":
				art.box(obj,Vector3(0,.03,0),Vector3(.24,.37,.19),"dd624e")
				art.box(obj,Vector3(0,.177,0),Vector3(.27,.11,.22),"fff1d2")
				art.box(obj,Vector3(0,-.108,-.110),Vector3(.25,.18,.37),"ea8261",.08)
			"hook":
				art.rim(obj,Vector3.UP*.20,.095,.033,"ffd063").rotation.x=PI/2
				art.cone(obj,Vector3.UP*.004,.32,.053,.078,"f7983c",12)
				for prong in 3:
					var side:=Vector3.RIGHT.rotated(Vector3.UP,prong*TAU/3)
					var elbow:=side*.18-Vector3.UP*.21
					var tip:=side*.25+Vector3.UP*.015
					art.tube(obj,Vector3.DOWN*.13,elbow,.034,"eaf2e5")
					art.tube(obj,elbow,tip,.034,"eaf2e5")
					art.tube(obj,tip,side*.17-Vector3.UP*.035,.022,"ffcc64")

func reset() -> void:
	count=0
	time=0
	for obj: Node3D in items.values(): obj.show()

func frame_bounds(camera: Camera3D, item: Node3D) -> Rect2:
	var bounds:=Rect2(camera.unproject_position(item.global_position),Vector2.ZERO)
	for tip: Vector3 in FRAME_TIPS:
		var point:=item.to_global(tip)
		if camera.is_position_behind(point):return camera.get_viewport().get_visible_rect()
		bounds=bounds.expand(camera.unproject_position(point))
	return bounds

func collect(foot: Vector3, delta: float) -> String:
	time+=delta
	for key: String in ITEMS:
		var obj: Node3D=items[key]
		if not obj.visible: continue
		var rest: Vector3=ITEMS[key][2]
		obj.position.y=rest.y+.060*sin(time*3.+rest.x)
		obj.rotation.y=time*1.7
		if (foot+Vector3.UP*.53).distance_squared_to(obj.global_position)>.54*.54: continue
		obj.hide()
		count+=1
		return key
	return ""


func visible_hint(camera: Camera3D, player: CharacterBody3D) -> Node3D:
	var nearest: Node3D
	var range_sq:=65.
	for obj: Node3D in items.values():
		if not obj.visible or not camera.is_position_in_frustum(obj.global_position): continue
		var dist:=player.global_position.distance_squared_to(obj.global_position)
		if dist>=range_sq: continue
		var ray:=PhysicsRayQueryParameters3D.create(camera.global_position,obj.global_position)
		ray.exclude=[player.get_rid()]
		if not camera.get_world_3d().direct_space_state.intersect_ray(ray).is_empty(): continue
		range_sq=dist
		nearest=obj
	return nearest
