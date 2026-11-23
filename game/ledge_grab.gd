extends RefCounted

const CHANCE := .70
const REACH := .57
const SETTLE_TIME := .10
const HANG_TIME := .43
const CLIMB_TIME := .46
const REACH_STEP := .18
const MAX_HAND_STEP := .26
const STEP_TIME := .25
const DROP_HOLD := .18
enum Attempt { NONE, JUMP, SLIP }

# Store grips on the prop, so a planted palm stays fixed as a carrier turns.
class Hold:
	var body: CollisionObject3D
	var palms: Array[Vector3] = []
	var inward: Vector3
	var hang: Vector3
	var crest: Vector3
	var across: Vector3
	var stand: Vector3

var rng := RandomNumberGenerator.new()
var attempt := Attempt.NONE
var active := false
var elapsed := 0.0
var climb_start := HANG_TIME
var forward := Vector3.FORWARD
var hands: Array[Vector3] = [Vector3.ZERO,Vector3.ZERO]
var start := Vector3.ZERO
var support_body: CollisionObject3D
var support_transform := Transform3D.IDENTITY
var hold: Hold
var next_hold: Hold
var step_elapsed := 0.
var leading_hand := 0
var retry_after := 0.
var drop_elapsed := 0.
var pull_requested := false

func reset() -> void:
	attempt = Attempt.NONE
	active = false
	elapsed = 0
	support_body = null
	hold=null
	next_hold=null

func ray(player: CharacterBody3D, a: Vector3, b: Vector3) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(a,b)
	q.exclude = [player.get_rid()]
	return player.get_world_3d().direct_space_state.intersect_ray(q)

func room_to_move(player: CharacterBody3D, at: Vector3, motion: Vector3) -> bool:
	var from := player.global_transform
	from.origin = at
	return not player.test_move(from,motion,null,player.safe_margin)

func find_hold(player: CharacterBody3D, foot: Vector3, direction: Vector3, last_ledge: int, foot_radius: float) -> Hold:
	var ahead := foot+direction*REACH
	var top := ray(player,ahead+Vector3.UP*1.10,ahead+Vector3.UP*.37)
	var body:=top.get("collider") as CollisionObject3D
	if not body or not body.has_meta("ledge") or top.normal.y<cos(player.floor_max_angle): return null
	var same_ledge:=int(body.get_meta("ledge"))==last_ledge
	if active:
		if body!=support_body:return null
	elif same_ledge!=(attempt==Attempt.SLIP):return null
	var outside := Vector3(foot.x,top.position.y-.055,foot.z)
	var lip := ray(player,outside,outside+direction*REACH)
	if lip.get("collider")!=body or absf(lip.normal.y)>.7: return null
	var inward := -Vector3(lip.normal.x,0,lip.normal.z).normalized()
	if inward.dot(direction)<.45: return null
	var side := inward.cross(Vector3.UP)
	var rim: Vector3 = lip.position+inward*.045
	var found_hands: Array[Vector3] = []
	for offset: float in [-.16,.16]:
		var hand := rim+side*offset
		var grip := ray(player,hand+Vector3.UP*.29,hand-Vector3.UP*.13)
		if grip.get("collider")!=body or grip.normal.y<cos(player.floor_max_angle): return null
		found_hands.append(grip.position+Vector3.UP*.015)
	var middle := (found_hands[0]+found_hands[1])*.5
	var onto := middle+inward*(foot_radius+.08)
	var support := ray(player,onto+Vector3.UP*.38,onto-Vector3.UP*.38)
	if support.get("collider")!=body or support.normal.y<cos(player.floor_max_angle): return null
	var hang := middle-inward*(foot_radius+.12)-Vector3.UP*.88
	var finish: Vector3 = support.position+Vector3.UP*.10
	var high := Vector3(hang.x,maxf(middle.y,finish.y)+.06,hang.z)
	var across := Vector3(finish.x,high.y,finish.z)
	if not room_to_move(player,player.global_position,hang-player.global_position) or not room_to_move(player,hang,high-hang) or not room_to_move(player,high,across-high): return null
	var result:=Hold.new()
	result.body=body
	for hand in found_hands:result.palms.append(body.to_local(hand))
	result.inward=body.global_basis.inverse()*inward
	result.hang=body.to_local(hang)
	result.crest=body.to_local(high)
	result.across=body.to_local(across)
	result.stand=body.to_local(support.position+Vector3.UP*.012)
	return result

func try_catch(player: CharacterBody3D, approach: Vector2, last_ledge: int, foot_radius: float) -> bool:
	if attempt==Attempt.NONE or approach.length_squared()<.04: return false
	var direction:=Vector3(approach.x,0,approach.y).normalized()
	var initial:=find_hold(player,player.global_position,direction,last_ledge,foot_radius)
	if not initial:return false
	# Roll only once in this flight, after both hands and the climb path fit.
	attempt = Attempt.NONE
	if rng.randf()>=CHANCE: return false
	hold=initial
	support_body=hold.body
	support_transform=support_body.global_transform
	start=support_body.to_local(player.global_position)
	forward=support_transform.basis*hold.inward
	for i in hands.size():hands[i]=support_transform*hold.palms[i]
	next_hold=null
	retry_after=0.
	drop_elapsed=0.
	pull_requested=false
	elapsed=0
	climb_start=HANG_TIME
	active=true
	return true

func can_pull_up() -> bool:
	return active and not pull_requested and elapsed<climb_start

func pull_up() -> void:
	if can_pull_up():
		pull_requested=true
		climb_start=maxf(elapsed,SETTLE_TIME)
		if next_hold:climb_start=elapsed+STEP_TIME-step_elapsed

func climb_progress() -> float:
	return clampf((elapsed-climb_start)/CLIMB_TIME,0,1)

func steer_on_rim(player: CharacterBody3D, move: Vector2, delta: float, carry: Vector3, foot_radius: float) -> void:
	var side:=forward.cross(Vector3.UP).normalized()
	var input:=Vector3(move.x,0,move.y)
	var lateral:=input.dot(side)
	var inward:=input.dot(forward)
	if inward<-.65 and -inward>absf(lateral):
		drop_elapsed+=delta
		climb_start=elapsed+HANG_TIME
		if drop_elapsed>=DROP_HOLD:
			active=false
			player.velocity=carry-forward*.65+Vector3.DOWN*.65
		return
	drop_elapsed=0.
	if absf(lateral)<.35 or absf(lateral)<absf(inward):return
	climb_start=elapsed+HANG_TIME
	if next_hold or elapsed<retry_after:return
	var probe:=support_body.to_global(hold.hang)+side*signf(lateral)*REACH_STEP
	next_hold=find_hold(player,probe,forward,-1,foot_radius)
	if next_hold:
		for i in hands.size():
			if (support_transform.basis*(next_hold.palms[i]-hold.palms[i])).length()>MAX_HAND_STEP:
				next_hold=null
				break
	if not next_hold:
		retry_after=elapsed+.08
		return
	leading_hand=1 if lateral>0 else 0
	step_elapsed=0.

func advance(player: CharacterBody3D, delta: float, move: Vector2, foot_radius: float) -> void:
	if not is_instance_valid(support_body) or support_body.collision_layer==0:
		active=false
		return
	var frame:=support_body.global_transform
	var carry:=(frame*hold.hang-support_transform*hold.hang)/delta
	support_transform=frame
	forward=frame.basis*hold.inward
	elapsed+=delta
	if elapsed>=SETTLE_TIME and can_pull_up():
		steer_on_rim(player,move,delta,carry,foot_radius)
		if not active:return
	var next:=start.lerp(hold.hang,smoothstep(0,SETTLE_TIME,elapsed))
	for i in hands.size():hands[i]=frame*hold.palms[i]
	if next_hold:
		step_elapsed+=delta
		var step:=minf(step_elapsed/STEP_TIME,1.)
		next=hold.hang.lerp(next_hold.hang,smoothstep(0,1,step))
		for i in hands.size():
			# Seat the leading palm before the trailing hand lets go.
			var reach:=smoothstep(0,.46,step) if i==leading_hand else smoothstep(.54,1.,step)
			hands[i]=frame*hold.palms[i].lerp(next_hold.palms[i],reach)+Vector3.UP*(sin(reach*PI)*.025)
		if step>=1.:
			hold=next_hold
			next_hold=null
	var progress := climb_progress()
	if progress>0:
		next = hold.hang.lerp(hold.crest,smoothstep(0,.52,progress))
		next = next.lerp(hold.across,smoothstep(.52,.88,progress))
		next = next.lerp(hold.stand,smoothstep(.88,1.,progress))
	var motion := frame*next-player.global_position
	if motion.length_squared()>.0000001:
		var blocked := player.move_and_collide(motion)
		if blocked and blocked.get_remainder().length()>.018: active=false
	if progress>=1: active=false
