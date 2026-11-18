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
var jump_count := 0
var jump_buffer := 0.0
var grace := 0.0
var tap_direction := Vector2.ZERO
var air_speed := 0.0
var model := Node3D.new()
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
	model.add_child(courier)
	courier.scale = Vector3.ONE*.285
	courier.rotation.y = PI
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
	position = p + Vector3.UP*0.035
	velocity = Vector3.ZERO
	aim = Vector2(0.45,-0.89).normalized()
	jump_buffer = 0
	grace = 0
	jump_count = 0
	grounded_ledge = -1

func request_jump(move: Vector2) -> void:
	# A finger can lift between the tap and the next fixed physics tick.
	tap_direction = move
	jump_buffer = BUFFER_TIME

func ground_at(point: Vector3, depth: float) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(point+Vector3.UP*.16,point+Vector3.DOWN*depth)
	query.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(query)

func step(delta: float, move: Vector2, running: bool) -> void:
	var on_floor_before := is_on_floor()
	if on_floor_before: grace = COYOTE_TIME
	else: grace = maxf(0,grace-delta)
	var horizontal := Vector2(velocity.x,velocity.z)
	if move.length_squared() > .016: aim = move.normalized()
	var taking_off := jump_buffer>0 and grace>0
	if taking_off:
		jump_buffer = 0
		grace = 0
		# Push off from rest, or carry the speed built on the approach.
		var push := tap_direction if move.is_zero_approx() else move
		if on_floor_before and horizontal.length_squared()<0.04:
			horizontal = push*STANDING_PUSH
		air_speed = horizontal.length()
		velocity.y = JUMP_SPEED-0.5*GRAVITY*delta
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
		# Keep launch momentum when the stick or sprint finger is released.
		# In-air input steers gently, within the launch-speed envelope.
		if not move.is_zero_approx():
			var steer := move.normalized()*maxf(air_speed,1.05)
			horizontal = horizontal.move_toward(steer,AIR_STEER*move.length()*delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.y
	jump_buffer = maxf(0,jump_buffer-delta)
	move_and_slide()
	if is_on_floor():
		for i in get_slide_collision_count():
			var contact := get_slide_collision(i)
			var body := contact.get_collider() as Node3D
			if contact.get_normal().y < .66 or not body or not body.has_meta("ledge"): continue
			var index := int(body.get_meta("ledge"))
			if index != grounded_ledge or not on_floor_before:
				grounded_ledge = index
				landed.emit(index)
			break
	animate(delta,move,running)

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
