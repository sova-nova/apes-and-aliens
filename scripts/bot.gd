extends CharacterBody3D

enum Faction { TEAM_ALPHA, TEAM_BRAVO }

@export var faction: Faction = Faction.TEAM_BRAVO
@export var character_class: CharacterClass

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var move_speed: float = 3.0
var attack_damage: float = 10.0
var attack_range: float = 10.0
var attack_cooldown: float = 1.0
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
		original_material = team_mat
		
	health_component.died.connect(_on_died)
	add_to_group("bots")
	
	# Apply class stats if we have one
	if character_class:
		apply_class()

func apply_class():
	if not character_class:
		print("Bot missing CharacterClass!")
		return
		
	move_speed = character_class.move_speed
	attack_damage = character_class.gun_damage
	attack_cooldown = character_class.fire_rate
	attack_range = 15 # character_class.gun_range later
	
	if health_component:
		health_component.max_health = character_class.max_health
		health_component.current_health = character_class.max_health

func apply_knockback(force: Vector3):
	_knockback_velocity = force

func take_damage(amount: float, _source_faction: int = -1):
	if health_component.is_dead():
		return
		
	var final_damage = amount
	if is_vulnerable:
		final_damage *= 1.1 
		
	health_component.take_damage(final_damage)
	_flash_damage()
	if AudioManager:
		AudioManager.play_hit(global_position)
	
func set_vulnerable(state: bool):
	is_vulnerable = state
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

	# --- NEW AI LOGIC ---
	var combat_target = _find_nearest_target()
	var target_destination = Vector3.ZERO
	
	# Priority 1: If an opponent is in range and visible, fight them!
	if combat_target:
		var to_target = combat_target.global_position - global_position
		to_target.y = 0.0
		var dist = to_target.length()

		if dist <= attack_range and has_line_of_sight(combat_target):
			# ATTACK MODE
			velocity.x = move_toward(velocity.x, 0.0, move_speed)
			velocity.z = move_toward(velocity.z, 0.0, move_speed)
			
			if to_target.length_squared() > 0.01:
				rotation.y = atan2(-to_target.x, -to_target.z)
			
			_attack_timer -= delta
			if _attack_timer <= 0.0:
				_attack(combat_target)
				_attack_timer = attack_cooldown
			return # Skip pathfinding if we are shooting
			
	# Priority 2: If not fighting, move towards the active Capture Point!
	if GameManager and GameManager.active_capture_point:
		target_destination = GameManager.active_capture_point.global_position
	elif combat_target:
		# Fallback: If no point exists, just walk toward the nearest opponent
		target_destination = combat_target.global_position
	else:
		# Stand still if nothing to do
		velocity.x = move_toward(velocity.x, 0.0, move_speed)
		velocity.z = move_toward(velocity.z, 0.0, move_speed)
		move_and_slide()
		return

	# --- PATHFINDING MOVEMENT ---
	# OPTIMIZATION: Only update the NavAgent's target if the destination actually moved > 1 meter.
	# This stops the agent from restarting its path calculation every single frame.
	if nav_agent.target_position.distance_to(target_destination) > 1.0:
		nav_agent.target_position = target_destination
		
	if not nav_agent.is_navigation_finished():
		var next_position = nav_agent.get_next_path_position()
		var direction = (next_position - global_position)
		direction.y = 0.0 
		
		if direction.length() > 0.05: 
			direction = direction.normalized()
			velocity.x = direction.x * move_speed
			velocity.z = direction.z * move_speed
			rotation.y = atan2(-direction.x, -direction.z)
		else:
			velocity.x = move_toward(velocity.x, 0.0, move_speed)
			velocity.z = move_toward(velocity.z, 0.0, move_speed)
	else:
		# Path is finished (We reached the capture point)
		# Stop moving, but face the center of the point so we contest it!
		velocity.x = move_toward(velocity.x, 0.0, move_speed)
		velocity.z = move_toward(velocity.z, 0.0, move_speed)
		
		var to_point = target_destination - global_position
		to_point.y = 0.0
		if to_point.length_squared() > 0.01:
			rotation.y = atan2(-to_point.x, -to_point.z)

	# Apply Knockback if any
	if _knockback_velocity.length() > 0.1:
		velocity = _knockback_velocity
		_knockback_velocity = _knockback_velocity.move_toward(Vector3.ZERO, delta * 15.0)
	else:
		_knockback_velocity = Vector3.ZERO

	move_and_slide()
	
func has_line_of_sight(target: Node3D) -> bool:
	var space_state = get_world_3d().direct_space_state
	var origin = global_position + Vector3(0, 0.5, 0)
	var target_pos = target.global_position + Vector3(0, 0.5, 0)
	var query = PhysicsRayQueryParameters3D.create(origin, target_pos)
	query.exclude = [self.get_rid()] 
	var result = space_state.intersect_ray(query)
	if result.is_empty():
		return true
	if result.collider == target:
		return true
	return false

func _find_nearest_target() -> Node3D:
	var potential_targets = []
	potential_targets.append_array(get_tree().get_nodes_in_group("players"))
	potential_targets.append_array(get_tree().get_nodes_in_group("bots"))
	
	var nearest: Node3D = null
	var nearest_dist: float = INF
	
	for t in potential_targets:
		if not is_instance_valid(t): continue
		if t == self: continue
		if not "faction" in t: continue
		if t.faction == self.faction:
			continue
			
		var dist = global_position.distance_to(t.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = t
			
	return nearest

func _attack(target: Node3D):
	_attack_timer = attack_cooldown
	var to_target = target.global_position - global_position
	to_target.y = 0.0
	rotation.y = atan2(-to_target.x, -to_target.z)
	
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(
		global_position + Vector3(0, 0.5, 0), 
		target.global_position + Vector3(0, 0.5, 0) 
	)
	query.exclude = [self.get_rid()] 
	
	var result = space_state.intersect_ray(query)
	
	if result and result.collider == target:
		if target.has_method("take_damage"):
			target.take_damage(attack_damage, faction)
			_spawn_bot_tracer(global_position + Vector3(0, 0.5, 0), result.position)

	if AudioManager:
		AudioManager.play_shoot(global_position)

func _spawn_bot_tracer(from: Vector3, to: Vector3):
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
	var label = Label3D.new()
	label.text = str(int(amount))
	label.font_size = 64
	label.modulate = Color.YELLOW
	label.pixel_size = 0.01 
	label.outline_size = 10
	label.outline_modulate = Color.BLACK
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED 
	label.global_position = global_position + Vector3(0, 1.5, 0)
	get_tree().root.add_child(label)

	var tween = label.create_tween()
	tween.tween_property(label, "global_position", label.global_position + Vector3(0, 1.5, 0), 0.8).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(label, "scale", Vector3.ZERO, 0.8).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	tween.tween_callback(label.queue_free)
