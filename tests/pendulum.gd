extends "res://tests/branches.gd"

func forward_jump(strength: float, runup_ticks: int) -> void:
	game.web_command(["sprint",true])
	game.web_command(["stick",0,-strength])
	await frames(runup_ticks)
	game.web_command(["jump"])
	await frames(5)
	game.web_command(["stick",0,0])
	game.web_command(["sprint",false])

func reach_floor(id: int) -> bool:
	for tick in 125:
		await frames(1)
		if game.player.is_on_floor():
			return check(game.ledge==id,"land on "+game.art.stop_name(id))
	return check(false,"missed "+game.art.stop_name(id))

func board(entry_tick: int) -> bool:
	await start_on(13)
	game.web_command(["branch"])
	if not check(game.alternate and game.art.destination(13,true)==B.PENDULUM,"bollard offers the pendulum"):return false
	var bob:=game.art.branches.pendulum
	await frames(entry_tick-roundi(bob.time*60.))
	await forward_jump(.54,9)
	return await reach_floor(B.PENDULUM)

func run() -> void:
	game=Game.new()
	root.add_child(game)
	game.best=100
	game.muted=true
	game.follow_camera=false
	if not await board(32):return
	var bob:=game.art.branches.pendulum
	var player:=game.player
	await frames(3)
	# Align once at boarding, before the bob has carried us across.
	game.web_command(["align"])
	var local_foot:=bob.to_local(player.position)
	var lowest:=player.position.y
	var highest:=lowest
	var phase:=bob.time
	var parked:=bob.position
	game.toggle_pause()
	await frames(30)
	if not check(parked.is_equal_approx(bob.position) and is_equal_approx(phase,bob.time),"pause holds the pendulum"):return
	game.toggle_pause()
	for tick in roundi(bob.PERIOD*60.):
		await frames(1)
		if not check(player.is_on_floor() and game.ledge==B.PENDULUM and local_foot.distance_to(bob.to_local(player.position))<.04,"feet ride the round bob through a full swing"):return
		lowest=minf(lowest,player.position.y)
		highest=maxf(highest,player.position.y)
	if not check(highest-lowest>1.4 and bob.position.distance_to(parked)<.01,"round trip rises and returns to its starting point"):return
	await frames(roundi((bob.PERIOD+2.60-bob.time)*60.))
	await forward_jump(.78,12)
	if not await reach_floor(16):return
	if not check(player.jump_count==2 and game.falls==0 and player.ability=="","two ordinary jumps reach the girder"):return
	if not await leap(17):return

	if not await board(29):return
	await frames(276-roundi(bob.time*60.))
	var off:=Vector2(0,-.34).rotated(game.camera_yaw)
	game.web_command(["stick",off.x,off.y])
	for tick in 105:
		await frames(1)
		if not player.is_on_floor():break
	game.web_command(["stick",0,0])
	if not await reach_floor(8):return
	if not check(game.falls==1 and player.jump_count==1,"turntable catches a step off the left swing"):return
	await start_on(13)
	game.web_command(["branch"])
	await frames(90-roundi(bob.time*60.))
	await forward_jump(.54,9)
	if not await reach_floor(7):return
	if not check(game.falls==1 and player.jump_count==1,"mistimed boarding falls onto the boombox"):return

	await start_on(B.CLOCK_CASE)
	# Step back on the housing for a run-up to the near side of the counter.
	game.web_command(["stick",0,-.4])
	await frames(15)
	game.web_command(["stick",0,0])
	await frames(3)
	if not await leap(18,Vector3(0,0,-.50)):return
	game.start_run()
	if not check(bob.position.is_equal_approx(bob.bob_at(-bob.ANGLE)) and is_zero_approx(bob.time),"restart returns the clock to its first beat"):return
	print("PASS pendulum boarding, full swing, girder exit, lower catch and clock housing")
	game.free()
	quit()
