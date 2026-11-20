extends SceneTree
const Game = preload("res://game/ascent.gd")
const Land = preload("res://game/islands.gd")
var game: Game
var pre_jump_marks := 0

func _initialize() -> void:
	call_deferred("run")

func frames(n: int) -> void:
	for i in n: await physics_frame

func check(ok: bool, message: String) -> bool:
	if not ok:
		printerr("FAIL ",message," ledge=",game.ledge," position=",game.player.position)
		quit(1)
	return ok

func leap(index: int, offset := Vector3.ZERO, check_guide := true) -> bool:
	# Run up on the actual previous object, then take a ballistic jump. The
	# test only drives the controls available to the player, including sprint.
	game.web_command(["stick",0,0])
	await frames(2)
	var target := game.art.stop_position(index)+offset
	var gap := target-game.player.position
	var aim := Vector2(gap.x,gap.z).normalized()
	var t := (game.player.JUMP_SPEED+sqrt(maxf(.01,game.player.JUMP_SPEED**2-2*game.player.GRAVITY*gap.y)))/game.player.GRAVITY
	var speed := minf(game.player.RUN_SPEED,game.player.GROUND_ACCEL*(sqrt(t*t+2*Vector2(gap.x,gap.z).length()/game.player.GROUND_ACCEL)-t))
	game.web_command(["sprint",true])
	var stick := aim.rotated(game.camera_yaw)*(speed/game.player.RUN_SPEED)
	game.web_command(["stick",stick.x,stick.y])
	for tick in 25:
		await frames(1)
		var remaining := target-game.player.position
		var velocity := Vector2(game.player.velocity.x,game.player.velocity.z)
		if velocity.dot(aim)*t>=Vector2(remaining.x,remaining.z).dot(aim)-.07 or not game.player.is_on_floor():break
	game.landing_guide.refresh(game.player,game.world_move(),1./60)
	var before_mark := game.landing_guide.global_position if game.landing_guide.visible else Vector3.INF
	var air_mark := Vector3.INF
	game.web_command(["jump"])
	for tick in 95:
		await frames(1)
		if not game.player.is_on_floor() and game.player.velocity.y<-.8 and game.landing_guide.visible:
			if air_mark==Vector3.INF: air_mark=game.landing_guide.global_position
		if game.player.is_on_floor() and game.ledge==index:
			if check_guide and not check(air_mark.distance_to(game.player.position)<.40,"in-flight landing guide for "+game.art.stop_name(index)):return false
			if check_guide and before_mark!=Vector3.INF:
				pre_jump_marks+=1
				if not check(before_mark.distance_to(game.player.position)<.40,"takeoff landing guide for "+game.art.stop_name(index)):return false
			game.web_command(["stick",0,0])
			print("landed ",index," ",game.art.stop_name(index))
			return true
	return check(false,"could not land on "+game.art.stop_name(index))

func surface_normal(point: Vector3) -> Vector3:
	var ray := PhysicsRayQueryParameters3D.create(point+Vector3.UP*.7,point+Vector3.DOWN)
	var hit := game.get_world_3d().direct_space_state.intersect_ray(ray)
	return hit.get("normal",Vector3.ZERO)

func check_rescue(seed_value: int, should_catch: bool) -> bool:
	# A deliberately short jump from the sofa to the coffee table.
	game.start_run()
	var player := game.player
	player.reset_at(Land.ROUTE[1])
	await frames(10)
	game.face_target()
	player.grab.rng.seed=seed_value
	var expected_rng := RandomNumberGenerator.new()
	expected_rng.seed=seed_value
	expected_rng.randf()
	game.web_command(["sprint",true])
	game.web_command(["stick",0,-1])
	await frames(6)
	game.web_command(["jump"])
	await frames(4)
	game.web_command(["stick",0,0])
	game.web_command(["sprint",false])
	var saw_hang := false
	var tested_pause := false
	var saw_climb := false
	for tick in 150:
		await frames(1)
		if player.grab.active:
			saw_hang=true
			if not check(should_catch and not game.landing_guide.visible,"guide hidden while hanging"):return false
			if player.grab.elapsed>.17 and not tested_pause:
				tested_pause=true
				var hips:=player.rig.get_bone_global_pose(player.rig.find_bone("Hips")).origin
				if not check(player.rig.to_global(hips).y-player.position.y>.35,"torso stays above the feet when switching to a grip"):return false
				for i in player.arms.size():
					var hand := player.rig.to_global(player.rig.get_bone_global_pose(player.arms[i][2]).origin)
					if not check(hand.distance_to(player.grab.hands[i])<.08,"both palms on lip"):return false
				var hang := player.position
				var time := player.grab.elapsed
				game.toggle_pause()
				await frames(12)
				if not check(is_equal_approx(time,player.grab.elapsed) and hang.is_equal_approx(player.position),"pause freezes the ledge grab"):return false
				game.toggle_pause()
				game.web_command(["jump"])
			if player.grab.climb_progress()>.2: saw_climb=true
		if not player.grab.active and player.is_on_floor() and tick>38:break
	if not check(player.grab.rng.state==expected_rng.state,"one chance per eligible jump"):return false
	if not check(saw_hang==should_catch and saw_climb==should_catch,"rescue outcome"):return false
	if should_catch:
		return check(tested_pause and game.ledge==2 and player.is_on_floor() and player.jump_count==1,"finish pull-up on the table without another jump")
	return check(game.ledge!=2,"missed grip keeps falling")

func check_blocked_grip() -> bool:
	game.start_run()
	var player := game.player
	var dock: Vector3 = Land.ROUTE[14]
	player.reset_at(dock+Vector3(0,-.65,1.62))
	var ceiling := StaticBody3D.new()
	game.add_child(ceiling)
	game.art.solid(ceiling,dock+Vector3(0,1.18,1.36),Vector3(1.4,.2,1.15),"909090")
	await frames(2)
	player.grab.available=true
	var state := player.grab.rng.state
	var grabbed := player.grab.try_catch(player,Vector2.UP,0,player.FOOT_RADIUS)
	ceiling.queue_free()
	return check(not grabbed and player.grab.available and player.grab.rng.state==state,"no roll under a blocked lip")

func check_standing_jump() -> bool:
	var player:=game.player
	var left:=player.rig.find_bone("Foot.L")
	var right:=player.rig.find_bone("Foot.R")
	game.web_command(["jump"])
	await frames(2)
	if not check(player.jump_count==1 and player.velocity.y>5.5,"immediate standing jump"):return false
	if not check(Vector2(player.velocity.x,player.velocity.z).length()<.01,"standing jump drift"):return false
	var peak:=player.position.y
	var max_gap:=0.
	var apex_gap:=0.
	var air_ticks:=2
	while not player.is_on_floor() and air_ticks<75:
		var sole:=player.rig.to_global(player.rig.get_bone_global_pose(left).origin)
		var other:=player.rig.to_global(player.rig.get_bone_global_pose(right).origin)
		var higher:=maxf(sole.y,other.y)-player.position.y
		var lower:=minf(sole.y,other.y)-player.position.y
		max_gap=maxf(max_gap,higher)
		if absf(player.velocity.y)<.3:apex_gap=lower
		if player.velocity.y < -5 and not check(lower>-.015 and higher<.04,"both feet extend before contact"):return false
		if air_ticks==15:
			game.toggle_pause()
			await frames(10)
			if not check(sole.distance_to(player.rig.to_global(player.rig.get_bone_global_pose(left).origin))<.001,"pause holds the airborne pose"):return false
			game.toggle_pause()
		await frames(1)
		air_ticks+=1
		peak=maxf(peak,player.position.y)
	print("standing jump: apex ",snappedf(peak,.001)," m, tucked foot ",snappedf(apex_gap,.001)," m, max foot gap ",snappedf(max_gap,.001)," m")
	if not check(peak>1.17 and peak<1.40 and air_ticks in range(45,54),"jump apex and duration"):return false
	return check(apex_gap>.025 and max_gap<.15,"knees tuck at the physical apex within the body's flight path")

func run() -> void:
	game = Game.new()
	root.add_child(game)
	game.best=100
	game.muted=true
	game.follow_camera=false
	game.show_landing_guide=true
	game.show_route_ring=false
	game.start_run()
	await frames(6)
	if not check(root.get_camera_3d()==game.camera,"active gameplay camera"):return
	if not check(not game.landing_ring.visible and not game.landing_guide.visible,"idle aids hidden"):return
	game.show_route_ring=true
	game.update_hud()
	if not check(game.landing_ring.visible,"optional next-object ring"):return
	game.show_route_ring=false
	if not await check_standing_jump():return
	game.web_command(["look",-PI/(2*3.55),0])
	game.web_command(["stick",0,-1])
	await frames(10)
	if not check(game.player.velocity.x < -3 and absf(game.player.velocity.z)<.1,"camera-relative forward"):return
	game.web_command(["stick",-1,0])
	await frames(14)
	if not check(game.player.velocity.z > 3,"touch direction reversal"):return
	game.web_command(["stick",0,0])
	await frames(3)
	if not check(game.player.velocity.length()<.1,"release stops grounded movement"):return
	game.start_run()
	await frames(6)
	game.web_command(["stick",1,0])
	await frames(10)
	var walk := game.player.velocity.x
	game.web_command(["sprint",true])
	await frames(9)
	if not check(game.player.velocity.x > walk*1.5,"sprint acceleration"):return
	game.web_command(["jump"])
	await frames(1)
	var takeoff := game.player.velocity.x
	game.web_command(["stick",0,0])
	game.web_command(["sprint",false])
	await frames(12)
	if not check(absf(game.player.velocity.x-takeoff)<.03,"coast without air braking"):return
	game.start_run()
	await frames(6)
	for index in range(1,Land.ROUTE.size()):
		if not await leap(index):return
	if not check(pre_jump_marks>=12,"takeoff guide coverage"):return
	if not check(game.phase=="won" and game.player.jump_count==24 and game.art.pickups.count==0,"summit"):return
	# Part of the flat sole extends past a 76 cm wide steel beam.
	game.start_run()
	game.player.reset_at(Land.ROUTE[16])
	await frames(6)
	game.stick=Vector2.DOWN
	for i in 90:
		await frames(1)
		if game.player.position.z > Land.ROUTE[16].z+.45:break
	if not check(game.player.position.z>Land.ROUTE[16].z+.38 and game.player.velocity.z<2,"braking at rim"):return
	game.stick=Vector2.ZERO
	var perched := game.player.position
	await frames(65)
	if not check(game.player.is_on_floor() and game.player.position.distance_to(perched)<.05,"one-foot ledge hold"):return
	# Walk off deliberately and tap just beyond the edge.
	game.stick=Vector2.DOWN
	for i in 45:
		await frames(1)
		if not game.player.is_on_floor():break
	if not check(not game.player.is_on_floor(),"can leave rim"):return
	game.web_command(["jump"])
	await frames(2)
	if not check(game.player.velocity.y>5.5,"late edge jump"):return
	game.start_run()
	await frames(6)
	if not await leap(1):return
	game.sprint=false
	game.stick=Vector2(-.3,1).normalized()
	for i in 160:
		await frames(1)
		if game.ledge==0 and game.player.is_on_floor():break
	if not check(game.ledge==0 and game.falls==1,"catch on lower roof"):return
	game.stick=Vector2.RIGHT
	for i in 260:
		await frames(1)
		if game.falls==2:break
	await frames(24)
	if not check(game.falls==2 and game.stick.is_zero_approx() and game.player.position.length()<.1,"respawn releases input"):return
	game.toggle_pause()
	var time := game.elapsed
	await frames(8)
	if not check(is_equal_approx(time,game.elapsed),"pause clock"):return
	# Steering stays world-stable while the automatic camera turns behind the player.
	game.follow_camera=true
	game.start_run()
	await frames(6)
	game.web_command(["stick",1,0])
	await frames(27)
	if not check(absf(game.camera_yaw+PI/2)<.12 and game.player.velocity.x>3 and absf(game.player.position.z)<.02,"follow behind sustained rightward movement"):return
	game.web_command(["jump"])
	await frames(2)
	var heading := game.camera_yaw
	game.web_command(["stick",0,-1])
	await frames(10)
	if not check(not game.player.is_on_floor() and is_equal_approx(game.camera_yaw,heading),"stable airborne framing"):return
	game.follow_camera=false
	game.start_run()
	await frames(6)
	game.web_command(["stick",1,0])
	await frames(12)
	if not check(is_zero_approx(game.camera_yaw),"disable automatic orbit"):return
	# Sample playable geometry on both sides of the mailing tube and across the reel.
	var left := surface_normal(Land.ROUTE[17]+Vector3.FORWARD*.7)
	var right := surface_normal(Land.ROUTE[17]+Vector3.BACK*.7)
	if not check(left.z<-.4 and right.z>.4 and minf(left.y,right.y)>.75,"two walkable parcel slopes"):return
	var radial := Vector3.BACK.rotated(Vector3.UP,deg_to_rad(70))
	var crown := surface_normal(Land.ROUTE[15])
	var shoulder := surface_normal(Land.ROUTE[15]+radial*.60)
	if not check(crown.y>.97 and shoulder.y>.68 and shoulder.dot(radial)>.4,"curved cable reel contact normals"):return
	if not await check_rescue(1,true):return
	if not await check_rescue(2,false):return
	if not await check_blocked_grip():return
	print("PASS landing guidance and ledge rescues")
	print("PASS mobile parkour: 24 landings, instant jump, sprint, orbit, edge hold, recovery")
	game.free()
	quit()
