extends Area3D

@onready var collision_shape: CollisionShape3D = $CollisionShape3D

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
