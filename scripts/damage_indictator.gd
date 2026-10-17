class_name DamageIndicator
extends Control
## Red arcs around the crosshair that point toward whoever just hurt you.
## HUD creates one and feeds it the angle from the player's damage_taken signal.

const LIFETIME := 1.1                  # Seconds a marker stays on screen
const MAX_MARKERS := 6
const MERGE_ANGLE := 0.314             # About 18 degrees: hits from nearly the same direction share one marker

# Each marker: {"angle": float, "age": float}.
# angle is clockwise from straight ahead, in radians: 0 = ahead, PI/2 = right, PI = behind.
var _markers: Array = []

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false) # Only runs while there's something to fade

func show_hit_from(angle: float) -> void:
	for m in _markers:
		if absf(angle_difference(m.angle, angle)) < MERGE_ANGLE:
			m.angle = angle
			m.age = 0.0 # Same direction again: refresh instead of stacking
			set_process(true)
			queue_redraw()
			return

	if _markers.size() >= MAX_MARKERS:
		_markers.pop_front()
	_markers.append({"angle": angle, "age": 0.0})
	set_process(true)
	queue_redraw()

func _process(delta: float) -> void:
	for m in _markers:
		m.age += delta
	_markers = _markers.filter(func(m): return m.age < LIFETIME)
	if _markers.is_empty():
		set_process(false)
	queue_redraw()

func _draw() -> void:
	var center := size * 0.5
	var radius := minf(size.x, size.y) * 0.2

	for m in _markers:
		var fade: float = 1.0 - m.age / LIFETIME
		var color := Color(1.0, 0.15, 0.1, fade)

		# Screen angles run clockwise from "up"; canvas angles run clockwise from "right"
		var canvas_angle: float = m.angle - PI / 2.0
		var dir := Vector2(cos(canvas_angle), sin(canvas_angle))
		var side := Vector2(-dir.y, dir.x)

		# An arc around the crosshair, plus an arrowhead pointing outward to the attacker
		draw_arc(center, radius, canvas_angle - 0.35, canvas_angle + 0.35, 20, color, 6.0, true)
		var tip := center + dir * (radius + 26.0)
		var base := center + dir * (radius + 4.0)
		draw_colored_polygon(PackedVector2Array([tip, base + side * 12.0, base - side * 12.0]), color)
