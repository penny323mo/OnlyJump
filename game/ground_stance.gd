extends SkeletonModifier3D

class Leg:
	var hip: int
	var knee: int
	var foot: int
	var pole: int
	var sole: Vector3
	var offset:=Vector3.ZERO
	var up:=Vector3.UP
	var thigh: Transform3D
	var shin: Transform3D
	var shoe: Transform3D
	var calf: Vector3

var legs: Array[Leg]=[]
var body: int
var weight_shift:=Vector3.ZERO
var plant_weight:=0.
var support: Node3D
var local_lip:=Vector3.ZERO
var landing_time:=0.
var landing_depth:=0.
var compression:=0.
const LANDING_DURATION := .24

func land(strength: float) -> void:
	landing_time=LANDING_DURATION
	landing_depth=.145*strength

func build(rig: Skeleton3D, parts: Dictionary) -> void:
	active=false
	body=rig.find_bone("Body")
	for side in ["L","R"]:
		var leg:=Leg.new()
		leg.hip=rig.find_bone("UpperLeg."+side)
		leg.knee=rig.find_bone("LowerLeg."+side)
		leg.foot=rig.find_bone("Foot."+side)
		leg.pole=rig.find_bone("PoleTarget."+side)
		var shoe: MeshInstance3D=parts["Foot_"+side]
		var rest:=rig.global_transform*rig.get_bone_global_rest(leg.foot)
		var bounds:=rest*shoe.transform*shoe.get_aabb()
		var center:=bounds.get_center()
		center.y=bounds.position.y
		leg.sole=rest.affine_inverse()*center
		legs.append(leg)
	rig.add_child(self)

func release() -> void:
	active=false
	landing_time=0.
	compression=0.
	plant_weight=0.
	support=null
	weight_shift=Vector3.ZERO
	for leg in legs:
		leg.offset=Vector3.ZERO
		leg.up=Vector3.UP

func support_at(player, point: Vector3) -> Dictionary:
	var probe:=Vector3(point.x,player.global_position.y+.08,point.z)
	var hit: Dictionary=player.ground_at(probe,.44)
	if hit.get("collider")==support and hit.normal.y>=cos(player.floor_max_angle): return hit
	return {}

# Keep the real footsteps from the walk and run clips. Measure only the
# difference between their level ground plane and the prop under each shoe.
func sample_floor(player, contact: KinematicCollision3D, below: Dictionary, delta: float) -> void:
	if player.spring_pad:
		release()
		return
	if not player.is_on_floor():
		support=null
		landing_time=0.
		compression=0.
		if active:
			plant_weight=move_toward(plant_weight,0.,delta/.10)
			if is_zero_approx(plant_weight): release()
		return
	landing_time=maxf(0.,landing_time-delta)
	var elapsed:=LANDING_DURATION-landing_time
	compression=landing_depth*smoothstep(0.,.055,elapsed)*(1.-smoothstep(.055,LANDING_DURATION,elapsed))
	var rig:=get_skeleton()
	# Floor snapping can keep the body grounded without a new slide contact.
	# Keep a rim contact in prop space so it also travels with a moving ledge.
	if contact:
		support=contact.get_collider()
		local_lip=support.to_local(contact.get_position())
	elif not below.is_empty() and below.collider.get_meta("ledge",-1)==player.grounded_ledge and absf(player.position.y-below.position.y)<.34:
		support=below.collider
		local_lip=support.to_local(below.position)
	elif not support or support.get_meta("ledge",-1)!=player.grounded_ledge:
		release()
		return
	var points: Array[Vector3]=[]
	var hits: Array[Dictionary]=[]
	for leg in legs:
		var sole:=rig.global_transform*rig.get_bone_global_pose(leg.foot)*leg.sole
		points.append(sole)
		hits.append(support_at(player,sole))
	var lip:=support.to_global(local_lip)
	for i in legs.size():
		if not hits[i].is_empty(): continue
		# A small step towards the crown can plant the downhill shoe on a reel.
		var inward:=Vector3(lip.x-points[i].x,0,lip.z-points[i].z)
		var closer:=points[i]+inward.limit_length(.18)
		var other: Vector3=points[1-i] if hits[1-i].is_empty() else hits[1-i].position
		if Vector2(closer.x-other.x,closer.z-other.z).length()>=.17:
			hits[i]=support_at(player,closer)
	if hits[0].is_empty() and hits[1].is_empty():
		# The collision sole can balance on a lip even with both shoe centres
		# outside. Move the nearer shoe onto that lip, leaving the other free.
		var i:=0 if points[0].distance_squared_to(lip)<points[1].distance_squared_to(lip) else 1
		var inward: Vector3=lip-player.global_position
		inward.y=0.
		if inward.length()>player.FOOT_RADIUS+.06:
			release()
			return
		hits[i]=support_at(player,lip+inward.normalized()*.065)
		if hits[i].is_empty():
			release()
			return
	var lowest:=0.
	for hit in hits:
		if not hit.is_empty(): lowest=minf(lowest,hit.position.y-player.global_position.y)
	var weight:=1.-exp(-24.*delta)
	var balance:=Vector3.ZERO
	if hits[0].is_empty() or hits[1].is_empty():
		var planted: Vector3=hits[1 if hits[0].is_empty() else 0].position
		balance=Vector3(planted.x-player.position.x,0,planted.z-player.position.z).limit_length(.11)
	weight_shift=weight_shift.lerp(balance,weight)
	var needed:=compression>.0001
	for i in legs.size():
		var leg:=legs[i]
		var offset:=Vector3.UP*(lowest+.025)
		var up:=Vector3.UP
		if not hits[i].is_empty():
			offset=hits[i].position-Vector3(points[i].x,player.global_position.y,points[i].z)
			up=hits[i].normal
		leg.offset=leg.offset.lerp(offset,weight)
		# Walkable normals all face upwards. A normalized blend also handles
		# nearly parallel normals where a rotation axis is poorly defined.
		leg.up=leg.up.lerp(up,weight).normalized()
		needed=needed or leg.offset.length_squared()>.000016 or leg.up.y<.9995
	active=needed
	plant_weight=1.

func _process_modification_with_delta(_delta: float) -> void:
	var rig:=get_skeleton()
	var inverse:=rig.global_transform.affine_inverse()
	var shift:=(weight_shift+Vector3.UP*minf(0.,minf(legs[0].offset.y,legs[1].offset.y)))*plant_weight
	shift.y-=compression*plant_weight
	var min_drop:=shift.y-.08
	for leg in legs:
		leg.thigh=rig.global_transform*rig.get_bone_global_pose(leg.hip)
		leg.shin=rig.global_transform*rig.get_bone_global_pose(leg.knee)
		leg.shoe=rig.global_transform*rig.get_bone_global_pose(leg.foot)
		# The foot controls are siblings of the torso. Keep the length and
		# direction of the animated shin before moving its ankle target.
		leg.calf=leg.shoe.origin-leg.shin.origin
		var sole:=leg.shoe*leg.sole
		# Blend the targets before solving the joints so takeoff keeps the
		# ankle attached even as the terrain correction fades out.
		var normal:=Vector3.UP.lerp(leg.up,plant_weight).normalized()
		leg.shoe.basis=Basis(Quaternion(Vector3.UP,normal))*leg.shoe.basis
		leg.shoe.origin=sole+leg.offset*plant_weight-leg.shoe.basis*leg.sole
		var reach:=leg.thigh.origin.distance_to(leg.shin.origin)+leg.calf.length()
		var span:=leg.thigh.origin+weight_shift*plant_weight-leg.shoe.origin
		var vertical:=sqrt(maxf(0.,reach*reach-span.x*span.x-span.z*span.z))
		shift.y=maxf(min_drop,minf(shift.y,vertical-span.y))
	var torso:=rig.get_bone_global_pose(body)
	torso.origin+=inverse.basis*shift
	rig.set_bone_global_pose(body,torso)
	for leg in legs:
		var thigh:=leg.thigh.translated(shift)
		var shin:=leg.shin.translated(shift)
		var shoe:=leg.shoe
		var axis:=thigh.origin.direction_to(shoe.origin)
		var a:=thigh.origin.distance_to(shin.origin)
		var b:=leg.calf.length()
		var d:=clampf(thigh.origin.distance_to(shoe.origin),absf(a-b)+.00001,a+b-.00001)
		shoe.origin=thigh.origin+axis*d
		var along:=(a*a+d*d-b*b)/(2.*d)
		var pole:=rig.to_global(rig.get_bone_global_pose(leg.pole).origin)-thigh.origin
		var bend:=pole.slide(axis).normalized()
		var knee:=thigh.origin+axis*along+bend*sqrt(maxf(0.,a*a-along*along))
		thigh.basis=Basis(Quaternion(thigh.origin.direction_to(shin.origin),thigh.origin.direction_to(knee)))*thigh.basis
		shin.basis=Basis(Quaternion(leg.calf.normalized(),knee.direction_to(shoe.origin)))*shin.basis
		shin.origin=knee
		rig.set_bone_global_pose(leg.hip,inverse*thigh)
		rig.set_bone_global_pose(leg.knee,inverse*shin)
		rig.set_bone_global_pose(leg.foot,inverse*shoe)
