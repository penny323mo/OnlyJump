extends "res://tests/route.gd"

# Project the built meshes so rotations, feet, handles and speaker cones all
# count towards the daylight between jump targets. Recovery props can sit below.
func check_opening_spacing() -> bool:
	var pairs: Array[Vector2i]=[]
	for stage in range(8):
		pairs.append(Vector2i(stage,stage+1))
	pairs.append_array([Vector2i(1,1),Vector2i(0,Land.Branches.BED),Vector2i(4,Land.Branches.DRAWER),
		Vector2i(5,Land.Branches.DRAWER),Vector2i(6,Land.Branches.TAPE)])
	var hulls: Dictionary={}
	for body in game.art.get_children():
		if not body.has_meta("ledge"):continue
		var id:=int(body.get_meta("ledge"))
		if id>8 and id not in [Land.Branches.BED,Land.Branches.DRAWER,Land.Branches.TAPE]:continue
		var footprint:=PackedVector2Array()
		for mesh: MeshInstance3D in body.find_children("*","MeshInstance3D",true,false):
			for surface in mesh.mesh.get_surface_count():
				var vertices: PackedVector3Array=mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
				for local in vertices:
					var point:=mesh.to_global(local)
					footprint.append(Vector2(point.x,point.z))
		if not hulls.has(id):hulls[id]=[]
		hulls[id].append(Geometry2D.convex_hull(footprint))
	for pair in pairs:
		for i in hulls[pair.x].size():
			var margin:=Geometry2D.offset_polygon(hulls[pair.x][i],.25)
			for j in hulls[pair.y].size():
				if pair.x==pair.y and i>=j:continue
				if not check(margin.size()==1 and Geometry2D.intersect_polygons(margin[0],hulls[pair.y][j]).is_empty(),
					"25 cm of open space between %s and %s" % [game.art.stop_name(pair.x),game.art.stop_name(pair.y)]):return false
	return true

func ordinary_jump(target: int, runup: int, angle: float, strength := 1.) -> bool:
	var player:=game.player
	var gap:=game.art.stop_position(target)-player.position
	var direction:=Vector2(gap.x,gap.z).normalized().rotated(game.camera_yaw+deg_to_rad(angle))
	game.web_command(["stick",direction.x*strength,direction.y*strength])
	await frames(runup)
	game.web_command(["jump"])
	var airborne:=false
	for tick in 90:
		await frames(1)
		if player.grab.active or game.falls>0:break
		if not player.is_on_floor():airborne=true
		elif airborne:break
	game.web_command(["stick",0,0])
	await frames(6)
	return check(airborne and player.is_on_floor() and game.ledge==target and game.falls==0,
		"ordinary jump to %s after %d ticks, %s degrees at %s stick" % [game.art.stop_name(target),runup,angle,strength])

func walk_to_suitcase_centre() -> void:
	var player:=game.player
	var centre:=game.art.stop_position(4)
	for tick in 35:
		var gap:=Vector2(centre.x-player.position.x,centre.z-player.position.z)
		if gap.length()<.20:break
		var steer:=gap.limit_length(.65).rotated(game.camera_yaw)
		game.web_command(["stick",steer.x,steer.y])
		await frames(1)
	game.web_command(["stick",0,0])
	await frames(6)

func run() -> void:
	game=Game.new()
	game.record_path=course_test_save
	root.add_child(game)
	game.muted=true
	game.best=100
	if not check_opening_spacing():return
	for strength: float in [.8,1.]:
		for angle: float in [-12.,0.,12.]:
			game.start_run()
			await frames(12)
			if not await ordinary_jump(1,4,angle,strength):return
	for target in range(1,10):
		for runup: int in [9,13,17]:
			for angle: float in [-12.,0.,12.]:
				game.start_run()
				game.player.reset_at(game.art.stop_position(target-1)+Vector3.UP*.12)
				await frames(22)
				if not await ordinary_jump(target,runup,angle):return

	# Keep all six runs continuous. Walk across the case from the actual landing
	# before aiming for the sole, which is narrower at the toe.
	for strength: float in [.90,1.]:
		for angle: float in [-8.,0.,8.]:
			game.start_run()
			await frames(12)
			for target in range(1,7):
				if target==5:await walk_to_suitcase_centre()
				if not await ordinary_jump(target,15,angle if target%2 else -angle,strength):return

	game.start_run()
	await frames(12)
	for target in range(1,11):
		if not await ordinary_jump(target,18,0.):return
	if not check(game.player.jump_count==10 and game.art.pickups.count==0,"ten ordinary jumps from the roof without a pickup"):return
	print("PASS nine forgiving walk jumps and a continuous ordinary climb to the camera")
	game.free()
	DirAccess.remove_absolute(course_test_save)
	quit()
