extends "res://tests/branches.gd"

func arrow_visible() -> bool:
	var guide:=game.landing_guide
	return guide.visible and guide.ink.get_shader_parameter("edge_landing")

func drop_at(id: int, offset: Vector3) -> void:
	await start_on(0)
	game.player.reset_at(game.art.stop_position(id)+offset+Vector3.UP*.95)
	await frames(8)
	game.landing_guide.refresh(game.player,Vector2.ZERO,1./60.)

func girder(offset: Vector3, hits: bool) -> bool:
	await drop_at(16,offset)
	var guide:=game.landing_guide
	if not hits:
		if not check(not guide.visible,"no target beyond the corner"):return false
		await frames(42)
		return check(not game.player.is_on_floor() and game.player.position.y<Land.ROUTE[16].y-.5,"runner falls past the unsupported corner")
	var rim:=Vector3(clampf(offset.x,-2.275,2.275),.028,clampf(offset.z,-.38,.38))
	var actual:=guide.position-Land.ROUTE[16]
	if not check(guide.visible and actual.distance_to(rim)<.008,"mark at the nearest girder lip directly under the sole"):return false
	var inward:=Vector3(rim.x-offset.x,0.,rim.z-offset.z).normalized()
	if not check(arrow_visible()==(not inward.is_zero_approx()),"cross on the deck and arrow only for an overhang"):return false
	if arrow_visible() and not check((-guide.basis.z).dot(inward)>.996,"arrow points back onto the girder, including at corners"):return false
	return await reach_floor(16)

func lower_rung() -> bool:
	# The sole just misses the gold top step and overlaps a lower silver rung.
	var offset:=Vector3.BACK.rotated(Vector3.UP,deg_to_rad(-22.))*.68
	await drop_at(23,offset)
	var p:=game.player
	var guide:=game.landing_guide
	if not check(arrow_visible(),"lower ladder rung is a partial landing"):return false
	var mark:=guide.position-guide.basis.y*.028
	var across:=(Land.ROUTE[23]+offset-mark).rotated(Vector3.UP,deg_to_rad(30.))
	if not check(absf(across.x)<.006 and across.z>.24 and across.z<p.FOOT_RADIUS+.003,"lower rung contact stays inside the sole instead of jumping to the end of the rung"):return false
	if not await reach_floor(23):return false
	return check(absf(mark.y-p.position.y)<.006 and mark.y<Land.ROUTE[23].y-.45,"predicted rung height matches the observed foothold")

func parcel_side(index: int) -> bool:
	game.start_run()
	var p:=game.player
	var direction:=Vector3.BACK.rotated(Vector3.UP,TAU*(index+.35)/12.)
	p.reset_at(Land.ROUTE[17]+direction*1.47+Vector3.UP*.70)
	await frames(5)
	var guide:=game.landing_guide
	guide.refresh(p,Vector2.ZERO,1./60.)
	for tick in 40:
		if not check(not guide.visible or guide.position.y<Land.ROUTE[17].y-1.1,"side impact does not promise a landing on the parcel"):return false
		await frames(1)
	return check(not p.is_on_floor() and p.position.y<Land.ROUTE[17].y-1.2,"runner actually falls past the bevel")

func mesh_jump(steps: int, edge: bool) -> bool:
	await start_on(0)
	game.face_target()
	await forward_jump(.89,steps)
	var guide:=game.landing_guide
	var p:=game.player
	var first:=Vector3.INF
	var seen:=0
	for tick in 65:
		await frames(1)
		if p.is_on_floor():break
		if not guide.visible:continue
		if not check(arrow_visible()==edge,"running jump distinguishes the curved sofa lip from its seat"):return false
		if first==Vector3.INF:first=guide.position-guide.basis.y*.028
		if edge and not check((-guide.basis.z).x>.5,"sofa arrow points up the cushion"):return false
		seen+=1
	return check(seen>=20 and p.is_on_floor() and game.ledge==1 and first.distance_to(p.position)<p.FOOT_RADIUS+.04,"rendered mesh target remains on the actual sofa landing")

func moving_rim(phase: float, offset: Vector3, step: bool) -> bool:
	await start_on(0)
	var lift:=game.art.branches.lift
	var guide:=game.landing_guide
	var p:=game.player
	await frames(roundi((phase-lift.phase)*60.))
	p.reset_at(lift.position_at(lift.phase+.345)+offset+Vector3.UP*.95)
	var body:=lift.plate if step else lift
	var initial:=body.global_position
	var seen:=0
	for tick in 65:
		await frames(1)
		if p.is_on_floor():break
		if not guide.visible or guide.moving_support!=body:continue
		var rim:=body.to_local(guide.position)
		var inward:=body.global_basis.inverse()*(-guide.basis.z)
		if not check(arrow_visible() and absf(rim.y-.028)<.004,"partial moving landing stays on the surface"):return false
		if step:
			if not check(absf(rim.z+lift.PLATE_LENGTH)<.005 and inward.z>.995,"open step arrow points towards the hinge"):return false
		elif not check(absf(rim.x-lift.DECK_SIZE.x/2.)<.005 and inward.x<-.995,"moving deck arrow stays at its outer edge"):return false
		seen+=1
	return check(seen>=12 and game.ledge==B.LIFT and p.is_on_floor() and (step or body.global_position.distance_to(initial)>.50),"runner meets the marked moving rim")

func run() -> void:
	game=Game.new()
	game.record_path=course_test_save
	root.add_child(game)
	game.muted=true
	game.best=100
	for offset:Vector3 in [Vector3.ZERO,Vector3.BACK*.60,Vector3.FORWARD*.49,Vector3(2.41,0,.53)]:
		if not await girder(offset,true):return
	if not await girder(Vector3(2.53,0,.62),false):return
	if not await lower_rung():return
	for side in [5,11]:
		if not await parcel_side(side):return
	if not await mesh_jump(13,true):return
	if not await mesh_jump(16,false):return
	if not await moving_rim(2.,Vector3(1.06,0,0),false):return
	if not await moving_rim(.35,Vector3(-.68,0,-1.8),true):return
	print("PASS landing arrows on real box and mesh rims, lower rungs, moving decks and folding steps")
	game.free()
	DirAccess.remove_absolute(course_test_save)
	quit()
