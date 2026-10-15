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

var health_bar_pivot: Node3D
var health_bar_mesh: MeshInstance3D
var health_bar_mat: StandardMaterial3D

var _target_point_ref: Node3D = null # Tracks which point we are heading to
var _current_point_target: Vector3 = Vector3.ZERO # The specific random spot we chose inside the point

var last_attacker_name: String = ""

@onready var health_component: HealthComponent = $HealthComponent
@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var original_material: Material = mesh_instance.material_override if mesh_instance else null
@onready var nav_agent: NavigationAgent3D = $NavAgent

# --- AI Ability System ---
var ability_cooldowns: Array[float] = [0.0, 0.0, 0.0]
var _ability_eval_timer: float = 0.0
var _is_invulnerable: bool = false
var _damage_reduction_multiplier: float = 1.0
var _speed_multiplier: float = 1.0

func _ready():
	# --- Apply Team Color ---
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
	
	if character_class:
		apply_class()
		
	# --- Generate Health Bar ---
	var bar_container = Node3D.new()
	bar_container.position.y = 1.8 # Float above head
	add_child(bar_container)
	
	## 1. Background Bar (The dark "missing health" bar)
	#var bg_mesh_inst = MeshInstance3D.new()
	#var bg_mesh = QuadMesh.new()
	#bg_mesh.size = Vector2(1.0, 0.1) # Vector2 for QuadMesh!
	#bg_mesh_inst.mesh = bg_mesh
	#var bg_mat = StandardMaterial3D.new()
	#bg_mat.albedo_color = Color(0.1, 0.1, 0.1) # Dark grey
	#bg_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	#bg_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED # Ignore sun
	#bg_mat.cull_mode = BaseMaterial3D.CULL_DISABLED # Visible from both sides
	#bg_mesh_inst.material_override = bg_mat
	#bar_container.add_child(bg_mesh_inst)
	
	# 2. Foreground Bar (The green/yellow/red bar)
	health_bar_mesh = MeshInstance3D.new()
	var fg_mesh = QuadMesh.new()
	fg_mesh.size = Vector2(1.0, 0.1) # Vector2 for QuadMesh!
	health_bar_mesh.mesh = fg_mesh
	
	# Push slightly forward in Z so it renders IN FRONT of the grey bar
	health_bar_mesh.position.z = 0.001
	
	health_bar_mat = StandardMaterial3D.new()
	health_bar_mat.albedo_color = Color.GREEN
	health_bar_mat.emissive = Color.GREEN
	health_bar_mat.emissive_energy = 1.0
	health_bar_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	health_bar_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED # Ignore sun
	health_bar_mat.cull_mode = BaseMaterial3D.CULL_DISABLED # Visible from both sides
	health_bar_mesh.material_override = health_bar_mat
	
	bar_container.add_child(health_bar_mesh)
	
	# Hide health bar if they are an enemy
	if faction != PlayerSetup.selected_faction:
		bar_container.visible = false

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

func take_damage(amount: float, _source_faction: int = -1, attacker_name: String = ""):
	if health_component.is_dead():
		return
	if _is_invulnerable:
		return 
		
	var final_damage = amount * _damage_reduction_multiplier
	if is_vulnerable:
		final_damage *= 1.1 
		
	# Remember who shot us!
	if attacker_name != "":
		last_attacker_name = attacker_name
		
	health_component.take_damage(final_damage)
	_flash_damage()
	update_health_bar()
	if AudioManager:
		AudioManager.play_hit(global_position)
		
func update_health_bar():
	if not health_bar_mesh or not health_bar_mesh.visible:
		return
		
	if not health_component:
		return
		
	var health_pct = health_component.current_health / health_component.max_health
	var new_width = 1.0 * health_pct
	
	# 1. Change the size of the QuadMesh (Uses Vector2)
	health_bar_mesh.mesh.size = Vector2(new_width, 0.1)
	
	# 2. Shift the mesh so its left edge stays pinned at -0.5
	health_bar_mesh.position.x = -0.5 + (new_width / 2.0)
	
	# 3. Change color based on health percentage
	if health_pct > 0.6:
		health_bar_mat.albedo_color = Color.GREEN
		health_bar_mat.emissive = Color.GREEN
	elif health_pct > 0.3:
		health_bar_mat.albedo_color = Color.YELLOW
		health_bar_mat.emissive = Color.YELLOW
	else:
		health_bar_mat.albedo_color = Color.RED
		health_bar_mat.emissive = Color.RED
	
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
	# Broadcast Kill
	var my_name = character_class.class_name_str if character_class else "Bot"
	GameManager.kill_occurred.emit(last_attacker_name, my_name, faction)
	
	# Death Effect (We'll add this below)
	_spawn_death_debris()
	
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector3.ZERO, 0.3).set_ease(Tween.EASE_IN)
	tween.tween_callback(queue_free)

func _physics_process(delta: float):
	if health_component.is_dead():
		return

	# --- MATCH COUNTDOWN GATE ---
	if not GameManager.is_match_playing:
		if not is_on_floor():
			velocity.y -= gravity * delta
		move_and_slide()
		return # Bots stand still during countdown

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
		# Check if the active point has changed, or if we haven't picked a spot yet
		if GameManager.active_capture_point != _target_point_ref:
			_target_point_ref = GameManager.active_capture_point
			
			# Ask the capture point for a random position inside it!
			if _target_point_ref.has_method("get_random_point_inside"):
				_current_point_target = _target_point_ref.get_random_point_inside()
			else:
				_current_point_target = _target_point_ref.global_position
				
		# Set our destination to the specific random spot we chose
		target_destination = _current_point_target
		
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
			velocity.x = direction.x * move_speed * _speed_multiplier
			velocity.z = direction.z * move_speed * _speed_multiplier
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

	# --- AI Ability Evaluation ---
	_ability_eval_timer -= delta
	if _ability_eval_timer <= 0.0:
		_ability_eval_timer = 0.5
		_evaluate_abilities(combat_target)

	move_and_slide()
	
func has_line_of_sight(target: Node3D) -> bool:
	# Safety check: If the target doesn't exist anymore, we don't have line of sight!
	if not is_instance_valid(target):
		return false
		
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
		
		# CRITICAL: Don't target dead players/bots!
		if "is_alive" in t and not t.is_alive:
			continue
			
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
			var my_name = character_class.class_name_str if character_class else "Bot"
			target.take_damage(attack_damage, faction, my_name)
			_spawn_bot_tracer(global_position + Vector3(0, 0.5, 0), result.position)

	if AudioManager:
		AudioManager.play_shoot(global_position)
		
func _evaluate_abilities(target: Node3D):
	if not character_class:
		return
		
	# Safety check: If the target is dead/gone, don't try to use targeted abilities
	var target_is_valid = is_instance_valid(target)
		
	# Decrease cooldowns
	for i in range(3):
		if ability_cooldowns[i] > 0:
			ability_cooldowns[i] -= 0.5 
			
	var health_pct = health_component.current_health / health_component.max_health
	var dist_to_target = INF
	if target_is_valid:
		dist_to_target = global_position.distance_to(target.global_position)
		
	# --- ABILITY 1 LOGIC ---
	if ability_cooldowns[0] <= 0:
		match character_class.ability_1_type:
			CharacterClass.AbilityType.PHASE_DASH:
				# Breacher: Dash if low health and enemy is close
				if health_pct < 0.4 and dist_to_target < 8.0:
					_bot_dash()
			CharacterClass.AbilityType.GRAPPLE_HOOK:
				# Ghost: Grapple if target is far away but visible
				if dist_to_target > 15.0 and has_line_of_sight(target):
					_bot_dash() # Reuse dash logic for a quick speed lunge
			_:
				pass
				
	# --- ABILITY 2 LOGIC ---
	if ability_cooldowns[1] <= 0:
		match character_class.ability_2_type:
			CharacterClass.AbilityType.OVERCHARGE:
				# Breacher: Overcharge if healthy and enemy is visible
				if health_pct > 0.7 and dist_to_target < attack_range:
					_bot_overcharge()
			CharacterClass.AbilityType.BULWARK:
				# Warden: Bulwark if health is dropping
				if health_pct < 0.6:
					_bot_bulwark()
			CharacterClass.AbilityType.TARGET_LOCK:
				# Ghost: Target lock if enemy is medium range
				if dist_to_target < 15.0 and has_line_of_sight(target):
					_bot_overcharge() # Reuse overcharge logic for a damage boost
			_:
				pass
				
	# --- ABILITY 3 LOGIC ---
	if ability_cooldowns[2] <= 0:
		match character_class.ability_3_type:
			CharacterClass.AbilityType.ADRENALINE_SPIKE:
				# Breacher: Adrenaline if very low health
				if health_pct < 0.3:
					_bot_adrenaline()
			CharacterClass.AbilityType.DEPLOY_COVER:
				# Warden: Deploy cover if on capture point and taking fire
				if health_pct < 0.8 and GameManager.active_capture_point:
					var dist_to_point = global_position.distance_to(GameManager.active_capture_point.global_position)
					if dist_to_point < 6.0:
						_bot_adrenaline() # Reuse adrenaline logic for a quick heal/speed to reposition
			CharacterClass.AbilityType.SHOCKWAVE:
				# Warden: Shockwave if enemy is very close
				if dist_to_target < 5.0:
					_bot_shockwave(target)
			CharacterClass.AbilityType.LIFE_SIPHON:
				# Ghost: Siphon if close and low health
				if health_pct < 0.5 and dist_to_target < 10.0:
					_bot_adrenaline() # Reuse as a heal
			_:
				pass

func _bot_dash():
	ability_cooldowns[0] = character_class.ability_1_cooldown
	_is_invulnerable = true
	_speed_multiplier = 3.0
	_flash_ability_color(Color.CYAN)
	await get_tree().create_timer(0.3).timeout
	_is_invulnerable = false
	_speed_multiplier = 1.0
	if mesh_instance: mesh_instance.material_override = original_material

func _bot_overcharge():
	ability_cooldowns[1] = character_class.ability_2_cooldown
	# For bots, overcharge/target lock just gives a damage boost. We simulate this by temporarily doubling their attack damage
	attack_damage *= 1.5 
	_flash_ability_color(Color.ORANGE)
	await get_tree().create_timer(4.0).timeout
	attack_damage /= 1.5
	if mesh_instance: mesh_instance.material_override = original_material

func _bot_bulwark():
	ability_cooldowns[1] = character_class.ability_2_cooldown
	_damage_reduction_multiplier = 0.5
	_flash_ability_color(Color.DODGER_BLUE)
	await get_tree().create_timer(4.0).timeout
	_damage_reduction_multiplier = 1.0
	if mesh_instance: mesh_instance.material_override = original_material

func _bot_adrenaline():
	ability_cooldowns[2] = character_class.ability_3_cooldown
	health_component.current_health = min(health_component.max_health, health_component.current_health + 30)
	_speed_multiplier = 1.5
	_flash_ability_color(Color.YELLOW)
	await get_tree().create_timer(2.0).timeout
	_speed_multiplier = 1.0
	if mesh_instance: mesh_instance.material_override = original_material

func _bot_shockwave(target: Node3D):
	ability_cooldowns[2] = character_class.ability_3_cooldown
	_flash_ability_color(Color.RED)
	
	if target and is_instance_valid(target):
		var push_dir = (target.global_position - global_position).normalized()
		if target.has_method("apply_knockback"):
			target.apply_knockback(push_dir * 15.0 + Vector3.UP * 5.0)
			
	await get_tree().create_timer(0.2).timeout
	if mesh_instance: mesh_instance.material_override = original_material

func _flash_ability_color(color: Color):
	if not mesh_instance: return
	var mat = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emissive = color
	mat.emissive_energy = 2.0
	mesh_instance.material_override = mat

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

func _spawn_death_debris():
	var debris_count = 6
	for i in range(debris_count):
		var debris = RigidBody3D.new()
		var mesh_inst = MeshInstance3D.new()
		var col_shape = CollisionShape3D.new()
		
		var box_mesh = BoxMesh.new()
		var box_shape = BoxShape3D.new()
		
		# Theme differences!
		var mat = StandardMaterial3D.new()
		if faction == 0: # Apes
			box_mesh.size = Vector3(0.15, 0.15, 0.15)
			box_shape.size = Vector3(0.15, 0.15, 0.15)
			mat.albedo_color = Color.BURLYWOOD # Brown/yarn
		else: # Aliens
			box_mesh.size = Vector3(0.1, 0.1, 0.2) # Flat metal scraps
			box_shape.size = Vector3(0.1, 0.1, 0.2)
			mat.albedo_color = Color.LIGHT_GRAY
			mat.emissive = Color.CYAN
			mat.emissive_energy = 0.5
			
		mesh_inst.mesh = box_mesh
		mesh_inst.material_override = mat
		col_shape.shape = box_shape
		
		debris.add_child(mesh_inst)
		debris.add_child(col_shape)
		
		# 1. ADD TO TREE FIRST! 
		get_tree().root.add_child(debris)
		
		# 2. NOW set the position and velocity!
		# Spawn at the bot's chest
		debris.global_position = global_position + Vector3(0, 0.5, 0)
		# Add some random offset so they don't spawn perfectly inside each other
		debris.global_position += Vector3(randf_range(-0.3, 0.3), 0, randf_range(-0.3, 0.3))
		
		# Set velocity directly for the explosion
		var explosion_dir = Vector3(randf_range(-1, 1), randf_range(1, 3), randf_range(-1, 1))
		debris.linear_velocity = explosion_dir * 5.0
		
		# Clean up after 3 seconds so we don't lag the game
		get_tree().create_timer(3.0).timeout.connect(debris.queue_free)
