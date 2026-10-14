extends CharacterBody3D

enum Faction { TEAM_ALPHA, TEAM_BRAVO }

@export var faction: Faction = Faction.TEAM_BRAVO
@export var move_speed: float = 2.5
@export var attack_damage: float = 10.0
@export var attack_range: float = 10.0
@export var attack_cooldown: float = 1.0

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _attack_timer: float = 0.0
var _knockback_velocity: Vector3 = Vector3.ZERO
var is_vulnerable: bool = false

@onready var health_component: HealthComponent = $HealthComponent
@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var original_material: Material = mesh_instance.material_override if mesh_instance else null
@onready var nav_agent: NavigationAgent3D = $NavAgent

func _ready():
	# Apply team color on spawn
	if mesh_instance:
		var team_mat = StandardMaterial3D.new()
		team_mat.roughness = 0.8
		if faction == 0: # TEAM_ALPHA
			team_mat.albedo_color = Color.DODGER_BLUE
		else: # TEAM_BRAVO
			team_mat.albedo_color = Color.RED
			
		mesh_instance.material_override = team_mat
		original_material = team_mat # NOW it correctly saves the team color!
		
	health_component.died.connect(_on_died)
	add_to_group("enemies")
	
func apply_knockback(force: Vector3):
	_knockback_velocity = force

func take_damage(amount: float, _source_faction: int = -1):
	if health_component.is_dead():
		return
		
	var final_damage = amount
	if is_vulnerable:
		final_damage *= 1.1 # 10% extra damage from all sources!
		
	health_component.take_damage(final_damage)
	_flash_damage()
	
func set_vulnerable(state: bool):
	is_vulnerable = state
	# Quick visual flash when debuffed
	if state and mesh_instance:
		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color.ORANGE
		mesh_instance.material_override = mat
		await get_tree().create_timer(0.2).timeout
		mesh_instance.material_override = original_material

func _flash_damage():
	if not mesh_instance:
		return
	var flash_mat = StandardMaterial3D.new()
	flash_mat.albedo_color = Color.RED
	mesh_instance.material_override = flash_mat
	await get_tree().create_timer(0.1).timeout
	mesh_instance.material_override = original_material

func _on_died():
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector3.ZERO, 0.3).set_ease(Tween.EASE_IN)
	tween.tween_callback(queue_free)

func _physics_process(delta: float):
	if health_component.is_dead():
		return

	if not is_on_floor():
		velocity.y -= gravity * delta

	var target = _find_nearest_target()
	if target:
		var to_target = target.global_position - global_position
		to_target.y = 0.0 # Flatten Y for distance checks
		var dist = to_target.length()

		if dist > attack_range:
			# --- PATHFINDING MOVEMENT ---
			nav_agent.target_position = target.global_position
			
			# Check if the NavAgent has a valid path in progress
			if not nav_agent.is_navigation_finished():
				var next_position = nav_agent.get_next_path_position()
				var direction = (next_position - global_position)
				direction.y = 0.0 # Ignore Y axis differences
				
				# If the direction is valid, use it
				if direction.length_squared() > 0.01: 
					direction = direction.normalized()
					velocity.x = direction.x * move_speed
					velocity.z = direction.z * move_speed
					rotation.y = atan2(-direction.x, -direction.z)
				else:
					# Fallback: If next position is too close, walk directly
					var direct_dir = to_target.normalized()
					velocity.x = direct_dir.x * move_speed
					velocity.z = direct_dir.z * move_speed
					rotation.y = atan2(-direct_dir.x, -direct_dir.z)
			else:
				# Fallback: NavAgent finished or failed, walk directly
				var direct_dir = to_target.normalized()
				velocity.x = direct_dir.x * move_speed
				velocity.z = direct_dir.z * move_speed
				rotation.y = atan2(-direct_dir.x, -direct_dir.z)

		else:
			# In range: attack
			velocity.x = move_toward(velocity.x, 0.0, move_speed)
			velocity.z = move_toward(velocity.z, 0.0, move_speed)
			
			# Face the target when standing still
			if to_target.length_squared() > 0.01:
				rotation.y = atan2(-to_target.x, -to_target.z)
			
			_attack_timer -= delta
			if _attack_timer <= 0.0:
				_attack(target)
				_attack_timer = attack_cooldown
	else:
		velocity.x = move_toward(velocity.x, 0.0, move_speed)
		velocity.z = move_toward(velocity.z, 0.0, move_speed)

	# Apply Knockback if any
	if _knockback_velocity.length() > 0.1:
		velocity = _knockback_velocity
		_knockback_velocity = _knockback_velocity.move_toward(Vector3.ZERO, delta * 15.0)
	else:
		_knockback_velocity = Vector3.ZERO

	move_and_slide()
	
func has_line_of_sight(target: Node3D) -> bool:
	var space_state = get_world_3d().direct_space_state
	
	# Start the ray from the enemy's chest, aim at the target's chest
	var origin = global_position + Vector3(0, 0.5, 0)
	var target_pos = target.global_position + Vector3(0, 0.5, 0)
	
	var query = PhysicsRayQueryParameters3D.create(origin, target_pos)
	query.exclude = [self.get_rid()] # Make sure the ray doesn't hit the enemy's own body
	
	var result = space_state.intersect_ray(query)
	
	# If the ray hits nothing (shot into the sky), or hits the target directly, we have LoS
	if result.is_empty():
		return true
	if result.collider == target:
		return true
		
	# If the ray hit anything else (a wall, a crate, another bot), we do NOT have LoS
	return false

func _find_nearest_target() -> Node3D:
	var potential_targets = []
	# Combine both players and enemies into one list of everyone on the map
	potential_targets.append_array(get_tree().get_nodes_in_group("players"))
	potential_targets.append_array(get_tree().get_nodes_in_group("enemies"))
	
	var nearest: Node3D = null
	var nearest_dist: float = INF
	
	for t in potential_targets:
		if not is_instance_valid(t): continue # Skip deleted nodes
		if t == self: continue # Don't target yourself!
		if not "faction" in t: continue # Skip nodes that don't have a faction
		
		# CRITICAL: Only target those on the OPPOSING team
		if t.faction == self.faction:
			continue
			
		var dist = global_position.distance_to(t.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = t
			
	return nearest

func _attack(target: Node3D):
	_attack_timer = attack_cooldown
	
	# Face the player before shooting
	var to_target = target.global_position - global_position
	to_target.y = 0.0
	rotation.y = atan2(-to_target.x, -to_target.z)
	
	# Create a raycast dynamically to check if they can see the player
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(
		global_position + Vector3(0, 0.5, 0), # Shoot from roughly chest height
		target.global_position + Vector3(0, 0.5, 0) # Aim at player chest
	)
	# Don't shoot ourselves
	query.exclude = [self.get_rid()] 
	
	var result = space_state.intersect_ray(query)
	
	# If the ray hit something, and that something is the player
	if result and result.collider == target:
		if target.has_method("take_damage"):
			target.take_damage(attack_damage, faction)
			# Spawn a red flash on the player to indicate they got hit
			_spawn_enemy_tracer(global_position + Vector3(0, 0.5, 0), result.position)

func _spawn_enemy_tracer(from: Vector3, to: Vector3):
	var tracer = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = 0.05
	sphere.height = 0.1
	tracer.mesh = sphere

	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color.RED
	mat.emissive = Color.RED
	mat.emissive_energy = 4.0
	tracer.material_override = mat

	get_tree().root.add_child(tracer)
	tracer.global_position = from

	var tween = create_tween()
	tween.tween_property(tracer, "global_position", to, 0.05)
	tween.tween_callback(tracer.queue_free)

func spawn_damage_number(amount: float):
	# 1. Create the 3D text label
	var label = Label3D.new()
	label.text = str(int(amount))
	
		# 2. Make it big and readable
	label.font_size = 64
	label.modulate = Color.YELLOW # <-- ADD THIS LINE RIGHT HERE
	label.pixel_size = 0.01 

	# 3. Add a thick black outline so we can read it against the sky
	label.outline_size = 10
	label.outline_modulate = Color.BLACK

	# 4. Make it face the camera
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED 

	# 5. Position it above the enemy's head
	label.global_position = global_position + Vector3(0, 1.5, 0)

	# 6. Add it to the root scene tree
	get_tree().root.add_child(label)

	# 7. Attach the tween to the label
	var tween = label.create_tween()

	# 8. Float upward
	tween.tween_property(label, "global_position", label.global_position + Vector3(0, 1.5, 0), 0.8).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)

	# 9. Shrink to nothing (This replaces the broken fade-out!)
	tween.parallel().tween_property(label, "scale", Vector3.ZERO, 0.8).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)

	# 10. Despawn when finished
	tween.tween_callback(label.queue_free)
