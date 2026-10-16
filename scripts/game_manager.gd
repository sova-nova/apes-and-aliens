extends Node

signal score_updated(points_captured: int, total_points: int)
signal point_captured(point_index: int, capturing_team: int) # Used by gates etc.
signal game_won(winning_team: int)
signal objective_updated(active_point_order: int)
signal match_timer_updated(time_left: float)
signal match_state_changed(new_state: String) # Countdown, Playing, Overtime
signal kill_occurred(killer_name: String, victim_name: String, victim_faction: int)

const TEAM_NONE := -1
const TEAM_ALPHA := 0 # Apes
const TEAM_BRAVO := 1 # Chrome Legion

var points_captured: int = 0 # Replaces team_alpha_score / team_bravo_score

var attacking_team: int = TEAM_ALPHA
var defending_team: int = TEAM_BRAVO
var winning_team: int = TEAM_NONE
var is_match_over: bool = false

var capture_points: Array = []
var current_point_index: int = 0
var active_capture_point: Node3D = null

# --- Timer Variables ---
var match_time_limit: float = 300.0
var match_time_left: float = 300.0
var time_bonus_per_capture: float = 60.0
var is_match_playing: bool = false
var is_overtime: bool = false

# --- Team helpers (single source of truth for names/colors) ---
func get_team_name(team: int) -> String:
	match team:
		TEAM_ALPHA: return "PRIMAL APES"
		TEAM_BRAVO: return "CHROME LEGION"
	return "NOBODY"

func get_team_color(team: int) -> Color:
	match team:
		TEAM_ALPHA: return Color.DODGER_BLUE
		TEAM_BRAVO: return Color.RED
	return Color.WHITE

func set_roles(attacker: int):
	attacking_team = attacker
	defending_team = TEAM_BRAVO if attacker == TEAM_ALPHA else TEAM_ALPHA

## Call between rounds (or from a menu) to flip who attacks.
func swap_roles():
	PlayerSetup.attacking_team = defending_team
	set_roles(defending_team)

func _process(delta):
	if not is_match_playing:
		return

	if not is_overtime:
		match_time_left = max(0.0, match_time_left - delta)
		match_timer_updated.emit(match_time_left)
		if match_time_left <= 0.0:
			_check_overtime()
	else:
		_check_overtime()

func _check_overtime():
	var hold = active_capture_point != null and active_capture_point.should_hold_overtime()
	if hold:
		if not is_overtime:
			is_overtime = true
			match_state_changed.emit("OVERTIME")
			match_time_left = 0.0
			match_timer_updated.emit(0.0)
	else:
		# Time is up and the attackers aren't mid-capture: defenders win
		match_state_changed.emit("TIME_UP")
		_end_match(defending_team)

func initialize_level():
	#team_alpha_score = 0
	#team_bravo_score = 0
	current_point_index = 0
	capture_points.clear()
	active_capture_point = null
	match_time_left = match_time_limit
	is_match_playing = false
	is_overtime = false
	is_match_over = false
	winning_team = TEAM_NONE
	set_roles(PlayerSetup.attacking_team)

	# Wait a frame so the level nodes are fully loaded
	await get_tree().process_frame

	var points = get_tree().get_nodes_in_group("capture_points")
	points.sort_custom(func(a, b): return a.point_order < b.point_order)
	capture_points.assign(points)

	for p in capture_points:
		if not p.point_captured.is_connected(_on_point_captured):
			p.point_captured.connect(_on_point_captured)

	# Unlock the first point
	if capture_points.size() > 0:
		capture_points[0].is_active = true
		active_capture_point = capture_points[0]
		objective_updated.emit(capture_points[0].point_order)

	score_updated.emit(points_captured, capture_points.size())

func start_match_countdown():
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

# Only the attacking team can capture, so `team` is always attacking_team.
# Only the attacking team can capture, so `team` is always attacking_team.
func _on_point_captured(team: int):
	if is_match_over:
		return

	var captured_index = current_point_index
	points_captured += 1
	score_updated.emit(points_captured, capture_points.size())
	point_captured.emit(captured_index, team) # 0 = Point A

	current_point_index += 1

	# Every point taken: attackers win
	if current_point_index >= capture_points.size():
		_end_match(attacking_team)
		return

	# Reward the push with extra time (also rescues a capture made in overtime)
	match_time_left += time_bonus_per_capture
	if is_overtime:
		is_overtime = false
		match_time_left = max(match_time_left, 10.0)
		match_state_changed.emit("PLAYING")
	match_timer_updated.emit(match_time_left)

	# Advance the frontline
	var next_point = capture_points[current_point_index]
	next_point.is_active = true
	active_capture_point = next_point
	objective_updated.emit(next_point.point_order)

func _end_match(winner: int):
	if is_match_over:
		return # Guards against double-firing
	is_match_over = true
	is_match_playing = false
	is_overtime = false
	winning_team = winner

	game_won.emit(winner)
	print("%s WIN" % get_team_name(winner))

	await get_tree().create_timer(2.0).timeout
	get_tree().change_scene_to_file("res://round_end.tscn")
