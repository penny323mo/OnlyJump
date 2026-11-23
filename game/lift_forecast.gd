extends CharacterBody3D

const Lift = preload("res://game/laundry_lift.gd")
const Climber = preload("res://game/climber.gd")
const OPEN_STEP_NORMAL_Y := cos(deg_to_rad(8.))

var lift: Lift
var envelope: AABB
var deck_query := PhysicsTestMotionParameters3D.new()
var step_query := PhysicsTestMotionParameters3D.new()
var hit := PhysicsTestMotionResult3D.new()
var support: Node3D
var local_point := Vector3.ZERO
var inward := Vector3.ZERO
var first_fraction := INF

func configure(player: Climber, basket: Lift) -> void:
	lift=basket
	# This body only sweeps the runner's real shape against the two lift
	# colliders. It has no collision layer and never moves through the level.
	top_level=true
	global_position=Vector3.DOWN*1000.
	collision_layer=0
	collision_mask=Lift.FORECAST_LAYER
	var owner_id:=player.get_shape_owners()[0]
	var sole:=CollisionShape3D.new()
	sole.shape=player.shape_owner_get_shape(owner_id,0)
	sole.transform=player.shape_owner_get_transform(owner_id)
	add_child(sole)
	deck_query.exclude_bodies=[lift.plate.get_rid()]
	step_query.exclude_bodies=[lift.get_rid()]
	deck_query.margin=player.safe_margin
	step_query.margin=player.safe_margin
	var path:=AABB(lift.entry,Vector3.ZERO).expand(lift.exit_dock)
	path.size.z+=Lift.PATH_BOW
	envelope=lift.get_parent_node_3d().global_transform*path.grow(2.+Climber.BODY_HEIGHT)

func crosses(bounds: AABB, start: Vector3, end: Vector3) -> bool:
	return bounds.has_point(start) or bounds.intersects_segment(start,end)!=null

# In the live collider's frame a future moving surface stands still and
# the runner travels by the relative displacement. No live body is advanced.
func sweep(body: Node3D, query: PhysicsTestMotionParameters3D, start_pose: Transform3D, end_pose: Transform3D, start: Vector3, end: Vector3, extent: Vector2, floor_y: float) -> void:
	var from:=start_pose.affine_inverse()*start
	var to:=end_pose.affine_inverse()*end
	var middle:=Vector3.FORWARD*extent.y if body==lift.plate else Vector3.ZERO
	var bounds:=AABB(middle-Vector3(extent.x,0,extent.y),Vector3(extent.x*2.,0,extent.y*2.)).grow(Climber.BODY_HEIGHT+.20)
	if not crosses(bounds,from,to):return
	var live:=body.global_transform
	# Follow the centre of the cylinder as well as the sole when the hinge turns.
	var offset:=Vector3.UP*Climber.BODY_HEIGHT*.5
	var relative_basis:=live.basis*start_pose.basis.inverse()
	query.from=Transform3D(relative_basis,live*from)
	query.motion=live*(to+end_pose.basis.inverse()*offset)-(query.from.origin+relative_basis*offset)
	if not PhysicsServer3D.body_test_motion(get_rid(),query,hit):return
	var fraction:=hit.get_collision_safe_fraction()
	if fraction>=first_fraction:return
	first_fraction=fraction
	support=null
	var normal:=live.basis.inverse()*hit.get_collision_normal()
	var pose:=start_pose.interpolate_with(end_pose,fraction)
	if normal.y<.9 or (pose.basis*normal).y<floor_y:return
	# A rapidly folding step can touch the runner without supporting a landing.
	if body==lift.plate and minf(live.basis.y.y,pose.basis.y.y)<OPEN_STEP_NORMAL_Y:return
	# A swept convex shape can report a contact before the sole reaches the
	# top plane. A fast toe passing the far rim still needs actual overlap.
	var touchdown:=fraction
	if from.y>0. and to.y<from.y:
		touchdown=clampf(from.y/(from.y-to.y),fraction,1.)
	var foot:=from.lerp(to,touchdown)
	local_point=Vector3(clampf(foot.x,-extent.x,extent.x),0.,clampf(foot.z,middle.z-extent.y,middle.z+extent.y))
	inward=Vector3(local_point.x-foot.x,0.,local_point.z-foot.z)
	if inward.length()>Climber.FOOT_RADIUS-query.margin:return
	support=body

func trace(start: Vector3, end: Vector3, ahead: float, duration: float, tick: float, floor_y: float) -> bool:
	if duration<=0. or not crosses(envelope,start,end):return false
	# A long, straight sock glide can span more than half the lift's cycle.
	var slices:=maxi(1,ceili(duration/(4.*tick)-.00001))
	var frame:=lift.get_parent_node_3d().global_transform
	var time:=lift.phase+ahead
	var cabin:=frame.translated_local(lift.position_at(time))
	var step:=cabin*Transform3D(Basis(Vector3.RIGHT,lift.step_angle_at(time)),Lift.HINGE)
	var foot:=start
	for i in slices:
		var progress:=float(i+1)/slices
		var next_time:=time+duration*progress
		var next_cabin:=frame.translated_local(lift.position_at(next_time))
		var next_step:=next_cabin*Transform3D(Basis(Vector3.RIGHT,lift.step_angle_at(next_time)),Lift.HINGE)
		var next_foot:=start.lerp(end,progress)
		first_fraction=INF
		sweep(lift,deck_query,cabin,next_cabin,foot,next_foot,Vector2(Lift.DECK_SIZE.x,Lift.DECK_SIZE.z)*.5,floor_y)
		sweep(lift.plate,step_query,step,next_step,foot,next_foot,Vector2(Lift.PLATE_WIDTH,Lift.PLATE_LENGTH)*.5,floor_y)
		if is_finite(first_fraction):return true
		cabin=next_cabin
		step=next_step
		foot=next_foot
	return false
