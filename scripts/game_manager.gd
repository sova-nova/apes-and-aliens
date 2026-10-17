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

# Every player and bot joins the group for its team, so targeting only has to scan enemies.
# Indexed by team: GameManager.TEAM_GROUPS[team]
const TEAM_GROUPS := ["alpha_combatants", "bravo_combatants"]

var points_captured: int = 0

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

# Bumped when a match starts or is aborted. Countdown and end-of-match timers remember the
# value they started with, so a stale one can't start or end a match that has since been
# restarted or quit.
var _match_run_id: int = 0

# ─── Teams ──────────────────────────────────────────────────
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

func get_opposing_team(team: int) -> int:
	return TEAM_BRAVO if team == TEAM_ALPHA else TEAM_ALPHA

func set_roles(attacker: int):
	attacking_team = attacker
	defending_team = get_opposing_team(attacker)

# ─── Spawns ─────────────────────────────────────────────────
## Spawns that apply RIGHT NOW for a role: ones made for the current point,
## else any fallback for that role. (Attackers/defenders are roles, not factions.)
func _get_spawn_pool(is_attacker: bool) -> Array:
	var exact: Array = []
	var fallback: Array = []

	for sp in get_tree().get_nodes_in_group("spawn_points"):
		if not is_instance_valid(sp) or sp.for_attackers != is_attacker:
			continue
		if sp.is_fallback:
			fallback.append(sp)
		elif sp.for_active_point == current_point_index:
			exact.append(sp)

	return exact if not exact.is_empty() else fallback

## Single source of truth for where a team spawns RIGHT NOW (match start and respawns).
## Roles decide the side: the attacking team uses attacker spawns, the other uses defender spawns.
## Returns Vector3.INF if the current scene has no spawns (e.g. menus), so callers can skip.
func get_spawn_position(team: int) -> Vector3:
	var pool = _get_spawn_pool(team == attacking_team)
	if pool.is_empty():
		return Vector3.INF
	return pool.pick_random().get_spawn_position()

## Flat, normalized direction from `from_pos` toward where attackers currently spawn.
## Defenders use this to face the likely threat. ZERO if unknown.
func get_attacker_direction(from_pos: Vector3) -> Vector3:
	var pool = _get_spawn_pool(true)
	if pool.is_empty():
		return Vector3.ZERO
	var sum = Vector3.ZERO
	for sp in pool:
		sum += sp.global_position
	var dir = sum / pool.size() - from_pos
	dir.y = 0.0
	if dir.length_squared() < 0.01:
		return Vector3.ZERO
	return dir.normalized()

## Flat distance from `pos` to the nearest attacker spawn (INF if none). Used to stop defenders spawn-camping.
func distance_to_attacker_spawn(pos: Vector3) -> float:
	var pool = _get_spawn_pool(true)
	var best = INF
	for sp in pool:
		var d = Vector2(pos.x, pos.z).distance_to(Vector2(sp.global_position.x, sp.global_position.z))
		best = minf(best, d)
	return best

# ─── Match flow ─────────────────────────────────────────────
func _process(delta):
	if not is_match_playing:
		return

	if not is_overtime:
		var previous_second = floori(match_time_left)
		match_time_left = max(0.0, match_time_left - delta)
		# The HUD shows whole seconds, so only announce the time when the shown second changes
		if floori(match_time_left) != previous_second:
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
	_match_run_id += 1
	points_captured = 0 # Fresh score every match
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
	match_timer_updated.emit(match_time_left) # Show the full time during the countdown

func start_match_countdown():
	var run_id = _match_run_id
	match_state_changed.emit("3")
	await get_tree().create_timer(1.0, false).timeout
	if run_id != _match_run_id: return
	match_state_changed.emit("2")
	await get_tree().create_timer(1.0, false).timeout
	if run_id != _match_run_id: return
	match_state_changed.emit("1")
	await get_tree().create_timer(1.0, false).timeout
	if run_id != _match_run_id: return
	match_state_changed.emit("GO!")
	await get_tree().create_timer(0.5, false).timeout
	if run_id != _match_run_id: return
	match_state_changed.emit("PLAYING")
	is_match_playing = true

## Stops the current match without scoring it (used by the pause menu's Restart and Quit).
func abort_match():
	_match_run_id += 1
	is_match_playing = false
	is_overtime = false
	is_match_over = true # Nothing should end or score a match from the menus

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
	PlayerSetup.record_result(winner)

	game_won.emit(winner)

	var run_id = _match_run_id
	await get_tree().create_timer(2.0, false).timeout
	if run_id != _match_run_id:
		return # The match was aborted or restarted in the meantime
	get_tree().change_scene_to_file("res://round_end.tscn")
