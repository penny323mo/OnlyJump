extends RefCounted

const REACH := 3.35
const PULL_TIME := .36
const MAX_SPEED := 5.5
const REEL_ACCEL := 36.

var anchor: MeshInstance3D
var rope: MeshInstance3D
var time_left := 0.

func build(art) -> void:
	anchor = art.aerial
	rope = art.cone(art,Vector3.ZERO,1.,.024,.024,"fff0a3",8)
	rope.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	rope.hide()

func chest(player: CharacterBody3D) -> Vector3:
	return player.global_position+Vector3.UP*.82

func clear_line(player: CharacterBody3D) -> bool:
	var ray := PhysicsRayQueryParameters3D.create(chest(player),anchor.global_position)
	ray.exclude = [player.get_rid()]
	return player.get_world_3d().direct_space_state.intersect_ray(ray).is_empty()

func can_attach(player: CharacterBody3D, camera: Camera3D) -> bool:
	var gap := anchor.global_position-chest(player)
	if gap.length_squared()>REACH*REACH or gap.y<-.45: return false
	var facing := -camera.global_basis.z
	var ahead := Vector2(facing.x,facing.z).normalized()
	if ahead.dot(Vector2(gap.x,gap.z).normalized())<cos(deg_to_rad(34)): return false
	return camera.is_position_in_frustum(anchor.global_position) and clear_line(player)

func attach() -> void:
	time_left = PULL_TIME

func release() -> void:
	time_left = 0.
	rope.hide()

func pull(player: CharacterBody3D, delta: float) -> Vector3:
	var toward := chest(player).direction_to(anchor.global_position)
	var speed := player.velocity+toward*REEL_ACCEL*minf(delta,time_left)
	var horizontal := Vector2(speed.x,speed.z).limit_length(MAX_SPEED)
	time_left = maxf(0.,time_left-delta)
	return Vector3(horizontal.x,speed.y,horizontal.y)

func draw_line(hand: Vector3) -> void:
	var span := anchor.global_position-hand
	rope.quaternion = Quaternion(Vector3.UP,span.normalized())
	rope.scale = Vector3(1.,span.length(),1.)
	rope.global_position = hand+span*.5
	rope.show()
