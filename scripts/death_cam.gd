class_name DeathCam
extends Camera3D
## The camera used while you're dead: it swings from where you died to the enemy who killed you,
## eases in close, and zooms the field of view. Created by the player on death and removed on respawn.
##
## The killer is framed on the LEFT of the screen, so the death screen's info card can sit on the
## right without covering them (see DeathScreen).

const DURATION := 1.3     # Seconds to glide in
const STAND_OFF := 4.5    # Meters from the killer once we arrive
const ZOOM_FOV := 38.0    # Field of view at the end (the normal view is wider)

# Where the killer ends up on screen, as a fraction of half the screen:
# FRAMING_X: -1 = left edge, 0 = middle, 1 = right edge.  FRAMING_Y: -1 = bottom, 0 = middle, 1 = top.
# -0.42 puts them about a third of the way across. To flip the layout, use +0.42 and move the card.
const FRAMING_X := -0.42
const FRAMING_Y := 0.5

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
	var new_fov := lerpf(_start_fov, ZOOM_FOV, eased)

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

	var to_focus := focus - pos
	if to_focus.length_squared() < 0.0001:
		return

	# Frame the killer off-center. Aiming beside them moves them across the screen (aim to their right and
	# they appear on the left). Rather than guess how far to aim, measure where they actually land and
	# nudge the aim point until they land on target; four quick passes put them within a hair of it.
	# Using the current zoom and distance keeps this right even if a wall stopped the camera short,
	# and the target eases in with the glide.
	var screen := get_viewport().get_visible_rect().size
	var aspect := screen.x / maxf(screen.y, 1.0)
	var half_tan := tan(deg_to_rad(new_fov) * 0.5)
	var want := Vector2(FRAMING_X, FRAMING_Y) * eased # Where on screen, from -1 to 1
	var aim_point := focus
	for _i in range(4):
		var forward := (aim_point - pos).normalized()
		var right := forward.cross(Vector3.UP)
		right = right.normalized() if right.length_squared() > 0.0001 else Vector3.RIGHT
		var up := right.cross(forward).normalized()
		var depth := to_focus.dot(forward)
		if depth <= 0.01:
			break
		var now := Vector2(to_focus.dot(right) / (depth * half_tan * aspect), to_focus.dot(up) / (depth * half_tan))
		var error := want - now
		aim_point -= right * (error.x * depth * half_tan * aspect) + up * (error.y * depth * half_tan)

	var look := (aim_point - pos).normalized()
	var aim := Basis.looking_at(look, Vector3.UP)
	var blended := Quaternion(_start.basis).slerp(Quaternion(aim), eased)
	global_transform = Transform3D(Basis(blended), pos)
	fov = new_fov
