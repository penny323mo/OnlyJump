extends CharacterBody3D

const GROUND_SPEED := 3.35
const GRAVITY := 24.0
const CHARGE_TIME := 0.78
const RADIUS := 0.25
var aim := Vector2(0.45,-0.89).normalized()
var charging := false
var power := 0.0
var grounded_ledge := -1
var jump_count := 0
var model := Node3D.new()
var boots: Array[MeshInstance3D] = []
var scarf: MeshInstance3D
var dots: Array[MeshInstance3D] = []
var foot_shadow: MeshInstance3D
var gait := 0.0
var launch_pending := false
signal landed(ledge: int)
signal jumped(strength: float)

func build(art) -> void:
	floor_snap_length = 0.17
	var hit := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = RADIUS
	capsule.height = 1.13
	hit.shape = capsule
	hit.position.y = 0.57
	add_child(hit)
	add_child(model)
	for side in [-1,1]:
		boots.append(art.box(model,Vector3(side*0.128,0.15,-0.022),Vector3(0.18,0.30,0.25),"40383b"))
	# Ochre rain cape, red knitted hood, dark face and a rolled bedroll.
	art.cone(model,Vector3(0,0.5,0),0.52,0.37,0.22,"e0a244",7)
	art.cone(model,Vector3(0,0.7,0),0.20,0.33,0.18,"f1bd64",7)
	art.box(model,Vector3(0,0.91,-0.03),Vector3(0.35,0.33,0.33),"79493b")
	art.box(model,Vector3(0,1.06,0),Vector3(0.44,0.19,0.41),"b43e2d")
	art.box(model,Vector3(0,0.976,0.01),Vector3(0.46,0.087,0.43),"dc5737")
	art.box(model,Vector3(0,0.89,-0.189),Vector3(0.32,0.12,0.04),"e0a579")
	for side in [-1,1]:
		art.box(model,Vector3(side*0.082,0.911,-0.212),Vector3(0.039,0.038,0.022),"3d3538")
	art.box(model,Vector3(0,0.56,0.23),Vector3(0.28,0.32,0.14),"735038")
	art.cone(model,Vector3(0,0.73,0.265),0.41,0.093,0.093,"658781",8).rotation.z = PI/2
	scarf = art.box(model,Vector3(0.16,0.77,0.29),Vector3(0.11,0.055,0.39),"d34d36")
	for i in 8:
		var dot = art.cone(get_parent(),Vector3.ZERO,0.09,0.055,0.055,"ffdf87",5)
		dot.visible = false
		dots.append(dot)
	foot_shadow = art.cone(get_parent(),Vector3.ZERO,0.012,0.29,0.29,"766648",12)
	foot_shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func reset_at(p: Vector3) -> void:
	position = p + Vector3.UP*0.035
	velocity = Vector3.ZERO
	aim = Vector2(0.45,-0.89).normalized()
	cancel_charge()
	jump_count = 0
	grounded_ledge = -1

func begin_charge() -> void:
	if is_on_floor() and not charging:
		charging = true
		power = 0
		launch_pending = false

func release_charge() -> void:
	if charging:
		launch_pending = true

func cancel_charge() -> void:
	charging = false
	power = 0
	launch_pending = false
	for dot in dots:
		dot.visible = false

func launch_velocity() -> Vector3:
	var speed := lerpf(2.6,7.45,power)
	return Vector3(aim.x*speed,lerpf(5.9,12.25,power),aim.y*speed)

func step(delta: float, move: Vector2) -> void:
	var was_on_floor := is_on_floor()
	if was_on_floor:
		if move.length() > 0.14:
			aim = move.normalized()
		if charging:
			power = minf(1.0,power + delta/CHARGE_TIME)
			velocity = Vector3.ZERO
			if launch_pending:
				velocity = launch_velocity()
				jump_count += 1
				jumped.emit(power)
				cancel_charge()
		else:
			velocity = Vector3(move.x*GROUND_SPEED,0,move.y*GROUND_SPEED)
	else:
		velocity.y -= GRAVITY*delta
		# Small corrections preserve the commitment of a charged launch.
		velocity.x += move.x*1.05*delta
		velocity.z += move.y*1.05*delta
	move_and_slide()
	if is_on_floor():
		for i in get_slide_collision_count():
			var contact := get_slide_collision(i)
			if contact.get_normal().y < 0.7:
				continue
			var body := contact.get_collider() as Node3D
			if body and body.has_meta("ledge"):
				var index := int(body.get_meta("ledge"))
				if index != grounded_ledge or not was_on_floor:
					grounded_ledge = index
					landed.emit(index)
				break
	elif was_on_floor and charging:
		cancel_charge()
	animate(delta, move)

func animate(delta: float, move: Vector2) -> void:
	var walking := is_on_floor() and not charging and move.length() > 0.1
	gait += delta*(13 if walking else 3)
	model.rotation.y = lerp_angle(model.rotation.y,atan2(-aim.x,-aim.y),minf(1,delta*14))
	model.scale = Vector3(1+power*0.15,1-power*0.36,1+power*0.15)
	model.position.y = absf(sin(gait))*0.045 if walking else 0.0
	for i in boots.size():
		boots[i].rotation.x = sin(gait+i*PI)*0.50 if walking else 0.0
	scarf.rotation.x = sin(gait)*0.13 - (0.32 if not is_on_floor() else 0.0)
	var launch := launch_velocity()
	for i in dots.size():
		dots[i].visible = charging
		if charging:
			var t := (i+1)*0.089
			dots[i].global_position = global_position + Vector3.UP*0.22 + launch*t + Vector3.DOWN*(0.5*GRAVITY*t*t)
	var query := PhysicsRayQueryParameters3D.create(global_position+Vector3.UP*0.15,global_position+Vector3.DOWN*12)
	query.exclude = [get_rid()]
	var contact := get_world_3d().direct_space_state.intersect_ray(query)
	foot_shadow.visible = not contact.is_empty()
	if foot_shadow.visible:
		foot_shadow.global_position = contact.position+Vector3.UP*0.012
		var size := clampf(1.0-(global_position.y-foot_shadow.global_position.y)*0.10,0.45,1.0)
		foot_shadow.scale = Vector3(size,1,size)
