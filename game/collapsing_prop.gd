extends AnimatableBody3D

const Props = preload("res://game/props.gd")
const BOARD_PITCH := -PI/15.
const HINGE := Vector3(0,-.10,-1.17)
var drawer := false
var home: Transform3D

func build(art: Props, is_drawer: bool) -> void:
	drawer=is_drawer
	set_meta("drop_surface",true)
	var fitting:=Node3D.new()
	art.add_child(fitting)
	if not drawer: rotation.x=BOARD_PITCH
	home=transform
	fitting.transform=home
	if drawer:
		art.deck(self,Vector3(1.78,.17,1.54),"c8915f")
		art.solid(self,Vector3(-.83,.095,0),Vector3(.12,.30,1.54),"a46b46")
		art.solid(self,Vector3(.83,.095,.55),Vector3(.12,.30,.36),"a46b46")
		art.solid(self,Vector3(0,.045,.77),Vector3(1.78,.31,.14),"955838")
		for x: float in [-.27,.27]:
			art.tube(self,Vector3(x,.06,.84),Vector3(x,.06,.99),.042,"d9a550")
		art.tube(self,Vector3(-.27,.06,.99),Vector3(.27,.06,.99),.052,"edbc68")
		# The outer channels stay put. Their red end stops are uncovered as the tray slides out.
		for side: float in [-1.,1.]:
			art.box(fitting,Vector3(side*.70,-.21,-.52),Vector3(.14,.11,1.28),"515e60")
			art.box(fitting,Vector3(side*.70,-.15,-.76),Vector3(.13,.06,.22),"d95132",.018)
			art.box(self,Vector3(side*.70,-.15,.10),Vector3(.085,.07,1.30),"becac5")
	else:
		art.deck(self,Vector3(1.25,.17,2.54),"b47e4e")
		for side: float in [-1.,1.]:
			var pin:=art.cone(fitting,HINGE+Vector3.RIGHT*side*.63,.13,.105,.105,"586b68",16)
			pin.rotation.z=PI/2
			art.box(fitting,HINGE+Vector3(side*.65,-.11,-.03),Vector3(.11,.21,.36),"807766")
			art.box(self,Vector3(side*.48,.009,-.96),Vector3(.13,.023,.49),"8c9892",.01)
			art.cone(self,Vector3(side*.48,.023,-.80),.018,.044,.044,"4e5654",8)
		# A zigzag split crosses the grain near the fastenings.
		var seam: Array[Vector3]=[Vector3(-.62,.008,-.61),Vector3(-.19,.008,-.43),Vector3(-.03,.008,-.59),Vector3(.34,.008,-.32),Vector3(.61,.008,-.37)]
		for i in seam.size()-1: art.tube(self,seam[i],seam[i+1],.018,"584030")

func reset() -> void:
	transform=home
	show()
	collision_layer=1

func strain(progress: float) -> Transform3D:
	if drawer:
		# The slide catches briefly on its stop before slipping a second time.
		var extension:=.14*smoothstep(0.,.36,progress)+.16*smoothstep(.52,1.,progress)
		return home.translated(Vector3.BACK*extension)
	# Rotate about the bolted end so the far end and its actual floor sag together.
	var angle:=deg_to_rad(9.)*(.32*smoothstep(0.,.40,progress)+.68*smoothstep(.48,1.,progress))
	var tilt:=Basis(Vector3.RIGHT,angle)
	return home*Transform3D(tilt,HINGE-tilt*HINGE)

func advance(elapsed: float, deadline: float) -> void:
	if elapsed<deadline:
		transform=strain(elapsed/deadline)
		return
	collision_layer=0
	var falling:=elapsed-deadline
	if falling>=1.1:
		if visible:
			hide()
			# Park while non-solid so respawning imparts no return-trip velocity.
			transform=home
		return
	# Continue from the last loaded pose instead of snapping back to the mounting.
	transform=strain(1.)
	position+=Vector3.DOWN*8.*falling*falling
	if drawer: position+=Vector3(-.65,0,1.60)*smoothstep(.04,.63,falling)
	rotate_object_local(Vector3.BACK,falling*.65)
