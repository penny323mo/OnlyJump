extends MeshInstance3D

const Climber = preload("res://game/climber.gd")
const Lift = preload("res://game/laundry_lift.gd")
const MARK = preload("res://game/landing_guide.gdshader")
const MARK_SIZE := .58
const TICKS_PER_CAST := 4
const MAX_CASTS := 24
var contact := PhysicsTestMotionResult3D.new()
var scene_query := PhysicsTestMotionParameters3D.new()
var tick_starts := PackedVector3Array()
var tick_moves := PackedVector3Array()
var lift_forecast := preload("res://game/lift_forecast.gd").new()
var moving_support: Node3D
var local_mark := Transform3D.IDENTITY
var ink := ShaderMaterial.new()

func _ready() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE*MARK_SIZE
	mesh = plane
	ink.shader = MARK
	material_override = ink
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	hide()

func configure(player: Climber, lift: Lift) -> void:
	tick_starts.resize(TICKS_PER_CAST)
	tick_moves.resize(TICKS_PER_CAST)
	add_child(lift_forecast)
	lift_forecast.configure(player,lift)
	scene_query.exclude_bodies=[lift.get_rid(),lift.plate.get_rid()]
	scene_query.max_collisions=4
	scene_query.margin=player.safe_margin

func follow_support() -> void:
	if visible and moving_support:
		global_transform=moving_support.global_transform*local_mark

func mark_surface(point: Vector3, normal: Vector3, inward: Vector3, carrier: Node3D=null) -> void:
	var direction:=inward.slide(normal)
	var perched:=direction.length_squared()>.000004
	var axes:=Basis.looking_at(direction.normalized(),normal) if perched else Basis(Quaternion(Vector3.UP,normal))
	ink.set_shader_parameter("edge_landing",perched)
	moving_support=carrier
	local_mark=Transform3D(axes,point+normal*.028)
	global_transform=carrier.global_transform*local_mark if carrier else local_mark
	show()

# Probe the predicted contact plane. Another rung can belong to exactly
# the same body yet sit below the part of the sole that actually lands.
func probe(player: Climber, body: CollisionObject3D, at: Vector3, floor_y: float) -> Dictionary:
	var hit:=player.ground_at(at,.10)
	if hit.get("collider")==body and hit.normal.y>=floor_y and absf(hit.position.y-at.y)<.10:
		return hit
	return {}

func mark_contact(player: Climber, body: CollisionObject3D, index: int, sole: Vector3, floor_y: float) -> bool:
	var point:=contact.get_collision_point(index)
	var normal:=contact.get_collision_normal(index)
	sole.y=point.y-(normal.x*(sole.x-point.x)+normal.z*(sole.z-point.z))/normal.y
	var hit:=probe(player,body,sole,floor_y)
	if not hit.is_empty():
		mark_surface(hit.position,hit.normal,Vector3.ZERO)
		return true

	# A box manifold can report a corner far along a beam. Use its actual
	# shape transform to find the rim directly below this runner.
	var owner_id:=body.shape_find_owner(contact.get_collider_shape(index))
	var collider:=body.shape_owner_get_owner(owner_id) as CollisionShape3D
	if collider and collider.shape is BoxShape3D:
		var half: Vector3=collider.shape.size*.5
		var rim:=collider.to_global(collider.to_local(sole).clamp(-half,half))
		var inward:=rim-sole
		if Vector2(inward.x,inward.z).length()<=player.FOOT_RADIUS:
			hit=probe(player,body,rim+inward.normalized()*.002,floor_y)
			if not hit.is_empty():
				mark_surface(hit.position,hit.normal,inward)
				return true

	# For curved or mesh props, sample the edge of the circular sole.
	# Bisect towards its centre to anchor the arrow on a verified surface.
	var offset:=Vector3(point.x-sole.x,0.,point.z-sole.z).normalized()
	if offset.is_zero_approx():offset=Vector3.RIGHT
	var first:=Vector3.ZERO
	var sum:=Vector3.ZERO
	for i in 12:
		var sample:=offset.rotated(Vector3.UP,TAU*i/12.)*player.FOOT_RADIUS
		sample.y=-normal.dot(sample)/normal.y
		if probe(player,body,sole+sample,floor_y).is_empty():continue
		if first.is_zero_approx():first=sample
		sum+=sample
	if first.is_zero_approx():return false
	var inside:=sum/maxf(Vector2(sum.x,sum.z).length(),.00001)*player.FOOT_RADIUS
	hit=probe(player,body,sole+inside,floor_y)
	if hit.is_empty():
		inside=first
		hit=probe(player,body,sole+inside,floor_y)
	var outside:=Vector3.ZERO
	for i in 4:
		var mid:=(inside+outside)*.5
		var candidate:=probe(player,body,sole+mid,floor_y)
		if candidate.is_empty():outside=mid
		else:
			inside=mid
			hit=candidate
	mark_surface(hit.position,hit.normal,inside)
	return true

func screen_bounds(camera: Camera3D, viewport_size: Vector2) -> Rect2:
	if not visible or camera.is_position_behind(global_position): return Rect2()
	var bounds:=Rect2(camera.unproject_position(global_position)/viewport_size,Vector2.ZERO)
	for x: float in [-.5,.5]:
		for z: float in [-.5,.5]:
			var corner:=to_global(Vector3(x,0,z)*MARK_SIZE)
			if camera.is_position_behind(corner): return Rect2()
			bounds=bounds.expand(camera.unproject_position(corner)/viewport_size)
	return bounds

# A four-tick sweep can touch a bevel that a runner slipping past it hits
# side-on. Confirm the first contact using the runner's actual tick lengths.
func first_impact(player: Climber, start: Transform3D, linear_step: Vector3, first_tick: int, ticks: int) -> float:
	for k in range(first_tick,ticks):
		if linear_step.is_zero_approx():
			scene_query.from=Transform3D(start.basis,tick_starts[k])
			scene_query.motion=tick_moves[k]
		else:
			scene_query.from=Transform3D(start.basis,start.origin+linear_step*k)
			scene_query.motion=linear_step
		if PhysicsServer3D.body_test_motion(player.get_rid(),scene_query,contact):
			return k+contact.get_collision_safe_fraction()
	return INF

# Keep the input constant while tracing. Sweep the same body that actually
# jumps, so the top of a narrow beam can support part of the player's sole.
func refresh(player: Climber, move: Vector2, tick: float) -> void:
	hide()
	moving_support=null
	if player.spring_pad or player.ability=="jet" or player.hook.time_left>0: return
	var grounded := player.is_on_floor()
	if grounded and move.is_zero_approx() and not player.coasting(): return
	var at := player.global_transform
	var horizontal := Vector2(player.velocity.x,player.velocity.z)
	var vertical := player.velocity.y
	var speed := player.air_speed
	var glide_left:=player.ability_time if player.ability=="glide" else 0.
	if grounded:
		horizontal = player.launch_horizontal(horizontal,move)
		speed = horizontal.length()
		# move_and_slide adds the support's contact velocity on takeoff.
		# Air steering still uses the runner's speed relative to the support.
		var carry := player.get_platform_velocity()
		horizontal += Vector2(carry.x,carry.z)
		vertical = player.JUMP_SPEED + player.takeoff_rise() + .5*player.GRAVITY*tick + carry.y
	var ahead:=0.
	var floor_y:=cos(player.floor_max_angle)
	for segment in MAX_CASTS:
		var motion := Vector3.ZERO
		# At terminal speed a steady glide is one straight sweep. Stop at
		# expiry, then trace normal gravity within the same phone cast budget.
		var steady_ticks:=0
		if glide_left>tick*TICKS_PER_CAST and is_equal_approx(vertical,-Climber.GLIDE_FALL_SPEED):
			if player.steer_in_air(horizontal,move,speed,tick,true).is_equal_approx(horizontal):
				steady_ticks=floori((glide_left-Climber.TIMER_EPSILON)/tick)
		if steady_ticks>0:
			var span:=steady_ticks*tick
			motion=Vector3(horizontal.x,vertical,horizontal.y)*span
			glide_left-=span
		else:
			var world_point:=at.origin
			for k in TICKS_PER_CAST:
				glide_left=maxf(0.,glide_left-tick)
				var gliding:=glide_left>=Climber.TIMER_EPSILON
				vertical=player.fall_speed(vertical,gliding,tick)
				if not (grounded and segment==0 and k==0):
					horizontal=player.steer_in_air(horizontal,move,speed,tick,gliding and vertical<0.)
				# The live body stores velocity and position as Vector3 each
				# tick. Preserve that rounding near a face/side transition.
				var velocity:=Vector3(horizontal.x,vertical,horizontal.y)
				vertical=velocity.y
				tick_starts[k]=world_point
				tick_moves[k]=velocity*tick
				world_point+=tick_moves[k]
			motion=world_point-at.origin
		var ticks:=steady_ticks if steady_ticks>0 else TICKS_PER_CAST
		scene_query.from=at
		scene_query.motion=motion
		var impact:=INF
		if PhysicsServer3D.body_test_motion(player.get_rid(),scene_query,contact):
			var first_tick:=0
			var linear_step:=motion/steady_ticks if steady_ticks>0 else Vector3.ZERO
			if steady_ticks>TICKS_PER_CAST:
				# The straight part of a sock glide may span several seconds.
				# Skip the clear prefix and resume the glide after this window.
				first_tick=maxi(0,floori(steady_ticks*contact.get_collision_safe_fraction())-1)
				ticks=mini(first_tick+TICKS_PER_CAST,steady_ticks)
				glide_left+=(steady_ticks-ticks)*tick
				motion=linear_step*ticks
			impact=first_impact(player,at,linear_step,first_tick,ticks)
		var stop:=scene_query.from.origin+contact.get_travel() if is_finite(impact) else at.origin+motion
		if lift_forecast.trace(at.origin,stop,ahead,minf(impact,ticks)*tick,tick,floor_y):
			if lift_forecast.support:
				mark_surface(lift_forecast.local_point,Vector3.UP,lift_forecast.inward,lift_forecast.support)
			return
		if is_finite(impact):
			if scene_query.motion.y>=0: return
			for i in contact.get_collision_count():
				var normal := contact.get_collision_normal(i)
				var body := contact.get_collider(i)
				if normal.y<floor_y or not body.has_meta("ledge"): continue
				if body.has_meta("mobile_surface") or body.has_meta("drop_surface"): return
				if mark_contact(player,body,i,stop,floor_y):return
			# A wall or underside blocks this arc. Wait for the real deflection.
			return
		at.origin += motion
		ahead+=ticks*tick
