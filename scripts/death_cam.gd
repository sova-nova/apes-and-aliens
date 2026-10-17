class_name DeathCam
extends Camera3D
## The camera used while you're dead: it swings from where you died to the enemy who killed you,
## then eases in close and zooms the field of view. Created by the player on death and removed on respawn.

const DURATION := 1.3     # Seconds to glide in
const STAND_OFF := 4.5    # Meters from the killer once we arrive
const ZOOM_FOV := 38.0    # Field of view at the end (the normal view is wider)

var _target: Node3D = null
var _last_pos: Vector3 = Vector3.ZERO
var _start: Transform3D = Transform3D.IDENTITY
var _start_fov: float = 75.0
var _t: float = 0.0

## Call after adding this node to the tree.
func begin(start: Transform3D, start_fov: float, target: Node3D) -> void:
	_start = start
	_start_fov = start_fov
	_target = target
	_last_pos = target.global_position
	global_transform = start
	fov = start_fov
	make_current()

func _process(delta: float) -> void:
	# Keep tracking the killer while they're around; if they vanish, look where they last were
	if is_instance_valid(_target):
		_last_pos = _target.global_position

	_t = minf(_t + delta / DURATION, 1.0)
	var eased := _t * _t * (3.0 - 2.0 * _t) # smoothstep: gentle start, gentle landing

	var focus := _last_pos + Vector3(0, 1.0, 0) # Their chest

	# We arrive on the same side we started from, a little above them
	var back := _start.origin - focus
	back.y = 0.0
	back = back.normalized() if back.length_squared() > 0.01 else Vector3.BACK
	var dest := focus + back * STAND_OFF + Vector3(0, 0.9, 0)

	# Don't end up inside a wall: if something is between them and the destination, stop short of it
	var query := PhysicsRayQueryParameters3D.create(focus, dest)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		dest = hit.position + hit.normal * 0.3

	var pos := _start.origin.lerp(dest, eased)
	var look := focus - pos
	if look.length_squared() > 0.0001:
		var aim := Basis.looking_at(look.normalized(), Vector3.UP)
		var blended := Quaternion(_start.basis).slerp(Quaternion(aim), eased)
		global_transform = Transform3D(Basis(blended), pos)

	fov = lerpf(_start_fov, ZOOM_FOV, eased)
