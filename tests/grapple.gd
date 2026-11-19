extends "res://tests/branches.gd"

func collect_on_awning() -> bool:
	await start_on(4)
	if not await leap(B.DRAWER,Vector3.ZERO,false):return false
	await frames(145)
	if not check(game.ledge==B.AWNING and game.player.ability=="","drawer fall reaches awning beside hook"):return false
	if not await approach_pickup("hook"):return false
	game.web_command(["align"])
	await frames(3)
	return check(game.player.ability=="hook" and game.art.pickups.count==1,"collect one hook and face the television aerial")

func run() -> void:
	game=Game.new()
	root.add_child(game)
	game.muted=true
	game.best=100
	game.follow_camera=false
	if not await collect_on_awning():return
	var p:=game.player
	var view_size:=game.get_viewport().get_visible_rect().size
	var ring_y:=game.camera.unproject_position(game.art.aerial.global_position).y/view_size.y
	var foot_y:=game.camera.unproject_position(p.position).y/view_size.y
	if not check(game.tracking_aerial() and ring_y>.04 and ring_y<foot_y and foot_y<.98,"align frames both the aerial and the launch surface"):return
	game.web_command(["look",PI/3.55,0])
	if not check(not game.tracking_aerial(),"manual orbit releases target framing"):return
	game.web_command(["jump"])
	await frames(12)
	game.web_command(["jump"])
	await frames(54)
	if not check(p.ability=="hook" and p.hook.time_left==0 and game.ledge==B.AWNING and p.is_on_floor(),"a backwards shot keeps the charge and follows gravity"):return
	game.web_command(["align"])
	await frames(3)
	game.web_command(["stick",0,-.55])
	game.web_command(["jump"])
	await frames(12)
	if not check(p.ability=="hook" and p.hook.time_left==0 and p.hook.can_attach(p,game.camera),"normal jump leaves hook armed and aerial in reach"):return
	var jumps:=p.jump_count
	game.web_command(["jump"])
	await frames(3)
	if not check(p.hook.time_left>0 and p.hook.rope.visible and not game.landing_guide.visible,"second tap tensions the visible rope"):return
	game.toggle_pause()
	var position:=p.position
	var remaining:=p.hook.time_left
	await frames(35)
	if not check(p.position.is_equal_approx(position) and is_equal_approx(p.hook.time_left,remaining),"pause freezes the pull"):return
	game.toggle_pause()
	game.web_command(["jump"])
	var peak:=p.position.y
	for tick in 75:
		await frames(1)
		peak=maxf(peak,p.position.y)
		if tick==2 and not check(p.hook.time_left<remaining,"repeat tap cannot renew the cable"):return
		if p.is_on_floor():break
	if not check(game.ledge==3 and p.is_on_floor() and peak<3.25 and p.jump_count==jumps,"bounded pull skips the table and lands on the television"):return
	if not check(p.ability=="" and not p.hook.rope.visible and not game.art.pickups.items["hook"].visible,"one charge consumed and original pickup stays gone"):return
	if not await collect_on_awning():return
	p.equip("")
	game.web_command(["stick",0,-.55])
	game.web_command(["jump"])
	await frames(12)
	game.web_command(["jump"])
	await frames(88)
	if not check(game.ledge!=3,"matching jump without the hook falls short"):return
	if not await collect_on_awning():return
	game.web_command(["jump"])
	await frames(30)
	game.web_command(["jump"])
	await frames(2)
	if not check(p.hook.time_left>0,"late shot catches the ring"):return
	await frames(130)
	if not check(game.ledge!=3 and p.ability=="","a spent late shot still falls short"):return
	if not await collect_on_awning():return
	game.web_command(["stick",0,-.55])
	game.web_command(["jump"])
	await frames(12)
	var blocker:=StaticBody3D.new()
	game.add_child(blocker)
	blocker.position=p.hook.chest(p).lerp(game.art.aerial.global_position,.5)
	game.art.solid(blocker,Vector3.ZERO,Vector3(.9,1.2,.38),"705b53")
	await frames(1)
	if not check(not p.hook.clear_line(p),"solid object blocks the rope path"):return
	game.web_command(["jump"])
	await frames(2)
	if not check(p.ability=="hook" and not p.hook.rope.visible,"blocked shot keeps its charge"):return
	blocker.free()
	await frames(1)
	game.web_command(["jump"])
	await frames(2)
	if not check(p.hook.time_left>0,"removing obstruction permits a fresh cast"):return
	var crossing:=StaticBody3D.new()
	game.add_child(crossing)
	crossing.position=p.hook.chest(p).lerp(game.art.aerial.global_position,.5)
	game.art.solid(crossing,Vector3.ZERO,Vector3(.9,1.2,.38),"705b53")
	await frames(3)
	if not check(p.ability=="" and not p.hook.rope.visible,"obstruction after attachment breaks the spent line"):return
	crossing.free()
	await start_on(0)
	p.equip("hook")
	game.web_command(["jump"])
	await frames(12)
	if not check(p.hook.chest(p).distance_to(game.art.aerial.global_position)>p.hook.REACH and not p.hook.can_attach(p,game.camera),"rooftop is outside hook range"):return
	game.web_command(["jump"])
	await frames(2)
	if not check(p.ability=="hook" and not p.hook.rope.visible,"out-of-range tap does not fire"):return
	game.start_run()
	if not check(p.ability=="" and game.art.pickups.items["hook"].visible,"restart restores pickup and clears equipment"):return
	print("PASS awning grapple, one charge, physical landing, blocked shots and pause")
	game.free()
	quit()
