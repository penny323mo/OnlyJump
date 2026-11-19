extends "res://tests/route.gd"
const B = Land.Branches

func moving_grip(stage: int, target: int, delay: int, runup: int) -> bool:
	game.start_run()
	var player:=game.player
	var body: StaticBody3D=game.art.branches.bodies[target]
	player.reset_at(Land.ROUTE[stage])
	player.grab.rng.seed=1
	await frames(6+delay)
	var gap:=game.art.stop_position(target)-player.position
	var direction:=Vector2(gap.x,gap.z).normalized()
	game.web_command(["sprint",true])
	game.web_command(["stick",direction.x,direction.y])
	await frames(runup)
	game.web_command(["jump"])
	await frames(4)
	game.web_command(["stick",0,0])
	game.web_command(["sprint",false])
	var left_hand:=Vector3.ZERO
	var right_hand:=Vector3.ZERO
	var lip_start:=Vector3.ZERO
	var travel:=0.
	var hung:=false
	var climbed:=false
	for tick in 140:
		await frames(1)
		if player.grab.active:
			if not check(player.grab.support_body==body,"caught the intended moving object"):return false
			if not hung:
				hung=true
				lip_start=player.grab.hands[0]
				left_hand=body.to_local(lip_start)
				right_hand=body.to_local(player.grab.hands[1])
			travel=maxf(travel,lip_start.distance_to(player.grab.hands[0]))
			if not check(body.to_global(left_hand).distance_to(player.grab.hands[0])<.002 and body.to_global(right_hand).distance_to(player.grab.hands[1])<.002,"both grips fixed to the moving rim"):return false
			var facing:=-player.model.basis.z
			if not check(Vector2(facing.x,facing.z).normalized().dot(Vector2(player.grab.forward.x,player.grab.forward.z).normalized())>.999,"torso faces the moving rim"):return false
			if player.grab.elapsed>.15 and player.grab.climb_progress()<.1:
				for i in player.arms.size():
					var palm:=player.rig.to_global(player.rig.get_bone_global_pose(player.arms[i][2]).origin)
					if not check(palm.distance_to(player.grab.hands[i])<.08,"palm reaches moving rim"):return false
			climbed=climbed or player.grab.climb_progress()>.6
		elif hung and player.is_on_floor():break
	if not check(climbed and game.ledge==target and player.is_on_floor() and player.jump_count==1,"pull up onto moving support"):return false
	var min_travel:=.35 if target==B.FAN else 3.
	return check(travel>min_travel,"ledge moved during the catch")

func jump_from_sheet(direction: float, seed_value: int, collapse: bool) -> bool:
	game.start_run()
	var player:=game.player
	player.reset_at(game.art.stop_position(B.SHEET)+Vector3.LEFT*1.12)
	player.grab.rng.seed=seed_value
	await frames(8)
	game.web_command(["stick",direction*.15,0])
	await frames(4)
	game.web_command(["stick",0,0])
	await frames(14)
	if not check(game.ledge==B.SHEET and player.is_on_floor(),"standing on lower sheet"):return false
	var expected_rng:=RandomNumberGenerator.new()
	expected_rng.seed=seed_value
	var should_catch:=direction>0 and expected_rng.randf()<player.grab.CHANCE
	if collapse:
		# An already-loaded board gives way before the pull-up completes.
		game.art.branches.land(B.BOARD)
	game.web_command(["jump"])
	var caught:=false
	var lost_support:=false
	for tick in 150:
		await frames(1)
		if tick==3 and not check(Vector2(player.velocity.x,player.velocity.z).length()<.001,"jump starts vertically"):return false
		if player.grab.active:
			if not check(player.grab.support_body==game.art.branches.bodies[B.BOARD],"hands caught the board"):return false
			caught=true
		elif caught and game.art.branches.bodies[B.BOARD].collision_layer==0:
			lost_support=true
		if tick>30 and player.is_on_floor() and not player.grab.active:break
	if not check(caught==should_catch and player.grab.rng.state==expected_rng.state,"one roll for a reachable rim ahead"):return false
	if not check(player.jump_count==1 and player.is_on_floor(),"resolved one standing jump"):return false
	if collapse and not check(lost_support,"release when the board drops"):return false
	var destination:=B.BOARD if should_catch and not collapse else B.SHEET
	return check(game.ledge==destination,"standing jump lands on the correct object")

func run() -> void:
	game=Game.new()
	root.add_child(game)
	game.muted=true
	game.best=100
	game.follow_camera=false
	game.player.costumes.select("dino")
	if not await jump_from_sheet(1,1,false):return
	if not await jump_from_sheet(-1,1,false):return
	if not await jump_from_sheet(1,2,false):return
	if not await jump_from_sheet(1,1,true):return
	if not await moving_grip(8,B.FAN,0,10):return
	if not await moving_grip(19,B.LIFT,30,6):return
	print("PASS standing and moving ledge grabs, failed rolls and collapsing support")
	game.free()
	quit()
