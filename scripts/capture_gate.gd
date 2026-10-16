extends Node3D
class_name CaptureGate

## Emitted once the gate finishes its open animation.
signal gate_opened

@export_group("Trigger")
@export var trigger_point_index: int = 0 ## Opens when this point is captured (0 = Point A)

@export_group("Animation")
@export var open_direction: Vector3 = Vector3.UP ## Slide direction (in this gate's local space)
@export var open_distance: float = 6.0
@export var open_duration: float = 1.5
@export var open_delay: float = 0.3 ## Brief pause before sliding

@export_group("Navigation")
@export var nav_link: NavigationLink3D ## Bridges the hole the closed gate leaves in the navmesh

var is_open: bool = false

var _tween: Tween
var _gate_body: StaticBody3D
var _collision_shape: CollisionShape3D
var _closed_pos: Vector3
var _open_pos: Vector3

func _ready():
	_gate_body = $GateBody
	_collision_shape = _gate_body.get_node("CollisionShape3D")

	_closed_pos = _gate_body.position
	_open_pos = _closed_pos + open_direction.normalized() * open_distance

	# Closed gate = no path through it
	if nav_link:
		nav_link.enabled = false

	GameManager.point_captured.connect(_on_point_captured)

func _on_point_captured(point_index: int, _capturing_team: int):
	if point_index == trigger_point_index:
		open_gate()

func open_gate():
	if is_open:
		return
	is_open = true

	AudioManager.play_gate(global_position)

	_tween = create_tween()
	_tween.tween_interval(open_delay)
	_tween.tween_property(_gate_body, "position", _open_pos, open_duration) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_callback(_on_fully_opened)

func _on_fully_opened():
	# Collision off so players and projectiles pass through
	_collision_shape.set_deferred("disabled", true)
	# NOW let bots path through
	if nav_link:
		nav_link.enabled = true
	gate_opened.emit()
