extends "res://tests/branches.gd"

func visible_climber() -> bool:
	var size:=game.get_viewport().get_visible_rect().size
	var space:=game.get_world_3d().direct_space_state
	for height: float in [.06,.12,.65,1.12,game.player.BODY_HEIGHT+.10]:
		var target:=game.player.position+Vector3.UP*height
		var pixel:=game.camera.unproject_position(target)/size
		if not game.camera.is_position_in_frustum(target) or pixel.y<.03 or pixel.y>.97:return false
		var ray:=PhysicsRayQueryParameters3D.create(game.camera.position,target)
		ray.exclude=[game.player.get_rid()]
		if not space.intersect_ray(ray).is_empty():return false
	return true

func check_orbit(id: int) -> bool:
	await start_on(id)
	game.camera_pitch=deg_to_rad(10)
	game.game_camera(1.,true)
	for tick in 240:
		game.web_command(["look",-TAU/(3.55*240),0])
		await frames(1)
		var offset:=game.camera.position-game.player.position
		var facing:=Vector2(offset.x,offset.z).normalized()
		var requested:=Vector2(sin(game.camera_yaw),cos(game.camera_yaw))
		if not check(facing.dot(requested)>.999 and visible_climber(),"clear view while turning on "+game.art.stop_name(id)):return false
	return true

func check_zoom() -> bool:
	await start_on(0)
	var heading:=game.camera.global_basis
	var initial:=game.camera_distance
	game.web_command(["zoom",1.5])
	await frames(3)
	if not check(is_equal_approx(game.camera_distance,initial/1.5) and visible_climber(),"spreading fingers brings the camera closer"):return false
	game.web_command(["zoom",100])
	await frames(2)
	if not check(is_equal_approx(game.camera_distance,Game.CLOSEST_ZOOM) and visible_climber(),"close zoom keeps the whole character in frame"):return false
	var wall:=StaticBody3D.new()
	var blocker:=CollisionShape3D.new()
	var shape:=BoxShape3D.new()
	shape.size=Vector3(4,5,.5)
	blocker.shape=shape
	wall.add_child(blocker)
	game.add_child(wall)
	var pivot:=game.player.position+Vector3.UP*1.08
	wall.position=pivot+(game.camera.position-pivot).normalized()*7.5
	await frames(2)
	game.web_command(["zoom",.01])
	await frames(75)
	if not check(game.camera_distance>Game.CLOSEST_ZOOM and game.camera_distance<7.5 and visible_climber(),"zoom-out respects the wall behind the player"):return false
	wall.free()
	await frames(90)
	if not check(absf(game.camera_distance-Game.FARTHEST_ZOOM)<.01 and game.camera.global_basis.is_equal_approx(heading),"clearing the wall restores the chosen distance and heading"):return false
	game.toggle_pause()
	game.web_command(["zoom",2])
	game.toggle_pause()
	if not check(is_equal_approx(game.camera_reach,Game.FARTHEST_ZOOM),"paused touches preserve zoom"):return false
	return true

func run() -> void:
	game=Game.new()
	root.add_child(game)
	game.best=100
	game.muted=true
	var samples:=0
	var failures:=0
	for id: int in range(Land.ROUTE.size())+B.STOPS.keys():
		await start_on(id)
		if not check(game.player.is_on_floor(),"camera fixture has support"):return
		for pitch: float in [9.,10.,24.,48.,72.]:
			for heading in 24:
				game.camera_pitch=deg_to_rad(pitch)
				game.camera_yaw=TAU*heading/24
				game.game_camera(1.,true)
				samples+=1
				if not visible_climber():
					failures+=1
					if failures<=5: print("blocked at ",game.art.stop_name(id)," pitch ",pitch," heading ",heading*15)
	if not check(failures==0,"%d of %d camera views crop or hide the climber" % [failures,samples]):return
	print("PASS camera orbit keeps head, body and feet visible in ",samples," views")
	for id: int in [1,7,10,13,B.AWNING,B.FAN,B.SHEET,B.COIL,B.LEVEL]:
		if not await check_orbit(id):return
	game.orbit(.25,1.)
	await frames(2)
	if not check(is_equal_approx(rad_to_deg(game.camera_pitch),72.),"manual tilt remains available after obstacle avoidance"):return
	game.start_run()
	await frames(5)
	if not check(is_zero_approx(game.camera_pitch_offset) and is_equal_approx(game.camera.fov,59.),"open rooftop restores normal camera"):return
	print("PASS continuous orbit keeps manual heading and a clear view on nine objects")
	if not await check_zoom():return
	print("PASS pinch zoom changes camera distance, respects obstacles and preserves heading")
	game.free()
	quit()
