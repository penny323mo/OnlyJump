extends "res://tests/branches.gd"

func cross_keys(z: float, stick_x: float, running: bool, expected: Array) -> bool:
	game.start_run()
	var piano:=game.art.keys
	var p:=game.player
	var direction:=signf(stick_x)
	p.reset_at(piano.to_global(Vector3(-1.71*direction,.42,z)))
	await frames(30)
	if not check(piano.pressed==expected[0] and game.ledge==9,"land on the first key"):return false
	var notes: Array[int]=[piano.pressed]
	var voice:=piano.voice_index
	game.web_command(["sprint",running])
	game.web_command(["stick",stick_x,0])
	for tick in 240:
		await frames(1)
		if not check(p.is_on_floor(),"run over key edges without jumping"):return false
		if piano.voice_index!=voice:
			voice=piano.voice_index
			notes.append(piano.pressed)
			if not check(is_equal_approx(piano.voices[voice].pitch_scale,pow(2.,piano.pressed/12.)),"key sets its chromatic pitch"):return false
		if piano.to_local(p.position).x*direction>1.61:break
	game.web_command(["stick",0,0])
	if not check(notes==expected and game.falls==0 and p.jump_count==0,"notes played walking across the keys: "+str(notes)):return false
	await frames(12)
	var key:=piano.keys[expected.back()]
	var sole:=p.ground_at(p.position,.15)
	var top:=key.to_global(Vector3(0,piano.WHITE_TOP,piano.to_local(p.position).z-piano.HINGE))
	return check(piano.voice_index==voice and piano.display.text==("C4" if direction<0 else "C5") and key.depth==1. and sole.get("collider")==key and sole.normal.z>.04 and absf(sole.position.y-top.y)<.003,"held key stays depressed with one attack and a matching tilted collision surface")

func run() -> void:
	game=Game.new()
	game.record_path=course_test_save
	root.add_child(game)
	game.muted=false
	if not await cross_keys(.58,.62,false,[0,2,4,5,7,9,11,12]):return
	if not await cross_keys(.62,-.3,false,[12,11,9,7,5,4,2,0]):return
	if not await cross_keys(-.05,-1.,true,range(12,-1,-1)):return
	if not await cross_keys(-.14,1.,true,range(13)):return
	var piano:=game.art.keys
	var p:=game.player
	var voice:=piano.voice_index
	game.toggle_pause()
	var pose:=piano.keys[12].transform
	await frames(10)
	if not check(not piano.voices[voice].playing and piano.keys[12].transform==pose,"pause silences and holds the key"):return
	game.toggle_pause()
	await frames(4)
	if not check(piano.voice_index==voice,"resume does not replay a held note"):return
	game.web_command(["jump"])
	await frames(12)
	if not check(piano.pressed==-1 and is_zero_approx(piano.keys[12].depth) and not p.is_on_floor() and p.position.y>piano.global_position.y+.85,"an ordinary jump clears and releases the key"):return
	if not await reach_floor(9):return
	if not check(piano.pressed==12 and piano.voice_index!=voice,"landing again strikes the same note"):return
	game.web_command(["mute"])
	voice=piano.voice_index
	p.reset_at(piano.to_global(Vector3(-1.41,.48,-.05)))
	await frames(36)
	if not check(piano.pressed==1 and piano.display.text=="C♯4" and piano.voice_index==voice and not piano.voices[voice].playing,"muted black key still lights and dips"):return
	p.reset_at(piano.to_global(Vector3(.05,.22,-.65)))
	await frames(40)
	if not check(game.ledge==9 and piano.pressed==-1 and piano.display.text=="–" and piano.keys[1].depth==0.,"rear panel is a silent foothold"):return
	p.reset_at(piano.to_global(Vector3(.7,.35,.52)))
	await frames(28)
	game.web_command(["stick",0,1])
	for tick in 60:
		await frames(1)
		if not p.is_on_floor():break
	await frames(12)
	if not check(not p.is_on_floor() and piano.pressed==-1 and p.position.y<piano.global_position.y-.15 and p.jump_count==0,"walking past the front lip falls freely"):return
	game.web_command(["stick",0,0])
	game.web_command(["mute"])
	p.reset_at(piano.to_global(Vector3(-.94,.42,-.05)))
	await frames(28)
	if not check(piano.pressed==3,"press D sharp before restarting"):return
	game.start_run()
	if not check(piano.pressed==-1 and piano.keys[3].depth==0. and not piano.voices[piano.voice_index].playing,"restart releases sound and keys"):return
	await frames(16) # Let the audio thread drain the stopped voice before teardown.
	print("PASS playable keyboard, white and chromatic runs, pitch, real key travel, mute and restart")
	game.free()
	DirAccess.remove_absolute(course_test_save)
	quit()
