extends "res://tests/branches.gd"

func horizontal(v: Vector3) -> Vector2:
	return Vector2(v.x,v.z).normalized()

func board_step() -> bool:
	await start_on(19)
	await frames(248)
	game.web_command(["branch"])
	var lift:=game.art.branches.lift
	var yaw:=game.camera_yaw
	if not check(lift.position.distance_to(lift.entry)>7. and Vector2.UP.rotated(-yaw).dot(horizontal(lift.boarding_point()-game.player.position))>.999,"aim at boarding dock when basket is at the far stop"):return false
	# React a quarter second after the basket returns to the near stop.
	await frames(roundi((8.25-game.art.branches.clock)*60.))
	if not check(is_equal_approx(yaw,game.camera_yaw) and is_zero_approx(lift.plate.rotation.x),"open step and fixed heading for boarding"):return false
	await forward_jump(.55,6)
	if not await reach_floor(B.LIFT):return false
	var foot:=game.player.ground_at(game.player.position,.15)
	return check(foot.get("collider")==lift.plate and lift.to_local(game.player.position).z<-1.20,"the unfolded tip catches a jump short of the basket floor")

func run() -> void:
	game=Game.new()
	root.add_child(game)
	game.best=100
	game.muted=true
	if not await board_step():return
	var lift:=game.art.branches.lift
	var player:=game.player
	var step:=horizontal(lift.position-player.position).rotated(game.camera_yaw)*.85
	game.web_command(["stick",step.x,step.y])
	for tick in 55:
		await frames(1)
		if lift.position.distance_to(player.position)<.30:break
	game.web_command(["stick",0,0])
	await frames(4)
	if not check(player.ground_at(player.position,.15).get("collider")==lift,"walk from the plate onto the basket"):return
	game.web_command(["align"])
	var exit_yaw:=game.camera_yaw
	await frames(roundi((2.7-game.art.branches.clock)*60.))
	var parked:=lift.plate.global_transform
	var tip:=lift.position+lift.HINGE+Vector3.FORWARD*.72
	if not check(lift.plate.rotation.x<deg_to_rad(-70) and player.ground_at(tip,.18).get("collider")!=lift.plate,"the stowed step has no horizontal foothold"):return
	game.toggle_pause()
	await frames(24)
	if not check(parked.is_equal_approx(lift.plate.global_transform),"pause holds both the basket and hinge"):return
	game.toggle_pause()
	await frames(roundi((4.08-game.art.branches.clock)*60.))
	if not check(lift.position.distance_to(lift.exit_dock)<.01 and is_zero_approx(lift.plate.rotation.x) and is_equal_approx(exit_yaw,game.camera_yaw),"far stop unfolds on the preselected heading"):return
	await forward_jump(.85,11)
	if not await reach_floor(22):return
	if not check(player.jump_count==2 and game.falls==0,"board and leave for the drying rack in two jumps"):return
	if not await board_step():return
	# Remain on the outer tip as the plate folds away.
	for tick in 250:
		await frames(1)
		if player.is_on_floor() and game.ledge!=B.LIFT:break
	if not check(player.is_on_floor() and game.ledge==2 and game.falls==1 and player.jump_count==1,"the coffee table catches a rider who stays on the closing step"):return
	game.start_run()
	if not check(lift.position==lift.entry and lift.plate.rotation.x==0.,"restart opens the near step"):return
	print("PASS laundry lift boarding step, dock alignment, timed crossing and lower catch")
	game.free()
	quit()
