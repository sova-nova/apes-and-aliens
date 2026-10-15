extends CharacterBody3D

@export var move_speed: float = 3.0
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D

func _ready():
	# Wait a couple of frames for the NavigationServer to fully initialize
	await get_tree().process_frame
	await get_tree().process_frame
	
	var agent_map = nav_agent.get_navigation_map()
	var is_map_active = NavigationServer3D.map_is_active(agent_map)
	var regions_on_map = NavigationServer3D.map_get_regions(agent_map)
	
	print("=== RUNTIME NAV DIAGNOSTICS ===")
	print("Agent is on Map ID: ", agent_map)
	print("Is Map Active? ", is_map_active)
	print("Number of NavRegions on this Map: ", regions_on_map.size())
	
	if regions_on_map.size() == 0:
		push_error("CRITICAL ERROR: The Agent cannot find the NavigationRegion3D! They are on different maps or the region failed to bake.")
	else:
		for region_rid in regions_on_map:
			print("Found Region RID: ", region_rid, " | Enabled: ", NavigationServer3D.region_get_enabled(region_rid))

func _physics_process(delta: float):
	if not is_on_floor():
		velocity.y -= gravity * delta

	var players = get_tree().get_nodes_in_group("players")
	if players.size() == 0:
		return
	var target = players[0]

	# Set the target
	nav_agent.target_position = target.global_position

	# --- NAVIGATION DIAGNOSTICS ---
	# Check if the agent thinks the target is reachable
	var is_reachable = nav_agent.is_target_reachable()
	var is_finished = nav_agent.is_navigation_finished()
	var target_pos = nav_agent.target_position
	var current_pos = global_position
	
	# Print every 30 frames so it doesn't spam insanely
	if Engine.get_process_frames() % 30 == 0:
		print("=== DUMMY BOT DIAGNOSTICS ===")
		print("Bot Pos: ", current_pos)
		print("Target Pos: ", target_pos)
		print("Is Target Reachable? ", is_reachable)
		print("Is Navigation Finished? ", is_finished)

	# Move along the path
	if not is_finished:
		var next_pos = nav_agent.get_next_path_position()
		var direction = (next_pos - current_pos)
		direction.y = 0.0 
		
		if direction.length() > 0.05:
			direction = direction.normalized()
			velocity.x = direction.x * move_speed
			velocity.z = direction.z * move_speed
			rotation.y = atan2(-direction.x, -direction.z)
		else:
			velocity.x = move_toward(velocity.x, 0, move_speed)
			velocity.z = move_toward(velocity.z, 0, move_speed)
	else:
		velocity.x = move_toward(velocity.x, 0, move_speed)
		velocity.z = move_toward(velocity.z, 0, move_speed)

	move_and_slide()
