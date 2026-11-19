extends "res://tests/route.gd"
const B = Land.Branches

func start_on(id: int) -> void:
	game.start_run()
	game.player.grab.rng.seed=2
	game.player.reset_at(game.art.stop_position(id))
	await frames(6)

func ride_bounce(destination: int) -> bool:
	game.web_command(["stick",0,0])
	game.web_command(["sprint",false])
	await frames(2)
	if not check(game.player.velocity.y>8.5,"centre triggers a spring"): return false
	for tick in 100:
		await frames(1)
		if game.player.is_on_floor():
			return check(game.ledge==destination,"spring destination "+str(destination))
	return check(false,"spring failed to land")

func approach_pickup(id: String) -> bool:
	for tick in 80:
		var obj: Node3D=game.art.pickups.items[id]
		if not obj.visible:
			game.stick=Vector2.ZERO
			return true
		var gap:=obj.global_position-game.player.position
		game.stick=Vector2(gap.x,gap.z).limit_length(.55).rotated(game.camera_yaw)
		await frames(1)
	return check(false,"could not reach pickup "+id)

func check_double_jump() -> bool:
	var player:=game.player
	for direction: Vector2 in [Vector2.ZERO,Vector2.LEFT*.18]:
		game.stick=Vector2.ZERO
		game.web_command(["jump"])
		await frames(18)
		game.stick=direction
		var before:=player.jump_count
		game.web_command(["jump"])
		await frames(4)
		var axis:=Vector3.UP if direction.is_zero_approx() else Vector3.LEFT
		if not check(player.stunt_axis==axis and player.velocity.y>5 and player.jump_count==before+1,"second jump with selected stunt"):return false
		if not check(not player.stunt_pivot.basis.is_equal_approx(Basis.IDENTITY) and player.basis.is_equal_approx(Basis.IDENTITY),"visual spin only"):return false
		game.web_command(["jump"])
		game.stick=Vector2.ZERO
		await frames(46)
		if not check(player.jump_count==before+1 and player.stunt_pivot.basis.is_equal_approx(Basis.IDENTITY),"no third jump and pose restored"):return false
		await frames(45)
		if not check(player.is_on_floor(),"land after double jump"):return false
	if not check(player.double_charges==1,"each extra jump spends one of three charges"):return false
	while player.ability=="double":await frames(1)
	if not check(game.elapsed>=15 and game.elapsed<18 and game.art.pickups.count==1,"timed duck expires without collecting twice"):return false
	return true

func check_moving_takeoff(source: int, phase_ticks: int, aim: int, landing: int) -> bool:
	game.start_run()
	await frames(phase_ticks)
	var platform: Node3D=game.art.branches.bodies[source]
	var foot:=Vector3.RIGHT.rotated(Vector3.UP,TAU/3)*1.28 if source==B.FAN else Vector3.ZERO
	var player:=game.player
	player.reset_at(platform.to_global(foot)+Vector3.UP*.035)
	player.grab.rng.seed=2
	await frames(7)
	var to_target:=game.art.stop_position(aim)-player.position
	var direction:=Vector2(to_target.x,to_target.z).normalized()
	game.web_command(["sprint",true])
	game.web_command(["stick",direction.x,direction.y])
	await frames(9)
	if not check(player.is_on_floor() and game.ledge==source and player.get_platform_velocity().length()>.6,"moving support before jump"):return false
	game.landing_guide.refresh(player,game.world_move(),1./60)
	if not check(game.landing_guide.visible,"visible takeoff prediction"):return false
	var mark:=game.landing_guide.global_position
	game.web_command(["jump"])
	await frames(2)
	if not check(not player.is_on_floor(),"left moving platform"):return false
	for tick in 90:
		await frames(1)
		if player.is_on_floor():
			var error:=mark.distance_to(player.position)
			print("moving takeoff ",source," to ",game.ledge," error ",snappedf(error,.001)," m")
			return check(game.ledge==landing and error<.30,"moving takeoff matches first landing")
	return check(false,"no landing after moving takeoff")

func run() -> void:
	game=Game.new()
	root.add_child(game)
	game.best=100
	game.muted=true
	game.follow_camera=false
	for id: String in game.player.costumes.NAMES:
		game.player.costumes.select(id)
		if not check(game.player.costumes.key==id,"select "+id):return
		if id!="courier" and not check(game.player.costumes.mounts.size()>=2,"animated costume mounts"):return
	await start_on(0)
	game.web_command(["branch"])
	if not check(game.alternate and game.art.destination(0,true)==B.BED,"choose optional route"):return
	game.web_command(["branch"])
	if not check(not game.alternate,"restore main route"):return
	# Off-centre landings support the player; adjust on the bed and jump again.
	if not await leap(B.BED,Vector3(.55,0,.03),false):return
	await frames(12)
	if not check(game.player.is_on_floor() and game.player.spring_impulse.is_zero_approx(),"off-centre bed supports player"):return
	if not check(game.player.ability=="double" and game.art.pickups.count==1,"land beside duck to collect once"):return
	if not await check_double_jump():return
	await start_on(0)
	if not await leap(B.BED,Vector3.ZERO,false):return
	if not await ride_bounce(3):return
	# Spend all three charges on three jumps, then try the same input again.
	await start_on(0)
	if not await leap(B.BED,Vector3(.55,0,.03),false):return
	await frames(10)
	for n in 4:
		var before:=game.player.jump_count
		game.web_command(["jump"])
		await frames(17)
		game.web_command(["jump"])
		await frames(2)
		var spent:=mini(n+1,3)
		if not check(game.player.jump_count==before+(2 if n<3 else 1) and game.player.double_charges==3-spent,"three extra jumps per duck"):return
		await frames(94)
	await start_on(4)
	if not await leap(B.DRAWER,Vector3.ZERO,false):return
	if not await leap(6,Vector3.ZERO,false):return
	await start_on(4)
	if not await leap(B.DRAWER,Vector3.ZERO,false):return
	await frames(110)
	if not check(game.art.branches.bodies[B.DRAWER].collision_layer==0,"drawer gives way"):return
	await frames(246)
	if not check(game.art.branches.bodies[B.DRAWER].collision_layer==1,"drawer returns"):return
	await start_on(8)
	if not await leap(B.FAN,Vector3.ZERO,false):return
	var local_foot: Vector3=game.art.branches.bodies[B.FAN].to_local(game.player.position)
	await frames(60)
	var moved_foot: Vector3=game.art.branches.bodies[B.FAN].to_local(game.player.position)
	if not check(game.player.is_on_floor() and game.ledge==B.FAN and local_foot.distance_to(moved_foot)<.25,"rotating blade carries rider"):return
	if not await approach_pickup("jet"):return
	if not check(game.player.jet_armed and game.art.pickups.count==1,"wind-up key arms jet"):return
	var ignition:=game.player.position
	game.web_command(["jump"])
	await frames(90)
	if not check(game.player.position.y>ignition.y+1.9 and game.player.position.y<ignition.y+2.55 and absf(game.player.ability_time-1.5)<.06,"jet thrust and timer"):return
	game.toggle_pause()
	var fuel:=game.player.ability_time
	await frames(20)
	if not check(is_equal_approx(game.player.ability_time,fuel),"pause saves jet fuel"):return
	game.toggle_pause()
	await frames(96)
	if not check(game.player.position.y<ignition.y+2.56,"jet caps altitude gain"):return
	if not check(game.player.ability=="" and not game.player.exhaust.visible,"three second jet expires"):return
	await start_on(8)
	await frames(251) # Board the next blade past the turntable, away from the key.
	if not await leap(B.FAN,Vector3.ZERO,false):return
	while game.art.branches.fan_angle<5.19: await frames(1)
	if not await leap(10,Vector3.ZERO,false):return
	await start_on(18)
	if not await leap(B.POLE,Vector3.ZERO,false):return
	game.sprint=false
	game.stick=Vector2(-1,.24).normalized()
	for i in 180:
		await frames(1)
		if game.player.position.x < -4.25:break
	game.stick=Vector2.ZERO
	if not check(game.ledge==B.POLE and game.player.position.x< -4.25 and game.player.is_on_floor(),"balance up round pole"):return
	if not await leap(21,Vector3.ZERO,false):return
	await start_on(19)
	if not await leap(B.LIFT,Vector3.ZERO,false):return
	await frames(5)
	game.toggle_pause()
	var parked: Vector3=game.art.branches.bodies[B.LIFT].position
	await frames(20)
	if not check(parked.is_equal_approx(game.art.branches.bodies[B.LIFT].position),"pause parks lift"):return
	game.toggle_pause()
	while game.art.branches.clock<4.: await frames(1)
	if not check(game.player.is_on_floor() and game.ledge==B.LIFT and game.player.position.distance_to(B.LIFT_END)<1.3,"basket carries rider"):return
	if not await leap(22,Vector3.ZERO,false):return
	await start_on(20)
	if not await leap(B.COIL,Vector3.ZERO,false):return
	if not await ride_bounce(23):return
	await start_on(21)
	if not await leap(B.BOARD,Vector3.ZERO,false):return
	var timer: float=game.art.branches.timers[B.BOARD]
	game.toggle_pause()
	await frames(25)
	if not check(is_equal_approx(timer,game.art.branches.timers[B.BOARD]),"pause freezes cracking board"):return
	game.toggle_pause()
	await frames(135)
	if not check(game.ledge==B.SHEET and game.player.is_on_floor() and game.falls==1,"sheet catches real board fall"):return
	if not await leap(21,Vector3.ZERO,false):return
	await start_on(21)
	if not await leap(B.BOARD,Vector3.ZERO,false):return
	await frames(135)
	if not await approach_pickup("glide"):return
	if not check(game.player.ability=="glide","collect sock on the rescue route"):return
	game.web_command(["jump"])
	await frames(44)
	if not check(game.player.velocity.y>=-2.11 and game.player.velocity.y<0,"gliding limits fall speed"):return
	await start_on(21)
	if not await leap(B.BOARD,Vector3.ZERO,false):return
	if not await leap(24,Vector3.ZERO,false):return
	if not await check_moving_takeoff(B.FAN,165,10,10):return
	if not await check_moving_takeoff(B.LIFT,205,22,22):return
	if not await check_moving_takeoff(B.LIFT,403,22,20):return
	game.start_run()
	if not check(game.art.branches.timers.is_empty() and game.art.branches.bodies[B.BOARD].collision_layer==1,"restart restores props"):return
	print("PASS branches, rotating fan, timed pickups, double-jump stunts, lower recovery and five characters")
	game.free()
	quit()
