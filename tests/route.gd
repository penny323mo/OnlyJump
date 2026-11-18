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
	var dest: Vector3 = Land.ROUTE[index]
	game.sprint = true
	game.web_command(["jump"])
	for tick in 120:
		var delta := dest-game.player.position
		var vy := game.player.JUMP_SPEED if tick==0 else game.player.velocity.y
		var disc: float = vy*vy-2.0*game.player.GRAVITY*delta.y
		var time_left := maxf(.12,(vy+sqrt(maxf(0,disc)))/game.player.GRAVITY)
		var input := (Vector2(delta.x,delta.z)/(time_left*game.player.RUN_SPEED)).limit_length()
		game.stick = input.rotated(game.camera_yaw)
		await frames(1)
		if game.player.is_on_floor() and game.ledge==index:
			game.stick = Vector2.ZERO
			print("landed ",index," ",Land.NAMES[index])
			return true
	return check(false,"could not land on "+Land.NAMES[index])

func run() -> void:
	game = Game.new()
	root.add_child(game)
	game.best=100
	game.muted=true
	game.start_run()
	await frames(6)
	if not check(root.get_camera_3d()==game.camera,"active gameplay camera"):return
	# Touch-down initiates a standing jump on the next physics step.
	game.web_command(["jump"])
	await frames(2)
	if not check(game.player.jump_count==1 and game.player.velocity.y>8,"immediate standing jump"):return
	if not check(Vector2(game.player.velocity.x,game.player.velocity.z).length()<.01,"standing jump drift"):return
	await frames(85)
	game.web_command(["look",-PI/(2*3.55),0])
	game.web_command(["stick",0,-1])
	await frames(3)
	if not check(game.player.velocity.x < -3 and absf(game.player.velocity.z)<.1,"camera-relative forward"):return
	game.web_command(["stick",-1,0])
	await frames(2)
	if not check(game.player.velocity.z > 3,"touch direction reversal"):return
	game.web_command(["stick",0,0])
	await frames(3)
	if not check(game.player.velocity.length()<.1,"release stops grounded movement"):return
	game.start_run()
	await frames(6)
	game.web_command(["stick",1,0])
	await frames(2)
	var walk := game.player.velocity.x
	game.web_command(["sprint"])
	await frames(2)
	if not check(game.player.velocity.x > walk*1.5,"sprint acceleration"):return
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
	if not check(game.player.velocity.y>8,"late edge jump"):return
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
	print("PASS mobile parkour: 18 landings, instant jump, sprint, orbit, edge hold, recovery")
	game.free()
	quit()
