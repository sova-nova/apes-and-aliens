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
	
	# 1. ADD TO TREE FIRST! (So _ready() runs and Godot knows they exist)
	add_child(player)
	
	# 2. NOW SET POSITION & ROTATION!
	var spawn_pos = GameManager.get_spawn_position(PlayerSetup.selected_faction)
	player.global_position = spawn_pos if spawn_pos.is_finite() else Vector3(0, 1.25, 0)
		
	# --- FACE THE BATTLEFIELD ---
	if GameManager and GameManager.active_capture_point:
		var target_pos = GameManager.active_capture_point.global_position
		var direction = target_pos - player.global_position
		direction.y = 0.0 
		
		if direction.length_squared() > 0.01:
			var target_transform = Transform3D().looking_at(direction, Vector3.UP)
			player.rotation.y = target_transform.basis.get_euler().y
			
			# If they are still consistently facing backwards, uncomment this:
			# player.rotation.y += PI
			
	# Ensure the camera is looking straight ahead, not tilted up/down
	if player.has_node("CameraPivot"):
		player.get_node("CameraPivot").rotation.x = 0.0
