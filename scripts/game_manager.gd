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
	# Wait a frame so the level nodes are fully loaded
	await get_tree().process_frame
	
	# Find all capture points and sort them by their 'point_order' export
	var points = get_tree().get_nodes_in_group("capture_points")
	for p in points:
		p.point_captured.connect(_on_point_captured)
	capture_points.assign(points)
	capture_points.sort_custom(func(a, b): return a.point_order < b.point_order)
	
	# Unlock the first point!
	if capture_points.size() > 0:
		capture_points[0].is_active = true
		objective_updated.emit(capture_points[0].point_order)

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
		get_tree().paused = true
		return
	elif team_bravo_score >= score_to_win:
		game_won.emit(1)
		print("TEAM BRAVO WINS!")
		get_tree().paused = true
		return
		
	# Advance the frontline!
	current_point_index += 1
	if current_point_index < capture_points.size():
		capture_points[current_point_index].is_active = true
		objective_updated.emit(capture_points[current_point_index].point_order)
