@tool
extends EditorScenePostImport

func _post_import(scene: Node) -> Object:
	var player: AnimationPlayer=scene.find_children("*","AnimationPlayer",true,false)[0]
	var rig: Skeleton3D=scene.find_children("*","Skeleton3D",true,false)[0]
	var jump:=player.get_animation("Jump")
	var air:=jump.duplicate() as Animation
	var idle:=player.get_animation("Idle")
	var rig_path:=player.get_node(player.root_node).get_path_to(rig)
	var body_path:=NodePath("%s:Body"%rig_path)
	var body:=jump.find_track(body_path,Animation.TYPE_POSITION_3D)
	var left:=jump.find_track(NodePath("%s:Foot.L"%rig_path),Animation.TYPE_POSITION_3D)
	var right:=jump.find_track(NodePath("%s:Foot.R"%rig_path),Animation.TYPE_POSITION_3D)
	var idle_body:=idle.find_track(body_path,Animation.TYPE_POSITION_3D)
	var standing_height:=idle.position_track_interpolate(idle_body,0.).y
	var planted_foot:=jump.position_track_interpolate(left,0.).y

	# The body, feet and knee controls are siblings. Bake their shared lift
	# out of this clip's own tracks so a cut to the ledge pose is clean.
	var parent:=rig.get_bone_parent(rig.find_bone("Foot.L"))
	for child in rig.get_bone_children(parent):
		var path:=NodePath("%s:%s"%[rig_path,rig.get_bone_name(child)])
		var source:=jump.find_track(path,Animation.TYPE_POSITION_3D)
		if source<0:continue
		air.remove_track(air.find_track(path,Animation.TYPE_POSITION_3D))
		var track:=air.add_track(Animation.TYPE_POSITION_3D)
		air.track_set_path(track,path)
		for frame in ceili(jump.length*60.)+1:
			var t:=minf(frame/60.,jump.length)
			var hip_lift:=jump.position_track_interpolate(body,t).y-standing_height
			var feet:=minf(jump.position_track_interpolate(left,t).y,jump.position_track_interpolate(right,t).y)
			var lift:=maxf(0.,minf(hip_lift,feet-planted_foot))
			air.position_track_insert_key(track,t,jump.position_track_interpolate(source,t)-Vector3.UP*lift)
	player.get_animation_library("").add_animation("Airborne",air)
	return scene
