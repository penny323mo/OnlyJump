extends MeshInstance3D

const Climber = preload("res://game/climber.gd")
const MARK = preload("res://game/landing_guide.gdshader")
const TICKS_PER_CAST := 4
const MAX_CASTS := 24
var contact := KinematicCollision3D.new()

func _ready() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(.58,.58)
	mesh = plane
	var ink := ShaderMaterial.new()
	ink.shader = MARK
	material_override = ink
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	hide()

# Keep the input constant while tracing. Sweep the same body that actually
# jumps, so the top of a narrow beam can support part of the player's sole.
func refresh(player: Climber, move: Vector2, tick: float) -> void:
	hide()
	if player.ability=="glide" or player.ability=="jet": return
	var grounded := player.is_on_floor()
	if grounded and move.is_zero_approx(): return
	var at := player.global_transform
	var horizontal := Vector2(player.velocity.x,player.velocity.z)
	var vertical := player.velocity.y
	var speed := player.air_speed
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
		for k in TICKS_PER_CAST:
			vertical -= player.GRAVITY*tick
			if not (grounded and segment==0 and k==0):
				horizontal = player.steer_in_air(horizontal,move,speed,tick)
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
