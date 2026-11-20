extends "res://tests/branches.gd"

var fixture := "user://onlyjump-record-test-%s-%s.cfg" % [OS.get_process_id(),Time.get_ticks_usec()]

func reopen() -> void:
	if is_instance_valid(game): game.free()
	game=Game.new()
	game.record_path=fixture
	root.add_child(game)

func run() -> void:
	var legacy:=ConfigFile.new()
	legacy.set_value("run","best",Land.PREVIOUS_HEIGHTS[4])
	legacy.set_value("controls","character","dino")
	legacy.set_value("controls","follow_camera",false)
	legacy.set_value("run","muted",true)
	legacy.save(fixture)
	reopen()
	if not check(is_equal_approx(game.best,Land.ROUTE[4].y),"old course height keeps the equivalent landmark"):return
	if not check(not game.oil_paint.visible,"legacy saves open in the normal style"):return
	legacy.set_value("run","best_ledge",7)
	legacy.save(fixture)
	reopen()
	if not check(is_equal_approx(game.best,Land.ROUTE[7].y),"landmark save takes precedence over old course height"):return
	game.start_run()
	game.toggle_pause()
	game.web_command(["art_style","oil"])
	if not check(game.oil_paint.visible and game.phase=="paused","oil paint applies in place"):return
	game.web_command(["art_style","unknown"])
	if not check(game.oil_paint.visible,"ignore an unknown style"):return
	await start_on(19)
	if not await leap(B.LIFT,Vector3.ZERO,false):return
	var boarding:=game.best
	if not check(is_equal_approx(boarding,snappedf(game.player.position.y,.1)),"boarding height matches the basket floor"):return
	while game.art.branches.clock<4.1: await frames(1)
	var top:=game.best
	if not check(is_equal_approx(top,18.2) and top>boarding+1 and game.player.is_on_floor(),"basket ride raises the standing record"):return
	game.web_command(["jump"])
	await frames(18)
	if not check(game.player.position.y>top+.9 and not game.player.is_on_floor() and is_equal_approx(game.best,top),"airborne peak does not raise standing record"):return
	reopen()
	if not check(game.oil_paint.visible,"oil paint survives relaunch"):return
	if not check(is_equal_approx(game.best,top) and game.player.costumes.key=="dino" and not game.follow_camera and game.muted,"basket record and settings survive relaunch"):return
	await start_on(4)
	if not await leap(B.DRAWER,Vector3.ZERO,false):return
	await frames(145)
	if not check(game.ledge==B.AWNING and game.falls==1 and is_equal_approx(game.best,top),"low recovery keeps lifetime record"):return
	game.toggle_pause()
	game.web_command(["art_style","normal"])
	reopen()
	if not check(not game.oil_paint.visible and is_equal_approx(game.best,top),"restoring normal style keeps the height record"):return
	print("PASS standing height, moving basket, old saves and relaunch")
	game.free()
	DirAccess.remove_absolute(fixture)
	quit()
