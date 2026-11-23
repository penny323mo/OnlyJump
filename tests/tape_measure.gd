extends "res://tests/branches.gd"

func walk_to_hook() -> bool:
	var tape:=game.art.branches.tape
	game.web_command(["align"])
	game.web_command(["stick",0,-.86])
	for tick in 90:
		await frames(1)
		if tape.cycle>=0.:break
	game.web_command(["stick",0,0])
	return check(tape.cycle>=0. and tape.on_hook(game.player.position),"stepping onto the steel hook releases the tape")

func board() -> bool:
	await start_on(6)
	game.web_command(["branch"])
	if not check(game.art.destination(6,game.alternate)==B.TAPE,"cassette offers the tape measure"):return false
	await forward_jump(.76,11)
	if not await reach_floor(B.TAPE):return false
	await frames(24)
	if not check(game.art.branches.tape.cycle<0.,"standing on the case does not release the tape"):return false
	return await walk_to_hook()

func run() -> void:
	game=Game.new()
	root.add_child(game)
	game.best=100
	game.muted=true
	var tape:=game.art.branches.tape
	var player:=game.player
	for delay: float in [.86,1.06]:
		if not await board():return
		game.web_command(["align"])
		await frames(roundi((delay-tape.cycle)*60.))
		if not check(tape.rider_hint(player.position)=="紅段出緊，推前撳跳" and player.get_platform_velocity().length()>2.8,"the painted interval reaches the slot with launch momentum"):return
		var parked:=tape.blade.global_transform
		game.toggle_pause()
		await frames(30)
		if not check(tape.blade.global_transform.is_equal_approx(parked),"pause holds the exposed length and rider"):return
		game.toggle_pause()
		game.web_command(["stick",0,-1])
		game.web_command(["jump"])
		await frames(4)
		game.web_command(["stick",0,0])
		if not await reach_floor(9):return
		if not check(player.jump_count==2 and game.falls==0 and player.ability=="","ride and jump to the keyboard without a power-up"):return

	if not await board():return
	var origin:=player.position
	var foot:=tape.blade.to_local(origin)
	var extended_tip:=tape.guide.to_global(Vector3.FORWARD*(tape.FULL-.55))
	var reached_end:=false
	for tick in 310:
		await frames(1)
		if not check(player.is_on_floor() and foot.distance_to(tape.blade.to_local(player.position))<.05,"a stationary rider travels with the graduations in both directions"):return
		if tape.length_out==tape.FULL and not reached_end:
			reached_end=player.ground_at(extended_tip,.18).get("collider")==tape.blade
	if not check(reached_end and tape.length_out==tape.REST and not tape.armed and origin.distance_to(player.position)<.03,"a missed launch comes back and waits"):return
	if not check(player.ground_at(extended_tip,.18).get("collider")!=tape.blade,"the retracted length has no invisible foothold"):return
	game.web_command(["stick",0,.85])
	for tick in 60:
		await frames(1)
		if tape.to_local(player.position).z>-.52:break
	game.web_command(["stick",0,0])
	await frames(3)
	if not check(tape.armed and tape.cycle<0.,"stepping back onto the case rearms the hook"):return
	if not await walk_to_hook():return
	game.start_run()
	if not check(tape.armed and tape.cycle<0. and tape.length_out==tape.REST,"restart rewinds an active tape"):return

	if not await board():return
	game.web_command(["stick",.84,0])
	for tick in 40:
		await frames(1)
		if not player.is_on_floor():break
	game.web_command(["stick",0,0])
	if not await reach_floor(6):return
	if not check(game.falls==1 and player.jump_count==1,"an early sideways slip lands back on the cassette"):return
	print("PASS tape measure trigger, momentum shortcut, safe rewind, retry and lower catch")
	game.free()
	quit()
