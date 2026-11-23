extends MeshInstance3D

const Climber = preload("res://game/climber.gd")
const MARK = preload("res://game/landing_guide.gdshader")
const MARK_SIZE := .58
const TICKS_PER_CAST := 4
const MAX_CASTS := 24
var contact := KinematicCollision3D.new()

func _ready() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE*MARK_SIZE
	mesh = plane
	var ink := ShaderMaterial.new()
	ink.shader = MARK
	material_override = ink
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	hide()

func screen_bounds(camera: Camera3D, viewport_size: Vector2) -> Rect2:
	if not visible or camera.is_position_behind(global_position): return Rect2()
	var bounds:=Rect2(camera.unproject_position(global_position)/viewport_size,Vector2.ZERO)
	for x: float in [-.5,.5]:
		for z: float in [-.5,.5]:
			var corner:=to_global(Vector3(x,0,z)*MARK_SIZE)
			if camera.is_position_behind(corner): return Rect2()
			bounds=bounds.expand(camera.unproject_position(corner)/viewport_size)
	return bounds

# Keep the input constant while tracing. Sweep the same body that actually
# jumps, so the top of a narrow beam can support part of the player's sole.
func refresh(player: Climber, move: Vector2, tick: float) -> void:
	hide()
	if player.spring_pad or player.ability=="jet" or player.hook.time_left>0: return
	var grounded := player.is_on_floor()
	if grounded and move.is_zero_approx(): return
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
		vertical = player.JUMP_SPEED + .5*player.GRAVITY*tick + carry.y
	for segment in MAX_CASTS:
		var motion := Vector3.ZERO
		# At terminal speed a steady glide is one straight sweep. Stop at
		# expiry, then trace normal gravity within the same phone cast budget.
		var steady_ticks:=0
		if glide_left>tick*TICKS_PER_CAST and vertical==-Climber.GLIDE_FALL_SPEED:
			if player.steer_in_air(horizontal,move,speed,tick,true).is_equal_approx(horizontal):
				steady_ticks=floori((glide_left-Climber.TIMER_EPSILON)/tick)
		if steady_ticks>0:
			var span:=steady_ticks*tick
			motion=Vector3(horizontal.x,vertical,horizontal.y)*span
			glide_left-=span
		else:
			for k in TICKS_PER_CAST:
				glide_left=maxf(0.,glide_left-tick)
				var gliding:=glide_left>=Climber.TIMER_EPSILON
				vertical=player.fall_speed(vertical,gliding,tick)
				if not (grounded and segment==0 and k==0):
					horizontal=player.steer_in_air(horizontal,move,speed,tick,gliding and vertical<0.)
				motion += Vector3(horizontal.x,vertical,horizontal.y)*tick
		if player.test_move(at,motion,contact,player.safe_margin,false,4):
			if motion.y>=0: return
			for i in contact.get_collision_count():
				var normal := contact.get_normal(i)
				var body := contact.get_collider(i)
				if normal.y<cos(player.floor_max_angle) or not body.has_meta("ledge"): continue
				if body.has_meta("mobile_surface") or body.has_meta("drop_surface"): return
				# Use the surface under the centre of the sole where it exists.
				# On an overhang the actual contact is the supported edge instead.
				var point := contact.get_position(i)
				var sole := at.origin+contact.get_travel()
				var center := player.ground_at(sole,player.FOOT_RADIUS+.07)
				if center.get("collider")==body and center.normal.y>=cos(player.floor_max_angle):
					point = center.position
					normal = center.normal
				global_position = point+normal*.028
				quaternion = Quaternion(Vector3.UP,normal)
				show()
				return
			# A wall or underside blocks this arc. Wait for the real deflection.
			return
		at.origin += motion
