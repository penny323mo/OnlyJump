extends CharacterBody3D

const SpringPad = preload("res://game/spring_pad.gd")
const COURIER = preload("res://assets/character/courier.glb")
const WALK_SPEED := 3.65
const RUN_SPEED := 6.45
const JUMP_SPEED := 6.4
const GRAVITY := 16.0
const GROUND_ACCEL := 25.0
const STANDING_PUSH := 2.85
const AIR_STEER := 2.8
const FOOT_RADIUS := 0.285
const BODY_HEIGHT := 1.18
const COYOTE_TIME := 0.12
const BUFFER_TIME := 0.13
const ABILITY_SECONDS := {"double":15,"jet":3,"glide":6}
const MAX_DOUBLE_CHARGES := 3

var aim := Vector2(0.45,-0.89).normalized()
var grounded_ledge := -1
var standing_platform: Node3D
var local_foot := Vector3.ZERO
var platform_yaw := 0.0
var spring_pad: SpringPad
var ability := ""
var ability_time := 0.0
var jet_armed := false
var jet_ceiling := 0.
var double_charges := 0
var extra_jump := true
var exhaust := Node3D.new()
var grab := preload("res://game/ledge_grab.gd").new()
var hook := preload("res://game/grappling_hook.gd").new()
var costumes := preload("res://game/costumes.gd").new()
var rig: Skeleton3D
var arms: Array[PackedInt32Array] = []
var jump_count := 0
var jump_buffer := 0.0
var grace := 0.0
var tap_direction := Vector2.ZERO
var air_speed := 0.0
var model := Node3D.new()
var stunt_pivot := Node3D.new()
const STUNT_SECONDS := .47
var stunt_time := 0.
var stunt_axis := Vector3.ZERO
var flames := Node3D.new()
var animations: AnimationPlayer
var pose := ""
var foot_shadow := preload("res://game/foot_shadow.gd").new()
var stance := preload("res://game/ground_stance.gd").new()
var heading := Node3D.new()
signal landed(ledge: int)
signal jumped(from_spring: bool)

func build(art) -> void:
	hook.build(art)
	floor_snap_length = 0.21
	floor_stop_on_slope = true
	floor_max_angle = deg_to_rad(48)
	# A flat sole keeps partial contact on ledges instead of rolling off a capsule.
	var hit := CollisionShape3D.new()
	var sole := CylinderShape3D.new()
	sole.radius = FOOT_RADIUS
	sole.height = BODY_HEIGHT
	hit.shape = sole
	hit.position.y = sole.height/2
	add_child(hit)
	add_child(model)
	var courier: Node3D = COURIER.instantiate()
	model.add_child(stunt_pivot)
	stunt_pivot.position.y=.57
	stunt_pivot.add_child(courier)
	courier.position.y=-stunt_pivot.position.y
	courier.scale = Vector3.ONE*.285
	courier.rotation.y = PI
	rig = courier.find_children("*","Skeleton3D",true,false)[0]
	costumes.setup(art,rig,model)
	stance.build(rig,costumes.parts)
	model.add_child(exhaust)
	exhaust.add_child(flames)
	for side: float in [-1,1]:
		var nozzle:=Vector3(side*.155,.37,.17)
		art.cone(exhaust,nozzle+Vector3.UP*.12,.25,.083,.088,"4c646a",12)
		art.cone(flames,nozzle-Vector3.UP*.13,.27,.015,.071,"ffac31",12)
		art.cone(flames,nozzle-Vector3.UP*.067,.14,.028,.057,"fff2a9",12)
	exhaust.hide()
	for side in ["L","R"]:
		arms.append(PackedInt32Array([rig.find_bone("UpperArm."+side),rig.find_bone("LowerArm."+side),rig.find_bone("Palm2."+side)]))
	animations = courier.find_children("*","AnimationPlayer",true,false)[0]
	for clip in ["Idle","Walking","Running"]:
		animations.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	set_pose("Idle")
	get_parent().add_child(heading)
	for side in [-1,1]:
		art.tube(heading,Vector3(0,0,-0.85),Vector3(side*.16,0,-0.60),.034,"f5ab43")

func reset_at(p: Vector3) -> void:
	stance.release()
	foot_shadow.hide()
	end_grab_pose()
	grab.reset()
	position = p + Vector3.UP*0.035
	velocity = Vector3.ZERO
	aim = Vector2(0.45,-0.89).normalized()
	jump_buffer = 0
	grace = 0
	jump_count = 0
	grounded_ledge = -1
	standing_platform = null
	spring_pad = null
	stop_stunt()
	equip("")

func equip(id: String) -> void:
	hook.release()
	ability=id
	double_charges=MAX_DOUBLE_CHARGES if id=="double" else 0
	ability_time=float(ABILITY_SECONDS.get(id,0))
	jet_armed=id=="jet"
	extra_jump=true
	exhaust.visible=id=="jet"
	flames.hide()

func request_jump(move: Vector2) -> void:
	if spring_pad: return
	if grab.active:
		grab.pull_up()
		return
	# A finger can lift between the tap and the next fixed physics tick.
	tap_direction = move
	jump_buffer = BUFFER_TIME

func ground_at(point: Vector3, depth: float) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(point+Vector3.UP*.16,point+Vector3.DOWN*depth)
	query.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(query)

func launch_horizontal(horizontal: Vector2, direction: Vector2) -> Vector2:
	if is_on_floor() and horizontal.length_squared()<.04: return direction*STANDING_PUSH
	return horizontal

func steer_in_air(horizontal: Vector2, move: Vector2, speed: float, delta: float) -> Vector2:
	if move.is_zero_approx(): return horizontal
	var target := move.normalized()*maxf(speed,1.05)
	return horizontal.move_toward(target,AIR_STEER*move.length()*delta)

func settle_on_platform(body: Node3D) -> void:
	if body!=standing_platform:
		local_foot=body.to_local(global_position)
	else:
		# The solver carries us along the instantaneous tangent. Keep the sole
		# at its place on the rotating deck without pulling it through a wall.
		var correction:=(body.to_global(local_foot)-global_position).slide(get_floor_normal())
		if not correction.is_zero_approx() and move_and_collide(correction):
			local_foot=body.to_local(global_position)
		var turn:=angle_difference(platform_yaw,body.global_rotation.y)
		aim=aim.rotated(-turn)
		model.rotation.y+=turn
	standing_platform=body
	platform_yaw=body.global_rotation.y

func step(delta: float, move: Vector2, running: bool, camera: Camera3D) -> void:
	if ability_time>0 and not jet_armed:
		ability_time=maxf(0.,ability_time-delta)
		if ability_time<.00001: equip("")
	if grab.active:
		grab.advance(self,delta)
		pose_on_ledge()
		if not grab.active: end_grab_pose()
		return
	var on_floor_before := is_on_floor()
	if spring_pad and (not on_floor_before or grounded_ledge!=spring_pad.get_meta("ledge")):
		spring_pad=null
	if on_floor_before:
		grace = COYOTE_TIME
		extra_jump = true
	else: grace = maxf(0,grace-delta)
	var horizontal := Vector2(velocity.x,velocity.z)
	if move.length_squared() > .016: aim = move.normalized()
	var boosted := spring_pad!=null and not spring_pad.loading
	var air_jump := ability=="double" and extra_jump and not on_floor_before and grace<=0
	if ability=="hook" and jump_buffer>0 and not on_floor_before and grace<=0:
		jump_buffer=0
		if hook.time_left<=0 and hook.can_attach(self,camera):
			hook.attach()
			grab.available=false
	if hook.time_left>0 and not hook.clear_line(self): equip("")
	var pulling := hook.time_left>0
	if jump_buffer>0 and jet_armed:
		jet_armed=false
		flames.show()
		jump_buffer=0
		jet_ceiling=global_position.y+2.5
		velocity.y=clampf(velocity.y,1.25,2.45)
		air_speed=maxf(horizontal.length(),WALK_SPEED)
		grab.available=false
		grace=0
		jump_count+=1
		jumped.emit(false)
	if spring_pad and spring_pad.loading:
		horizontal=Vector2.ZERO
		velocity.y=-.5
	elif pulling:
		var pulled:=hook.pull(self,delta)
		velocity.y=minf(pulled.y-GRAVITY*delta,JUMP_SPEED)
		horizontal=Vector2(pulled.x,pulled.z)
		air_speed=horizontal.length()
		var toward:=hook.anchor.global_position-global_position
		aim=Vector2(toward.x,toward.z).normalized()
	elif ability=="jet" and not jet_armed:
		spring_pad=null
		var lift:=clampf((jet_ceiling-global_position.y)*2.8,0.,2.45)
		velocity.y=move_toward(velocity.y,lift,delta*19)
		horizontal=horizontal.move_toward(move*3.05,delta*9)
	elif boosted or (jump_buffer>0 and (grace>0 or air_jump)):
		if air_jump and not boosted:
			extra_jump=false
			double_charges-=1
			if double_charges==0: equip("")
			stunt_axis=Vector3.UP if tap_direction.is_zero_approx() else Vector3.LEFT
			stunt_time=STUNT_SECONDS
		jump_buffer = 0
		grace = 0
		if boosted:
			horizontal = Vector2(spring_pad.impulse.x,spring_pad.impulse.z)
			velocity.y = spring_pad.impulse.y-.5*GRAVITY*delta
			spring_pad = null
		else:
			var push := tap_direction if move.is_zero_approx() else move
			horizontal = launch_horizontal(horizontal,push)
			velocity.y = JUMP_SPEED-.5*GRAVITY*delta
		air_speed = horizontal.length()
		grab.available = true
		jump_count += 1
		jumped.emit(boosted)
	elif on_floor_before:
		var target := move*(RUN_SPEED if running else WALK_SPEED)
		if move.is_zero_approx():
			horizontal = Vector2.ZERO
		else:
			var direction := Vector3(move.x,0,move.y).normalized()
			var support := ground_at(position+direction*(FOOT_RADIUS+.16),.34)
			if support.is_empty() or support.normal.y<.65:
				target *= .88 if running else .46
			horizontal = horizontal.move_toward(target,GROUND_ACCEL*delta)
		velocity.y = 0
		air_speed = horizontal.length()
	else:
		velocity.y -= GRAVITY*delta
		if ability=="glide": velocity.y=maxf(velocity.y,-2.1)
		# Keep launch momentum when the stick or sprint finger is released.
		# In-air input steers gently, within the launch-speed envelope.
		horizontal = steer_in_air(horizontal,move,air_speed,delta)
		if ability=="glide" and velocity.y<0: horizontal=horizontal.limit_length(WALK_SPEED)
	velocity.x = horizontal.x
	velocity.z = horizontal.y
	jump_buffer = maxf(0,jump_buffer-delta)
	var falling_speed := velocity.y
	# A vertical jumper can reach the rim in front of their chest.
	var reach := Vector2(-model.basis.z.x,-model.basis.z.z) if horizontal.is_zero_approx() else horizontal
	move_and_slide()
	if not is_on_floor(): standing_platform=null
	if pulling:
		if hook.time_left<=0 or get_slide_collision_count()>0 or hook.chest(self).distance_to(hook.anchor.global_position)<.38:
			equip("")
	var floor_contact: KinematicCollision3D
	if is_on_floor():
		grab.available=false
		stop_stunt()
		for i in get_slide_collision_count():
			var contact := get_slide_collision(i)
			var body := contact.get_collider() as Node3D
			if contact.get_normal().y < .66 or not body or not body.has_meta("ledge"): continue
			floor_contact=contact
			if move.is_zero_approx() and body.has_meta("mobile_surface"): settle_on_platform(body)
			else: standing_platform=null
			var index := int(body.get_meta("ledge"))
			if index != grounded_ledge or not on_floor_before:
				grounded_ledge = index
				if not on_floor_before and falling_speed<-.7 and body is SpringPad:
					var incoming:=Vector3(horizontal.x,falling_speed,horizontal.y)
					if body.start_stroke(global_position,incoming,GRAVITY):
						spring_pad=body
						jump_buffer=0.
				landed.emit(index)
			break
	elif falling_speed<-.2 and falling_speed> -8.5 and grab.try_catch(self,reach,grounded_ledge,FOOT_RADIUS):
		stop_stunt()
		velocity=Vector3.ZERO
		grace=0
		jump_buffer=0
		animations.play("Jump")
		animations.seek(.18,true)
		animations.pause()
		heading.hide()
		foot_shadow.hide()
		stance.release()
		pose_on_ledge()
		return
	if stunt_time>0:
		stunt_time=maxf(0,stunt_time-delta)
		var angle:=TAU*smoothstep(0,1,1.-stunt_time/STUNT_SECONDS)
		stunt_pivot.basis=Basis(stunt_axis,angle) if stunt_time>0 else Basis.IDENTITY
	animate(delta,move,running,floor_contact)
	if hook.time_left>0:
		var arm:=arms[1]
		var target:=rig.to_local(hook.anchor.global_position)
		aim_bone(arm[0],arm[1],target)
		aim_bone(arm[1],arm[2],target)
		hook.draw_line(rig.to_global(rig.get_bone_global_pose(arm[2]).origin))

func stop_stunt() -> void:
	stunt_time=0
	stunt_pivot.basis=Basis.IDENTITY

func end_grab_pose() -> void:
	if animations and (grab.active or not animations.is_playing()):
		model.rotation.x=0
		pose=""
		set_pose("Idle")

func pose_on_ledge() -> void:
	aim=Vector2(grab.forward.x,grab.forward.z).normalized()
	model.rotation.y=atan2(-aim.x,-aim.y)
	model.rotation.x=-.20*sin(PI*grab.climb_progress())
	for i in arms.size():
		var arm := arms[i]
		var upper := rig.get_bone_global_pose(arm[0]).origin
		var elbow := rig.get_bone_global_pose(arm[1]).origin
		var palm := rig.get_bone_global_pose(arm[2]).origin
		var target := rig.to_local(grab.hands[i])
		var toward := upper.direction_to(target)
		# Solve the two arm segments towards a stationary handhold.
		# Bend the elbow outwards as the body rises through the pull-up.
		var a := upper.distance_to(elbow)
		var b := elbow.distance_to(palm)
		var d := clampf(upper.distance_to(target),absf(a-b)+.00001,a+b-.00001)
		var along := (a*a+d*d-b*b)/(2*d)
		var side := -1 if i==0 else 1
		var pole := rig.global_basis.inverse()*(grab.forward.cross(Vector3.UP)*side+Vector3.DOWN*.7-grab.forward*.5)
		var bend := pole.slide(toward).normalized()
		var bent := upper+toward*along+bend*sqrt(maxf(0.,a*a-along*along))
		aim_bone(arm[0],arm[1],bent)
		aim_bone(arm[1],arm[2],target)

func aim_bone(bone: int, child: int, target: Vector3) -> void:
	var xform := rig.get_bone_global_pose(bone)
	var from := xform.origin.direction_to(rig.get_bone_global_pose(child).origin)
	var to := xform.origin.direction_to(target)
	if from.is_zero_approx() or to.is_zero_approx(): return
	xform.basis=Basis(Quaternion(from,to))*xform.basis
	rig.set_bone_global_pose(bone,xform)

func animate(delta: float, move: Vector2, running: bool, floor_contact: KinematicCollision3D) -> void:
	model.rotation.y = lerp_angle(model.rotation.y,atan2(-aim.x,-aim.y),minf(1,delta*18))
	var hit := ground_at(global_position,10)
	if spring_pad:
		# Both feet stay planted through the crouch in the standing-up clip.
		if pose!="Standing":
			pose="Standing"
			animations.play(pose,0.)
			animations.pause()
		animations.seek((1.-spring_pad.load_fraction())*.32,true)
	elif not is_on_floor():
		if pose!="Airborne":
			pose="Airborne"
			animations.play(pose,0.)
			animations.pause()
		# Extend at takeoff, tuck at the apex and reach for the actual floor.
		var phase:=clampf((JUMP_SPEED-velocity.y)/(2.*JUMP_SPEED),0.,1.)
		var sample_time:=lerpf(.205,.50,phase)
		if velocity.y<0. and not hit.is_empty():
			var clearance:=global_position.y-float(hit.position.y)
			sample_time=lerpf(.50,sample_time,smoothstep(.10,.55,clearance))
		animations.seek(sample_time,true)
	elif move.length_squared()>.016: set_pose("Running" if running else "Walking")
	else: set_pose("Idle")
	heading.visible = not spring_pad and is_on_floor() and move.length_squared()>.016
	heading.position = position+Vector3.UP*.055
	heading.rotation.y = atan2(-aim.x,-aim.y)
	# A centre ray beyond the lip can miss, or hit a lower rung of the same object.
	if floor_contact:
		var surface:=floor_contact.get_position()
		var body:=floor_contact.get_collider()
		if hit.get("collider")!=body or absf(hit.position.y-surface.y)>FOOT_RADIUS*tan(floor_max_angle)+safe_margin:
			hit={"position":surface,"collider":body}
	stance.sample_floor(self,floor_contact,hit,delta)
	foot_shadow.project(global_position,hit)

func set_pose(next: String) -> void:
	if next != pose:
		pose = next
		animations.play(next,.10)
