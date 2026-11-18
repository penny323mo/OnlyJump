extends SceneTree
const Game = preload("res://game/ascent.gd")
const Land = preload("res://game/islands.gd")
var game: Game

func _initialize() -> void:
	call_deferred("run")

func frames(n: int) -> void:
	for i in n: await physics_frame

func check(ok: bool, message: String) -> bool:
	if not ok:
		printerr("FAIL ",message," ledge=",game.ledge," position=",game.player.position)
		quit(1)
	return ok

func leap(index: int) -> bool:
	# Run up on the actual previous object, then take a ballistic jump. The
	# test only drives the controls available to the player, including sprint.
	game.web_command(["stick",0,0])
	await frames(2)
	var target: Vector3 = Land.ROUTE[index]
	var gap := target-game.player.position
	var aim := Vector2(gap.x,gap.z).normalized()
	var t := (game.player.JUMP_SPEED+sqrt(maxf(.01,game.player.JUMP_SPEED**2-2*game.player.GRAVITY*gap.y)))/game.player.GRAVITY
	var speed := minf(game.player.RUN_SPEED,game.player.GROUND_ACCEL*(sqrt(t*t+2*Vector2(gap.x,gap.z).length()/game.player.GROUND_ACCEL)-t))
	game.web_command(["sprint",true])
	var stick := aim.rotated(game.camera_yaw)*(speed/game.player.RUN_SPEED)
	game.web_command(["stick",stick.x,stick.y])
	for tick in 25:
		await frames(1)
		var remaining := target-game.player.position
		var velocity := Vector2(game.player.velocity.x,game.player.velocity.z)
		if velocity.dot(aim)*t>=Vector2(remaining.x,remaining.z).dot(aim)-.07 or not game.player.is_on_floor():break
	game.web_command(["jump"])
	for tick in 95:
		await frames(1)
		if game.player.is_on_floor() and game.ledge==index:
			game.web_command(["stick",0,0])
			print("landed ",index," ",Land.NAMES[index])
			return true
	return check(false,"could not land on "+Land.NAMES[index])

func surface_normal(point: Vector3) -> Vector3:
	var ray := PhysicsRayQueryParameters3D.create(point+Vector3.UP*.7,point+Vector3.DOWN)
	var hit := game.get_world_3d().direct_space_state.intersect_ray(ray)
	return hit.get("normal",Vector3.ZERO)

func run() -> void:
	game = Game.new()
	root.add_child(game)
	game.best=100
	game.muted=true
	game.follow_camera=false
	game.start_run()
	await frames(6)
	if not check(root.get_camera_3d()==game.camera,"active gameplay camera"):return
	# Touch-down initiates a standing jump on the next physics step.
	game.web_command(["jump"])
	await frames(2)
	if not check(game.player.jump_count==1 and game.player.velocity.y>5.5,"immediate standing jump"):return
	if not check(Vector2(game.player.velocity.x,game.player.velocity.z).length()<.01,"standing jump drift"):return
	var peak := game.player.position.y
	var air_ticks := 2
	while not game.player.is_on_floor() and air_ticks<75:
		await frames(1)
		air_ticks+=1
		peak=maxf(peak,game.player.position.y)
	if not check(peak>1.17 and peak<1.40 and air_ticks in range(45,54),"jump apex and duration"):return
	game.web_command(["look",-PI/(2*3.55),0])
	game.web_command(["stick",0,-1])
	await frames(10)
	if not check(game.player.velocity.x < -3 and absf(game.player.velocity.z)<.1,"camera-relative forward"):return
	game.web_command(["stick",-1,0])
	await frames(14)
	if not check(game.player.velocity.z > 3,"touch direction reversal"):return
	game.web_command(["stick",0,0])
	await frames(3)
	if not check(game.player.velocity.length()<.1,"release stops grounded movement"):return
	game.start_run()
	await frames(6)
	game.web_command(["stick",1,0])
	await frames(10)
	var walk := game.player.velocity.x
	game.web_command(["sprint",true])
	await frames(9)
	if not check(game.player.velocity.x > walk*1.5,"sprint acceleration"):return
	game.web_command(["jump"])
	await frames(1)
	var takeoff := game.player.velocity.x
	game.web_command(["stick",0,0])
	game.web_command(["sprint",false])
	await frames(12)
	if not check(absf(game.player.velocity.x-takeoff)<.03,"coast without air braking"):return
	game.start_run()
	await frames(6)
	for index in range(1,Land.ROUTE.size()):
		if not await leap(index):return
	if not check(game.phase=="won" and game.player.jump_count==18,"summit"):return
	# Part of the flat sole extends past a 76 cm wide steel beam.
	game.start_run()
	game.player.reset_at(Land.ROUTE[16])
	await frames(6)
	game.stick=Vector2.DOWN
	for i in 90:
		await frames(1)
		if game.player.position.z > Land.ROUTE[16].z+.45:break
	if not check(game.player.position.z>Land.ROUTE[16].z+.38 and game.player.velocity.z<2,"braking at rim"):return
	game.stick=Vector2.ZERO
	var perched := game.player.position
	await frames(65)
	if not check(game.player.is_on_floor() and game.player.position.distance_to(perched)<.05,"one-foot ledge hold"):return
	# Walk off deliberately and tap just beyond the edge.
	game.stick=Vector2.DOWN
	for i in 45:
		await frames(1)
		if not game.player.is_on_floor():break
	if not check(not game.player.is_on_floor(),"can leave rim"):return
	game.web_command(["jump"])
	await frames(2)
	if not check(game.player.velocity.y>5.5,"late edge jump"):return
	game.start_run()
	await frames(6)
	if not await leap(1):return
	game.sprint=false
	game.stick=Vector2(-.3,1).normalized()
	for i in 160:
		await frames(1)
		if game.ledge==0 and game.player.is_on_floor():break
	if not check(game.ledge==0 and game.falls==1,"catch on lower roof"):return
	game.stick=Vector2.RIGHT
	for i in 260:
		await frames(1)
		if game.falls==2:break
	await frames(24)
	if not check(game.falls==2 and game.stick.is_zero_approx() and game.player.position.length()<.1,"respawn releases input"):return
	game.toggle_pause()
	var time := game.elapsed
	await frames(8)
	if not check(is_equal_approx(time,game.elapsed),"pause clock"):return
	# Steering stays world-stable while the automatic camera turns behind the player.
	game.follow_camera=true
	game.start_run()
	await frames(6)
	game.web_command(["stick",1,0])
	await frames(27)
	if not check(absf(game.camera_yaw+PI/2)<.12 and game.player.velocity.x>3 and absf(game.player.position.z)<.02,"follow behind sustained rightward movement"):return
	game.web_command(["jump"])
	await frames(2)
	var heading := game.camera_yaw
	game.web_command(["stick",0,-1])
	await frames(10)
	if not check(not game.player.is_on_floor() and is_equal_approx(game.camera_yaw,heading),"stable airborne framing"):return
	game.follow_camera=false
	game.start_run()
	await frames(6)
	game.web_command(["stick",1,0])
	await frames(12)
	if not check(is_zero_approx(game.camera_yaw),"disable automatic orbit"):return
	# Sample playable geometry on both sides of the mailing tube and across the reel.
	var left := surface_normal(Land.ROUTE[17]+Vector3.FORWARD*.7)
	var right := surface_normal(Land.ROUTE[17]+Vector3.BACK*.7)
	if not check(left.z<-.4 and right.z>.4 and minf(left.y,right.y)>.75,"two walkable parcel slopes"):return
	var radial := Vector3.BACK.rotated(Vector3.UP,deg_to_rad(70))
	var crown := surface_normal(Land.ROUTE[15])
	var shoulder := surface_normal(Land.ROUTE[15]+radial*.60)
	if not check(crown.y>.97 and shoulder.y>.68 and shoulder.dot(radial)>.4,"curved cable reel contact normals"):return
	print("PASS mobile parkour: 18 landings, instant jump, sprint, orbit, edge hold, recovery")
	game.free()
	quit()
