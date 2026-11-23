extends "res://tests/branches.gd"

func steer(direction: Vector3, strength:=1.) -> void:
	var input:=Vector2(direction.x,direction.z).normalized().rotated(game.camera_yaw)*strength
	game.web_command(["stick",input.x,input.y])

func catch_girder() -> bool:
	await start_on(16)
	var p:=game.player
	p.grab.rng.seed=1
	game.web_command(["look",.21,0])
	steer(Vector3.BACK,.64)
	for tick in 90:
		await frames(1)
		if not p.is_on_floor():break
	await frames(7)
	steer(Vector3.FORWARD)
	for tick in 40:
		await frames(1)
		if p.grab.active:return true
	return check(false,"grabbed the girder on the way down")

func traverse_girder() -> bool:
	if not await catch_girder():return false
	var p:=game.player
	var grip:=p.grab
	var body:=grip.support_body
	var roll:=grip.rng.state
	p.equip("double")
	steer(Vector3.RIGHT)
	await frames(8)
	var start:=p.position
	var lead:=false
	var follow:=false
	var max_error:=0.
	for tick in 100:
		var left:=body.to_local(grip.hands[0])
		var right:=body.to_local(grip.hands[1])
		await frames(1)
		if not check(grip.can_pull_up() and grip.support_body==body,"stay hanging while traversing"):return false
		var dl:=left.distance_to(body.to_local(grip.hands[0]))
		var dr:=right.distance_to(body.to_local(grip.hands[1]))
		if not check(minf(dl,dr)<.002,"one hand remains planted on every reach"):return false
		lead=lead or dr>.008
		follow=follow or dl>.008
		for i in p.arms.size():
			var palm:=p.rig.to_global(p.rig.get_bone_global_pose(p.arms[i][2]).origin)
			max_error=maxf(max_error,palm.distance_to(grip.hands[i]))
		if tick==24:
			var foot:=p.position
			game.toggle_pause()
			await frames(15)
			if not check(p.position==foot and grip.active,"pause halfway along the rim"):return false
			game.toggle_pause()
			steer(Vector3.RIGHT)
	if not check(p.position.x>start.x+.65 and lead and follow,"both hands take turns and carry the body sideways"):return false
	print("girder traverse ",snappedf(p.position.x-start.x,.01)," m; maximum palm error ",snappedf(max_error,.001)," m")
	if not check(max_error<.08,"both animated palms reach their handholds"):return false
	await frames(160)
	var end:=p.position
	await frames(30)
	if not check(grip.active and p.position.distance_to(end)<.003 and body.to_local(grip.hands[1]).x<2.28,"stop where the girder edge ends"):return false
	steer(Vector3.LEFT)
	await frames(32)
	if not check(p.position.x<end.x-.18,"reverse along the same rim"):return false
	game.web_command(["jump"])
	game.web_command(["stick",0,0])
	await frames(55)
	return check(p.is_on_floor() and game.ledge==16 and p.jump_count==0 and p.double_charges==p.MAX_DOUBLE_CHARGES and grip.rng.state==roll,"pull up at the new spot without an extra jump or roll")

func drop_to_sheet() -> bool:
	await start_on(0)
	var p:=game.player
	p.reset_at(game.art.stop_position(B.SHEET)+Vector3.LEFT*1.12)
	p.grab.rng.seed=1
	await frames(8)
	steer(Vector3.RIGHT,.15)
	await frames(4)
	game.web_command(["stick",0,0])
	await frames(14)
	game.web_command(["jump"])
	for tick in 80:
		await frames(1)
		if p.grab.active:break
	if not check(p.grab.active and p.grab.support_body==game.art.branches.bodies[B.BOARD],"caught the cracked board above the sheet"):return false
	var roll:=p.grab.rng.state
	var away:=-p.grab.forward
	steer(away)
	await frames(10)
	if not check(p.grab.active,"a brief outward push keeps the grip"):return false
	game.web_command(["stick",0,0])
	await frames(2)
	steer(away)
	await frames(7)
	if not check(p.grab.active,"releasing the stick clears the drop hold"):return false
	await frames(8)
	if not check(not p.grab.active and p.velocity.y<0,"deliberately let go before pulling up"):return false
	game.web_command(["stick",0,0])
	if not await reach_floor(B.SHEET):return false
	return check(p.jump_count==1 and p.grab.rng.state==roll,"land on the lower sheet without regrabbing or using a jump")

func blocked_section() -> bool:
	if not await catch_girder():return false
	var p:=game.player
	var origin:=game.art.stop_position(16)
	var obstruction:=StaticBody3D.new()
	game.add_child(obstruction)
	game.art.solid(obstruction,origin+Vector3(.98,.92,.32),Vector3(.6,.25,.9),"919498")
	steer(Vector3.RIGHT)
	await frames(100)
	var stalled:=p.position
	await frames(20)
	if not check(p.grab.active and stalled.distance_to(p.position)<.003 and stalled.x<origin.x+.6,"remain at the last climbable hold beside an obstruction"):return false
	obstruction.queue_free()
	await frames(52)
	if not check(p.position.x>stalled.x+.35 and p.grab.active,"resume along the rim when the climb space clears"):return false
	game.web_command(["stick",0,0])
	await frames(80)
	return check(p.is_on_floor() and game.ledge==16,"neutral stick automatically climbs at the new hold")

func moving_traverse(drop: bool) -> bool:
	await start_on(19)
	await frames(30)
	var p:=game.player
	var lift:=game.art.branches.lift
	p.grab.rng.seed=1
	steer(lift.position-p.position)
	game.web_command(["sprint",true])
	await frames(6)
	game.web_command(["jump"])
	await frames(4)
	game.web_command(["stick",0,0])
	game.web_command(["sprint",false])
	for tick in 75:
		await frames(1)
		if p.grab.active:break
	var grip:=p.grab
	if not check(grip.active and grip.support_body==lift,"catch the main basket rim"):return false
	var rail_start:=lift.to_local(grip.hands[0])
	var start:=lift.position
	var side:=grip.forward.cross(Vector3.UP)
	if side.dot(lift.position-p.position)<0:side=-side
	steer(side)
	for tick in 54:
		var left:=lift.to_local(grip.hands[0])
		var right:=lift.to_local(grip.hands[1])
		await frames(1)
		if not check(grip.can_pull_up() and minf(left.distance_to(lift.to_local(grip.hands[0])),right.distance_to(lift.to_local(grip.hands[1])))<.002,"one palm stays attached as the basket accelerates"):return false
	if not check(lift.position.distance_to(start)>1. and lift.to_local(grip.hands[0]).distance_to(rail_start)>.3,"move along the rail independently of the moving basket"):return false
	if drop:
		steer(-grip.forward)
		for tick in 24:
			var previous:=lift.position
			await frames(1)
			if not grip.active:
				var carry:=(lift.position-previous)*Engine.physics_ticks_per_second
				var released:=p.velocity-carry
				return check(carry.length()>1. and released.dot(-grip.forward)>.4 and released.y<-.4 and released.length()<1.1 and p.jump_count==1,"letting go inherits the basket's speed plus an outward drop")
		return check(false,"released the accelerating basket")
	game.web_command(["jump"])
	game.web_command(["stick",0,0])
	await frames(60)
	return check(p.is_on_floor() and game.ledge==B.LIFT and p.jump_count==1,"pull up at the new position on the travelling basket")

func run() -> void:
	game=Game.new()
	game.record_path=course_test_save
	root.add_child(game)
	game.muted=true
	if not await traverse_girder():return
	if not await drop_to_sheet():return
	if not await blocked_section():return
	if not await moving_traverse(false):return
	if not check(game.player.get_platform_velocity().length()>1.,"basket is moving before restarting"):return
	game.web_command(["pause"])
	game.web_command(["restart"])
	await frames(8)
	if not check(game.player.is_on_floor() and game.player.position.distance_to(Land.ROUTE[0])<.008,"restart on a moving carrier places the runner at the rooftop spawn"):return
	if not await moving_traverse(true):return
	print("PASS hand-over-hand girder traverse, rim end, reversal, pull-up and drop to the sheet")
	print("PASS clear climb space and independent handholds on the travelling basket")
	game.free()
	DirAccess.remove_absolute(course_test_save)
	quit()
