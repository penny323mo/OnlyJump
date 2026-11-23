extends "res://tests/branches.gd"

func check_recovery() -> bool:
	await start_on(21)
	if not await leap(B.BOARD,Vector3.ZERO,false):return false
	await frames(135)
	if not check(game.ledge==B.SHEET and game.player.is_on_floor(),"sheet catches the collapsing board"):return false
	if not await approach_pickup("glide"):return false
	var p:=game.player
	game.web_command(["stick",0,-.48])
	for tick in 160:
		await frames(1)
		if not p.is_on_floor():break
	if not check(not p.is_on_floor() and p.ability=="glide","walk off the sheet wearing the sock"):return false
	game.web_command(["stick",0,0])
	var first:=Vector3.INF
	var expired_mark:=Vector3.INF
	for tick in 450:
		await frames(1)
		if p.is_on_floor():break
		if game.landing_guide.visible:
			if p.ability_time>3. and first==Vector3.INF:
				first=game.landing_guide.global_position
				game.toggle_pause()
				game.web_command(["landing_guide",false])
				game.toggle_pause()
				await frames(12)
				if not check(not game.landing_guide.visible,"disabled guide stays hidden during a glide"):return false
				game.toggle_pause()
				game.web_command(["landing_guide",true])
				game.toggle_pause()
				await frames(12)
				if not check(game.landing_guide.visible,"re-enabled guide reacquires the landing"):return false
			if p.ability=="" and expired_mark==Vector3.INF: expired_mark=game.landing_guide.global_position
	if not check(game.ledge==6 and p.is_on_floor(),"land on the cassette below the laundry"):return false
	if not check(first!=Vector3.INF,"show the recovery landing with at least three seconds of glide left"):return false
	print("cassette landing errors in metres, during glide / after expiry: ",first.distance_to(p.position)," / ",expired_mark.distance_to(p.position))
	return check(first.distance_to(p.position)<.36 and expired_mark.distance_to(p.position)<.36,"both predictions match the actual landing")

func check_steering() -> bool:
	await start_on(0)
	var player:=game.player
	player.equip("glide")
	game.web_command(["stick",.6,0])
	game.web_command(["jump"])
	await frames(20)
	var before:=game.landing_guide.global_position
	if not check(game.landing_guide.visible,"mark during ascent"):return false
	game.web_command(["stick",0,1])
	await frames(14)
	game.web_command(["stick",0,0])
	await frames(6)
	var released:=game.landing_guide.global_position
	if not check(game.landing_guide.visible and released.distance_to(before)>.25,"mark follows the change in direction"):return false
	for tick in 120:
		await frames(1)
		if player.is_on_floor():break
	return check(player.is_on_floor() and player.ability=="glide" and released.distance_to(player.position)<.20,"released trajectory lands while the sock is still active")

func run() -> void:
	game=Game.new()
	var fixture:="user://glide-guide-%s-%s.cfg" % [OS.get_process_id(),Time.get_ticks_usec()]
	game.record_path=fixture
	root.add_child(game)
	game.best=100
	game.muted=true
	if not await check_recovery():return
	if not await check_steering():return
	# A collapsing board can move before touchdown.
	game.start_run()
	game.player.reset_at(game.art.stop_position(B.BOARD)+Vector3.UP)
	game.player.equip("glide")
	await frames(10)
	if not check(not game.player.is_on_floor() and not game.landing_guide.visible,"no promised foothold on the collapsing board"):return
	for tick in 90:
		await frames(1)
		if game.player.is_on_floor():break
	if not check(game.player.is_on_floor() and game.ledge==B.BOARD,"test fall actually meets the board"):return
	print("PASS glide landing guide, midair expiry, steering, settings and unstable footing")
	game.free()
	DirAccess.remove_absolute(fixture)
	quit()
