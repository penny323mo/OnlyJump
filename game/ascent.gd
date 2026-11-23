extends Node3D

const Islands = preload("res://game/islands.gd")
const Climber = preload("res://game/climber.gd")
const SKY_SHADER = preload("res://game/sky.gdshader")
const DEFAULT_CAMERA_REACH := 6.8
const CLOSEST_ZOOM := 3.6
const FARTHEST_ZOOM := 11.0
const FULL_BODY_DISTANCE := 2.65
const CAMERA_FREE_STEP := .58
const JUMP_SOUND := preload("res://audio/lift.wav")
const SPRING_SOUND := preload("res://audio/spring.wav")
const SUMMIT_SOUND := preload("res://audio/summit.wav")
var art := Islands.new()
var player := Climber.new()
var camera := Camera3D.new()
var oil_paint := ColorRect.new()
var landing_guide := preload("res://game/landing_guide.gd").new()
var landing_ring := MeshInstance3D.new()
var audio := AudioStreamPlayer.new()
var footfall := AudioStreamPlayer.new()
var phase := "intro"
var elapsed := 0.0
var falls := 0
var ledge := 0
var alternate := false
var best := 0.0
var summit_times := preload("res://game/summit_times.gd").new(Islands.ROUTE.size()-1)
var record_path := "user://summit.cfg"
var muted := false
var web: JavaScriptObject
var touch_web := false
var web_callback: JavaScriptObject
var native_label: Label
var stick := Vector2.ZERO
var camera_yaw := 0.0
var camera_pitch := deg_to_rad(24.0)
var camera_reach := DEFAULT_CAMERA_REACH
var camera_distance := DEFAULT_CAMERA_REACH
var camera_anchor := Vector2.ZERO
var recenter_camera := false
var camera_pitch_offset := 0.0
var frame_aerial := false
var camera_sweep := PhysicsShapeQueryParameters3D.new()
var camera_ray := PhysicsRayQueryParameters3D.new()
var show_route_ring := false
var show_landing_guide := true
# Capture the view when a movement gesture begins. Automatic camera motion
# must not feed back into that same held direction and turn it into a circle.
var native_drag := false
var sprint := false
var hud_clock := 0.0
var menu_time := 0.0
var notice := ""

func _ready() -> void:
	if OS.has_feature("web"):
		web = JavaScriptBridge.get_interface("OnlyJumpUI")
		touch_web = web != null and bool(web.touchGraphics)
	var lightweight := web != null and bool(web.lightweight)
	if lightweight:
		get_viewport().msaa_3d = Viewport.MSAA_DISABLED
	var env := Environment.new()
	var sky := Sky.new()
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = SKY_SHADER
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_sky_contribution = 0.0
	env.ambient_light_energy = 0.42
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.tonemap_exposure = 0.93
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.ambient_light_color = Color("e9edf5")
	env.fog_enabled = true
	env.fog_light_color = Color("a4b9cb")
	env.fog_density = 0.0085
	env.fog_sky_affect = 0.23
	var world := WorldEnvironment.new()
	world.environment = env
	add_child(world)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-47,-32,0)
	light.light_color = Color("ffebce")
	light.light_energy = 0.49
	light.shadow_enabled = not lightweight
	light.directional_shadow_max_distance = 46
	add_child(light)
	add_child(art)
	var ring := TorusMesh.new()
	ring.inner_radius = 0.32
	ring.outer_radius = 0.42
	ring.rings = 24
	ring.ring_segments = 5
	landing_ring.mesh = ring
	landing_ring.material_override = art.material("f89d3e")
	landing_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(landing_ring)
	add_child(landing_guide)
	add_child(player)
	player.build(art)
	landing_guide.configure(player,art.branches.lift)
	var column := BoxShape3D.new()
	column.size = Vector3(.30,player.BODY_HEIGHT+.06,.30)
	camera_sweep.shape = column
	camera_sweep.exclude = [player.get_rid()]
	camera_ray.exclude = camera_sweep.exclude
	player.landed.connect(on_landing)
	player.jumped.connect(on_jump)
	add_child(camera)
	camera.make_current()
	camera.fov = 54
	camera.far = 320
	add_child(audio)
	add_child(footfall)
	var paint_layer:=CanvasLayer.new()
	paint_layer.layer=1
	paint_layer.visible=not lightweight
	add_child(paint_layer)
	paint_layer.add_child(oil_paint)
	oil_paint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	oil_paint.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var paint_material:=ShaderMaterial.new()
	paint_material.shader=preload("res://game/oil_paint.gdshader")
	oil_paint.material=paint_material
	oil_paint.hide()
	var data := ConfigFile.new()
	if data.load(record_path) == OK:
		summit_times.load_best(data.get_value("run","fastest_ascent",{}))
		player.costumes.select(str(data.get_value("controls","character","courier")))
		show_route_ring = data.get_value("controls","route_ring",false)
		show_landing_guide = data.get_value("controls","landing_guide",true)
		if data.has_section_key("run","best_height"):
			best = data.get_value("run","best_height",0.0)
		elif data.has_section_key("run","best_ledge"):
			var index := clampi(data.get_value("run","best_ledge",0),0,Islands.ROUTE.size()-1)
			best = Islands.ROUTE[index].y
		else:
			var old_height: float = data.get_value("run","best",0.0)
			for i in Islands.PREVIOUS_HEIGHTS.size():
				if old_height+.001 >= Islands.PREVIOUS_HEIGHTS[i]: best = Islands.ROUTE[i].y
		muted = data.get_value("run","muted",false)
		oil_paint.visible=data.get_value("display","art_style","normal")=="oil"
	player.reset_at(Islands.ROUTE[0])
	if web:
		web_callback = JavaScriptBridge.create_callback(web_command)
		RenderingServer.frame_post_draw.connect(func(): web.bindGame(web_callback), CONNECT_ONE_SHOT)
	else:
		var layer := CanvasLayer.new()
		layer.layer=2
		add_child(layer)
		native_label = Label.new()
		layer.add_child(native_label)
		native_label.position = Vector2(28,24)
		native_label.add_theme_font_size_override("font_size",22)
		native_label.add_theme_constant_override("outline_size",6)
	intro_camera()
	update_hud()

func save_record() -> void:
	var data := ConfigFile.new()
	data.set_value("run","best_height",best)
	if not summit_times.best.is_empty():
		data.set_value("run","fastest_ascent",summit_times.best)
	data.set_value("controls","character",player.costumes.key)
	data.set_value("controls","route_ring",show_route_ring)
	data.set_value("controls","landing_guide",show_landing_guide)
	data.set_value("run","muted",muted)
	data.set_value("display","art_style","oil" if oil_paint.visible else "normal")
	data.save(record_path)

func web_command(args: Array) -> void:
	if args.is_empty():
		return
	match str(args[0]):
		"character":
			if phase=="intro" and args.size()==2 and player.costumes.NAMES.has(str(args[1])):
				player.costumes.select(str(args[1]))
				save_record()
		"start": start_run()
		"pause": toggle_pause()
		"hide": interrupt_run()
		"resume":
			if phase=="interrupted": resume_run()
		"menu": show_intro()
		"restart": start_run()
		"mute":
			muted = not muted
			if muted:
				audio.stop()
				footfall.stop()
			save_record()
		"stick":
			if phase in ["playing","interrupted"] and args.size() == 3:
				stick = Vector2(float(args[1]),float(args[2])).limit_length()
				if phase=="interrupted" and not stick.is_zero_approx(): resume_run()
			return
		"look":
			if phase in ["playing","interrupted"] and args.size() == 3:
				orbit(float(args[1]),float(args[2]))
			return
		"zoom":
			if phase in ["playing","interrupted"] and args.size() == 2:
				var scale_factor := float(args[1])
				if is_finite(scale_factor) and scale_factor > 0:
					camera_reach = clampf(camera_reach/scale_factor,CLOSEST_ZOOM,FARTHEST_ZOOM)
					if phase=="interrupted": recenter_camera=true
			return
		"branch":
			if phase=="playing" and Islands.Branches.FORKS.has(ledge):
				alternate=not alternate
				if Islands.Branches.FORKS[ledge]==Islands.Branches.PENDULUM:
					notice="等銅擺經過低位，再跳上去" if alternate else ""
				elif Islands.Branches.FORKS[ledge]==Islands.Branches.LIFT:
					notice="等吊籃返嚟，黃邊踏板放平就可以跳上去" if alternate else ""
				face_target()
		"align":
			if phase == "playing": face_target()
		"sprint":
			if phase in ["playing","interrupted"] and args.size()==2: sprint = bool(args[1])
		"route_ring","landing_guide":
			if phase=="paused" and args.size()==2:
				set_hint(str(args[0]),bool(args[1]))
		"art_style":
			if phase=="paused" and args.size()==2 and args[1] in ["normal","oil"]:
				oil_paint.visible=args[1]=="oil"
				save_record()
		"jump":
			if phase=="interrupted": resume_run()
			if phase == "playing": queue_jump()
	update_hud()

func clear_controls() -> void:
	landing_guide.hide()
	stick = Vector2.ZERO
	native_drag = false
	sprint = false
	player.jump_buffer = 0
	if web: web.clearInputs()

func show_intro() -> void:
	phase = "intro"
	ledge=0
	alternate=false
	art.branches.reset()
	art.pickups.reset()
	clear_controls()
	player.reset_at(Islands.ROUTE[0])
	intro_camera()
	update_hud()

func start_run() -> void:
	frame_aerial=false
	phase = "playing"
	elapsed = 0
	falls = 0
	summit_times.start_run()
	art.branches.reset()
	art.pickups.reset()
	alternate=false
	ledge = 0
	clear_controls()
	camera_yaw = 0.0
	camera_pitch = deg_to_rad(24)
	notice = ""
	player.reset_at(Islands.ROUTE[0])
	game_camera(1.0,true)
	update_hud()

func toggle_pause() -> void:
	if phase in ["playing","interrupted"]:
		phase = "paused"
		clear_controls()
	elif phase == "paused":
		resume_run()
		return
	update_hud()

func interrupt_run() -> void:
	if phase not in ["playing","interrupted"]: return
	phase="interrupted" if touch_web else "paused"
	clear_controls()
	update_hud()

func resume_run() -> void:
	phase="playing"
	player.resume_on_carrier=player.is_on_floor() and not player.get_platform_velocity().is_zero_approx()
	update_hud()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		interrupt_run()

func _input(event: InputEvent) -> void:
	if phase == "playing" and not web:
		if event is InputEventMouseButton and event.button_index in [MOUSE_BUTTON_LEFT,MOUSE_BUTTON_RIGHT]:
			native_drag = event.pressed
		if event is InputEventMouseMotion and native_drag:
			var motion: Vector2 = event.relative / maxf(240.0,get_viewport().get_visible_rect().size.y)
			orbit(motion.x,motion.y)
	if event is InputEventKey and not event.echo:
		var key := event.physical_keycode as int
		if key == KEY_SPACE and phase == "playing":
			if event.pressed: queue_jump()
			get_viewport().set_input_as_handled()
		elif event.pressed:
			if key == KEY_ENTER and phase in ["won","intro"]:
				start_run()
			elif key>=KEY_1 and key<=KEY_5 and phase=="intro" and not web:
				web_command(["character",player.costumes.NAMES.keys()[key-KEY_1]])
			elif key in [KEY_ESCAPE,KEY_P]:
				toggle_pause()
			elif key == KEY_TAB and phase == "playing" and not web:
				web_command(["branch"])
			elif key == KEY_F and phase == "playing":
				face_target()
			elif key == KEY_1 and phase == "paused" and not web:
				set_hint("route_ring",not show_route_ring)
			elif key == KEY_2 and phase == "paused" and not web:
				set_hint("landing_guide",not show_landing_guide)
			elif key == KEY_3 and phase == "paused" and not web:
				web_command(["art_style","normal" if oil_paint.visible else "oil"])
			elif key == KEY_R and phase == "paused":
				start_run()

func on_jump(from_spring: bool) -> void:
	if from_spring:
		notice="彈向"+art.stop_name(art.destination(ledge,false))
		play_sound(SPRING_SOUND,.9 if ledge==Islands.Branches.BED else 1.12)
	else:
		notice=""
		play_sound(JUMP_SOUND,1.05)

func play_sound(stream: AudioStream, pitch := 1.0) -> void:
	if muted: return
	audio.stream = stream
	audio.pitch_scale = pitch
	audio.volume_db = -9
	audio.play()

func on_landing(index: int, strength: float) -> void:
	if phase != "playing": return
	if strength>0. and not muted:
		footfall.stream=art.landing_sound(index)
		footfall.volume_db=lerpf(-24.,-9.,strength)
		footfall.pitch_scale=lerpf(1.12,.89,strength)
		footfall.play()
	if index!=Islands.Branches.AWNING or player.ability!="hook": frame_aerial=false
	if art.stage(index) < art.stage(ledge):
		falls += 1
		notice = "下層平台接住咗你"
	elif index != ledge:
		notice = "跣腳時拉返向鋼樑，可以試扶邊" if index==16 else ""
	if index!=ledge: alternate=false
	summit_times.land(index,elapsed,player.jump_count,falls)
	ledge = index
	art.branches.land(index)
	match index:
		Islands.Branches.FAN: notice="企穩扇葉，轉到對面先起跳"
		Islands.Branches.PENDULUM: notice="擺向鋼樑、接近高位就起跳"
		Islands.Branches.LEVEL: notice="踩低近端，跑到紅刻度起跳"
		Islands.Branches.POLE: notice="沿桿行到高端，再跳洗衣機"
		Islands.Branches.LIFT: notice="搭到另一端，踏板放平就跳去晾衫架"
		Islands.Branches.BOARD,Islands.Branches.DRAWER: notice="開始鬆脫，快跳！"
		Islands.Branches.BED,Islands.Branches.COIL: notice="" if player.spring_pad else "跳落細圈先會彈起"
		Islands.Branches.SHEET: notice="被單接住咗你"
		Islands.Branches.AWNING: notice="布篷接住咗你，跳返木茶几"
	if index == Islands.ROUTE.size()-1:
		phase = "won"
		landing_guide.hide()
		play_sound(SUMMIT_SOUND)
	hud_clock = .06 # Publish the landing after this tick's height and pickup updates.

func keyboard_move() -> Vector2:
	return Vector2(
		int(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)) - int(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)),
		int(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)) - int(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)))

func world_move() -> Vector2:
	var move := (keyboard_move()+stick).limit_length()
	return move.rotated(-camera_yaw)

func queue_jump() -> void:
	player.request_jump(world_move())

func set_hint(which: String, enabled: bool) -> void:
	if which=="route_ring": show_route_ring = enabled
	if which=="landing_guide": show_landing_guide = enabled
	save_record()
	update_hud()

func _physics_process(delta: float) -> void:
	if phase=="interrupted" and recenter_camera: game_camera(delta,true)
	if phase != "playing": return
	elapsed += delta
	art.branches.advance(delta,player.grounded_ledge if player.is_on_floor() else -1,player.position)
	landing_guide.follow_support()
	var turn := int(Input.is_physical_key_pressed(KEY_E)) - int(Input.is_physical_key_pressed(KEY_Q))
	if turn != 0: orbit(turn*delta*2.1/3.55,0)
	var move := world_move()
	player.step(delta,move,sprint or Input.is_physical_key_pressed(KEY_SHIFT),camera)
	if player.hook.time_left>0: landing_guide.hide()
	if player.is_on_floor() and player.grounded_ledge>=0 and not player.grab.active:
		var foot_height:=snappedf(player.position.y,.1)
		if foot_height>best or phase=="won":
			best=maxf(best,foot_height)
			save_record()
	if phase=="playing":
		var found:=art.pickups.collect(player.position,delta)
		if found!="":
			player.equip(found)
			notice="執到"+str(art.pickups.ITEMS[found][0])
			play_sound(JUMP_SOUND,1.55)
	if player.position.y < -9:
		clear_controls()
		var count := player.jump_count
		falls += 1
		alternate=false
		ledge = 0
		player.reset_at(Islands.ROUTE[0])
		player.jump_count = count
		notice = "跌返街面，返到起點"
		camera_yaw = 0.0
		camera_pitch = deg_to_rad(24)
		game_camera(delta,true)
	else:
		game_camera(delta)
	hud_clock += delta
	if player.grab.active or (player.is_on_floor() and move.is_zero_approx()): landing_guide.hide()
	if hud_clock >= 0.06:
		if phase=="playing" and show_landing_guide and not player.grab.active: landing_guide.refresh(player,move,delta)
		hud_clock = 0
		update_hud()

func intro_camera() -> void:
	camera.fov = 52
	camera.position = Vector3(7.4+sin(menu_time*0.11)*0.4,4.7,11.8)
	var viewport_size := get_viewport().get_visible_rect().size
	var portrait := viewport_size.x < viewport_size.y
	camera.look_at(Vector3(0.3 if portrait else -3.6,1.55 if portrait else 2.35,-3.5), Vector3.UP)

func orbit(dx: float, dy: float) -> void:
	frame_aerial=false
	recenter_camera = true
	camera_yaw = wrapf(camera_yaw-dx*3.55,-PI,PI)
	camera_pitch = clampf(camera_pitch+dy*2.25,deg_to_rad(9),deg_to_rad(72))

func face_target() -> void:
	var next:=art.destination(ledge,alternate)
	if next<0: return
	frame_aerial=aiming_at_aerial()
	var target:=art.aerial.global_position if frame_aerial else art.stop_position(next)
	if next==Islands.Branches.PENDULUM: target=art.branches.pendulum.low_point
	if next==Islands.Branches.LIFT: target=art.branches.lift.boarding_point()
	if ledge==Islands.Branches.TAPE and player.is_on_floor():
		var tape:=art.branches.tape
		if tape.cycle<0. and not tape.on_hook(player.position):
			target=tape.blade.to_global(Vector3.BACK*.14)
	var offset:=target-player.position
	if ledge==Islands.Branches.PENDULUM and player.is_on_floor():
		# Align for the outgoing crest even if the rider taps at the bottom.
		var bob:=art.branches.pendulum
		offset-=bob.bob_at(bob.ANGLE)-bob.position
	elif ledge==Islands.Branches.LIFT and player.is_on_floor():
		offset-=art.branches.lift.exit_dock-art.branches.lift.position
	var direction := Vector2(offset.x,offset.z).normalized()
	recenter_camera = true
	camera_yaw = atan2(-direction.x,-direction.y)
	camera_pitch = deg_to_rad(26)
	if player.is_on_floor(): player.aim = direction

func boom_clearance(back: Vector3) -> float:
	camera_sweep.motion = back*camera_reach
	var space:=get_world_3d().direct_space_state
	var travel:=space.cast_motion(camera_sweep)
	if travel[0]<1.:return maxf(.42,travel[0]*camera_reach-.12)
	# A sweep can miss the tip of a tilted beam. Check the actual sight lines
	# before placing the eye beyond an apparently clear sweep.
	var distance:=camera_reach
	camera_ray.to=player.position+Vector3.UP*1.08+camera_sweep.motion
	for h: float in [.06,.65,player.BODY_HEIGHT+.10]:
		camera_ray.from=player.position+Vector3.UP*h
		var hit:=space.intersect_ray(camera_ray)
		if not hit.is_empty():
			var fraction:=camera_ray.from.distance_to(hit.position)/camera_ray.from.distance_to(camera_ray.to)
			distance=minf(distance,maxf(.42,fraction*camera_reach-.16))
	return distance

func game_camera(delta: float, snap := false) -> void:
	const MIN_DISTANCE := 1.95
	const LOW := deg_to_rad(3.)
	const HIGH := deg_to_rad(78.)
	var pivot := player.position+Vector3.UP*1.08
	var horizontal := Vector3(sin(camera_yaw),0,cos(camera_yaw))
	var axis := horizontal.cross(Vector3.UP)
	# The column starts just above the sole and includes the head. Sweeping
	# its volume catches rails and board edges at any height in between.
	camera_sweep.transform.origin = player.position+Vector3.UP*(.09+player.BODY_HEIGHT*.5)
	var pitch := camera_pitch
	var back := horizontal.rotated(axis,pitch)
	var distance := boom_clearance(back)
	for limit: float in [HIGH,LOW]:
		var candidate_pitch := camera_pitch
		while distance < FULL_BODY_DISTANCE and not is_equal_approx(candidate_pitch,limit):
			candidate_pitch = move_toward(candidate_pitch,limit,deg_to_rad(8))
			var candidate := horizontal.rotated(axis,candidate_pitch)
			var clearance := boom_clearance(candidate)
			# Under a low ceiling there may be more room below the obstacle.
			if clearance >= FULL_BODY_DISTANCE or clearance > distance+.08:
				pitch = candidate_pitch
				back = candidate
				distance = clearance

	var offset := pitch-camera_pitch
	if not snap and not is_equal_approx(camera_pitch_offset,offset):
		var rate := 3.5 if absf(offset)>absf(camera_pitch_offset) else 1.4
		var eased := move_toward(camera_pitch_offset,offset,rate*delta)
		eased = clampf(eased,LOW-camera_pitch,HIGH-camera_pitch)
		var direction := horizontal.rotated(axis,camera_pitch+eased)
		var clearance := boom_clearance(direction)
		# Ease through open space. Cross a lip immediately if an intermediate
		# angle would push the eye into the climber.
		if clearance >= minf(MIN_DISTANCE,distance):
			offset = eased
			back = direction
			distance = clearance
	camera_pitch_offset = offset
	if snap or distance < camera_distance:
		camera_distance = distance
	else:
		var eased := lerpf(camera_distance,distance,1.-exp(-7.*delta))
		camera_distance = maxf(minf(distance,MIN_DISTANCE),eased)
	camera.position = pivot+back*camera_distance
	# Keep a small foot adjustment inside the frame without moving the view.
	# Use the centred collision-safe boom whenever the offset sightline closes.
	var feet := Vector2(player.position.x,player.position.z)
	var lag := Vector2.ZERO
	if not snap and not recenter_camera and camera_distance >= camera_reach-.001 and not tracking_aerial():
		lag = (camera_anchor-feet).limit_length(CAMERA_FREE_STEP)
		var shift := Vector3(lag.x,0,lag.y)
		if lag.length_squared()>.000001 and boom_clearance(back+shift/camera_reach)>=camera_reach:
			camera.position += shift
		else:
			lag = Vector2.ZERO
	camera_anchor = feet+lag
	recenter_camera = false
	frame_climber(back,delta,snap)

func frame_climber(back: Vector3, delta: float, snap: bool) -> void:
	var framing := -back
	var field_of_view := 59.
	if camera_distance < FULL_BODY_DISTANCE:
		var feet := camera.position.direction_to(player.position)
		var head := camera.position.direction_to(player.position+Vector3.UP*(player.BODY_HEIGHT+.12))
		var middle := (feet+head).normalized()
		framing = framing.slerp(middle,1.-smoothstep(1.65,FULL_BODY_DISTANCE,camera_distance))
		var span := 2.*maxf(framing.angle_to(feet),framing.angle_to(head))
		field_of_view = clampf(rad_to_deg(span)+5.,59.,78.)
	if tracking_aerial():
		# Keep the marked antenna and takeoff edge in the same shot. Turning
		# the view by hand immediately returns control to the player.
		var forward:=Vector3(-sin(camera_yaw),0,-cos(camera_yaw))
		var low:=player.position-camera.position
		var high:=art.aerial.global_position+Vector3.UP*.30-camera.position
		var bottom:=atan2(low.y,low.dot(forward))
		var top:=atan2(high.y,high.dot(forward))
		if high.dot(forward)>0 and top>bottom:
			field_of_view=clampf(maxf(field_of_view,rad_to_deg(top-bottom)+12.),59.,78.)
			var half_angle:=deg_to_rad(field_of_view*.5-5.)
			var pitch:=clampf(asin(framing.y),minf(top-half_angle,bottom+half_angle),bottom+half_angle)
			framing=forward*cos(pitch)+Vector3.UP*sin(pitch)
	if snap or field_of_view > camera.fov:
		camera.fov = field_of_view
	else:
		camera.fov = move_toward(camera.fov,field_of_view,delta*60.)
	camera.look_at(camera.position+framing,Vector3.UP)

func _process(delta: float) -> void:
	if phase == "intro":
		menu_time += delta
		intro_camera()

func climber_screen_bounds(viewport_size: Vector2) -> Rect2:
	var foot:=player.global_position
	var head:=foot+Vector3.UP*(player.BODY_HEIGHT+.12)
	var radius:=player.FOOT_RADIUS+.06
	var side:=camera.global_basis.x*radius
	var depth:=side.cross(Vector3.UP)
	var bounds:=Rect2(camera.unproject_position(foot)/viewport_size,Vector2.ZERO)
	for centre: Vector3 in [foot,head]:
		for offset: Vector3 in [side+depth,side-depth,-side+depth,-side-depth]:
			var point:=centre+offset
			if camera.is_position_behind(point):return Rect2(0,0,1,1)
			bounds=bounds.expand(camera.unproject_position(point)/viewport_size)
	return bounds

func aiming_at_aerial() -> bool:
	return ledge==Islands.Branches.AWNING and player.ability=="hook"

func tracking_aerial() -> bool:
	return frame_aerial and ledge==Islands.Branches.AWNING and player.position.distance_squared_to(art.aerial.global_position)<25.

func update_hud() -> void:
	var next:=art.destination(ledge,alternate)
	if aiming_at_aerial(): next=3
	landing_ring.visible = show_route_ring and phase == "playing" and next>=0
	if landing_ring.visible and art.branches.bodies.has(next):
		landing_ring.visible = art.branches.bodies[next].collision_layer!=0
	if landing_ring.visible:
		var target:=art.stop_position(next)
		# Raised keys, tape reels and the turntable platter sit above their deck.
		var visible_top: float = {6:.12,8:.18,9:.22,14:.06,17:.055,24:.10}.get(next,.05)
		landing_ring.position = target+Vector3.UP*visible_top
	var height := maxf(0.0,player.position.y)
	var tape_hint:=""
	if phase=="playing" and ledge==Islands.Branches.TAPE and player.is_on_floor():
		tape_hint=art.branches.tape.rider_hint(player.position)
	var grip_action:=""
	if player.grab.active: grip_action="撐上" if player.grab.can_pull_up() else "攀爬中"
	var hook_hint:=""
	if player.ability=="hook":
		if player.hook.time_left>0: hook_hint="收索中"
		elif player.is_on_floor(): hook_hint="向銅環跳 · 再撳跳"
		elif player.hook.can_attach(player,camera): hook_hint="撳跳扣環"
		else: hook_hint="靠近並對準銅環"
	var brass:=art.material("80ffe0" if hook_hint=="撳跳扣環" or hook_hint=="收索中" else "e4a842")
	if art.aerial.material_override!=brass: art.aerial.material_override=brass
	var pace:=summit_times.pace_at(ledge,elapsed) if phase=="playing" else ""
	var result:=summit_times.finish_summary if phase=="won" else summit_times.best_summary
	if web:
		var message := notice if tape_hint.is_empty() else tape_hint
		if player.grab.active: message = "沿邊推可橫移，向外拉住放手" if player.grab.can_pull_up() else "爬緊上去"
		var destination:="電視銅環" if aiming_at_aerial() else (art.stop_name(next) if next>=0 else "")
		web.update(phase,height,best,art.stage(ledge),Islands.ROUTE.size()-1,sprint,elapsed,falls,player.jump_count,muted,message,destination,show_route_ring,show_landing_guide,Islands.Branches.FORKS.has(ledge),art.stage(ledge)>=Islands.LAUNDRY_START,player.costumes.key,player.ability,player.ability_time,player.jet_armed,art.pickups.count,player.double_charges,art.pickups.ITEMS.size(),hook_hint,grip_action,"oil" if oil_paint.visible else "normal",summit_times.best_clock,result,pace)
		var show_pickups:=phase=="playing" and not player.spring_pad and not player.grab.active and player.hook.time_left<=0 and not tracking_aerial()
		var hint: Node3D=art.pickups.visible_hint(camera,player) if show_pickups else null
		if hint:
			var viewport_size:=get_viewport().get_visible_rect().size
			var centre:=camera.unproject_position(hint.global_position)/viewport_size
			var frame:=art.pickups.frame_bounds(camera,hint)
			var first:=frame.position/viewport_size
			var last:=frame.end/viewport_size
			var climber:=climber_screen_bounds(viewport_size)
			var mark:=landing_guide.screen_bounds(camera,viewport_size)
			var key: String=art.pickups.items.find_key(hint)
			var effect: String="飛爪\n扣銅環 · 一次" if key=="hook" else "%s\n%d 秒" % [art.pickups.LABELS[key],player.ABILITY_SECONDS[key]]
			if key=="double": effect+=" · 最多 %d 次" % player.MAX_DOUBLE_CHARGES
			web.pickupHint(centre.x,centre.y,effect,first.x,first.y,last.x,last.y,
				climber.position.x,climber.position.y,climber.end.x,climber.end.y,
				mark.position.x,mark.position.y,mark.end.x,mark.end.y)
		else: web.pickupHint(0,0,"")
	elif native_label:
		match phase:
			"intro": native_label.text = "ONLYJUMP   /   Lost Property\nEnter to climb    /    1–5 change character    ·    %s" % player.costumes.NAMES[player.costumes.key]
			"won": native_label.text = "Summit reached   ·   %d jumps    /    Enter to play again" % player.jump_count
			"paused": native_label.text = "Paused   /   P to resume   ·   R to restart\n1   Next object ring: %s    ·    2   Landing guide: %s\n3   Art style: %s" % [str(show_route_ring),str(show_landing_guide),"Oil paint" if oil_paint.visible else "Normal"]
			_: native_label.text = "%04.1f m    ·    Ledge %d / %d\nWASD move   ·   Drag or Q / E orbit   ·   F face target   ·   Space jump   ·   Shift sprint   ·   P pause" % [height,art.stage(ledge),Islands.ROUTE.size()-1]
		if hook_hint!="" and phase=="playing": native_label.text+="\n飛爪 · "+hook_hint
		if grip_action!="" and phase=="playing": native_label.text+="\n"+("Space · 撐上　沿邊推可橫移，向外拉住放手" if player.grab.can_pull_up() else grip_action)
		if not tape_hint.is_empty():native_label.text+="\n"+tape_hint
		if phase in ["intro","paused","won"] and not result.is_empty(): native_label.text+="\n"+result
		if not pace.is_empty(): native_label.text+="\n"+pace
