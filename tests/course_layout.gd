extends "res://tests/route.gd"

# Check visible geometry. A floor collider alone misses basket cables, handles
# and clothes, while a shared top-down footprint is often an intentional catch.
class Part:
	var node: Node3D
	var owner: String
	var faces := PackedVector3Array()
	var tree := TriangleMesh.new()
	var bounds: AABB

	func finish() -> void:
		tree.create_from_faces(faces)
		bounds=AABB(faces[0],Vector3.ZERO)
		for point in faces:bounds=bounds.expand(point)

	func edges_cross(other: Part) -> bool:
		var relative:=other.node.global_transform.affine_inverse()*node.global_transform
		var points:=relative*faces
		for i in range(0,points.size(),3):
			var a:=points[i]
			var b:=points[i+1]
			var c:=points[i+2]
			if not AABB(a,Vector3.ZERO).expand(b).expand(c).grow(.0001).intersects(other.bounds):continue
			for edge in [[a,b],[b,c],[c,a]]:
				if not other.tree.intersect_segment(edge[0],edge[1]).is_empty():return true
		return false

var parts: Dictionary[Node,Part]={}

func register(node: Node3D, owner: String) -> void:
	var part:=Part.new()
	part.node=node
	part.owner=owner
	parts[node]=part

func collect(node: Node, parent: Part) -> void:
	var part: Part=parts.get(node,parent)
	if part and node is MeshInstance3D:
		var mesh:=node as MeshInstance3D
		if mesh.mesh:
			var relative:=part.node.global_transform.affine_inverse()*mesh.global_transform
			part.faces.append_array(relative*mesh.mesh.get_faces())
	for child in node.get_children():collect(child,part)

func clear_pair(a: Part,b: Part) -> bool:
	if not a.node.is_visible_in_tree() or not b.node.is_visible_in_tree():return true
	var box_a:=a.node.global_transform*a.bounds
	var box_b:=b.node.global_transform*b.bounds
	if not box_a.intersects(box_b):return true
	return check(not a.edges_cross(b) and not b.edges_cross(a),"%s clips %s" % [a.owner,b.owner])

func run() -> void:
	game=Game.new()
	root.add_child(game)
	var art:=game.art
	var branches:=art.branches
	for node in art.get_children():
		if node.has_meta("ledge"):register(node,art.stop_name(node.get_meta("ledge")))
	var lift:=branches.lift
	register(lift.plate,art.stop_name(Land.Branches.LIFT))
	register(branches.tape.blade,art.stop_name(Land.Branches.TAPE))
	register(branches.tape.strip,art.stop_name(Land.Branches.TAPE))
	register(art.platter,art.stop_name(8))
	for key in art.pickups.items:register(art.pickups.items[key],key)
	collect(art,null)
	var all:=parts.values()
	for part in all:part.finish()
	for i in all.size():
		for j in range(i):
			if all[i].owner!=all[j].owner and not clear_pair(all[i],all[j]):return

	# Loaded boards and a lift run on independent clocks. Sweep both lift
	# directions at physics ticks, with the board resting and fully strained.
	var board:=branches.bodies[Land.Branches.BOARD] as Land.Branches.CollapsingProp
	for strain: float in [0.,1.]:
		board.transform=board.strain(strain)
		for tick in range(roundi(lift.PERIOD*60.)+1):
			lift.advance(tick/60.)
			for cabin: Node3D in [lift,lift.plate]:
				for other in all:
					if other.owner!=parts[lift].owner and not clear_pair(parts[cabin],other):return

	# Each trap falls past a different set of lower objects.
	for id: int in branches.DROP_AFTER:
		var trap:=branches.bodies[id] as Land.Branches.CollapsingProp
		trap.reset()
		for tick in range(67):
			trap.advance(branches.DROP_AFTER[id]+tick/60.,branches.DROP_AFTER[id])
			for other in all:
				if other.owner!=parts[trap].owner and not clear_pair(parts[trap],other):return
		trap.reset()
	# The board can release at any point in the basket's trip. Compare its
	# falling poses to the basket near the far stop as well as its folded step.
	board.reset()
	for tick in range(0,66):
		board.advance(branches.DROP_AFTER[Land.Branches.BOARD]+tick/60.,branches.DROP_AFTER[Land.Branches.BOARD])
		if not board.visible:break
		for dock_tick in range(180,241,2):
			lift.advance(dock_tick/60.)
			if not clear_pair(parts[board],parts[lift]) or not clear_pair(parts[board],parts[lift.plate]):return
	print("PASS course mesh placement, lift travel and collapsing props")
	game.free()
	quit()
