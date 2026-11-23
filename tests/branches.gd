extends "res://tests/route.gd"
const B = Land.Branches

func start_on(id: int) -> void:
	game.start_run()
	game.player.grab.rng.seed=2
	game.player.reset_at(game.art.stop_position(id))
	await frames(6)

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

func ride_bounce(destination: int) -> bool:
	game.web_command(["stick",0,0])
	game.web_command(["sprint",false])
	var player:=game.player
	var contact_height:=player.position.y
	var bottom:=contact_height
	var jumps:=player.jump_count
	for tick in 20:
		await frames(1)
		if player.velocity.y>8.5: break
		bottom=minf(bottom,player.position.y)
		var surface:=player.ground_at(player.position,.4)
		if not check(player.is_on_floor() and not surface.is_empty() and absf(surface.position.y-player.position.y)<.10,"feet follow the compressing surface"):return false
		if tick==4:
			game.toggle_pause()
			var foot:=player.position
			await frames(20)
			if not check(foot.is_equal_approx(player.position),"pause during spring compression"):return false
			game.toggle_pause()
			game.web_command(["jump"])
	if not check(contact_height-bottom>.10 and player.velocity.y>8.5 and player.jump_count==jumps+1,"spring loads and releases once"):return false
	for tick in 100:
		await frames(1)
		if game.player.is_on_floor():
			return check(game.ledge==destination,"spring destination "+str(destination))
	return check(false,"spring failed to land")

func check_spring_impacts() -> bool:
	var pad:=game.art.branches.bodies[B.BED] as B.SpringPad
	var player:=game.player
	var depths: Array[float]=[]
	var speeds: Array[float]=[]
	for height: float in [.35,3.,5.]:
		game.start_run()
		player.reset_at(pad.global_position+Vector3.UP*height)
		var depth:=0.
		for tick in 120:
			await frames(1)
			depth=maxf(depth,-pad.plate.position.y)
			if player.jump_count>0:break
		if not check(not player.is_on_floor() and player.jump_count==1 and player.velocity.y>8.5,"drop triggers one spring launch"):return false
		depths.append(depth)
		speeds.append(player.velocity.y)
	if not check(depths[1]>depths[0]+.05 and speeds[1]>speeds[0]+.2,"a harder landing compresses further and launches faster"):return false
	if not check(is_equal_approx(depths[1],depths[2]) and is_equal_approx(speeds[1],speeds[2]),"hard drops reach the same limit"):return false
	print("spring drops from 0.35/3/5 m: depths ",depths," m, lift ",speeds," m/s")
	game.start_run()
	player.reset_at(pad.global_position+Vector3.UP)
	for tick in 90:
		await frames(1)
		if pad.load_fraction()>.5:break
	if not check(pad.loading and pad.load_fraction()>.5,"restart fixture is under load"):return false
	game.start_run()
	await frames(50)
	return check(not pad.loading and is_zero_approx(pad.plate.position.y) and player.is_on_floor() and game.ledge==0 and player.jump_count==0,"restart clears a loaded spring")

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

func check_fan_footing() -> bool:
	game.start_run()
	var blade: Node3D=game.art.branches.bodies[B.FAN]
	var player:=game.player
	# Ride the unladen blade so the jump button stays a normal jump.
	player.reset_at(blade.to_global(Vector3(2.13,.04,0).rotated(Vector3.UP,TAU/3)))
	await frames(40)
	var sole:=blade.to_local(player.position)
	var facing:=blade.basis.inverse()*(-player.model.basis.z)
	var yaw:=game.camera_yaw
	for quarter in 5:
		await frames(188)
		if not check(player.is_on_floor() and game.ledge==B.FAN,"remain on blade tip"):return false
		if not check(sole.distance_to(blade.to_local(player.position))<.006,"feet stay planted through each turn"):return false
		if not check(facing.angle_to(blade.basis.inverse()*(-player.model.basis.z))<.015,"rider turns with the blade"):return false
		if not check(is_equal_approx(game.camera_yaw,yaw),"idle ride keeps selected camera heading"):return false
	var previous:=player.position
	await frames(1)
	var carry:=(player.position-previous)*Engine.physics_ticks_per_second
	game.web_command(["jump"])
	await frames(2)
	var airborne:=Vector2(player.velocity.x,player.velocity.z)
	if not check(not player.is_on_floor() and airborne.distance_to(Vector2(carry.x,carry.z))<.06 and airborne.length()>.9,"neutral jump inherits the blade tangent once"):return false
	player.reset_at(blade.to_global(sole))
	await frames(10)
	var outward:=player.position-blade.position
	var stick:=Vector2(outward.x,outward.z).normalized().rotated(game.camera_yaw)
	game.web_command(["stick",stick.x,stick.y])
	await frames(35)
	game.web_command(["stick",0,0])
	return check(player.position.y<blade.position.y-.15 and player.jump_count==0,"stepping off the tip releases the foothold")

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
	game.record_path=course_test_save
	root.add_child(game)
	game.best=100
	game.muted=true
	if not await check_spring_impacts():return
	for id: String in game.player.costumes.NAMES:
		game.player.costumes.select(id)
		if not check(game.player.costumes.key==id,"select "+id):return
		if id!="courier" and not check(game.player.costumes.mounts.size()>=2,"animated costume mounts"):return
	await start_on(0)
	var view:=game.camera.global_transform
	var duck: Node3D=game.art.pickups.items["double"]
	game.camera.position=Vector3(0,3,4)
	game.camera.look_at(duck.global_position)
	if not check(game.art.pickups.visible_hint(game.camera,game.player)==duck,"label on visible duck"):return
	var frame:=game.art.pickups.frame_bounds(game.camera,duck)
	if not check(frame.has_area() and frame.has_point(game.camera.unproject_position(duck.global_position)),"projected frame surrounds duck"):return
	game.camera.position=Vector3(0,-3,0)
	game.camera.look_at(duck.global_position)
	if not check(game.art.pickups.visible_hint(game.camera,game.player)==null,"rooftop blocks duck label"):return
	game.camera.global_transform=view
	game.web_command(["branch"])
	if not check(game.alternate and game.art.destination(0,true)==B.BED,"choose optional route"):return
	game.web_command(["branch"])
	if not check(not game.alternate,"restore main route"):return
	# Off-centre landings support the player; adjust on the bed and jump again.
	if not await leap(B.BED,Vector3(.55,0,.03),false):return
	await frames(12)
	if not check(game.player.is_on_floor() and game.player.spring_pad==null,"off-centre bed supports player"):return
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
	game.web_command(["branch"])
	if not await leap(B.DRAWER,Vector3.ZERO,false):return
	await frames(145)
	if not check(game.art.branches.bodies[B.DRAWER].collision_layer==0,"drawer gives way"):return
	if not check(game.player.is_on_floor() and game.ledge==B.AWNING and game.falls==1,"striped awning catches drawer fall"):return
	for height: float in [.12,.65,1.12]:
		var subject:=game.player.position+Vector3.UP*height
		var sight:=PhysicsRayQueryParameters3D.create(game.camera.position,subject)
		sight.exclude=[game.player.get_rid()]
		if not check(game.camera.is_position_in_frustum(subject) and game.get_world_3d().direct_space_state.intersect_ray(sight).is_empty(),"suitcase leaves recovered climber visible"):return
	var normal:=game.player.get_floor_normal()
	if not check(normal.y>.94 and normal.z>.18 and game.art.destination(game.ledge,false)==2,"awning cloth slopes towards the coffee table"):return
	if not await leap(2):return
	if not await leap(3):return
	if not check(game.falls==1,"rejoin main route without respawning"):return
	await frames(226)
	if not check(game.art.branches.bodies[B.DRAWER].collision_layer==1,"drawer returns"):return
	await start_on(4)
	if not await leap(B.DRAWER,Vector3(0,0,.68),false):return
	await frames(210)
	if not check(game.ledge==0 and game.falls==1 and game.player.position.length()<.12,"outer lip misses the awning"):return
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
	if not await check_fan_footing():return
	game.start_run()
	if not check(game.art.branches.timers.is_empty() and game.art.branches.bodies[B.BOARD].collision_layer==1,"restart restores props"):return
	print("PASS branches, rotating fan, timed pickups, double-jump stunts, lower recovery and five characters")
	game.free()
	DirAccess.remove_absolute(course_test_save)
	quit()
