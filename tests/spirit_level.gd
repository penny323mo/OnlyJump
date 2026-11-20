extends "res://tests/branches.gd"

func board_level() -> bool:
	await start_on(10)
	game.web_command(["branch"])
	if not check(game.art.destination(10,game.alternate)==B.LEVEL,"choose the level at the camera"):return false
	await forward_jump(.85,10)
	if not await reach_floor(B.LEVEL):return false
	await frames(45)
	var level:=game.art.branches.level
	return check(is_equal_approx(level.rotation.z,level.LIMIT) and level.bubble.position.x>.35,"standing at the near cap lifts the far end and the bubble")

func cross_to(x: float) -> bool:
	var level:=game.art.branches.level
	game.web_command(["align"])
	game.web_command(["sprint",true])
	game.web_command(["stick",0,-1])
	for i in 90:
		await frames(1)
		if not check(game.player.is_on_floor() and game.ledge==B.LEVEL,"stay on the sight window and rails"):return false
		if level.to_local(game.player.position).x>=x:return true
	return check(false,"crossed the pivot to the takeoff point")

func run() -> void:
	game=Game.new()
	root.add_child(game)
	game.best=100
	game.muted=true
	game.follow_camera=false
	var level:=game.art.branches.level
	var p:=game.player
	if not await board_level():return
	if not await cross_to(1.32):return
	var tilt:=level.rotation.z
	if not check(tilt>.15 and level.angular_speed<0.,"far end is high but beginning to dip"):return
	game.web_command(["jump"])
	await frames(5)
	game.web_command(["stick",0,0])
	game.web_command(["sprint",false])
	if not await reach_floor(13):return
	if not check(p.jump_count==2 and game.falls==0 and p.ability=="","camera to bollard in two unassisted jumps"):return
	await frames(220)
	if not check(absf(level.rotation.z-level.REST)<.004,"unloaded beam settles back"):return

	if not await board_level():return
	if not await cross_to(1.85):return
	game.web_command(["stick",0,0])
	var foot:=level.to_local(p.position)
	await frames(15)
	game.toggle_pause()
	tilt=level.rotation.z
	var mark:=level.bubble.position.x
	await frames(24)
	if not check(is_equal_approx(level.rotation.z,tilt) and is_equal_approx(level.bubble.position.x,mark),"pause freezes the loaded beam and vial"):return
	game.toggle_pause()
	await frames(110)
	if not check(is_equal_approx(level.rotation.z,-level.LIMIT) and level.bubble.position.x<-.35,"waiting at the far end lowers it"):return
	if not check(p.is_on_floor() and game.ledge==B.LEVEL and foot.distance_to(level.to_local(p.position))<.15,"feet stay with the tipping beam"):return
	if not check(game.art.stop_position(13).y-p.position.y>p.JUMP_SPEED**2/(2*p.GRAVITY),"late takeoff loses the height advantage"):return
	var side:=Vector2.DOWN.rotated(game.camera_yaw)*.52
	game.web_command(["sprint",false])
	game.web_command(["stick",side.x,side.y])
	for i in 80:
		await frames(1)
		if not p.is_on_floor():break
	game.web_command(["stick",0,0])
	if not await reach_floor(8):return
	if not check(game.falls==1 and p.jump_count==1,"turntable catches the missed crossing"):return
	game.start_run()
	if not check(is_equal_approx(level.rotation.z,level.REST) and is_zero_approx(level.angular_speed),"restart resets the beam"):return
	print("PASS spirit level loading, running shortcut, late tilt and lower turntable catch")
	game.free()
	quit()
