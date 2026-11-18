extends SceneTree
const Game = preload("res://game/ascent.gd")
const Land = preload("res://game/islands.gd")
var game: Game
func _initialize() -> void:
	call_deferred("run")
func frames(n: int) -> void:
	for i in n: await physics_frame
func check(value: bool, message: String) -> bool:
	if not value:
		printerr("FAIL: ",message," ledge=",game.ledge," pos=",game.player.position)
		quit(1)
	return value
func leap(i: int) -> bool:
	var start := game.player.position
	var to: Vector3 = Land.ROUTE[i] - start
	var d := Vector2(to.x,to.z)
	var charge_ticks := 47
	var min_error := INF
	for ticks in range(1,48):
		var p := minf(1,ticks / (60.0*game.player.CHARGE_TIME))
		var vy := lerpf(5.9,12.25,p)
		var disc: float = vy*vy-48.0*to.y
		if disc <= 0: continue
		var t := (vy+sqrt(disc))/24.0
		var error := absf(t*lerpf(2.6,7.45,p)-d.length())
		if error < min_error:
			min_error = error
			charge_ticks = ticks
	game.stick = d.normalized()
	game.player.begin_charge()
	await frames(maxi(1,charge_ticks-1))
	game.player.release_charge()
	await frames(1)
	game.stick = Vector2.ZERO
	for f in 120:
		await physics_frame
		if game.ledge == i and game.player.is_on_floor():
			print("landed ",i," at ",game.player.position," charge_ticks ",charge_ticks)
			return true
	return check(false,"missed ledge %d" % i)
func run() -> void:
	game = Game.new()
	root.add_child(game)
	game.best = 30 # Avoid writing a record to the developer's native save.
	game.muted = true
	game.start_run()
	await frames(8)
	for i in range(1,Land.ROUTE.size()):
		if not await leap(i): return
	if not check(game.phase=="won" and game.player.jump_count==12,"summit"):return
	game.start_run()
	await frames(8)
	if not await leap(1): return
	game.stick = Vector2(-0.3,1).normalized()
	for i in 120:
		await frames(1)
		if game.player.is_on_floor() and game.ledge==0: break
	if not check(game.ledge==0 and game.falls==1,"lower platform caught fall"):return
	game.stick = Vector2(1,0)
	for i in 200:
		await frames(1)
		if game.falls==2: break
	if not check(game.ledge==0 and game.falls==2 and game.player.position.length()<1,"void return"):return
	game.toggle_pause()
	var clock := game.elapsed
	await frames(8)
	if not check(is_equal_approx(game.elapsed,clock),"pause clock"):return
	print("PASS all 12 consecutive jumps, finish, lower-platform catch, void respawn, pause")
	quit()
