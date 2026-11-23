extends AnimatableBody3D

const Props = preload("res://game/props.gd")
const PERIOD := 8.
const PLATE_LENGTH := .94
const HINGE := Vector3(-.68,0,-.76)
const PLATE_WIDTH := .54
const CLOSED_ANGLE := deg_to_rad(-78.)
const DECK_SIZE := Vector3(1.88,.16,1.62)
const PATH_BOW := 3.65
const FORECAST_LAYER := 2

var entry: Vector3
var exit_dock: Vector3
var phase := 0.
var plate := AnimatableBody3D.new()

func build(art: Props, end: Vector3) -> void:
	entry=position
	exit_dock=end
	collision_layer |= FORECAST_LAYER
	art.deck(self,DECK_SIZE,"c28947")
	for x: float in [-.90,.90]:
		for z: float in [-.77,.77]:
			art.tube(self,Vector3(x,0,z),Vector3(x*.55,1.72,z*.55),.029,"536c71")
		art.tube(self,Vector3(x*.55,1.72,-.42),Vector3(x*.55,1.72,.42),.04,"456467")
	art.tube(self,Vector3(-.52,1.72,0),Vector3(.52,1.72,0),.055,"567775")
	art.box(self,Vector3(0,.14,.78),Vector3(1.89,.24,.06),"b7713f")
	# Leave an opening for the hinged step in the front rail.
	art.box(self,Vector3(.28,.14,-.78),Vector3(1.32,.24,.06),"b7713f")
	plate.sync_to_physics=false
	plate.collision_layer |= FORECAST_LAYER
	plate.set_meta("ledge",get_meta("ledge"))
	plate.set_meta("mobile_surface",true)
	add_child(plate)
	plate.position=HINGE
	art.solid(plate,Vector3(0,-.043,-PLATE_LENGTH*.5),Vector3(PLATE_WIDTH,.086,PLATE_LENGTH),"407e80",.035)
	art.tube(plate,Vector3(-.32,0,0),Vector3(.32,0,0),.055,"b48845")
	for side: float in [-1.,1.]:
		# A yellow nosing on both faces reads when the gate is open or stowed.
		art.box(plate,Vector3(0,-.043+side*.045,-PLATE_LENGTH+.085),Vector3(PLATE_WIDTH-.01,.012,.14),"ffbd46",.005)
	for tread: float in [.26,.48,.70]:
		art.box(plate,Vector3(0,.004,-tread),Vector3(.47,.012,.045),"b7d0bf",.005)
	advance(0.)

func advance(clock: float) -> void:
	phase=clock
	position=position_at(clock)
	plate.rotation.x=step_angle_at(clock)

func position_at(time: float) -> Vector3:
	var clock:=fposmod(time,PERIOD)
	var trip:=smoothstep(1.35,3.95,clock)-smoothstep(5.35,7.95,clock)
	return entry.lerp(exit_dock,trip)+Vector3.BACK*(sin(trip*PI)*PATH_BOW)

func step_angle_at(time: float) -> float:
	var clock:=fposmod(time,PERIOD)
	# Fold as the basket accelerates, leaving time to walk aboard from the tip.
	var shut:=smoothstep(1.28,1.76,clock)-smoothstep(3.52,3.95,clock)
	shut+=smoothstep(5.28,5.76,clock)-smoothstep(7.52,7.95,clock)
	return CLOSED_ANGLE*shut

func boarding_point() -> Vector3:
	return entry+HINGE+Vector3.FORWARD*PLATE_LENGTH*.55
