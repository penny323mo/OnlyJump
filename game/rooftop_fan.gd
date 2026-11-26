extends AnimatableBody3D

const Props = preload("res://game/props.gd")
const WINGS := 3
const TURN_SPEED := .50
const PANEL_RADIUS := 1.63
const RUNUP_RADIUS := 1.

var angle := 0.
var exit_bearing := 0.
var lamps: Array[MeshInstance3D] = []

func build(art: Props, exit_point: Vector3) -> void:
	var offset:=exit_point-position
	exit_bearing=atan2(-offset.z,offset.x)
	var hub:=art.cone(self,Vector3.DOWN*.08,.16,.46,.44,"e1a735",24)
	var axle:=CollisionShape3D.new()
	var shape:=CylinderShape3D.new()
	shape.radius=.44
	shape.height=.16
	axle.shape=shape
	add_child(axle)
	axle.position=hub.position
	art.cone(self,Vector3.DOWN*.45,.58,.25,.30,"45606a",20)
	var chevrons:=chevron_mesh()
	var lamp_material:=StandardMaterial3D.new()
	lamp_material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	lamp_material.albedo_color=Color("fff2a1")
	for wing in WINGS:
		var yaw:=wing*TAU/WINGS
		var radial:=Vector3.RIGHT.rotated(Vector3.UP,yaw)
		art.solid(self,radial*1.20+Vector3.DOWN*.072,Vector3(1.97,.13,.72),"319d9d" if wing%2==0 else "e59646",.06,yaw)
		art.box(self,radial*2.08,Vector3(.09,.018,.64),"f1d79e",.006).rotation.y=yaw
		var panel:=art.box(self,radial*PANEL_RADIUS+Vector3.UP*.002,Vector3(.78,.024,.61),"263e42",.014)
		panel.rotation.y=yaw
		var lamp:=MeshInstance3D.new()
		lamp.mesh=chevrons
		lamp.material_override=lamp_material
		lamp.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		panel.add_child(lamp)
		lamp.position.y=.020
		lamps.append(lamp)
	set_angle(0.)

func chevron_mesh() -> ArrayMesh:
	# The arrows and edge lights share one surface and light up together.
	var surface:=SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for x: float in [-.18,.16]:
		var outline:=[Vector3(x-.15,0,-.25),Vector3(x-.01,0,-.25),Vector3(x+.17,0,0),
			Vector3(x-.01,0,.25),Vector3(x-.15,0,.25),Vector3(x+.03,0,0)]
		for i in [0,1,2,0,2,5,5,2,3,5,3,4]:
			surface.set_normal(Vector3.UP)
			surface.add_vertex(outline[i])
	# Wrap the light around the blade so the rider's shoes cannot hide the
	# entire signal at a shallow camera angle.
	for side: float in [-1.,1.]:
		var inner:=Vector3(0,-.018,.292*side)
		var edge:=Vector3(0,-.023,.364*side)
		var lower:=edge+Vector3.DOWN*.087
		for strip: Array in [[inner,edge,Vector3.UP],[edge,lower,Vector3.BACK*side]]:
			var corners: Array[Vector3]=[strip[0]+Vector3.LEFT*.30,strip[0]+Vector3.RIGHT*.30,
				strip[1]+Vector3.RIGHT*.30,strip[1]+Vector3.LEFT*.30]
			var order:=[0,1,2,0,2,3] if side>0 else [0,2,1,0,3,2]
			for i in order:
				surface.set_normal(strip[2])
				surface.add_vertex(corners[i])
	return surface.commit()

func set_angle(value: float) -> void:
	angle=fposmod(value,TAU)
	rotation.y=angle
	for wing in lamps.size():
		var bearing:=angle+wing*TAU/WINGS
		# Lead the alignment slightly so the rider has time for a short run-up.
		var past_exit:=angle_difference(exit_bearing,bearing)
		lamps[wing].visible=past_exit>=deg_to_rad(-10.) and past_exit<=deg_to_rad(18.)

func rider_hint(foot: Vector3, destination: String) -> String:
	if to_local(foot).slide(Vector3.UP).length_squared()<RUNUP_RADIUS*RUNUP_RADIUS:
		return "行去扇葉外半截，留意葉尖雙箭嘴"
	for lamp in lamps:
		if lamp.visible and lamp.to_local(foot).x>=RUNUP_RADIUS-PANEL_RADIUS:
			return "雙箭嘴着咗，向%s助跑跳" % destination
	return "企穩扇葉，等腳下雙箭嘴着燈"
