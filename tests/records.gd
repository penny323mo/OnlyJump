extends "res://tests/branches.gd"

var fixture := "user://onlyjump-record-test-%s-%s.cfg" % [OS.get_process_id(),Time.get_ticks_usec()]

func reopen() -> void:
	if is_instance_valid(game): game.free()
	game=Game.new()
	game.record_path=fixture
	root.add_child(game)

func check_split_times() -> bool:
	var times:=preload("res://game/summit_times.gd").new(24)
	times.land(B.TAPE,12.50,7,0)
	times.land(9,16.0,8,0)
	times.land(24,65.12,23,1)
	if not check(times.best_clock=="01:05.12" and times.finish_summary.begins_with("首次登頂"),"first time in centiseconds"):return false
	times.start_run()
	times.land(7,11.0,7,0)
	if not check(times.pace_at(7,11.0)=="" and times.finish_summary=="","main-route stereo has no split for the tape shortcut"):return false
	times.land(9,14.25,9,0)
	if not check(times.pace_at(9,14.25)=="比紀錄快 1.75 秒" and times.pace_at(9,17.25)=="","compare and expire pace at shared keyboard"):return false
	times.land(9,16.0,10,1)
	if not check(times.arrivals[9]==1425 and times.pace_at(9,16.0)=="","revisiting a stop keeps its first arrival and clears the split"):return false
	times.land(24,69.25,26,2)
	if not check(times.finish_summary.contains("慢咗 4.13 秒") and times.best.splits.has(B.TAPE),"slower route preserves best splits"):return false
	times.start_run()
	times.land(24,65.12,24,0)
	if not check(times.finish_summary.begins_with("追平紀錄") and times.best.jumps==23,"equal finish preserves original run"):return false
	times.start_run()
	times.land(7,10.50,7,0)
	times.land(24,60.00,24,0)
	return check(times.finish_summary.contains("快咗 5.12 秒") and times.best_clock=="01:00.00" and times.best.splits.has(7) and not times.best.splits.has(B.TAPE),"faster route replaces the whole comparison run")

func run() -> void:
	var legacy:=ConfigFile.new()
	legacy.set_value("run","best",Land.PREVIOUS_HEIGHTS[4])
	legacy.set_value("controls","character","dino")
	legacy.set_value("controls","follow_camera",true)
	legacy.set_value("run","muted",true)
	legacy.save(fixture)
	reopen()
	if not check(is_equal_approx(game.best,Land.ROUTE[4].y),"old course height keeps the equivalent landmark"):return
	if not check(game.summit_times.best.is_empty(),"a height-only save has no finish time"):return
	if not check(not game.oil_paint.visible,"legacy saves open in the normal style"):return
	legacy.set_value("run","fastest_ascent",{"splits":{24:"bad"},"jumps":24,"falls":1})
	legacy.set_value("run","best_ledge",7)
	legacy.save(fixture)
	reopen()
	if not check(is_equal_approx(game.best,Land.ROUTE[7].y),"landmark save takes precedence over old course height"):return
	if not check(game.summit_times.best.is_empty(),"malformed finish data leaves the height and settings usable"):return
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
	if not check(is_equal_approx(game.best,top) and game.player.costumes.key=="dino" and game.muted,"basket record and settings survive relaunch"):return
	await start_on(4)
	if not await leap(B.DRAWER,Vector3.ZERO,false):return
	await frames(145)
	if not check(game.ledge==B.AWNING and game.falls==1 and is_equal_approx(game.best,top),"low recovery keeps lifetime record"):return
	game.toggle_pause()
	game.web_command(["art_style","normal"])
	reopen()
	if not check(not game.oil_paint.visible and is_equal_approx(game.best,top),"restoring normal style keeps the height record"):return
	if not check_split_times():return
	await start_on(23)
	var before_pause:=game.elapsed
	game.toggle_pause()
	await frames(18)
	if not check(game.elapsed==before_pause,"pause excludes time from the finish"):return
	game.toggle_pause()
	if not await leap(24,Vector3.ZERO,false):return
	var finish:=game.summit_times.best.duplicate(true)
	if not check(finish.splits[24]==roundi(game.elapsed*100),"finish matches final physics tick"):return
	game.start_run()
	game.web_command(["mute"])
	game.show_intro()
	reopen()
	if not check(game.summit_times.best==finish and game.summit_times.arrivals.is_empty(),"relaunch and settings saves keep only the completed fastest run"):return
	print("PASS summit times, independent branch splits, ties, pause and relaunch")
	print("PASS standing height, moving basket, old saves and relaunch")
	game.free()
	DirAccess.remove_absolute(fixture)
	quit()
