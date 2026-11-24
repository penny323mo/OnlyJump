extends "res://tests/branches.gd"

func horizontal(v: Vector3) -> Vector2:
	return Vector2(v.x,v.z).normalized()

func forecast_drop(phase: float, aim_ahead: bool) -> bool:
	await start_on(0)
	var lift:=game.art.branches.lift
	var guide:=game.landing_guide
	var p:=game.player
	await frames(roundi((phase-lift.phase)*60.))
	var target:=lift.position_at(lift.phase+.5) if aim_ahead else lift.position
	p.reset_at(target+Vector3(.12,1.98,.05))
	var first:=Vector3.INF
	var seen:=0
	var first_tick:=-1
	for tick in 75:
		await frames(1)
		if p.is_on_floor():break
		if p.position.y<lift.entry.y-1.:break
		if guide.visible and guide.moving_support==lift:
			if not check(aim_ahead,"no landing promised on the departing basket"):return false
			var local:=lift.to_local(guide.global_position)
			if first==Vector3.INF:
				first=local
				first_tick=tick
			if not check(absf(local.y-.028)<.003 and absf(local.x)<=lift.DECK_SIZE.x*.5+.001 and absf(local.z)<=lift.DECK_SIZE.z*.5+.001,"cross rides on the physical deck between predictions"):return false
			seen+=1
	if not aim_ahead:
		return check(game.ledge!=B.LIFT and p.position.y<lift.entry.y-.8,"departed basket misses the runner")
	var error:=first.distance_to(lift.to_local(p.position))
	print("lift at ",phase," s: first forecast at frame ",first_tick,", ",seen," marked frames, landing error ",snappedf(error,.001)," m")
	return check(p.is_on_floor() and game.ledge==B.LIFT and first_tick>=0 and first_tick<9 and seen>=18 and error<.20,"early moving-deck forecast matches the actual landing")

func timed_boarding(phase: float, strength: float, runup: int, catches: bool, offset:=Vector3.ZERO) -> bool:
	await start_on(19)
	if not offset.is_zero_approx():
		game.player.reset_at(game.art.stop_position(19)+offset)
		await frames(8)
	game.web_command(["branch"])
	var lift:=game.art.branches.lift
	await frames(roundi((phase-lift.phase)*60.))
	await forward_jump(strength,runup)
	var mark:=Vector3.INF
	var guide:=game.landing_guide
	for tick in 165:
		await frames(1)
		if game.player.is_on_floor():break
		if guide.visible and guide.moving_support:
			if not check(catches,"late runner sees no promised basket landing"):return false
			if mark==Vector3.INF and guide.moving_support==lift:mark=lift.to_local(guide.global_position)
	if catches:
		var error:=mark.distance_to(lift.to_local(game.player.position))
		print("ironing board jump: basket displacement ",snappedf(lift.position.distance_to(lift.entry),.01)," m, landing error ",snappedf(error,.001)," m")
		return check(game.ledge==B.LIFT and lift.position.distance_to(lift.entry)>1.3 and error<.20,"running jump catches the moving basket at the forecast spot")
	return check(game.player.is_on_floor() and game.art.stage(game.ledge)<19 and game.falls>0,"late jump falls through to a lower object")

func upper_floor_first() -> bool:
	await start_on(0)
	var lift:=game.art.branches.lift
	var p:=game.player
	await frames(roundi((5.6-lift.phase)*60.))
	p.reset_at(lift.position_at(lift.phase+.5)+Vector3(-.85,4.,.72))
	var mark:=Vector3.INF
	for tick in 90:
		await frames(1)
		if p.is_on_floor():break
		if game.landing_guide.visible:
			if not check(not game.landing_guide.moving_support,"upper floor occludes the lift beneath it"):return false
			if mark==Vector3.INF:mark=game.landing_guide.global_position
	# Part of the sole overhangs the sloping parasol edge.
	return check(p.is_on_floor() and game.ledge==24 and mark.distance_to(p.position)<p.FOOT_RADIUS+.028,"forecast the actual upper floor before a passing basket")

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
	var mark:=Vector3.INF
	for tick in 60:
		await frames(1)
		if game.player.is_on_floor():break
		if mark==Vector3.INF and game.player.velocity.y<-.5 and game.landing_guide.visible:
			mark=lift.plate.to_local(game.landing_guide.global_position)
	if not await reach_floor(B.LIFT):return false
	var foot:=game.player.ground_at(game.player.position,.15)
	if not check(mark.distance_to(lift.plate.to_local(game.player.position))<.22,"boarding forecast lands on the opening step"):return false
	return check(foot.get("collider")==lift.plate and lift.to_local(game.player.position).z<-1.20,"the unfolded tip catches a jump short of the basket floor")

func run() -> void:
	game=Game.new()
	game.record_path=course_test_save
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
	if not await timed_boarding(1.,.85,14,true):return
	if not await timed_boarding(1.2,.85,14,false):return
	if not await timed_boarding(.8,.55,6,false):return
	# From the left corner the runner just overshoots the rear edge.
	if not await timed_boarding(7.3,.85,14,false,Vector3(-.506,0,.420)):return
	for phase in [2.0,6.6,7.8]:
		if not await forecast_drop(phase,true):return
	if not await forecast_drop(2.22,false):return
	if not await upper_floor_first():return
	print("PASS laundry lift boarding step, dock alignment, timed crossing and lower catch")
	print("PASS landing guide tracks both lift trips, open step, cycle wrap and a departing miss")
	game.free()
	DirAccess.remove_absolute(course_test_save)
	quit()
