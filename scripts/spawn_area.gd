extends Area3D

## Spawn areas work like ForwardSpawn markers (keyed by ROLE, not faction).
## true = used by whichever team is currently ATTACKING; false = by the DEFENDING team.
@export var for_attackers: bool = true
## Used while GameManager.current_point_index equals this (0 = Point A).
@export var for_active_point: int = 0
## If true, used only when no marker/area matches the current point exactly.
@export var is_fallback: bool = false

@onready var collision_shape: CollisionShape3D = $CollisionShape3D

func _ready():
	# Back-compat: areas still in the old faction groups map to roles automatically.
	# Alpha's base is the attackers' home and Bravo's is the defenders' home.
	# Remove the old group from an area if you want to set its role in the Inspector instead.
	if is_in_group("team_alpha_spawns"):
		for_attackers = true
		is_fallback = true
	elif is_in_group("team_bravo_spawns"):
		for_attackers = false
		is_fallback = true
	add_to_group("spawn_points")

func get_spawn_position() -> Vector3:
	return get_random_point_inside()

func get_random_point_inside() -> Vector3:
	if not collision_shape or not collision_shape.shape:
		return global_position
		
	var shape = collision_shape.shape
	
	# If it's a* BoxShape3D:
	if shape is BoxShape3D:
		# Get half the size of the box
		var extents = shape.size / 2.0
		# Pick a random X and Z within those extents
		var random_x = randf_range(-extents.x, extents.x)
		var random_z = randf_range(-extents.z, extents.z)
		
		return global_position + Vector3(random_x, 0, random_z)
		
	# If it's a CylinderShape3D (Fallback)
	elif shape is CylinderShape3D:
		var radius = shape.radius
		var angle = randf() * TAU
		var distance = sqrt(randf()) * radius
		var offset_x = cos(angle) * distance
		var offset_z = sin(angle) * distance
		return global_position + Vector3(offset_x, 0, offset_z)
		
	return global_position
