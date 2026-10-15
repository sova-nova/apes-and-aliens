extends Node3D

# Preload the player scene so we can instance it
var player_scene = preload("res://player.tscn")

func _ready():
	HUD.visible = true
	
	# 1. Find the capture points so the player knows where to look
	await GameManager.initialize_level()
	
	# 2. Spawn the player immediately (They can look around, but not move/shoot)
	_spawn_player()
	
	# 3. Start the 3-2-1-GO countdown (Unfreezes the player when it finishes)
	GameManager.start_match_countdown()

func _spawn_player():
	var player = player_scene.instantiate()
	
	var spawn_group = "team_alpha_spawns" if PlayerSetup.selected_faction == 0 else "team_bravo_spawns"
	var spawns = get_tree().get_nodes_in_group(spawn_group)
	
	if spawns.size() > 0:
		var chosen_spawn = spawns.pick_random()
		if chosen_spawn.has_method("get_random_point_inside"):
			player.global_position = chosen_spawn.get_random_point_inside()
		else:
			player.global_position = chosen_spawn.global_position
	else:
		player.global_position = Vector3(0, 1.25, 0) 
		
	# --- FACE THE BATTLEFIELD ---
	# If there is an active capture point, rotate the player to face it!
	if GameManager and GameManager.active_capture_point:
		var target_pos = GameManager.active_capture_point.global_position
		var direction = target_pos - player.global_position
		direction.y = 0.0 # Ignore vertical differences
		
		if direction.length_squared() > 0.01:
			# atan2 calculates the exact Y rotation needed to face a direction
			player.rotation.y = atan2(-direction.x, -direction.z)
		
	add_child(player)
