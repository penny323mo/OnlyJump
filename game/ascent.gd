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
	env.ambient_light_color = Color("fff0df")
	env.ambient_light_energy = 0.64
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	var world := WorldEnvironment.new()
	world.environment = env
	add_child(world)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-47,-32,0)
	light.light_color = Color("fff1da")
	light.light_energy = 0.74
	light.shadow_enabled = true
	light.directional_shadow_max_distance = 46
	add_child(light)
	add_child(art)
	var ring := TorusMesh.new()
	ring.inner_radius = 0.36
	ring.outer_radius = 0.41
	ring.rings = 24
	ring.ring_segments = 5
	landing_ring.mesh = ring
	landing_ring.material_override = art.material("d67039")
	landing_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(landing_ring)
	add_child(player)
	player.build(art)
	player.landed.connect(on_landing)
	player.jumped.connect(on_jump)
	add_child(camera)
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
			if args.size() == 3: stick = Vector2(float(args[1]),float(args[2])).limit_length()
		"down":
			if phase == "playing": player.begin_charge()
		"up":
			if phase == "playing": player.release_charge()
	update_hud()

func show_intro() -> void:
	phase = "intro"
	stick = Vector2.ZERO
	player.reset_at(Islands.ROUTE[0])
	intro_camera()
	update_hud()

func start_run() -> void:
	phase = "playing"
	elapsed = 0
	falls = 0
	ledge = 0
	last_jump_count = 0
	stick = Vector2.ZERO
	notice = ""
	player.reset_at(Islands.ROUTE[0])
	game_camera(1.0,true)
	update_hud()

func toggle_pause() -> void:
	if phase == "playing":
		phase = "paused"
		stick = Vector2.ZERO
		player.cancel_charge()
	elif phase == "paused":
		phase = "playing"
	update_hud()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and phase == "playing":
		toggle_pause()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and not event.echo:
		var key := event.physical_keycode as int
		if key == KEY_SPACE and phase == "playing":
			if event.pressed: player.begin_charge()
			else: player.release_charge()
			get_viewport().set_input_as_handled()
		elif event.pressed:
			if key == KEY_ENTER and phase in ["won","intro"]:
				start_run()
			elif key in [KEY_ESCAPE,KEY_P]:
				toggle_pause()
			elif key == KEY_R and phase == "paused":
				start_run()

func on_jump(strength: float) -> void:
	notice = ""
	play_sound(0,0.92+strength*0.25)

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

func _physics_process(delta: float) -> void:
	if phase != "playing": return
	elapsed += delta
	var move := Vector2(
		int(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)) - int(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)),
		int(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)) - int(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)))
	player.step(delta,(move+stick).limit_length())
	if player.position.y < -9:
		var count := player.jump_count
		falls += 1
		ledge = 0
		player.reset_at(Islands.ROUTE[0])
		player.jump_count = count
		last_jump_count = count
		notice = "跌出山谷，返到營地"
		game_camera(delta,true)
	hud_clock += delta
	if hud_clock >= 0.06:
		hud_clock = 0
		update_hud()

func intro_camera() -> void:
	camera.fov = 52
	camera.position = Vector3(4.2+sin(menu_time*0.11)*0.4,4.35,13.0)
	var viewport_size := get_viewport().get_visible_rect().size
	var portrait := viewport_size.x < viewport_size.y
	camera.look_at(Vector3(-1.0 if portrait else -4.1,1.85 if portrait else 3.4,-4.0), Vector3.UP)

func game_camera(delta: float, snap := false) -> void:
	camera.fov = 59
	var p := player.position
	var target := p + Vector3(0,5.10,8.15)
	camera.position = target if snap else camera.position.lerp(target,1.0-exp(-8*delta))
	camera.look_at(p+Vector3(0,1.28,-1.45),Vector3.UP)

func _process(delta: float) -> void:
	if phase == "intro":
		menu_time += delta
		intro_camera()
	elif phase == "playing":
		game_camera(delta)

func update_hud() -> void:
	landing_ring.visible = phase == "playing" and ledge+1 < Islands.ROUTE.size()
	if landing_ring.visible:
		landing_ring.position = Islands.ROUTE[ledge+1]+Vector3.UP*0.035
	var height := maxf(0.0,player.position.y)
	if web:
		web.update(phase,height,best,ledge,Islands.ROUTE.size()-1,player.power,player.charging,elapsed,falls,player.jump_count,muted,notice)
	elif native_label:
		match phase:
			"intro": native_label.text = "ONLYJUMP   /   Amber Expanse\nEnter to climb"
			"won": native_label.text = "Summit reached   ·   %d jumps    /    Enter to play again" % player.jump_count
			"paused": native_label.text = "Paused   /   P to resume   ·   R to restart"
			_: native_label.text = "%04.1f m    ·    Ledge %d / %d\nWASD move   ·   Hold Space to aim and charge   ·   Release to jump   ·   P pause\nPower   %d%%" % [height,ledge,Islands.ROUTE.size()-1,player.power*100]
