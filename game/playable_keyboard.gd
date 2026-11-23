extends Node3D

const Props = preload("res://game/props.gd")
const TONE := preload("res://audio/polytone-c4.wav")
const WHITE := [0,2,4,5,7,9,11,12]
const NOTE_NAMES := ["C4","C♯4","D4","D♯4","E4","F4","F♯4","G4","G♯4","A4","A♯4","B4","C5"]
const WIDTH := .47
const HINGE := -.30
const KEY_LENGTH := 1.05
const WHITE_TOP := .014
const BLACK_TOP := .038

class PianoKey extends StaticBody3D:
	var footprint: Rect2
	var cap: MeshInstance3D
	var idle: Material
	var lit: Material
	var depth := 0.

var keys: Array[PianoKey]=[]
var voices: Array[AudioStreamPlayer]=[]
var display: Label3D
var pressed := -1
var settling := false
var voice_index := 0

func build(art: Props, body: StaticBody3D) -> void:
	# The cabinet is recessed below the keys. Its back panel and cheeks can
	# support the climber independently when they step off the instrument.
	art.solid(body,Vector3(0,-.20,0),Vector3(4.25,.31,1.75),"a65442",.07)
	art.solid(body,Vector3(0,-.029,-.59),Vector3(4.18,.060,.57),"465256",.02)
	for side: float in [-1.,1.]:
		art.solid(body,Vector3(side*2.0,-.036,.23),Vector3(.22,.06,1.11),"af634c",.022)
	art.box(body,Vector3(0,-.043,.24),Vector3(3.80,.016,1.12),"353f40")
	art.label(body,Vector3(-1.23,.005,-.58),"POLYTONE",.15,"fff0bd",true)
	art.box(body,Vector3(.15,.012,-.58),Vector3(.84,.036,.35),"243537",.022)
	display=art.label(body,Vector3(.15,.033,-.58),"–",.23,"91f6cb",true)
	for i in 3: art.cone(body,Vector3(1.16+i*.24,.042,-.58),.084,.075,.064,"e0aa54",16)
	keys.resize(13)
	for i in WHITE.size():
		var x: float=(i-3.5)*WIDTH
		add_key(art,WHITE[i],x,WIDTH-.01,KEY_LENGTH,false)
		if i+1<WHITE.size() and WHITE[i+1]-WHITE[i]==2:
			add_key(art,WHITE[i]+1,x+WIDTH*.5,.265,.62,true)
	for i in 3:
		var voice:=AudioStreamPlayer.new()
		voice.stream=TONE
		add_child(voice)
		voices.append(voice)

func add_key(art: Props, note: int, x: float, width: float, length: float, sharp: bool) -> void:
	var key:=PianoKey.new()
	key.set_meta("ledge",get_parent().get_meta("ledge"))
	key.position=Vector3(x,0,HINGE)
	key.footprint=Rect2(x-width*.5,HINGE,width,length)
	add_child(key)
	keys[note]=key
	# Bevel each cap down to the bed so a planted sole can cross from a
	# depressed key onto its raised neighbour, including the semitones.
	var bevel:=.084 if sharp else .075
	var top:=BLACK_TOP if sharp else WHITE_TOP
	var bottom:=-.006 if sharp else -.043
	var corners:=PackedVector3Array()
	for i in 4:
		var side:=1. if i in [1,2] else -1.
		corners.append(Vector3(side*width*.5,bottom,length if i>=2 else 0.))
	for i in 4:
		var side:=1. if i in [1,2] else -1.
		corners.append(Vector3(side*(width*.5-bevel),top,length-bevel if i>=2 else bevel))
	var mesh:=SurfaceTool.new()
	mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
	for face: Array in [[4,5,6,7],[0,1,5,4],[1,2,6,5],[2,3,7,6],[3,0,4,7],[3,2,1,0]]:
		for j in [0,1,2,0,2,3]: mesh.add_vertex(corners[face[j]])
	mesh.generate_normals()
	var tint:="303b40" if sharp else "fff1d4"
	key.cap=art.piece(key,mesh.commit(),Vector3.ZERO,tint)
	var hit:=CollisionShape3D.new()
	hit.shape=key.cap.mesh.create_trimesh_shape()
	key.add_child(hit)
	key.idle=key.cap.material_override
	key.lit=art.material("339e9c" if sharp else "e8ae51")

func key_at(world_point: Vector3) -> int:
	var local:=to_local(world_point)
	var point:=Vector2(local.x,local.z)
	if not Rect2(-4.*WIDTH,HINGE,8.*WIDTH,KEY_LENGTH).has_point(point):return -1
	for i in WHITE.size()-1:
		if WHITE[i+1]-WHITE[i]==1:continue
		var note: int=WHITE[i]+1
		var bounds:=keys[note].footprint
		if note==pressed: bounds=bounds.grow(.016)
		if bounds.has_point(point):return note
	var white:=clampi(floori(point.x/WIDTH+4.),0,7)
	return WHITE[white]

func silence() -> void:
	for voice in voices: voice.stop()

func reset() -> void:
	silence()
	pressed=-1
	settling=false
	display.text="–"
	for key in keys:
		key.depth=0.
		key.rotation.x=0.
		key.cap.material_override=key.idle

func advance(delta: float, grounded: bool, foot: Vector3, muted: bool) -> void:
	if not grounded and pressed<0 and not settling:return
	var note:=key_at(foot) if grounded else -1
	if note!=pressed:
		if pressed>=0: keys[pressed].cap.material_override=keys[pressed].idle
		pressed=note
		settling=true
		display.text=NOTE_NAMES[note] if note>=0 else "–"
		if note>=0:
			keys[note].cap.material_override=keys[note].lit
			if not muted:
				voice_index=(voice_index+1)%voices.size()
				var voice:=voices[voice_index]
				voice.pitch_scale=pow(2.,note/12.)
				voice.volume_db=-8.
				voice.play()
	if settling:
		settling=false
		for i in keys.size():
			var key:=keys[i]
			var target:=1. if i==pressed else 0.
			if key.depth==target:continue
			key.depth=move_toward(key.depth,target,delta*(18. if target else 10.))
			key.rotation.x=deg_to_rad(2.8)*key.depth
			settling=settling or key.depth!=target
	# Damp the previous note while letting the next attack speak cleanly.
	for i in voices.size():
		var voice:=voices[i]
		if not voice.playing or (i==voice_index and pressed>=0):continue
		voice.volume_db-=delta*210.
		if voice.volume_db<=-45.:voice.stop()
		else:settling=true
