extends Marker3D
class_name ForwardSpawn

## Spawn markers are keyed by ROLE, not faction, so attackers/defenders can be swapped.
## GameManager.get_spawn_position(team) picks from these.

## true = used by whichever team is currently ATTACKING; false = by the DEFENDING team.
@export var for_attackers: bool = true
## Used while GameManager.current_point_index equals this (0 = Point A, 1 = Point B, ...).
@export var for_active_point: int = 0
## Random spread so players/bots don't stack on top of each other.
@export var spawn_radius: float = 2.5
## If true, used only when no marker matches the current point exactly.
@export var is_fallback: bool = false

func _ready():
	add_to_group("spawn_points")

func get_spawn_position() -> Vector3:
	var angle := randf() * TAU
	var r := sqrt(randf()) * spawn_radius
	return global_position + Vector3(cos(angle) * r, 0.0, sin(angle) * r)
