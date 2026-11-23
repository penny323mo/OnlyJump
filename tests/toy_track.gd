extends "res://tests/branches.gd"

func jump_from_board(angle: float, expected: int) -> bool:
	await start_on(11)
	var stick:=Vector2(1.,angle).normalized()*.83
	game.web_command(["sprint",true])
	game.web_command(["stick",stick.x,stick.y])
	await frames(11)
	game.web_command(["jump"])
	await frames(4)
	game.web_command(["stick",0,0])
	game.web_command(["sprint",false])
	return await reach_floor(expected)

func run() -> void:
	game=Game.new()
	game.record_path=course_test_save
	root.add_child(game)
	game.best=100
	game.muted=true
	var player:=game.player
	if not await jump_from_board(0.,12):return
	if not await jump_from_board(.6,0):return
	if not await jump_from_board(-.48,B.TRACK):return
	var track:=player.track
	if not check(track!=null and game.falls==1 and player.jump_count==1,"missed the car and landed on the track"):return
	# Check the physical surface on both grades and both banks of the trough.
	for t: float in [.23,.58,.84]:
		for lane: float in [-.8,0.,.8]:
			var point:=track.to_global(track.surface(t,lane))
			var hit:=player.ground_at(point+Vector3.UP*.10,.45)
			if not check(hit.get("collider")==track and absf(hit.position.y-point.y)<.025,"solid curved surface under the painted track"):return
	var caught:=player.position
	await frames(12)
	if not check(player.coasting() and caught.distance_to(player.position)>.45 and player.position.y<caught.y-.10 and player.pose=="Sliding","released stick preserves a downhill slide"):return
	var coast:=player.position
	var speed:=player.track_velocity
	game.toggle_pause()
	await frames(20)
	if not check(player.position.is_equal_approx(coast) and player.track_velocity.is_equal_approx(speed),"pause freezes the slide"):return
	game.toggle_pause()
	game.web_command(["sprint",true])
	var steer:=Vector2(-1.,.9).normalized()
	game.web_command(["stick",steer.x,steer.y])
	for tick in 100:
		await frames(1)
		if player.position.x<=1.22 or not player.track:break
	if not check(player.track==track and player.takeoff_rise()>.65 and player.jump_count==1,"steer up the curve without an automatic jump"):return
	game.web_command(["stick",0,0])
	game.landing_guide.refresh(player,Vector2.ZERO,1./60)
	if not check(game.landing_guide.visible,"coasting takeoff has a forecast"):return
	var mark:=game.landing_guide.global_position
	game.web_command(["jump"])
	await frames(2)
	if not check(not player.is_on_floor() and player.track==null and player.velocity.y>player.JUMP_SPEED,"manual launch keeps uphill momentum"):return
	if not await reach_floor(11):return
	if not check(player.position.distance_to(mark)<.38 and game.falls==1 and player.jump_count==2 and player.ability=="","real landing matches the forecast and recovers one stage"):return
	print("track catch ",caught," coast ",coast," predicted ",mark," board ",player.position)
	if not await jump_from_board(-.48,B.TRACK):return
	steer=Vector2(-player.track_velocity.x,-player.track_velocity.z).normalized()
	game.web_command(["stick",steer.x,steer.y])
	await frames(12)
	if not check(player.track==track and player.track_velocity.length()<speed.length()-.45,"countersteering brakes a skid on the same entry"):return
	game.start_run()
	await frames(8)
	if not check(player.track==null and not player.coasting() and player.jump_count==0,"restart releases the slide"):return
	print("PASS toy track banks, coasting, braking, manual ramp jump, forecast and selective recovery")
	game.free()
	DirAccess.remove_absolute(course_test_save)
	quit()
