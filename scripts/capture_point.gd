extends Area3D

@export var point_name: String = "A"
@export var capture_speed: float = 20.0          ## Progress per second, per attacker
@export var max_counted_attackers: int = 3       ## Extra attackers beyond this don't speed it up
@export var defender_reset_speed: float = 30.0   ## Progress removed per second when only defenders are present
@export var idle_decay_speed: float = 0.0        ## Optional slow decay when nobody is on the point
@export var point_order: int = 0                 ## 0 for A, 1 for B, 2 for C

signal point_captured(team: int)

var is_active: bool = false
var is_captured: bool = false
var is_contested: bool = false
var capture_progress: float = 0.0 # 0..100, always the ATTACKERS' progress
var controlling_team: int = -1    # -1 until captured, then the attacking team
var attackers_on_point: int = 0
var defenders_on_point: int = 0

# What the UI last drew, so update_ui can skip frames where nothing visible changed
var _ui_pct: int = -1
var _ui_state: int = -1

var progress_circle: MeshInstance3D
var progress_mat: StandardMaterial3D

@onready var status_label: Label3D = $StatusLabel
@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D

func _ready():
	progress_circle = MeshInstance3D.new()
	var mesh = CylinderMesh.new()
	mesh.top_radius = 4.5
	mesh.bottom_radius = 4.5
	mesh.height = 0.1
	progress_circle.mesh = mesh

	progress_mat = StandardMaterial3D.new()
	progress_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	progress_mat.albedo_color = Color.WHITE
	progress_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	progress_circle.material_override = progress_mat

	progress_circle.position.y = 0.15
	add_child(progress_circle)

	update_visuals()

func _physics_process(delta: float):
	if not is_active or not GameManager.is_match_playing:
		update_ui()
		return

	_count_occupants()

	var was_contested = is_contested
	is_contested = attackers_on_point > 0 and defenders_on_point > 0
	if was_contested != is_contested:
		update_visuals()

	# Contested = frozen. Otherwise attackers push, defenders push back.
	if not is_contested:
		if attackers_on_point > 0:
			var counted = min(attackers_on_point, max_counted_attackers)
			capture_progress += counted * capture_speed * delta
		elif defenders_on_point > 0:
			capture_progress -= defender_reset_speed * delta
		elif idle_decay_speed > 0.0:
			capture_progress -= idle_decay_speed * delta

		capture_progress = clampf(capture_progress, 0.0, 100.0)

		if capture_progress >= 100.0:
			_complete_capture()
			return

	update_ui()

func _count_occupants():
	attackers_on_point = 0
	defenders_on_point = 0

	for body in get_overlapping_bodies():
		if not ("faction" in body):
			continue
		# Dead players/bots don't count (bots linger for a moment while shrinking)
		if "is_alive" in body and not body.is_alive:
			continue
		if "health_component" in body and body.health_component and body.health_component.is_dead():
			continue

		if body.faction == GameManager.attacking_team:
			attackers_on_point += 1
		elif body.faction == GameManager.defending_team:
			defenders_on_point += 1

func _complete_capture():
	is_captured = true
	is_active = false # Lock it; it can't be retaken
	is_contested = false
	capture_progress = 100.0
	controlling_team = GameManager.attacking_team

	AudioManager.play_capture()
	update_visuals()
	update_ui()
	point_captured.emit(controlling_team) # Emit last: GameManager reacts to it

## GameManager asks this when time runs out.
func should_hold_overtime() -> bool:
	return is_active and (is_contested or (attackers_on_point > 0 and capture_progress > 0.0))

func update_ui():
	if not status_label:
		return

	# Skip the work unless the shown percent or the point's state changed
	var state = 3 if is_captured else (0 if not is_active else (2 if is_contested else 1))
	var pct = int(capture_progress)
	if pct == _ui_pct and state == _ui_state:
		return
	_ui_pct = pct
	_ui_state = state

	# Progress circle (never scale to exactly 0, it creates a singular transform)
	var progress_pct = capture_progress / 100.0
	progress_circle.scale = Vector3(max(progress_pct, 0.001), 1.0, max(progress_pct, 0.001))
	if capture_progress > 0.0:
		progress_mat.albedo_color = GameManager.get_team_color(GameManager.attacking_team)
	else:
		progress_mat.albedo_color = Color.WHITE

	# Text
	if is_captured:
		status_label.text = "Point %s\n[CAPTURED]" % point_name
	elif not is_active:
		status_label.text = "Point %s\n[LOCKED]" % point_name
	elif is_contested:
		status_label.text = "Point %s\n[CONTESTED]" % point_name
	else:
		status_label.text = "Point %s\n%d%%" % [point_name, int(capture_progress)]

func update_visuals():
	if not mesh_instance:
		return
	var mat = StandardMaterial3D.new()

	if is_captured:
		mat.albedo_color = GameManager.get_team_color(controlling_team)
	elif is_contested:
		mat.albedo_color = Color.YELLOW
	elif is_active:
		mat.albedo_color = Color.WHITE
	else:
		mat.albedo_color = Color.DIM_GRAY # Locked

	mat.roughness = 0.8
	mesh_instance.material_override = mat

func get_random_point_inside() -> Vector3:
	if not collision_shape or not collision_shape.shape:
		return global_position

	var shape = collision_shape.shape
	if shape is CylinderShape3D:
		var angle = randf() * TAU
		var distance = sqrt(randf()) * shape.radius
		return global_position + Vector3(cos(angle) * distance, 0, sin(angle) * distance)

	return global_position
