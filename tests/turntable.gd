extends "res://tests/branches.gd"

func walk_on_and_off() -> bool:
	await start_on(0)
	var disc:=game.art.platter
	var player:=game.player
	var hub:=disc.global_position
	player.reset_at(hub+Vector3.RIGHT*1.75)
	await frames(10)
	var wood:=player.position
	await frames(30)
	if not check(game.ledge==8 and player.position.distance_to(wood)<.008,"wooden surround stands still"):return false
	game.web_command(["stick",-.70,0])
	for tick in 60:
		await frames(1)
		if not player.is_on_floor():return check(false,"walk onto the record without a jump")
		if player.position.distance_to(hub)<.92:break
	game.web_command(["stick",0,0])
	await frames(5)
	if not check(player.standing_platform==disc,"stationary thumb releases onto the rotating grooves"):return false
	var start:=player.position
	var foot:=disc.to_local(start)
	var yaw:=game.camera_yaw
	await frames(68)
	if not check(player.position.distance_to(start)>1. and disc.to_local(player.position).distance_to(foot)<.015,"vinyl carries the planted feet around the spindle"):return false
	if not check(is_equal_approx(game.camera_yaw,yaw),"riding the vinyl preserves manual camera heading"):return false
	game.toggle_pause()
	var stopped:=disc.global_transform
	start=player.position
	await frames(32)
	if not check(stopped.is_equal_approx(disc.global_transform) and start.is_equal_approx(player.position),"pause holds the record and rider together"):return false
	game.toggle_pause()
	for tick in 300:
		if (player.position-hub).normalized().dot(Vector3.RIGHT)>.985:break
		await frames(1)
	game.web_command(["stick",.72,0])
	for tick in 80:
		await frames(1)
		if not player.is_on_floor():return check(false,"walk down the bevel without falling")
		if player.position.x-hub.x>1.68:break
	game.web_command(["stick",0,0])
	await frames(4)
	wood=player.position
	await frames(48)
	return check(player.standing_platform==null and player.position.distance_to(wood)<.008 and game.ledge==8 and game.falls==0 and player.jump_count==0,"step back onto the cabinet and stop")

func takeoff(offset: Vector3) -> bool:
	await start_on(0)
	var disc:=game.art.platter
	var p:=game.player
	p.reset_at(disc.global_position+offset+Vector3.UP*disc.TOP)
	await frames(6)
	game.web_command(["align"])
	game.web_command(["sprint",true])
	game.web_command(["stick",0,-.90])
	await frames(11)
	var before:=p.velocity
	var radial:=p.position-disc.global_position
	var tangent:=Vector3.DOWN.cross(radial)*disc.SPEED
	game.landing_guide.refresh(p,game.world_move(),1./60.)
	if not check(game.landing_guide.visible and tangent.length()>.65,"running from the grooves shows a landing on the keyboard"):return false
	var mark:=game.landing_guide.position
	game.web_command(["jump"])
	await frames(1)
	var inherited:=Vector2(p.velocity.x-before.x,p.velocity.z-before.z)
	if not check(inherited.distance_to(Vector2(tangent.x,tangent.z))<.04,"jump inherits the tangent under the runner once"):return false
	if not await reach_floor(9):return false
	return check(mark.distance_to(p.position)<.10 and game.falls==0,"forecast matches the first key reached")

func run() -> void:
	game=Game.new()
	game.record_path=course_test_save
	root.add_child(game)
	game.muted=true
	if not await walk_on_and_off():return
	for offset: Vector3 in [Vector3(.50,0,-.85),Vector3(.50,0,.65)]:
		if not await takeoff(offset):return
	await start_on(7)
	if not await leap(8):return
	if not check(game.player.ground_at(game.player.position,.16).get("collider")==game.art.platter,"incoming jump lands on the visible record"):return
	game.start_run()
	if not check(is_zero_approx(game.art.platter.rotation.y),"restart resets the record"):return
	print("PASS turntable walk-on, rotating ride, wooden surround, tangent jumps and landing marks")
	game.free()
	DirAccess.remove_absolute(course_test_save)
	quit()
