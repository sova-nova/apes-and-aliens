extends CharacterBody3D

enum Faction { TEAM_ALPHA, TEAM_BRAVO }

@export var faction: Faction = Faction.TEAM_ALPHA
@export var mouse_sensitivity: float = 0.003
@export var jump_velocity: float = 4.5
@export var character_class: CharacterClass:
	set(value):
		character_class = value
		if is_node_ready():
			apply_class()

@export var available_classes: Array[CharacterClass] = []

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var speed: float = 5.0
var max_health: float = 100.0
var current_health: float
var is_alive: bool = true

var _can_shoot: bool = true
var _shoot_cooldown: float = 0.0
var current_ammo: int = 30
var max_ammo: int = 30
var is_reloading: bool = false
var reload_timer: float = 0.0

var _heal_cooldown_timer: float = 0.0
var ability_cooldowns: Array[float] = [0.0, 0.0, 0.0]
var _is_overcharged: bool = false
var _overcharge_timer: float = 0.0
var _is_siphoning: bool = false
var _siphon_target: Node3D = null
var _siphon_timer: float = 0.0
var _siphon_tick_timer: float = 0.5
var _siphon_light: OmniLight3D = null
var _is_target_locking: bool = false
var _target_locked_enemy: Node3D = null
var _target_lock_timer: float = 0.0
var _target_lock_light: OmniLight3D = null
var _is_grappling: bool = false
var _grapple_target: Vector3 = Vector3.ZERO
var _grapple_timer: float = 0.0
var _is_bulwark_active: bool = false
var _bulwark_timer: float = 0.0
var _damage_reduction_multiplier: float = 1.0 # 1.0 is normal, 0.5 is half damage
var _is_adrenaline_boosted: bool = false # <-- ADD THESE
var _adrenaline_timer: float = 0.0
var _is_dashing: bool = false
var _dash_timer: float = 0.0
var _is_invulnerable: bool = false
var _dash_direction: Vector3 = Vector3.ZERO # <-- ADD THIS

@onready var camera_pivot: Node3D = $CameraPivot
@onready var camera_3d: Camera3D = $CameraPivot/SpringArm3D/Camera3D
@onready var aim_ray: RayCast3D = $CameraPivot/SpringArm3D/Camera3D/AimRay
@onready var gun_model: MeshInstance3D = $CameraPivot/GunModel
@onready var muzzle: Marker3D = $CameraPivot/GunModel/Muzzle
@onready var muzzle_flash: OmniLight3D = $CameraPivot/GunModel/Muzzle/MuzzleFlash

signal health_changed(new_health: float, max_health: float)
signal died
signal ability_status_changed(slot: int, is_ready: bool, time_left: float)
signal class_changed(new_class_name: String)


func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	aim_ray.add_exception(self)
	add_to_group("players")
	if muzzle_flash:
		muzzle_flash.light_energy = 0.0
	
	# --- APPLY SETUP DATA ---
	faction = PlayerSetup.selected_faction
	if available_classes.size() > PlayerSetup.selected_class_index:
		character_class = available_classes[PlayerSetup.selected_class_index]
		
	apply_class()

func apply_class():
	if not character_class:
		return
		
	# Apply Stats
	speed = character_class.move_speed
	max_health = character_class.max_health
	current_health = max_health # Refill health on class swap
	_is_overcharged = false
	current_ammo = character_class.mag_size
	max_ammo = character_class.mag_size
	is_reloading = false
	
	# Apply Weapon Stats
	if aim_ray:
		aim_ray.target_position = Vector3(0, 0, -character_class.gun_range)
		
	# Reset Cooldowns
	ability_cooldowns = [0.0, 0.0, 0.0]
	_shoot_cooldown = 0.0
	
	# Tell the HUD to update
	class_changed.emit(character_class.class_name_str)
	health_changed.emit(current_health, max_health)

func _unhandled_input(event: InputEvent):
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * mouse_sensitivity)
		camera_pivot.rotate_x(-event.relative.y * mouse_sensitivity)
		camera_pivot.rotation.x = clamp(camera_pivot.rotation.x, -1.2, 1.2)

	if event.is_action_pressed("ui_cancel"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			
func _apply_screen_shake(amount: float = 0.05):
	var tween = create_tween()
	tween.tween_property(camera_3d, "h_offset", randf_range(-amount, amount), 0.05)
	tween.tween_property(camera_3d, "h_offset", 0.0, 0.05)
	tween.parallel().tween_property(camera_3d, "v_offset", randf_range(-amount, amount), 0.05)
	tween.parallel().tween_property(camera_3d, "v_offset", 0.0, 0.05)

func _physics_process(delta: float):
	# --- MATCH COUNTDOWN GATE ---
	# If the match hasn't started yet, don't allow movement or shooting!
	if not GameManager.is_match_playing:
		# Still apply gravity so we stay on the floor
		if not is_on_floor():
			velocity.y -= gravity * delta
		move_and_slide()
		return # Stop right here, don't process movement or shooting!
	
	# --- Shoot cooldown ---
	if not _can_shoot:
		_shoot_cooldown -= delta
		if _shoot_cooldown <= 0.0:
			_can_shoot = true

	# --- Shooting ---
	if Input.is_action_pressed("shoot") \
		and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED \
		and _can_shoot:
		shoot()
		
	# --- Reload Logic ---
	if is_reloading:
		reload_timer -= delta
		if reload_timer <= 0.0:
			is_reloading = false
			current_ammo = max_ammo
	
	# Update HUD Ammo
	HUD.update_ammo(current_ammo, max_ammo, is_reloading)
			
	if Input.is_action_just_pressed("reload") and not is_reloading and current_ammo < max_ammo:
		is_reloading = true
		reload_timer = character_class.reload_time

	# --- Gravity ---
	if not is_on_floor():
		velocity.y -= gravity * delta

	# --- Jump ---
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity

	## --- Movement ---
	#var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	#var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
#
	#if direction:
		#velocity.x = direction.x * speed
		#velocity.z = direction.z * speed
	#else:
		#velocity.x = move_toward(velocity.x, 0, speed)
		#velocity.z = move_toward(velocity.z, 0, speed)
#
	#move_and_slide()
	
	# --- Handle Adrenaline Timer ---
	if _is_adrenaline_boosted:
		_adrenaline_timer -= delta
		if _adrenaline_timer <= 0.0:
			_is_adrenaline_boosted = false
			
	# --- Handle Bulwark Timer ---
	if _is_bulwark_active:
		_bulwark_timer -= delta
		if _bulwark_timer <= 0.0:
			_is_bulwark_active = false
			_damage_reduction_multiplier = 1.0 # Return to taking full damage
			
	# --- Handle Target Lock Timer ---
	if _is_target_locking:
		_target_lock_timer -= delta
		# End if timer runs out, or the enemy dies/disappears
		if _target_lock_timer <= 0.0 or not is_instance_valid(_target_locked_enemy):
			_end_target_lock()
			
	# --- Handle Life Siphon ---
	if _is_siphoning:
		_siphon_timer -= delta
		
		# Break the tether if time runs out, enemy dies, or they get too far away (10 meters)
		var distance_to_target = INF
		if is_instance_valid(_siphon_target):
			distance_to_target = global_position.distance_to(_siphon_target.global_position)
			
		if _siphon_timer <= 0.0 or not is_instance_valid(_siphon_target) or distance_to_target > 10.0:
			_end_siphon()
		else:
			# Handle damage/heal ticks
			_siphon_tick_timer -= delta
			if _siphon_tick_timer <= 0.0:
				_siphon_tick()
	
	# --- Movement & Dashing ---
	if _is_dashing:
		_dash_timer -= delta
		velocity.x = _dash_direction.x * speed * 6.0
		velocity.z = _dash_direction.z * speed * 6.0
		
		if _dash_timer <= 0.0:
			_is_dashing = false
			_is_invulnerable = false
			
	elif _is_grappling:
		_grapple_timer -= delta
		# Launch us toward the target point at high speed
		var direction_to_target = global_position.direction_to(_grapple_target)
		velocity = direction_to_target * speed * 5.0 # Grapple speed
		
		# Stop grappling if we get close to the target, or time runs out
		if global_position.distance_to(_grapple_target) < 1.5 or _grapple_timer <= 0.0:
			_is_grappling = false
			
	else:
		# Standard WASD Movement (Only runs if NOT dashing or grappling)
		var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
		var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
		
		# Calculate current speed (Halved if overcharged, boosted if adrenaline)
		var current_speed = speed
		if _is_overcharged:
			current_speed *= 0.5
		if _is_adrenaline_boosted:
			current_speed *= 1.5

		if direction:
			velocity.x = direction.x * current_speed
			velocity.z = direction.z * current_speed
		else:
			velocity.x = move_toward(velocity.x, 0, current_speed)
			velocity.z = move_toward(velocity.z, 0, current_speed)

	move_and_slide()
	
	# --- Class Swapping Logic (For Testing) ---
	if Input.is_action_just_pressed("class_1"):
		swap_class(0)
	elif Input.is_action_just_pressed("class_2"):
		swap_class(1)
	elif Input.is_action_just_pressed("class_3"):
		swap_class(2)
	
		# --- Ability Logic ---
	for i in range(3):
		if ability_cooldowns[i] > 0:
			ability_cooldowns[i] -= delta
		ability_status_changed.emit(i, ability_cooldowns[i] <= 0.0, ability_cooldowns[i])
		
	if Input.is_action_just_pressed("ability_1") and ability_cooldowns[0] <= 0.0:
		_use_ability(0)
	elif Input.is_action_just_pressed("ability_2") and ability_cooldowns[1] <= 0.0:
		_use_ability(1)
	elif Input.is_action_just_pressed("ability_3") and ability_cooldowns[2] <= 0.0:
		_use_ability(2)
		
	## --- Handle Phase Dash Movement ---
	#if _is_dashing:
		#_dash_timer -= delta
		## Maintain high speed during dash
		#var dash_dir = -global_transform.basis.z
		#velocity.x = dash_dir.x * speed * 4.0
		#velocity.z = dash_dir.z * speed * 4.0
		#if _dash_timer <= 0.0:
			#_is_dashing = false
			#_is_invulnerable = false

# ─── Shooting ───────────────────────────────────────────────

func shoot():
	# 1. Calculate base modified stats
	var current_fire_rate = character_class.fire_rate
	var current_gun_damage = character_class.gun_damage
	
	if current_ammo <= 0 or is_reloading:
		# Auto-reload if empty
		if not is_reloading:
			is_reloading = true
			reload_timer = character_class.reload_time
		return
		
	current_ammo -= 1
	
	if _is_overcharged:
		current_fire_rate *= 0.5 # Halved cooldown = Double fire rate!
		current_gun_damage *= 1.5 # 50% more damage!
	
	_can_shoot = false
	_shoot_cooldown = current_fire_rate

	_flash_muzzle()
	AudioManager.play_shoot(muzzle.global_position)
	_apply_screen_shake(0.1)

	aim_ray.force_raycast_update()

	var origin: Vector3 = muzzle.global_position if muzzle else camera_3d.global_position
	var end_point: Vector3

	if aim_ray.is_colliding():
		var collider = aim_ray.get_collider()
		end_point = aim_ray.get_collision_point()
		var normal = aim_ray.get_collision_normal()

		# 2. Target Lock 30% damage boost (Now collider exists!)
		if _is_target_locking and is_instance_valid(_target_locked_enemy) and collider == _target_locked_enemy:
			current_gun_damage *= 1.3

		if collider.has_method("take_damage"):
			# --- Friendly Fire Check ---
			# Only deal damage if they are NOT on our team
			var is_enemy = true
			if "faction" in collider:
				if collider.faction == faction:
					is_enemy = false # They are on our team, don't hurt them!
			
			if is_enemy:
				collider.take_damage(current_gun_damage, faction)
				
				if collider.has_method("spawn_damage_number"):
					collider.spawn_damage_number(current_gun_damage)
				
				HUD.show_hit_marker()

		_spawn_hit_effect(end_point, normal)
	else:
		end_point = aim_ray.global_position + (-aim_ray.global_transform.basis.z * character_class.gun_range)

	_spawn_tracer(origin, end_point)

func _flash_muzzle():
	if not muzzle_flash:
		return
	muzzle_flash.light_energy = 4.0
	var tween = create_tween()
	tween.tween_property(muzzle_flash, "light_energy", 0.0, 0.08)

func _spawn_tracer(from: Vector3, to: Vector3):
	var tracer = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = 0.04
	sphere.height = 0.08
	tracer.mesh = sphere

	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.85, 0.3)
	mat.emissive = Color(1.0, 0.6, 0.1)
	mat.emissive_energy = 4.0
	tracer.material_override = mat

	get_tree().root.add_child(tracer)
	tracer.global_position = from

	var tween = create_tween()
	tween.tween_property(tracer, "global_position", to, 0.06)
	tween.tween_callback(tracer.queue_free)

func _spawn_hit_effect(pos: Vector3, normal: Vector3):
	var spark = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = 0.06
	sphere.height = 0.12
	spark.mesh = sphere

	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.5, 0.1)
	mat.emissive = Color(1.0, 0.3, 0.0)
	mat.emissive_energy = 4.0
	spark.material_override = mat

	spark.global_position = pos + normal * 0.02
	get_tree().root.add_child(spark)
	await get_tree().create_timer(0.12).timeout
	spark.queue_free()

# ─── Ability System ────────────────────────────────────────

func _use_ability(slot: int):
	var ability_type = CharacterClass.AbilityType.NONE
	var cooldown_time = 0.0
	
	if slot == 0:
		ability_type = character_class.ability_1_type
		cooldown_time = character_class.ability_1_cooldown
	elif slot == 1:
		ability_type = character_class.ability_2_type
		cooldown_time = character_class.ability_2_cooldown
	elif slot == 2:
		ability_type = character_class.ability_3_type
		cooldown_time = character_class.ability_3_cooldown
		
	if ability_type == CharacterClass.AbilityType.NONE:
		return
		
	# --- Target Validation ---
	if ability_type == CharacterClass.AbilityType.GRAPPLE_HOOK:
		aim_ray.force_raycast_update()
		if not aim_ray.is_colliding():
			return 
	elif ability_type == CharacterClass.AbilityType.TARGET_LOCK:
		aim_ray.force_raycast_update()
		if not aim_ray.is_colliding() or not aim_ray.get_collider().has_method("take_damage"):
			return
	elif ability_type == CharacterClass.AbilityType.LIFE_SIPHON:
		aim_ray.force_raycast_update()
		# 1. Must hit an enemy
		if not aim_ray.is_colliding() or not aim_ray.get_collider().has_method("take_damage"):
			return
		# 2. Must be within 10 meters!
		var distance_to_target = global_position.distance_to(aim_ray.get_collision_point())
		if distance_to_target > 10.0:
			return # Too far away! Cancel the ability, no cooldown penalty.
		
	ability_cooldowns[slot] = cooldown_time
	
	# Route to the correct function
	match ability_type:
		CharacterClass.AbilityType.PHASE_DASH:
			_phase_dash()
		CharacterClass.AbilityType.OVERCHARGE:
			_overcharge()
		CharacterClass.AbilityType.ADRENALINE_SPIKE:
			_adrenaline_spike()
		CharacterClass.AbilityType.DEPLOY_COVER:
			_deploy_cover()
		CharacterClass.AbilityType.BULWARK:
			AudioManager.play_bulwark(global_position)
			_bulwark_ability()
		CharacterClass.AbilityType.SHOCKWAVE:
			_shockwave()
		CharacterClass.AbilityType.GRAPPLE_HOOK:
			_grapple_hook()
		CharacterClass.AbilityType.TARGET_LOCK:
			_target_lock()
		CharacterClass.AbilityType.LIFE_SIPHON:
			_life_siphon()

func take_damage(amount: float, _source_faction: int = -1):
	if _is_invulnerable:
		return # Can't take damage while dashing!
		
	# Apply damage reduction multiplier (1.0 normal, 0.5 if Bulwark is active)
	var final_damage = amount * _damage_reduction_multiplier
	
	current_health = max(0.0, current_health - final_damage)
	health_changed.emit(current_health, max_health)
	
	# Interactions
	AudioManager.play_hit(global_position)
	_apply_screen_shake(0.2)
	
	if current_health <= 0.0:
		died.emit()
		_handle_death()

# --- Specific Ability Implementations ---

func _phase_dash():
	_is_dashing = true
	_is_invulnerable = true
	_dash_timer = 0.25 # Increased from 0.2 to 0.25 for a longer dash distance
	
	# Determine dash direction based on current input
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var move_direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	# If the player is moving, dash in that direction. If standing still, dash forward.
	if move_direction != Vector3.ZERO:
		_dash_direction = move_direction
	else:
		_dash_direction = -global_transform.basis.z # Forward
	
	# Visual: Make player slightly transparent by overriding the material
	var ghost_mat = StandardMaterial3D.new()
	ghost_mat.albedo_color = Color(1, 1, 1, 0.3) # 30% opacity
	ghost_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ghost_mat.emissive = Color(0.5, 0.5, 1.0) # Add a slight blue glow
	$MeshInstance3D.material_override = ghost_mat
	
	# We use a one-shot timer to reset the visual, independent of the physics timer
	get_tree().create_timer(0.25).timeout.connect(func():
		if is_instance_valid(self) and is_node_ready():
			$MeshInstance3D.material_override = null
	)

func _overcharge():
	_is_overcharged = true
	
	# Visuals: Make the gun glow red/orange to indicate it's active
	if gun_model:
		var overcharge_mat = StandardMaterial3D.new()
		overcharge_mat.albedo_color = Color.ORANGE_RED
		overcharge_mat.emissive = Color.RED
		overcharge_mat.emissive_energy = 2.0
		gun_model.material_override = overcharge_mat
		
	# End the effect after 4 seconds
	get_tree().create_timer(4.0).timeout.connect(_end_overcharge)

func _end_overcharge():
	if is_instance_valid(self) and is_node_ready():
		_is_overcharged = false
		
		# Reset gun visuals
		if gun_model:
			gun_model.material_override = null

func _adrenaline_spike():
	# 1. Cost 20 HP. We clamp it to 1 HP so you can't accidentally kill yourself with it.
	var hp_cost = 20.0
	current_health = max(1.0, current_health - hp_cost)
	health_changed.emit(current_health, max_health)
	
	# 2. Reset Cooldowns for Dash (Slot 0) and Overcharge (Slot 1)
	ability_cooldowns[0] = 0.0
	ability_cooldowns[1] = 0.0
	
	# 3. Apply 2-second speed boost
	_is_adrenaline_boosted = true
	_adrenaline_timer = 2.0
	
	# 4. Visual: Brief yellow flash on the player to indicate the sacrifice
	var flash_mat = StandardMaterial3D.new()
	flash_mat.albedo_color = Color.YELLOW
	flash_mat.emissive = Color.YELLOW
	flash_mat.emissive_energy = 4.0
	$MeshInstance3D.material_override = flash_mat
	
	get_tree().create_timer(0.15).timeout.connect(func():
		if is_instance_valid(self) and is_node_ready():
			$MeshInstance3D.material_override = null
	)

func _deploy_cover():
	# 1. Find out where the player is aiming
	aim_ray.force_raycast_update()
	
	var target_position: Vector3
	
	if aim_ray.is_colliding():
		target_position = aim_ray.get_collision_point()
	else:
		# If aiming at the sky, place it 10 meters forward along the camera ray
		target_position = aim_ray.global_position + (-aim_ray.global_transform.basis.z * 10.0)
		
	# 2. Keep the wall grounded on the floor (assuming floor is at Y=0)
	target_position.y = 0.0
	
	# 3. Create the wall
	var wall = StaticBody3D.new()
	var col = CollisionShape3D.new()
	var box_shape = BoxShape3D.new()
	
	var wall_width = 3.0
	var wall_height = 2.0
	var wall_depth = 0.2
	
	box_shape.size = Vector3(wall_width, wall_height, wall_depth)
	col.shape = box_shape
	
	var mesh_inst = MeshInstance3D.new()
	var box_mesh = BoxMesh.new()
	box_mesh.size = Vector3(wall_width, wall_height, wall_depth)
	mesh_inst.mesh = box_mesh
	
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.6, 1.0, 0.5) # Semi-transparent blue
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emissive = Color(0.1, 0.3, 0.8)
	mat.emissive_energy = 0.5
	mesh_inst.material_override = mat
	
	wall.add_child(col)
	wall.add_child(mesh_inst)
	
	# 4. Position it so the bottom touches the floor
	wall.global_position = target_position + Vector3.UP * (wall_height / 2.0)
	
	# 5. Rotate it so the flat face is perpendicular to the camera's line of sight
	# We use the camera's right-ward vector to orient the wall perfectly.
	var cam_right = camera_3d.global_transform.basis.z
	cam_right.y = 0 # Keep it flat on the ground
	cam_right = cam_right.normalized()
	
	if cam_right.length_squared() > 0.001:
		wall.rotation.y = atan2(cam_right.x, cam_right.z)
	else:
		wall.rotation.y = global_rotation.y # Fallback if looking straight up/down
	
	get_tree().root.add_child(wall)
	
	# 6. CRITICAL: Make the player's aim ray ignore the wall so we can shoot through it!
	aim_ray.add_exception(wall)
	
	# 7. Wall destroys itself after 6 seconds
	wall.get_tree().create_timer(6.0).timeout.connect(func():
		if is_instance_valid(wall):
			# Clean up the exception just to be tidy, though queue_free handles it mostly
			if is_instance_valid(self) and aim_ray:
				aim_ray.remove_exception(wall)
			wall.queue_free()
	)
	
func _bulwark_ability():
	_is_bulwark_active = true
	_bulwark_timer = 4.0
	_damage_reduction_multiplier = 0.5 # 50% damage reduction
	
	# Visuals: Create% Create a glowing blue sphere aura
	var aura = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = 8
	sphere.height = 6
	aura.mesh = sphere

	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.6, 1.0, 0.15) # Very transparent blue
	mat.emissive = Color(0.2, 0.5, 1.0)
	mat.emissive_energy = 1.5
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED # So we can see the inside of the sphere
	aura.material_override = mat

	# Attach it to the player so it moves with us
	aura.position = Vector3(0, 0.75, 0) 
	add_child(aura)

	# End the effect after 4 seconds
	get_tree().create_timer(4.0).timeout.connect(func():
		if is_instance_valid(aura):
			aura.queue_free()
		if is_instance_valid(self):
			_is_bulwark_active = false
			_damage_reduction_multiplier = 1.0
	)

func _shockwave():
	# Get everyone on the battlefield
	var targets = []
	targets.append_array(get_tree().get_nodes_in_group("bots"))
	targets.append_array(get_tree().get_nodes_in_group("players"))
	
	for target in targets:
		if not is_instance_valid(target): continue
		if target == self: continue # Don't push yourself!
		
		# CRITICAL: Only push enemies, not allies!
		if "faction" in target and target.faction == self.faction:
			continue
			
		var dist = global_position.distance_to(target.global_position)
		if dist < 5.0:
			var push_dir = (target.global_position - global_position).normalized()
			if target.has_method("apply_knockback"):
				target.apply_knockback(push_dir * 15.0 + Vector3.UP * 5.0)
				
	# Visual: Expanding ring
	var ring = MeshInstance3D.new()
	var mesh = CylinderMesh.new()
	mesh.top_radius = 0.5
	mesh.bottom_radius = 0.5
	mesh.height = 0.2
	ring.mesh = mesh
	
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color.RED
	mat.emissive = Color.RED
	mat.emissive_energy = 4.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring.material_override = mat
	
	ring.global_position = global_position
	ring.rotation.x = PI / 2 # Lay flat
	get_tree().root.add_child(ring)
	
	var tween = ring.create_tween().set_parallel(true)
	tween.tween_property(mesh, "top_radius", 5.0, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(mesh, "bottom_radius", 5.0, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.3)
	tween.chain().tween_callback(ring.queue_free)
	
func _grapple_hook():
	# We already validated that the raycast is colliding in _use_ability
	_grapple_target = aim_ray.get_collision_point()
	
	# Nudge the target up slightly so we don't grind into the floor
	_grapple_target.y += 0.5 
		
	_is_grappling = true
	_grapple_timer = 0.4
	
	# Visual: Make the player flash cyan while flying
	var grapple_mat = StandardMaterial3D.new()
	grapple_mat.albedo_color = Color.CYAN
	grapple_mat.emissive = Color.CYAN
	grapple_mat.emissive_energy = 2.0
	$MeshInstance3D.material_override = grapple_mat
	
	get_tree().create_timer(0.4).timeout.connect(func():
		if is_instance_valid(self) and is_node_ready():
			$MeshInstance3D.material_override = null
	)
	
func _target_lock():
	_is_target_locking = true
	_target_locked_enemy = aim_ray.get_collider()
	_target_lock_timer = 5.0
	
	# Tell the enemy they are vulnerable (10% extra damage from all sources)
	if _target_locked_enemy.has_method("set_vulnerable"):
		_target_locked_enemy.set_vulnerable(true)
		
	# Visuals: Attach a red warning light to the enemy so you know who is locked
	_target_lock_light = OmniLight3D.new()
	_target_lock_light.light_color = Color.RED
	_target_lock_light.light_energy = 3.0
	_target_lock_light.omni_range = 3.0
	_target_lock_light.position = Vector3(0, 1.5, 0) # Above their head
	_target_locked_enemy.add_child(_target_lock_light)
	
func _end_target_lock():
	_is_target_locking = false
	
	# Remove the vulnerable debuff from the enemy
	if is_instance_valid(_target_locked_enemy) and _target_locked_enemy.has_method("set_vulnerable"):
		_target_locked_enemy.set_vulnerable(false)
		
	# Clean up the red light
	if is_instance_valid(_target_lock_light):
		_target_lock_light.queue_free()
		
	_target_locked_enemy = null
	
func _life_siphon():
	_is_siphoning = true
	_siphon_target = aim_ray.get_collider()
	_siphon_timer = 3.0
	_siphon_tick_timer = 0.5 # First tick happens after 0.5 seconds
	
	# Visuals: Turn the player purple to indicate siphoning
	var siphon_mat = StandardMaterial3D.new()
	siphon_mat.albedo_color = Color.MEDIUM_PURPLE
	siphon_mat.emissive = Color.PURPLE
	siphon_mat.emissive_energy = 2.0
	$MeshInstance3D.material_override = siphon_mat
	
	# Visuals: Put a purple light on the enemy so you know who is tethered
	_siphon_light = OmniLight3D.new()
	_siphon_light.light_color = Color.PURPLE
	_siphon_light.light_energy = 4.0
	_siphon_light.omni_range = 3.0
	_siphon_light.position = Vector3(0, 1.0, 0)
	_siphon_target.add_child(_siphon_light)

func _siphon_tick():
	var siphon_damage = 8.0
	var siphon_heal = 8.0
	
	# Drain enemy
	if is_instance_valid(_siphon_target) and _siphon_target.has_method("take_damage"):
		_siphon_target.take_damage(siphon_damage, faction)
		
	# Heal self
	current_health = min(max_health, current_health + siphon_heal)
	health_changed.emit(current_health, max_health)
	
	# Reset tick timer
	_siphon_tick_timer = 0.5

func _end_siphon():
	_is_siphoning = false
	
	# Reset player visuals
	if is_instance_valid(self) and is_node_ready():
		$MeshInstance3D.material_override = null
		
	# Remove enemy light
	if is_instance_valid(_siphon_light):
		_siphon_light.queue_free()
		
	_siphon_target = null

# ─── Damageable ─────────────────────────────────────────────

func _handle_death():
	is_alive = false
	$CollisionShape3D.disabled = true # Make us physically invisible to raycasts
	visible = false
	process_mode = Node.PROCESS_MODE_DISABLED
	await get_tree().create_timer(3.0).timeout
	_respawn()

func _respawn():
	is_alive = true
	$CollisionShape3D.disabled = false # Re-enable our physical body
	current_health = max_health
	visible = true
	process_mode = Node.PROCESS_MODE_INHERIT
	
	# Find the correct spawn point group based on faction
	var spawn_group = "team_alpha_spawns" if faction == 0 else "team_bravo_spawns"
	var spawns = get_tree().get_nodes_in_group(spawn_group)
	
	if spawns.size() > 0:
		# Pick a random spawn point from the group
		global_position = spawns.pick_random().global_position
	else:
		# Fallback if no spawn points exist
		global_position = Vector3(0, 1.25, 0)
		
	health_changed.emit(current_health, max_health)
	
	# --- Spawn Protection ---
	_is_invulnerable = true
	var shield_mat = StandardMaterial3D.new()
	shield_mat.albedo_color = Color(1, 1, 1, 0.5) # Semi-transparent
	shield_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shield_mat.emissive = Color.CYAN # Glowing cyan shield
	shield_mat.emissive_energy = 2.0
	$MeshInstance3D.material_override = shield_mat
	
	# Remove shield after 2 seconds
	get_tree().create_timer(2.0).timeout.connect(func():
		if is_instance_valid(self) and is_node_ready():
			_is_invulnerable = false
			if not _is_dashing and not _is_siphoning: # Don't override other ability visuals
				$MeshInstance3D.material_override = null
	)

# ─── Class Swapping ──────────────────────────────────────────

func swap_class(index: int):
	#print("Swap class triggered for index: ", index)
	#print("Available classes array size: ", available_classes.size())
	
	if available_classes.size() > index and available_classes[index] != null:
		#print("Class found in array! Swapping to: ", available_classes[index].class_name_str)
		character_class = available_classes[index]
	else:
		print("ERROR: Array is empty, too small, or the slot is null!")
