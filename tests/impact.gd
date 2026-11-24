extends "res://tests/stance.gd"

var contacts: Array[float]=[]
var expected_ledge: int

func drop(id: int, height: float) -> bool:
	expected_ledge=id
	contacts.clear()
	game.player.reset_at(game.art.stop_position(id)+Vector3.UP*height)
	for i in 100:
		await frames(1)
		if not contacts.is_empty(): return true
	return check(false,"no landing on "+game.art.stop_name(id))

func torso_height() -> float:
	var p:=game.player
	var torso: MeshInstance3D=p.costumes.parts["Torso"]
	return torso.to_global(torso.get_aabb().get_center()).y-p.position.y

func run() -> void:
	game=Game.new()
	var fixture:="user://onlyjump-impact-%s.cfg"%OS.get_process_id()
	game.record_path=fixture
	root.add_child(game)
	game.best=100
	game.muted=false
	game.start_run()
	game.player.landed.connect(func(id: int,strength: float):
		if id==expected_ledge: contacts.append(strength))
	cache_soles()
	await frames(30)
	if not check(game.footfall.stream==null,"spawn is quiet"):return
	if not await drop(2,.22):return
	var soft:=contacts[0]
	var quiet:=game.footfall.volume_db
	if not check(soft>0 and game.footfall.stream==preload("res://audio/land-wood.wav"),"small drop on the table plays wood without a jump"):return
	if not await drop(2,3.3):return
	if not check(contacts[0]>soft+.7 and game.footfall.volume_db>quiet+8.,"a higher fall makes a stronger impact"):return
	await frames(3)
	var crouched:=torso_height()
	if not check(game.player.stance.compression>.10,"heavy landing compresses the legs"):return
	for side in SIDES:
		var gaps:=clearances(side)
		if not check(not gaps.is_empty() and gaps.min()>-.025 and gaps.max()<.035 and ankle_connected(side),"feet stay planted through compression"):return
	await frames(24)
	if not check(torso_height()>crouched+.065 and is_zero_approx(game.player.stance.compression) and contacts.size()==1,"torso recovers without repeated landings"):return
	if not await drop(16,1.):return
	if not check(game.footfall.stream==preload("res://audio/land-metal.wav"),"girder plays metal"):return
	game.web_command(["jump"])
	await frames(2)
	if not check(game.player.velocity.y>4 and not game.player.is_on_floor() and is_zero_approx(game.player.stance.compression),"immediate jump releases the landing pose"):return
	if not await drop(1,1.):return
	if not check(game.footfall.stream==preload("res://audio/land-fabric.wav"),"footstool plays fabric"):return
	game.web_command(["mute"])
	if not await drop(2,2.):return
	if not check(not game.footfall.playing and game.footfall.stream==preload("res://audio/land-fabric.wav") and game.player.stance.compression>0,"mute silences landing audio and keeps the pose"):return
	print("PASS surface sounds, impact strength, planted landing compression and immediate rebound")
	game.free()
	DirAccess.remove_absolute(fixture)
	quit()
