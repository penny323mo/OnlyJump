extends RefCounted

const CHANCE := .70
const REACH := .57
const SETTLE_TIME := .10
const HANG_TIME := .43
const CLIMB_TIME := .46
var rng := RandomNumberGenerator.new()
var available := false
var active := false
var elapsed := 0.0
var climb_start := HANG_TIME
var anchor := Vector3.ZERO
var crest := Vector3.ZERO
var stand := Vector3.ZERO
var over_lip := Vector3.ZERO
var forward := Vector3.FORWARD
var hands: Array[Vector3] = []
var start := Vector3.ZERO
var support_body: CollisionObject3D
var support_transform := Transform3D.IDENTITY

func reset() -> void:
	available = false
	active = false
	elapsed = 0
	support_body = null

func ray(player: CharacterBody3D, a: Vector3, b: Vector3) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(a,b)
	q.exclude = [player.get_rid()]
	return player.get_world_3d().direct_space_state.intersect_ray(q)

func room_to_move(player: CharacterBody3D, at: Vector3, motion: Vector3) -> bool:
	var from := player.global_transform
	from.origin = at
	return not player.test_move(from,motion,null,player.safe_margin)

func try_catch(player: CharacterBody3D, approach: Vector2, last_ledge: int, foot_radius: float) -> bool:
	if not available or approach.length_squared()<.04: return false
	var direction := Vector3(approach.x,0,approach.y).normalized()
	var foot := player.global_position
	var ahead := foot+direction*REACH
	var top := ray(player,ahead+Vector3.UP*1.10,ahead+Vector3.UP*.37)
	if top.is_empty() or top.normal.y<cos(player.floor_max_angle): return false
	var body: Object = top.collider
	if not body.has_meta("ledge") or int(body.get_meta("ledge"))==last_ledge: return false
	var outside := Vector3(foot.x,top.position.y-.055,foot.z)
	var lip := ray(player,outside,outside+direction*REACH)
	if lip.get("collider")!=body or absf(lip.normal.y)>.7: return false
	var inward := -Vector3(lip.normal.x,0,lip.normal.z).normalized()
	if inward.dot(direction)<.45: return false
	var side := inward.cross(Vector3.UP)
	var rim: Vector3 = lip.position+inward*.045
	var found_hands: Array[Vector3] = []
	for offset: float in [-.16,.16]:
		var hand := rim+side*offset
		var grip := ray(player,hand+Vector3.UP*.29,hand-Vector3.UP*.13)
		if grip.get("collider")!=body or grip.normal.y<cos(player.floor_max_angle): return false
		found_hands.append(grip.position+Vector3.UP*.015)
	var middle := (found_hands[0]+found_hands[1])*.5
	var onto := middle+inward*(foot_radius+.08)
	var support := ray(player,onto+Vector3.UP*.38,onto-Vector3.UP*.38)
	if support.get("collider")!=body or support.normal.y<cos(player.floor_max_angle): return false
	var hang := middle-inward*(foot_radius+.12)-Vector3.UP*.88
	var finish: Vector3 = support.position+Vector3.UP*.10
	var high := Vector3(hang.x,maxf(middle.y,finish.y)+.06,hang.z)
	var across := Vector3(finish.x,high.y,finish.z)
	if not room_to_move(player,foot,hang-foot) or not room_to_move(player,hang,high-hang) or not room_to_move(player,high,across-high): return false
	# One roll for the whole jump, after the lip and the climb path qualify.
	available = false
	if rng.randf()>=CHANCE: return false
	support_body=body
	support_transform=support_body.global_transform
	start=foot
	anchor=hang
	crest=high
	over_lip=across
	stand=support.position+Vector3.UP*.012
	forward=inward
	hands=found_hands
	elapsed=0
	climb_start=HANG_TIME
	active=true
	return true

func can_pull_up() -> bool:
	return active and climb_start==HANG_TIME and elapsed<climb_start

func pull_up() -> void:
	if can_pull_up(): climb_start=maxf(elapsed,SETTLE_TIME)

func climb_progress() -> float:
	return clampf((elapsed-climb_start)/CLIMB_TIME,0,1)

func advance(player: CharacterBody3D, delta: float) -> void:
	if not is_instance_valid(support_body) or support_body.collision_layer==0:
		active=false
		return
	var shift:=support_body.global_transform*support_transform.affine_inverse()
	support_transform=support_body.global_transform
	start=shift*start
	anchor=shift*anchor
	crest=shift*crest
	stand=shift*stand
	over_lip=shift*over_lip
	forward=shift.basis*forward
	for i in hands.size(): hands[i]=shift*hands[i]
	elapsed+=delta
	var progress := climb_progress()
	var next := start.lerp(anchor,smoothstep(0,SETTLE_TIME,elapsed))
	if progress>0:
		next = anchor.lerp(crest,smoothstep(0,.52,progress))
		next = next.lerp(over_lip,smoothstep(.52,.88,progress))
		next = next.lerp(stand,smoothstep(.88,1.,progress))
	var motion := next-player.global_position
	if motion.length_squared()>.0000001:
		var blocked := player.move_and_collide(motion)
		if blocked and blocked.get_remainder().length()>.018: active=false
	if progress>=1: active=false
