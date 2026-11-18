extends Node3D

const Islands = preload("res://game/islands.gd")
const Climber = preload("res://game/climber.gd")
const SKY_SHADER = preload("res://game/sky.gdshader")
const SOUNDS = [preload("res://audio/lift.wav"),preload("res://audio/land.wav"),preload("res://audio/summit.wav")]
var art := Islands.new()
var player := Climber.new()
var camera := Camera3D.new()
var landing_ring := MeshInstance3D.new()
var audio := AudioStreamPlayer.new()
var phase := "intro"
var elapsed := 0.0
var falls := 0
var ledge := 0
var best := 0.0
var muted := false
var web: JavaScriptObject
var web_callback: JavaScriptObject
var native_label: Label
var stick := Vector2.ZERO
var camera_yaw := 0.0
var camera_pitch := deg_to_rad(24.0)
var camera_distance := 6.8
var native_drag := false
var sprint := false
var hud_clock := 0.0
var menu_time := 0.0
var last_jump_count := 0
var notice := ""

func _ready() -> void:
	var env := Environment.new()
	var sky := Sky.new()
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = SKY_SHADER
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_sky_contribution = 0.0
	env.ambient_light_energy = 0.47
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.tonemap_exposure = 0.85
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.ambient_light_color = Color("e9edf5")
	env.fog_enabled = true
	env.fog_light_color = Color("b8bbc3")
	env.fog_density = 0.008
	env.fog_sky_affect = 0.23
	var world := WorldEnvironment.new()
	world.environment = env
	add_child(world)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-47,-32,0)
	light.light_color = Color("fff1da")
	light.light_energy = 0.31
	light.shadow_enabled = true
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
	add_child(player)
	player.build(art)
	player.landed.connect(on_landing)
	player.jumped.connect(on_jump)
	add_child(camera)
	camera.make_current()
	camera.fov = 54
	camera.far = 320
	add_child(audio)
	var data := ConfigFile.new()
	if data.load("user://summit.cfg") == OK:
		best = data.get_value("run","best",0.0)
		muted = data.get_value("run","muted",false)
	player.reset_at(Islands.ROUTE[0])
	if OS.has_feature("web"):
		web = JavaScriptBridge.get_interface("OnlyJumpUI")
	if web:
		web_callback = JavaScriptBridge.create_callback(web_command)
		web.bindGame(web_callback)
	else:
		var layer := CanvasLayer.new()
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
	data.set_value("run","best",best)
	data.set_value("run","muted",muted)
	data.save("user://summit.cfg")

func web_command(args: Array) -> void:
	if args.is_empty():
		return
	match str(args[0]):
		"start": start_run()
		"pause": toggle_pause()
		"hide":
			if phase == "playing": toggle_pause()
		"menu": show_intro()
		"restart": start_run()
		"mute":
			muted = not muted
			save_record()
		"stick":
			if phase == "playing" and args.size() == 3:
				stick = Vector2(float(args[1]),float(args[2])).limit_length()
				if stick.length() > 0.14 and player.is_on_floor():
					player.aim = stick.rotated(-camera_yaw).normalized()
			return
		"look":
			if phase == "playing" and args.size() == 3:
				orbit(float(args[1]),float(args[2]))
			return
		"align":
			if phase == "playing": face_target()
		"sprint":
			if phase == "playing": sprint = not sprint
		"jump":
			if phase == "playing": queue_jump()
	update_hud()

func clear_controls() -> void:
	stick = Vector2.ZERO
	native_drag = false
	sprint = false
	player.jump_buffer = 0
	if web: web.clearInputs()

func show_intro() -> void:
	phase = "intro"
	clear_controls()
	player.reset_at(Islands.ROUTE[0])
	intro_camera()
	update_hud()

func start_run() -> void:
	phase = "playing"
	elapsed = 0
	falls = 0
	ledge = 0
	last_jump_count = 0
	clear_controls()
	camera_yaw = 0.0
	camera_pitch = deg_to_rad(24)
	notice = ""
	player.reset_at(Islands.ROUTE[0])
	game_camera(1.0,true)
	update_hud()

func toggle_pause() -> void:
	if phase == "playing":
		phase = "paused"
		clear_controls()
	elif phase == "paused":
		phase = "playing"
	update_hud()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and phase == "playing":
		toggle_pause()

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
			elif key in [KEY_ESCAPE,KEY_P]:
				toggle_pause()
			elif key == KEY_F and phase == "playing":
				face_target()
			elif key == KEY_R and phase == "paused":
				start_run()

func on_jump() -> void:
	notice = ""
	play_sound(0,1.05)

func play_sound(id: int, pitch := 1.0) -> void:
	if muted: return
	audio.stream = SOUNDS[id]
	audio.pitch_scale = pitch
	audio.volume_db = -12 if id == 1 else -9
	audio.play()

func on_landing(index: int) -> void:
	if phase != "playing": return
	if index < ledge:
		falls += 1
		notice = "下層平台接住咗你"
	elif index > ledge:
		notice = ""
	ledge = index
	if Islands.ROUTE[index].y > best:
		best = Islands.ROUTE[index].y
		save_record()
	if index == Islands.ROUTE.size()-1:
		phase = "won"
		play_sound(2)
	elif player.jump_count > last_jump_count:
		play_sound(1)
	last_jump_count = player.jump_count
	update_hud()

func keyboard_move() -> Vector2:
	return Vector2(
		int(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)) - int(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)),
		int(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)) - int(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)))

func queue_jump() -> void:
	player.request_jump((keyboard_move()+stick).limit_length().rotated(-camera_yaw),sprint or Input.is_physical_key_pressed(KEY_SHIFT))

func _physics_process(delta: float) -> void:
	if phase != "playing": return
	elapsed += delta
	var move := keyboard_move()
	var turn := int(Input.is_physical_key_pressed(KEY_E)) - int(Input.is_physical_key_pressed(KEY_Q))
	camera_yaw = wrapf(camera_yaw-turn*delta*2.1,-PI,PI)
	player.step(delta,(move+stick).limit_length().rotated(-camera_yaw),sprint or Input.is_physical_key_pressed(KEY_SHIFT))
	if player.position.y < -9:
		clear_controls()
		var count := player.jump_count
		falls += 1
		ledge = 0
		player.reset_at(Islands.ROUTE[0])
		player.jump_count = count
		last_jump_count = count
		notice = "跌返街面，返到起點"
		camera_yaw = 0.0
		camera_pitch = deg_to_rad(24)
		game_camera(delta,true)
	else:
		game_camera(delta)
	hud_clock += delta
	if hud_clock >= 0.06:
		hud_clock = 0
		update_hud()

func intro_camera() -> void:
	camera.fov = 52
	camera.position = Vector3(7.4+sin(menu_time*0.11)*0.4,4.7,11.8)
	var viewport_size := get_viewport().get_visible_rect().size
	var portrait := viewport_size.x < viewport_size.y
	camera.look_at(Vector3(0.3 if portrait else -3.6,1.55 if portrait else 2.35,-3.5), Vector3.UP)

func orbit(dx: float, dy: float) -> void:
	camera_yaw = wrapf(camera_yaw-dx*3.55,-PI,PI)
	camera_pitch = clampf(camera_pitch+dy*2.25,deg_to_rad(9),deg_to_rad(72))

func face_target() -> void:
	if ledge+1 >= Islands.ROUTE.size(): return
	var offset: Vector3 = Islands.ROUTE[ledge+1] - player.position
	var direction := Vector2(offset.x,offset.z).normalized()
	camera_yaw = atan2(-direction.x,-direction.y)
	camera_pitch = deg_to_rad(26)
	if player.is_on_floor(): player.aim = direction

func game_camera(delta: float, snap := false) -> void:
	camera.fov = 59
	var pivot := player.position+Vector3.UP*1.08
	var back := Vector3(sin(camera_yaw)*cos(camera_pitch),sin(camera_pitch),cos(camera_yaw)*cos(camera_pitch))
	var right := Vector3(cos(camera_yaw),0,-sin(camera_yaw))
	var safe_distance := 6.8
	var query := PhysicsRayQueryParameters3D.new()
	query.exclude = [player.get_rid()]
	query.hit_back_faces = true
	var space := get_world_3d().direct_space_state
	for side in [-0.18,0.0,0.18]:
		query.from = pivot+right*side
		query.to = query.from+back*6.8
		var hit := space.intersect_ray(query)
		if not hit.is_empty():
			safe_distance = minf(safe_distance,maxf(0.42,query.from.distance_to(hit.position)-0.20))
	if snap or safe_distance < camera_distance:
		camera_distance = safe_distance
	else:
		camera_distance = lerpf(camera_distance,safe_distance,1.0-exp(-7*delta))
	camera.position = pivot+back*camera_distance
	camera.look_at(pivot,Vector3.UP)

func _process(delta: float) -> void:
	if phase == "intro":
		menu_time += delta
		intro_camera()

func update_hud() -> void:
	landing_ring.visible = phase == "playing" and ledge+1 < Islands.ROUTE.size()
	if landing_ring.visible:
		var target: Vector3 = Islands.ROUTE[ledge+1]
		# Raised keys, tape reels and the turntable platter sit above their deck.
		var visible_top: float = {6:.12,8:.18,9:.22,14:.06,17:.055}.get(ledge+1,.05)
		landing_ring.position = target+Vector3.UP*visible_top
	var height := maxf(0.0,player.position.y)
	if web:
		web.update(phase,height,best,ledge,Islands.ROUTE.size()-1,sprint,elapsed,falls,player.jump_count,muted,notice,Islands.NAMES[ledge+1] if ledge+1<Islands.NAMES.size() else "")
	elif native_label:
		match phase:
			"intro": native_label.text = "ONLYJUMP   /   Lost Property\nEnter to climb"
			"won": native_label.text = "Summit reached   ·   %d jumps    /    Enter to play again" % player.jump_count
			"paused": native_label.text = "Paused   /   P to resume   ·   R to restart"
			_: native_label.text = "%04.1f m    ·    Ledge %d / %d\nWASD move   ·   Drag or Q / E orbit   ·   F face target   ·   Space jump   ·   Shift sprint   ·   P pause" % [height,ledge,Islands.ROUTE.size()-1]
