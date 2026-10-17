class_name Crosshair
extends Control
## The player's crosshair, drawn from the settings (style, color, size, thickness, gap, opacity,
## outline, center dot), plus the hit and kill markers. HUD uses one full-screen; the settings
## screen uses a small one as a live preview. Everything is drawn around the middle of this control.

enum Style { CROSS, T_SHAPE, CIRCLE, CHEVRON, DOT }
const STYLE_NAMES := ["Cross", "T-Shape", "Circle", "Chevron", "Dot"]

const HIT_TIME := 0.14
const KILL_TIME := 0.30

var _hit_age: float = 999.0
var _hit_duration: float = HIT_TIME
var _hit_is_kill: bool = false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_to_group("crosshairs") # The settings screen asks every crosshair to redraw when a value changes
	set_process(false)

## Redraw after a setting changed.
func refresh() -> void:
	queue_redraw()

## Briefly show the red "hit" marker, or the gold "kill" marker.
func flash_hit(is_kill: bool) -> void:
	_hit_age = 0.0
	_hit_is_kill = is_kill
	_hit_duration = KILL_TIME if is_kill else HIT_TIME
	set_process(true)
	queue_redraw()

func _process(delta: float) -> void:
	_hit_age += delta
	if _hit_age >= _hit_duration:
		set_process(false)
	queue_redraw()

func _draw() -> void:
	GameSettings.ensure_loaded()
	# Snap to a pixel centre so odd-width lines stay crisp
	var c := (size * 0.5).floor() + Vector2(0.5, 0.5)

	var color := GameSettings.crosshair_color
	color.a = GameSettings.crosshair_opacity
	var outline_color := Color(0, 0, 0, color.a * 0.85)
	var s := GameSettings.crosshair_size
	var t := GameSettings.crosshair_thickness
	var gap := GameSettings.crosshair_gap
	var outline := GameSettings.crosshair_outline
	var style := GameSettings.crosshair_style

	var segments: Array = [] # Pairs of points to stroke as straight lines
	match style:
		Style.CROSS, Style.T_SHAPE:
			if style == Style.CROSS:
				segments.append([c + Vector2(0, -gap), c + Vector2(0, -gap - s)]) # up
			segments.append([c + Vector2(0, gap), c + Vector2(0, gap + s)])       # down
			segments.append([c + Vector2(-gap, 0), c + Vector2(-gap - s, 0)])     # left
			segments.append([c + Vector2(gap, 0), c + Vector2(gap + s, 0)])       # right
		Style.CHEVRON:
			segments.append([c, c + Vector2(-s * 0.8, s * 0.8)])
			segments.append([c, c + Vector2(s * 0.8, s * 0.8)])
		Style.CIRCLE:
			var radius := gap + s * 0.5
			if outline:
				draw_arc(c, radius, 0.0, TAU, 48, outline_color, t + 2.0, true)
			draw_arc(c, radius, 0.0, TAU, 48, color, t, true)
		Style.DOT:
			var dot_radius := maxf(1.5, t * 1.2 + s * 0.08)
			if outline:
				draw_circle(c, dot_radius + 1.0, outline_color)
			draw_circle(c, dot_radius, color)

	# All the outlines first, then all the lines, so a neighbouring outline never cuts across a line
	if outline:
		for seg in segments:
			draw_line(seg[0], seg[1], outline_color, t + 2.0)
	for seg in segments:
		draw_line(seg[0], seg[1], color, t)

	# Optional center dot on top of any line-based style
	if GameSettings.crosshair_dot and style != Style.DOT:
		var r := maxf(1.0, t * 0.7)
		if outline:
			draw_circle(c, r + 1.0, outline_color)
		draw_circle(c, r, color)

	_draw_hit_marker(c)

func _draw_hit_marker(c: Vector2) -> void:
	if _hit_age >= _hit_duration:
		return
	var fade := 1.0 - _hit_age / _hit_duration
	var marker_color := Color.GOLD if _hit_is_kill else Color(1.0, 0.25, 0.2)
	marker_color.a = fade
	var shadow := Color(0, 0, 0, fade * 0.8)
	var near := 8.0 if not _hit_is_kill else 10.0
	var far := near + (8.0 if not _hit_is_kill else 12.0)
	var width := 2.0 if not _hit_is_kill else 3.0

	for d in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		draw_line(c + d * near, c + d * far, shadow, width + 2.0)
	for d in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		draw_line(c + d * near, c + d * far, marker_color, width)
