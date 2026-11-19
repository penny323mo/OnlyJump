extends CharacterBody3D

const COURIER = preload("res://assets/character/courier.glb")
const WALK_SPEED := 3.65
const RUN_SPEED := 6.45
const JUMP_SPEED := 6.4
const GRAVITY := 16.0
const GROUND_ACCEL := 25.0
const STANDING_PUSH := 2.85
const AIR_STEER := 2.8
const FOOT_RADIUS := 0.285
const COYOTE_TIME := 0.12
const BUFFER_TIME := 0.13

var aim := Vector2(0.45,-0.89).normalized()
var grounded_ledge := -1
var spring_impulse := Vector3.ZERO
var ability := ""
var ability_time := 0.0
var jet_armed := false
var jet_ceiling := 0.
var double_charges := 0
var extra_jump := true
var exhaust := Node3D.new()
var grab := preload("res://game/ledge_grab.gd").new()
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
var foot_shadow: MeshInstance3D
var heading := Node3D.new()
signal landed(ledge: int)
signal jumped()

func build(art) -> void:
	floor_snap_length = 0.21
	floor_stop_on_slope = true
	floor_max_angle = deg_to_rad(48)
	# A flat sole keeps partial contact on ledges instead of rolling off a capsule.
	var hit := CollisionShape3D.new()
	var sole := CylinderShape3D.new()
	sole.radius = FOOT_RADIUS
	sole.height = 1.18
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
	foot_shadow = art.cone(get_parent(),Vector3.ZERO,.012,.26,.26,"66625b",24)
	foot_shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func reset_at(p: Vector3) -> void:
	end_grab_pose()
	grab.reset()
	position = p + Vector3.UP*0.035
	velocity = Vector3.ZERO
	aim = Vector2(0.45,-0.89).normalized()
	jump_buffer = 0
	grace = 0
	jump_count = 0
	grounded_ledge = -1
	spring_impulse = Vector3.ZERO
	stop_stunt()
	equip("")

func equip(id: String) -> void:
	ability=id
	double_charges=3 if id=="double" else 0
	ability_time=float({"double":15,"jet":3,"glide":6}.get(id,0))
	jet_armed=id=="jet"
	extra_jump=true
	exhaust.visible=id=="jet"
	flames.hide()

func request_jump(move: Vector2) -> void:
	# A finger can lift between the tap and the next fixed physics tick.
	if grab.active: return
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

func step(delta: float, move: Vector2, running: bool) -> void:
	if ability!="" and not jet_armed:
		ability_time=maxf(0.,ability_time-delta)
		if ability_time<.00001: equip("")
	if grab.active:
		grab.advance(self,delta)
		pose_on_ledge()
		if not grab.active: end_grab_pose()
		return
	var on_floor_before := is_on_floor()
	if on_floor_before:
		grace = COYOTE_TIME
		extra_jump = true
	else: grace = maxf(0,grace-delta)
	var horizontal := Vector2(velocity.x,velocity.z)
	if move.length_squared() > .016: aim = move.normalized()
	var boosted := not spring_impulse.is_zero_approx()
	var air_jump := ability=="double" and extra_jump and not on_floor_before and grace<=0
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
		jumped.emit()
	if ability=="jet" and not jet_armed:
		spring_impulse=Vector3.ZERO
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
			horizontal = Vector2(spring_impulse.x,spring_impulse.z)
			velocity.y = spring_impulse.y-.5*GRAVITY*delta
			spring_impulse = Vector3.ZERO
		else:
			var push := tap_direction if move.is_zero_approx() else move
			horizontal = launch_horizontal(horizontal,push)
			velocity.y = JUMP_SPEED-.5*GRAVITY*delta
		air_speed = horizontal.length()
		grab.available = true
		jump_count += 1
		jumped.emit()
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
	if is_on_floor():
		grab.available=false
		stop_stunt()
		for i in get_slide_collision_count():
			var contact := get_slide_collision(i)
			var body := contact.get_collider() as Node3D
			if contact.get_normal().y < .66 or not body or not body.has_meta("ledge"): continue
			var index := int(body.get_meta("ledge"))
			if index != grounded_ledge or not on_floor_before:
				grounded_ledge = index
				if not on_floor_before and falling_speed<-.7 and body.has_meta("spring_target"):
					prime_spring(body)
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
		pose_on_ledge()
		return
	if stunt_time>0:
		stunt_time=maxf(0,stunt_time-delta)
		var angle:=TAU*smoothstep(0,1,1.-stunt_time/STUNT_SECONDS)
		stunt_pivot.basis=Basis(stunt_axis,angle) if stunt_time>0 else Basis.IDENTITY
	animate(delta,move,running)

func stop_stunt() -> void:
	stunt_time=0
	stunt_pivot.basis=Basis.IDENTITY

func prime_spring(body: Node3D) -> void:
	var foot := body.to_local(global_position)
	if Vector2(foot.x,foot.z).length() > float(body.get_meta("spring_radius")): return
	var offset: Vector3 = body.get_meta("spring_target")-global_position
	var rise_speed := 9.3
	var flight := (rise_speed+sqrt(maxf(0,rise_speed*rise_speed-2*GRAVITY*offset.y)))/GRAVITY
	spring_impulse = Vector3(offset.x/flight,rise_speed,offset.z/flight)

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

func animate(delta: float, move: Vector2, running: bool) -> void:
	model.rotation.y = lerp_angle(model.rotation.y,atan2(-aim.x,-aim.y),minf(1,delta*18))
	if not is_on_floor(): set_pose("Jump")
	elif move.length_squared()>.016: set_pose("Running" if running else "Walking")
	else: set_pose("Idle")
	heading.visible = is_on_floor() and move.length_squared()>.016
	heading.position = position+Vector3.UP*.055
	heading.rotation.y = atan2(-aim.x,-aim.y)
	var hit := ground_at(global_position,10)
	foot_shadow.visible = not hit.is_empty()
	if foot_shadow.visible:
		foot_shadow.global_position = hit.position+Vector3.UP*.014
		var size := clampf(1-(position.y-hit.position.y)*.11,.46,1)
		foot_shadow.scale = Vector3(size,1,size)

func set_pose(next: String) -> void:
	if next != pose:
		pose = next
		animations.play(next,.10)
