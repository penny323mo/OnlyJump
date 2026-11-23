extends "res://tests/branches.gd"

func run() -> void:
	game=Game.new()
	game.record_path=course_test_save
	root.add_child(game)
	game.best=100
	game.muted=true
	game.touch_web=true
	game.start_run()
	await frames(6)
	var player:=game.player
	player.equip("double")
	game.web_command(["sprint",true])
	game.web_command(["stick",0.,-.5])
	game.web_command(["jump"])
	await frames(12)
	game.web_command(["hide"])
	var foot:=player.position
	var momentum:=player.velocity
	var elapsed:=game.elapsed
	var power:=player.ability_time
	var camera:=game.camera.global_transform
	var lift:=game.art.branches.lift
	var clock:=game.art.branches.clock
	if not check(game.phase=="interrupted" and not game.sprint and game.stick==Vector2.ZERO and not player.is_on_floor(),"interrupt airborne sprint and release both thumbs"):return
	game.web_command(["stick",0.,0.])
	game.web_command(["sprint",true])
	game.web_command(["look",.13,0.])
	game.web_command(["zoom",1.4])
	await frames(40)
	if not check(game.phase=="interrupted" and player.position==foot and player.velocity==momentum and game.elapsed==elapsed and player.ability_time==power and game.art.branches.clock==clock,"preparing the next input freezes motion, route clock and power time"):return
	if not check(not camera.is_equal_approx(game.camera.global_transform) and game.camera_distance<game.DEFAULT_CAMERA_REACH-.5,"the frozen view allows manual orbit and zoom"):return
	game.web_command(["hide"])
	if not check(not game.sprint and game.phase=="interrupted","second interruption releases a newly armed sprint"):return
	game.web_command(["jump"])
	await frames(2)
	if not check(game.phase=="playing" and player.jump_count==2 and player.double_charges==player.MAX_DOUBLE_CHARGES-1,"jump resumes with exactly one midair charge"):return
	await start_on(B.LIFT)
	await frames(145)
	var deck:=lift.position
	if not check(player.is_on_floor() and player.get_platform_velocity().length()>1.,"ride a moving basket before interruption"):return
	game.web_command(["hide"])
	await frames(60)
	if not check(lift.position==deck and game.phase=="interrupted","basket stays at the same point in its trip"):return
	game.web_command(["sprint",true])
	game.web_command(["stick",.5,0.])
	if not check(game.phase=="playing" and game.stick==Vector2(.5,0) and game.sprint,"the first steering sample resumes with the prepared sprint"):return
	await frames(2)
	if not check(lift.position!=deck and game.falls==0,"carrier continues without a fall"):return
	game.web_command(["hide"])
	game.web_command(["pause"])
	game.web_command(["hide"])
	game.web_command(["jump"])
	if not check(game.phase=="paused" and game.stick==Vector2.ZERO and not game.sprint,"opening settings and hiding again keeps an explicit pause"):return
	game.web_command(["pause"])
	game.touch_web=false
	game.web_command(["hide"])
	if not check(game.phase=="paused","desktop focus loss opens the existing pause menu"):return
	print("PASS mobile interruption holds airborne and moving-platform state until deliberate input")
	game.free()
	quit()
