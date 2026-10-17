class_name DeathScreen
extends Control
## What you see while you're dead, on top of the death camera.
##
## The camera frames the killer on the left of the screen (see DeathCam), and this info card sits on
## the right, so it never covers them. Thin letterbox bars run along the top and bottom.
## HUD creates one, and shows it when the player's death_info_ready signal fires.

const CARD_WIDTH := 340.0
const SIDE_MARGIN := 56.0 # Space between the card and the right edge of the screen

var _card_style: StyleBoxFlat
var _title_label: Label
var _name_label: Label
var _class_label: Label
var _hp_bar: ProgressBar
var _hp_label: Label
var _divider: HSeparator
var _distance_label: Label
var _dealt_label: Label
var _kills_label: Label
var _taken_label: Label
var _respawn_label: Label
var _time_left: float = 0.0
var _fade: Tween = null

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false

	# One column fills the screen: a top bar, the middle (stretchy), and a bottom bar. It's a container
	# layout, so the card is always exactly as tall as its text and can never run off the screen.
	var layout := VBoxContainer.new()
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layout.add_theme_constant_override("separation", 0)
	layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(layout)

	layout.add_child(_make_bar())

	var middle := HBoxContainer.new()
	middle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	middle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout.add_child(middle)

	# The left side is left empty on purpose: the camera frames the killer there
	var left_space := Control.new()
	left_space.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_space.mouse_filter = Control.MOUSE_FILTER_IGNORE
	middle.add_child(left_space)

	var card_margin := MarginContainer.new()
	card_margin.add_theme_constant_override("margin_left", 16)
	card_margin.add_theme_constant_override("margin_right", int(SIDE_MARGIN))
	card_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	middle.add_child(card_margin)

	var card_column := VBoxContainer.new()
	card_column.alignment = BoxContainer.ALIGNMENT_CENTER # Centers the card vertically
	card_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_margin.add_child(card_column)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(CARD_WIDTH, 0)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card_style = StyleBoxFlat.new()
	_card_style.bg_color = Color(0.04, 0.05, 0.07, 0.9)
	_card_style.border_width_left = 5 # An accent stripe in the killer's team color
	_card_style.border_color = Color.WHITE
	_card_style.set_corner_radius_all(6)
	card.add_theme_stylebox_override("panel", _card_style)
	card_column.add_child(card)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(column)

	_title_label = _make_label(column, "ELIMINATED BY", 14)
	_title_label.modulate = Color(1, 1, 1, 0.6)

	_name_label = _make_label(column, "", 30)
	_class_label = _make_label(column, "", 16)
	_class_label.modulate = Color(1, 1, 1, 0.75)

	_hp_bar = ProgressBar.new()
	_hp_bar.show_percentage = false
	_hp_bar.custom_minimum_size = Vector2(0, 14)
	_hp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_hp_bar)
	_hp_label = _make_label(column, "", 16)

	_divider = HSeparator.new()
	_divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_divider)

	_distance_label = _make_label(column, "", 16)
	_dealt_label = _make_label(column, "", 16)
	_kills_label = _make_label(column, "", 16)
	_taken_label = _make_label(column, "", 16)
	_taken_label.modulate = Color(1, 1, 1, 0.65)

	_respawn_label = _make_label(column, "", 22)
	_respawn_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))

	layout.add_child(_make_bar())

func _make_bar() -> ColorRect:
	var bar := ColorRect.new()
	bar.color = Color(0, 0, 0, 0.88)
	bar.custom_minimum_size = Vector2(0, 36)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return bar

func _make_label(parent: Control, text: String, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.clip_text = true # Never let a long name stretch the card
	parent.add_child(label)
	return label

## `info` comes from the player (see Player._build_death_info).
func show_death(info: Dictionary) -> void:
	_time_left = float(info.get("respawn_time", 4.0))
	var known: bool = info.get("known_killer", false)

	# If we don't know who did it, show just a plain "eliminated" card
	for node in [_title_label, _class_label, _hp_bar, _hp_label, _divider, _distance_label, _dealt_label, _kills_label]:
		node.visible = known

	if known:
		var team_color := GameManager.get_team_color(int(info["killer_team"]))
		_card_style.border_color = team_color
		_name_label.add_theme_font_size_override("font_size", 30)
		_name_label.add_theme_color_override("font_color", team_color)
		_name_label.text = str(info["killer_name"])
		_class_label.text = str(info["killer_class"])

		var hp := maxf(float(info["killer_hp"]), 0.0)
		var max_hp := maxf(float(info["killer_max_hp"]), 1.0)
		_hp_bar.max_value = max_hp
		_hp_bar.value = hp
		var pct := hp / max_hp
		_hp_bar.modulate = Color(0.45, 1.0, 0.5) if pct > 0.6 else (Color(1.0, 0.85, 0.3) if pct > 0.3 else Color(1.0, 0.35, 0.3))
		_hp_label.text = "%d / %d HP left" % [ceili(hp), int(max_hp)]

		_distance_label.text = "%d m away" % int(round(float(info["distance"])))
		_dealt_label.text = "You dealt them %d damage" % int(round(float(info["your_damage"])))
		_kills_label.text = "They have %d kills" % int(info["killer_kills"])
	else:
		_card_style.border_color = Color.WHITE
		_name_label.add_theme_font_size_override("font_size", 22)
		_name_label.add_theme_color_override("font_color", Color.WHITE)
		_name_label.text = "YOU WERE ELIMINATED"

	var attackers := int(info.get("attacker_count", 0))
	_taken_label.text = "You took %d damage from %d %s" % [
		int(round(float(info.get("damage_taken", 0.0)))), attackers, "enemy" if attackers == 1 else "enemies"]

	_update_respawn_text()
	modulate.a = 0.0
	visible = true
	if _fade and _fade.is_valid():
		_fade.kill()
	_fade = create_tween()
	_fade.tween_property(self, "modulate:a", 1.0, 0.45)

func hide_screen() -> void:
	if _fade and _fade.is_valid():
		_fade.kill()
	visible = false

func _process(delta: float) -> void:
	if not visible:
		return
	_time_left = maxf(0.0, _time_left - delta)
	_update_respawn_text()

func _update_respawn_text() -> void:
	_respawn_label.text = "Respawning in %d" % ceili(_time_left)
