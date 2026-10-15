extends Node

signal score_updated(team_alpha_score: int, team_bravo_score: int)
signal game_won(winning_team: int)
signal objective_updated(active_point_order: int)
signal match_timer_updated(time_left: float)
signal match_state_changed(new_state: String) # For Countdown, Playing, Overtime

var team_alpha_score: int = 0
var team_bravo_score: int = 0
var score_to_win: int = 3 

var attacking_team: int = 0
var defending_team: int = 1

var capture_points: Array = []
var current_point_index: int = 0
var active_capture_point: Node3D = null

# --- Timer Variables ---
var match_time_limit: float = 300.0 # 5 minutes
var match_time_left: float = 300.0
var is_match_playing: bool = false
var is_overtime: bool = false

func _process(delta):
	if not is_match_playing:
		return
		
	if not is_overtime:
		match_time_left -= delta
		match_timer_updated.emit(match_time_left)
		
		if match_time_left <= 0.0:
			# Time ran out! Check for Overtime
			_check_overtime()
			
	else:
		# In Overtime: Timer stays at 0, but we must constantly check if the condition is broken
		_check_overtime()

func _check_overtime():
	if active_capture_point and active_capture_point.is_contested:
		if not is_overtime:
			is_overtime = true
			match_state_changed.emit("OVERTIME")
			match_time_left = 0.0
			match_timer_updated.emit(0.0)
	else:
		is_overtime = false
		is_match_playing = false
		match_state_changed.emit("TIME_UP")
		
		# The Defending team wins if time runs out!
		game_won.emit(defending_team)
		await get_tree().create_timer(2.0).timeout
		get_tree().change_scene_to_file("res://round_end.tscn")

func _ready():
	# Autoloads run on boot. We do nothing here because the level isn't loaded yet.
	pass

func initialize_level():
	# Reset scores and arrays for a fresh match
	team_alpha_score = 0
	team_bravo_score = 0
	current_point_index = 0
	capture_points.clear()
	match_time_left = match_time_limit
	is_match_playing = false
	is_overtime = false
	
	# Wait a frame so the level nodes are fully loaded
	await get_tree().process_frame
	
	# Find all capture points and sort them by their 'point_order' export
	var points = get_tree().get_nodes_in_group("capture_points")
	for p in points:
		if not p.point_captured.is_connected(_on_point_captured):
			p.point_captured.connect(_on_point_captured)
			
	capture_points.assign(points)
	capture_points.sort_custom(func(a, b): return a.point_order < b.point_order)
	
	# Unlock the first point!
	if capture_points.size() > 0:
		capture_points[0].is_active = true
		active_capture_point = capture_points[0]
		objective_updated.emit(capture_points[0].point_order)
		
	# Determine Attacker/Defender based on player choice
	attacking_team = PlayerSetup.selected_faction
	if attacking_team == 0:
		defending_team = 1
	else:
		defending_team = 0
		
	score_updated.emit(team_alpha_score, team_bravo_score)

func start_match_countdown():
	# --- START COUNTDOWN ---
	match_state_changed.emit("3")
	await get_tree().create_timer(1.0).timeout
	match_state_changed.emit("2")
	await get_tree().create_timer(1.0).timeout
	match_state_changed.emit("1")
	await get_tree().create_timer(1.0).timeout
	match_state_changed.emit("GO!")
	await get_tree().create_timer(0.5).timeout
	match_state_changed.emit("PLAYING")
	is_match_playing = true

func _on_point_captured(team: int):
	# Give a point to the team that captured it
	if team == 0:
		team_alpha_score += 1
	elif team == 1:
		team_bravo_score += 1
		
	score_updated.emit(team_alpha_score, team_bravo_score)
	
	# Check if the game is over
	if team_alpha_score >= score_to_win:
		game_won.emit(0)
		is_match_playing = false # Stop the timer!
		print("TEAM ALPHA WINS!")
		await get_tree().create_timer(2.0).timeout
		get_tree().change_scene_to_file("res://round_end.tscn")
		return
	elif team_bravo_score >= score_to_win:
		game_won.emit(1)
		print("TEAM BRAVO WINS!")
		await get_tree().create_timer(2.0).timeout
		get_tree().change_scene_to_file("res://round_end.tscn")
		return
		
	# Advance the frontline!
	if current_point_index < capture_points.size():
		current_point_index = team_alpha_score
		#print(current_point_index)
		capture_points[current_point_index].is_active = true
		active_capture_point = capture_points[current_point_index] # STORE IT
		objective_updated.emit(capture_points[current_point_index].point_order)
