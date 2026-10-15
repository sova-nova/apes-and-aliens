extends Area3D

@export var point_name: String = "A"
@export var capture_speed: float = 20.0
@export var score_tick_time: float = 1.0
@export var point_order: int = 0 # 0 for A, 1 for B, 2 for C

var is_active: bool = false
signal point_captured(team: int)

var capture_progress: float = 0.0
var controlling_team: int = -1 # -1 = Neutral, 0 = Alpha, 1 = Bravo
var _tick_timer: float = 0.0
var is_contested: bool = false

@onready var status_label: Label3D = $StatusLabel
@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D

func _ready():
	update_visuals()

func _physics_process(delta: float):
	var alpha_players = 0
	var bravo_players = 0
	
	# If the point is locked (previous point not captured), do nothing
	if not is_active:
		update_ui() # Keep UI updated to show it's locked
		return

	# Look at everyone standing on the point
	for body in get_overlapping_bodies():
		if "faction" in body:
			if body.faction == 0: # TEAM_ALPHA
				alpha_players += 1
			elif body.faction == 1: # TEAM_BRAVO
				bravo_players += 1

	# Check if the contested state has changed
	var was_contested = is_contested
	is_contested = (alpha_players > 0 and bravo_players > 0)
	
	# If it just became contested, or just stopped being contested, update the color
	if was_contested != is_contested:
		update_visuals()

	# Only allow progress to change if the point is NOT contested
	if not is_contested:
		var net_force = alpha_players - bravo_players

		if net_force != 0:
			capture_progress += net_force * capture_speed * delta
			capture_progress = clamp(capture_progress, -100.0, 100.0)

		# Check if a team has fully captured it
		var new_controlling_team = controlling_team
		#if capture_progress >= 100.0:
			#new_controlling_team = 0
		#elif capture_progress <= -100.0:
			#new_controlling_team = 1
		#elif abs(capture_progress) < 1.0:
			#new_controlling_team = -1
			
		if capture_progress >= 100.0:
			new_controlling_team = 0
			if controlling_team != 0: # Only emit the signal the moment it flips
				AudioManager.play_capture()
				point_captured.emit(0)
				is_active = false # Lock the point so it can't be recaptured
		elif capture_progress <= -100.0:
			new_controlling_team = 1
			if controlling_team != 1:
				point_captured.emit(1)
				is_active = true

		# If control changed, update the color
		if new_controlling_team != controlling_team:
			controlling_team = new_controlling_team
			update_visuals()

	# Update the UI text
	update_ui()

	# Only give points if the point is owned AND NOT contested
	#if controlling_team != -1 and not is_contested:
		#_tick_timer -= delta
		#if _tick_timer <= 0.0:
			#_tick_timer = score_tick_time
			#GameManager.add_score(controlling_team, 1)

func update_ui():
	if not status_label:
		return
	
	if not is_active and controlling_team == -1:
		status_label.text = "Point %s\n[LOCKED]" % point_name
		return
	
	# Override text if contested
	if is_contested:
		status_label.text = "Point %s\n[CONTESTED]" % point_name
		return

	var team_name = "Neutral"
	if controlling_team == 0:
		team_name = "Alpha"
	elif controlling_team == 1:
		team_name = "Bravo"
	
	var progress_display = int(abs(capture_progress))
	status_label.text = "Point %s [%s]\n%d%%" % [point_name, team_name, progress_display]

func update_visuals():
	if not mesh_instance:
		return
	var mat = StandardMaterial3D.new()
	
	# Turn Yellow if contested, otherwise revert to normal team colors
	if is_contested:
		mat.albedo_color = Color.YELLOW
	elif controlling_team == 0:
		mat.albedo_color = Color.DODGER_BLUE
	elif controlling_team == 1:
		mat.albedo_color = Color.RED
	else:
		if is_active:
			mat.albedo_color = Color.WHITE
		else:
			mat.albedo_color = Color.DIM_GRAY # Grayed out if locked and neutral
		
	mat.roughness = 0.8
	mesh_instance.material_override = mat
	
func get_random_point_inside() -> Vector3:
	# If we don't have a collision shape, just return the center
	if not collision_shape or not collision_shape.shape:
		return global_position
		
	var shape = collision_shape.shape
	
	# Check if it's a Cylinder (which we used for the capture point)
	if shape is CylinderShape3D:
		var radius = shape.radius
		# Pick a random angle (0 to 360 degrees / 0 to TAU radians)
		var angle = randf() * TAU
		# Pick a random distance from the center. 
		# We use sqrt(randf()) to ensure they spread out evenly across the circle, 
		# instead of clumping heavily in the very middle.
		var distance = sqrt(randf()) * radius
		
		# Calculate the X and Z offset
		var offset_x = cos(angle) * distance
		var offset_z = sin(angle) * distance
		
		return global_position + Vector3(offset_x, 0, offset_z)
		
	# Fallback if the shape isn't a cylinder
	return global_position
