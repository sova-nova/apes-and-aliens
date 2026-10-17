class_name CombatFx
extends RefCounted
## Shared combat visual effects.
##
## Meshes and materials are created once and reused, so firing a gun or taking a hit
## doesn't allocate new resources every time. Each effect also owns its own tween,
## so it still cleans itself up if whoever spawned it dies mid-effect.
##
## Shared materials must never be modified after creation. Anything that animates
## its own material (like a fading ring) should build one per instance instead.

static var _spheres: Dictionary = {}     # radius -> SphereMesh
static var _flat_materials: Dictionary = {}  # Color -> StandardMaterial3D
static var _team_materials: Dictionary = {}  # team -> StandardMaterial3D
static var _debris_parts: Dictionary = {}    # team -> { mesh, shape, material }

# ─── Shared resources ───────────────────────────────────────

## A plain colored material, shared by every caller that asks for the same color.
static func material(color: Color) -> StandardMaterial3D:
	var mat = _flat_materials.get(color)
	if mat == null:
		mat = StandardMaterial3D.new()
		mat.albedo_color = color
		_flat_materials[color] = mat
	return mat

## The body material for a team's bots.
static func team_material(team: int) -> StandardMaterial3D:
	var mat = _team_materials.get(team)
	if mat == null:
		mat = StandardMaterial3D.new()
		mat.roughness = 0.8
		mat.albedo_color = GameManager.get_team_color(team)
		_team_materials[team] = mat
	return mat

static func _sphere(radius: float) -> SphereMesh:
	var mesh = _spheres.get(radius)
	if mesh == null:
		mesh = SphereMesh.new()
		mesh.radius = radius
		mesh.height = radius * 2.0
		_spheres[radius] = mesh
	return mesh

# ─── Effects ────────────────────────────────────────────────

## A small glowing ball that flies from `from` to `to`.
static func tracer(host: Node, from: Vector3, to: Vector3, color: Color, radius: float, duration: float) -> void:
	var node = MeshInstance3D.new()
	node.mesh = _sphere(radius)
	node.material_override = material(color)

	# Add to the tree FIRST: global_position only works on nodes inside the tree
	host.get_tree().root.add_child(node)
	node.global_position = from

	var tween = node.create_tween()
	tween.tween_property(node, "global_position", to, duration)
	tween.tween_callback(node.queue_free)

## A brief spark where a shot lands.
static func spark(host: Node, pos: Vector3, normal: Vector3) -> void:
	var node = MeshInstance3D.new()
	node.mesh = _sphere(0.06)
	node.material_override = material(Color(1.0, 0.5, 0.1))

	host.get_tree().root.add_child(node)
	node.global_position = pos + normal * 0.02

	var tween = node.create_tween()
	tween.tween_interval(0.12)
	tween.tween_callback(node.queue_free)

## A floating number that rises and shrinks away.
static func damage_number(host: Node, world_pos: Vector3, amount: float) -> void:
	var label = Label3D.new()
	label.text = str(int(amount))
	label.font_size = 64
	label.modulate = Color.YELLOW
	label.pixel_size = 0.01
	label.outline_size = 10
	label.outline_modulate = Color.BLACK
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED

	host.get_tree().root.add_child(label)
	label.global_position = world_pos

	# Shrink to a tiny size, never exactly zero: a zero-scale transform is singular
	var tween = label.create_tween()
	tween.tween_property(label, "global_position", world_pos + Vector3(0, 1.5, 0), 0.8) \
		.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(label, "scale", Vector3.ONE * 0.01, 0.8) \
		.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	tween.tween_callback(label.queue_free)

## A burst of scrap when a bot dies. Apes leave yarn-colored cubes, Chrome Legion leaves flat metal.
static func death_debris(host: Node, pos: Vector3, team: int) -> void:
	var parts = _get_debris_parts(team)

	for i in range(6):
		var debris = RigidBody3D.new()

		var mesh_inst = MeshInstance3D.new()
		mesh_inst.mesh = parts.mesh
		mesh_inst.material_override = parts.material
		debris.add_child(mesh_inst)

		var col_shape = CollisionShape3D.new()
		col_shape.shape = parts.shape
		debris.add_child(col_shape)

		# Add to the tree FIRST, then position and launch
		host.get_tree().root.add_child(debris)
		debris.global_position = pos + Vector3(0, 0.5, 0) \
			+ Vector3(randf_range(-0.3, 0.3), 0, randf_range(-0.3, 0.3))
		debris.linear_velocity = Vector3(randf_range(-1, 1), randf_range(1, 3), randf_range(-1, 1)) * 5.0

		# Clean up after 3 seconds so we don't lag the game
		var tween = debris.create_tween()
		tween.tween_interval(3.0)
		tween.tween_callback(debris.queue_free)

static func _get_debris_parts(team: int) -> Dictionary:
	var parts = _debris_parts.get(team)
	if parts == null:
		var size: Vector3
		var color: Color
		if team == GameManager.TEAM_ALPHA: # Apes
			size = Vector3(0.15, 0.15, 0.15)
			color = Color.BURLYWOOD # Brown/yarn
		else: # Chrome Legion
			size = Vector3(0.1, 0.1, 0.2) # Flat metal scraps
			color = Color.LIGHT_GRAY

		var box_mesh = BoxMesh.new()
		box_mesh.size = size
		var box_shape = BoxShape3D.new()
		box_shape.size = size
		parts = {"mesh": box_mesh, "shape": box_shape, "material": material(color)}
		_debris_parts[team] = parts
	return parts
