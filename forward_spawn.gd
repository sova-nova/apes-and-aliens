extends Marker3D
class_name ForwardSpawn

@export var faction: int = 0 ## 0 = ALPHA (attackers), 1 = BRAVO (defenders)
@export var for_active_point: int = 0 ## This spawn is used when GameManager.current_point_index matches this
@export var spawn_radius: float = 4.0 ## Random spread so players/bots don't stack on top of each other
@export var is_fallback: bool = false ## If true, used when no exact match is found


func get_spawn_position() -> Vector3:
	var angle := randf() * TAU
	var r := sqrt(randf()) * spawn_radius
	return global_position + Vector3(cos(angle) * r, 0.0, sin(angle) * r)
