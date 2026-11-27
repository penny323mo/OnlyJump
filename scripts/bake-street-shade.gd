extends SceneTree

# Rebuild after changing the seeded city layout or sun direction:
# godot --headless --script scripts/bake-street-shade.gd
const District = preload("res://game/islands.gd")
const STREET_Y := -11.9
const EXTENT := 144.
const SIZE := 768

class BakeDistrict extends District:
	var shapes := PackedStringArray()


	func streetscape(scene: PackedScene, instances: Array[Transform3D]) -> void:
		if scene not in CITY: return
		var template: Node3D = scene.instantiate()
		add_child(template)
		var sunlight := Basis.from_euler(Vector3(deg_to_rad(-37),deg_to_rad(-125),0))*Vector3.FORWARD
		for part: MeshInstance3D in template.find_children("*","MeshInstance3D",true,false):
			var vertices: PackedVector3Array = part.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
			for placement in instances:
				var projection := PackedVector2Array()
				for local in vertices:
					var top := placement*part.global_transform*local
					var foot := top + sunlight*((STREET_Y-top.y)/sunlight.y)
					projection.append((Vector2(foot.x,foot.z)/EXTENT+Vector2(.5,.5))*SIZE)
				var points := PackedStringArray()
				for point in Geometry2D.convex_hull(projection):
					points.append("%.1f,%.1f" % [point.x,point.y])
				shapes.append('<polygon points="%s"/>' % " ".join(points))
		template.free()

func _initialize() -> void:
	call_deferred("bake")

func bake() -> void:
	var district := BakeDistrict.new()
	root.add_child(district)
	var shapes := district.shapes
	var image := Image.new()
	var svg := '<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d"><rect width="100%%" height="100%%" fill="white"/>%s</svg>' % [SIZE,SIZE,"".join(shapes)]
	if shapes.is_empty() or image.load_svg_from_string(svg) != OK:
		district.free()
		quit(1)
		return
	image.convert(Image.FORMAT_L8)
	var error := image.save_png("res://assets/city/street-shade.png")
	district.free()
	quit(error)
