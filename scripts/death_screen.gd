class_name DeathScreen
extends Control
## What you see while you're dead, on top of the death camera: letterbox bars and a panel
## naming who killed you, how much health they have left, how far away they were, and more.
## HUD creates one, and shows it when the player's death_info_ready signal fires.

var _name_label: Label
var _hp_bar: ProgressBar
var _hp_label: Label
var _stats_label: Label
var _taken_label: Label
var _respawn_label: Label
var _bottom: ColorRect
var _top: ColorRect
var _time_left: float = 0.0
var _fade: Tween = null

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false

	# Cinematic bars along the top and bottom
	_top = ColorRect.new()
	_top.color = Color(0, 0, 0, 0.88)
	_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_top.offset_bottom = 56.0
	add_child(_top)

	_bottom = ColorRect.new()
	_bottom.color = Color(0, 0, 0, 0.88)
	_bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_bottom.offset_top = -214.0
	add_child(_bottom)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	_bottom.add_child(margin)

	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 4)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(column)

	var eliminated := _make_label(column, "ELIMINATED BY", 16)
	eliminated.modulate = Color(1, 1, 1, 0.6)

	_name_label = _make_label(column, "", 38)

	_hp_bar = ProgressBar.new()
	_hp_bar.show_percentage = false
	_hp_bar.custom_minimum_size = Vector2(380, 16)
	_hp_bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_hp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_hp_bar)

	_hp_label = _make_label(column, "", 18)
	_stats_label = _make_label(column, "", 16)
	_stats_label.modulate = Color(1, 1, 1, 0.85)
	_taken_label = _make_label(column, "", 16)
	_taken_label.modulate = Color(1, 1, 1, 0.65)
	_respawn_label = _make_label(column, "", 20)
	_respawn_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))

func _make_label(parent: Control, text: String, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", size)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

## `info` comes from the player (see Player._build_death_info).
func show_death(info: Dictionary) -> void:
	_time_left = float(info.get("respawn_time", 4.0))

	if info.get("known_killer", false):
		var team := int(info["killer_team"])
		_name_label.text = "%s  ·  %s" % [info["killer_name"], info["killer_class"]]
		_name_label.add_theme_color_override("font_color", GameManager.get_team_color(team))

		var hp := maxf(float(info["killer_hp"]), 0.0)
		var max_hp := maxf(float(info["killer_max_hp"]), 1.0)
		_hp_bar.max_value = max_hp
		_hp_bar.value = hp
		var pct := hp / max_hp
		_hp_bar.modulate = Color(0.45, 1.0, 0.5) if pct > 0.6 else (Color(1.0, 0.85, 0.3) if pct > 0.3 else Color(1.0, 0.35, 0.3))
		_hp_label.text = "%d / %d HP left" % [ceili(hp), int(max_hp)]
		_hp_bar.visible = true
		_hp_label.visible = true

		_stats_label.text = "%d m away   ·   You dealt them %d damage   ·   They have %d kills" % [
			int(round(float(info["distance"]))), int(round(float(info["your_damage"]))), int(info["killer_kills"])]
	else:
		_name_label.text = "YOU WERE ELIMINATED"
		_name_label.add_theme_color_override("font_color", Color.WHITE)
		_hp_bar.visible = false
		_hp_label.visible = false
		_stats_label.text = ""

	var attackers := int(info.get("attacker_count", 0))
	_taken_label.text = "You took %d damage from %d %s this life" % [
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
