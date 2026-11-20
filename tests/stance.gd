extends "res://tests/route.gd"

var soles := {}
const SIDES := ["L","R"]

# Sample the bottom vertices of the visible rigid shoes, independently of the
# stance targets. Their attachment nodes receive the final animated transforms.
func cache_soles() -> void:
	var p:=game.player
	for side in SIDES:
		var shoe: MeshInstance3D=p.costumes.parts["Foot_"+side]
		var rest:=p.rig.global_transform*p.rig.get_bone_global_rest(p.rig.find_bone("Foot."+side))*shoe.transform
		var vertices:=shoe.mesh.get_faces()
		var bottom:=INF
		for v in vertices: bottom=minf(bottom,(rest*v).y)
		var points:=PackedVector3Array()
		for v in vertices:
			if (rest*v).y<bottom+.004 and not points.has(v): points.append(v)
		soles[side]=points

func clearances(side: String) -> Array[float]:
	var shoe: MeshInstance3D=game.player.costumes.parts["Foot_"+side]
	var gaps: Array[float]=[]
	for v: Vector3 in soles[side]:
		var sole:=shoe.to_global(v)
		var hit:=game.player.ground_at(sole+Vector3.UP*.08,1.8)
		if not hit.is_empty(): gaps.append(sole.y-hit.position.y)
	return gaps

func ankle_connected(side: String) -> bool:
	var p:=game.player
	var shin:=p.rig.get_bone_global_pose(p.rig.find_bone("LowerLeg."+side))
	var ankle:=p.rig.get_bone_global_pose(p.rig.find_bone("Foot."+side))
	var visible_shin: Node3D=p.costumes.parts["LowerLeg_"+side].get_parent()
	var visible_ankle: Node3D=p.costumes.parts["Foot_"+side].get_parent()
	var end:=visible_shin.to_global(shin.affine_inverse()*ankle.origin)
	return end.distance_to(visible_ankle.global_position)<.005

func stand(id: int, offset: Vector3) -> void:
	game.start_run()
	game.player.reset_at(game.art.stop_position(id)+offset+Vector3.UP*.12)
	await frames(45)

func run() -> void:
	game=Game.new()
	root.add_child(game)
	game.best=100
	game.muted=true
	var p:=game.player
	cache_soles()
	var shoulder:=Vector3.BACK.rotated(Vector3.UP,deg_to_rad(70))*.56
	for character in p.costumes.NAMES:
		p.costumes.select(character)
		for sample in [[17,Vector3.BACK*.70],[15,shoulder]]:
			await stand(sample[0],sample[1])
			if not check(game.ledge==sample[0] and p.is_on_floor(),"stand on the selected incline"):return
			for side in SIDES:
				var gaps:=clearances(side)
				if not check(gaps.size()>=5 and gaps.min()>-.015 and gaps.max()<.015,"shoe follows the surface, heel to toe: "+character):return
				if not check(ankle_connected(side),"shin meets the rotated ankle"):return
	var physical:=p.position
	game.web_command(["jump"])
	await frames(2)
	if not check(not p.is_on_floor() and p.position.y>physical.y+.1 and p.stance.plant_weight<1. and ankle_connected("L") and ankle_connected("R"),"takeoff starts releasing the stance with both ankles attached"):return
	await frames(8)
	if not check(not p.stance.active and p.pose=="Airborne","flight uses the jump animation"):return
	for sample in [[16,Vector3.BACK*.49],[23,(Vector3.BACK*.49).rotated(Vector3.UP,deg_to_rad(-22))]]:
		await stand(sample[0],sample[1])
		var near:=0
		for side in SIDES:
			var shoe: MeshInstance3D=p.costumes.parts["Foot_"+side]
			for v: Vector3 in soles[side]:
				var point:=shoe.to_global(v)
				if not check(point.y>p.position.y-.035,"neither shoe reaches down the drop"):return
				var hit:=p.ground_at(point,.06)
				if hit.get("collider")==p.foot_shadow.receiver and absf(point.y-hit.position.y)<.018: near+=1
		if not check(near>=3 and p.is_on_floor(),"visible sole stays on the real lip"):return
	for running in [false,true]:
		await stand(17,Vector3(-1.15,.08,.55))
		game.web_command(["sprint",running])
		game.web_command(["stick",1,0])
		var stride:=false
		for i in 24:
			await frames(1)
			if not check(p.is_on_floor() and ankle_connected("L") and ankle_connected("R"),"moving ankles stay attached"):return
			var left:=clearances("L")
			var right:=clearances("R")
			if left.is_empty() or right.is_empty():continue
			stride=stride or (minf(left.min(),right.min())<.025 and maxf(left.max(),right.max())>.09)
		if not check(stride,"walking and running retain a raised shoe during the stride"):return
	print("PASS planted soles, connected ankles, one-foot edges, takeoff and moving strides")
	game.free()
	quit()
