extends Node

signal score_updated(team_alpha_score: int, team_bravo_score: int)
signal game_won(winning_team: int)
signal objective_updated(active_point_order: int)

var team_alpha_score: int = 0
var team_bravo_score: int = 0
var score_to_win: int = 3 # First to capture 3 points wins!

var capture_points: Array = []
var current_point_index: int = 0

func _ready():
	# Autoloads run on boot. We do nothing here because the level isn't loaded yet.
	pass

func setup_level():
	# Reset scores for a new match
	team_alpha_score = 0
	team_bravo_score = 0
	current_point_index = 0
	capture_points.clear()
	
	# Wait a frame so the level nodes are fully loaded
	await get_tree().process_frame
	
	# Find all capture points and sort them by their 'point_order' export
	var points = get_tree().get_nodes_in_group("capture_points")
	for p in points:
		# Disconnect any old signals just in case, then connect
		if not p.point_captured.is_connected(_on_point_captured):
			p.point_captured.connect(_on_point_captured)
			
	capture_points.assign(points)
	capture_points.sort_custom(func(a, b): return a.point_order < b.point_order)
	
	# Unlock the first point!
	if capture_points.size() > 0:
		capture_points[0].is_active = true
		objective_updated.emit(capture_points[0].point_order)
		
	# Update HUD with 0 - 0 score
	score_updated.emit(team_alpha_score, team_bravo_score)

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
	current_point_index += 1
	if current_point_index < capture_points.size():
		capture_points[current_point_index].is_active = true
		objective_updated.emit(capture_points[current_point_index].point_order)
