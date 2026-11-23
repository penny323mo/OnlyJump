extends "res://tests/route.gd"

func ordinary_jump(target: int, runup: int, angle: float, strength := 1.) -> bool:
	var player:=game.player
	var gap:=game.art.stop_position(target)-player.position
	var direction:=Vector2(gap.x,gap.z).normalized().rotated(game.camera_yaw+deg_to_rad(angle))
	game.web_command(["stick",direction.x*strength,direction.y*strength])
	await frames(runup)
	game.web_command(["jump"])
	var airborne:=false
	for tick in 90:
		await frames(1)
		if player.grab.active or game.falls>0:break
		if not player.is_on_floor():airborne=true
		elif airborne:break
	game.web_command(["stick",0,0])
	await frames(6)
	return check(airborne and player.is_on_floor() and game.ledge==target and game.falls==0,
		"ordinary jump to %s after %d ticks, %s degrees at %s stick" % [game.art.stop_name(target),runup,angle,strength])

func run() -> void:
	game=Game.new()
	game.record_path=course_test_save
	root.add_child(game)
	game.muted=true
	game.best=100
	for target in range(1,10):
		for runup: int in [9,13,17]:
			for angle: float in [-12.,0.,12.]:
				game.start_run()
				game.player.reset_at(game.art.stop_position(target-1)+Vector3.UP*.12)
				await frames(22)
				if not await ordinary_jump(target,runup,angle):return

	# Leave each landing where the player actually stopped. Short run-ups and
	# alternating errors exercise the fourth and fifth jumps in one real climb.
	for strength: float in [.90,1.]:
		for angle: float in [-8.,0.,8.]:
			game.start_run()
			await frames(12)
			for target in range(1,7):
				if not await ordinary_jump(target,15,angle if target%2 else -angle,strength):return

	game.start_run()
	await frames(12)
	for target in range(1,11):
		if not await ordinary_jump(target,18,0.):return
	if not check(game.player.jump_count==10 and game.art.pickups.count==0,"ten ordinary jumps from the roof without a pickup"):return
	print("PASS nine forgiving walk jumps and a continuous ordinary climb to the camera")
	game.free()
	DirAccess.remove_absolute(course_test_save)
	quit()
