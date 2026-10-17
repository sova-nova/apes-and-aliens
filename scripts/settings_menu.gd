class_name SettingsMenu
extends Control
## The settings panel, in two tabs: General (sensitivity, volume, fullscreen, difficulty)
## and Crosshair (style, color, size, ... with a live preview).
## Built in code and shared by the main menu and the pause menu.
## Changes apply immediately and are saved to disk when the panel closes.

signal closed

var _sensitivity_label: Label
var _volume_label: Label
var _difficulty_option: OptionButton
var _difficulty_blurb: Label
var _crosshair_tab: VBoxContainer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS # Must keep working while the game is paused
	GameSettings.ensure_loaded()

	# A full-screen overlay holding a CenterContainer, which re-centers the panel every time its
	# size changes. (Anchors + "grow both" don't: the wrapping description text makes the panel
	# very tall on the first layout pass, and it stays stranded off-screen once it shrinks.)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(540, 0)
	center.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 22)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	margin.add_child(box)

	var title := Label.new()
	title.text = "SETTINGS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	box.add_child(title)

	# A fixed height, so switching tabs never makes the panel jump around
	var tabs := TabContainer.new()
	tabs.custom_minimum_size = Vector2(500, 360)
	box.add_child(tabs)

	var general := VBoxContainer.new()
	general.name = "General"
	general.add_theme_constant_override("separation", 14)
	tabs.add_child(general)
	_build_general_tab(general)

	_crosshair_tab = VBoxContainer.new()
	_crosshair_tab.name = "Crosshair"
	_crosshair_tab.add_theme_constant_override("separation", 6)
	tabs.add_child(_crosshair_tab)
	_build_crosshair_tab()

	var back := Button.new()
	back.text = "Back"
	back.custom_minimum_size = Vector2(0, 44)
	back.pressed.connect(_close)
	box.add_child(back)

	back.grab_focus()

# ─── General tab ────────────────────────────────────────────

func _build_general_tab(parent: Control) -> void:
	# Mouse sensitivity
	var sensitivity := _add_slider(parent, "Mouse sensitivity", 0.2, 3.0, 0.05,
		GameSettings.mouse_sensitivity_scale, _on_sensitivity_changed)
	_sensitivity_label = sensitivity.label
	_sensitivity_label.text = "%.2fx" % GameSettings.mouse_sensitivity_scale

	# Volume
	var volume := _add_slider(parent, "Volume", 0.0, 1.0, 0.05,
		GameSettings.master_volume, _on_volume_changed)
	_volume_label = volume.label
	_volume_label.text = "%d%%" % int(round(GameSettings.master_volume * 100.0))

	# Fullscreen
	var fullscreen_check := CheckButton.new()
	if GameSettings.is_fullscreen_supported():
		fullscreen_check.text = "Fullscreen"
	else:
		# The editor's embedded Game tab can only show a window, so say so instead of silently doing nothing
		fullscreen_check.text = "Fullscreen (unavailable in the editor's Game tab)"
		fullscreen_check.disabled = true
	# Set before connecting, so it doesn't fire
	fullscreen_check.button_pressed = GameSettings.fullscreen and GameSettings.is_fullscreen_supported()
	fullscreen_check.toggled.connect(_on_fullscreen_toggled)
	parent.add_child(fullscreen_check)

	# Difficulty
	var diff_row := HBoxContainer.new()
	parent.add_child(diff_row)
	var diff_name := Label.new()
	diff_name.text = "Bot difficulty"
	diff_name.custom_minimum_size.x = 170
	diff_row.add_child(diff_name)

	_difficulty_option = OptionButton.new()
	_difficulty_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for d in GameSettings.DIFFICULTY_DATA:
		_difficulty_option.add_item(GameSettings.DIFFICULTY_DATA[d]["name"], d)
	_difficulty_option.select(_difficulty_option.get_item_index(GameSettings.difficulty))
	_difficulty_option.item_selected.connect(_on_difficulty_selected)
	diff_row.add_child(_difficulty_option)

	_difficulty_blurb = Label.new()
	_difficulty_blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_difficulty_blurb.custom_minimum_size = Vector2(456, 0)
	_difficulty_blurb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_difficulty_blurb.modulate = Color(1, 1, 1, 0.7)
	parent.add_child(_difficulty_blurb)
	_update_blurb()

func _on_sensitivity_changed(value: float) -> void:
	GameSettings.mouse_sensitivity_scale = value
	_sensitivity_label.text = "%.2fx" % value

func _on_volume_changed(value: float) -> void:
	GameSettings.master_volume = value
	GameSettings.apply_audio()
	_volume_label.text = "%d%%" % int(round(value * 100.0))

func _on_fullscreen_toggled(on: bool) -> void:
	GameSettings.fullscreen = on
	GameSettings.apply_video()

func _on_difficulty_selected(index: int) -> void:
	GameSettings.difficulty = _difficulty_option.get_item_id(index)
	_update_blurb()

func _update_blurb() -> void:
	_difficulty_blurb.text = GameSettings.DIFFICULTY_DATA[GameSettings.difficulty]["blurb"]

# ─── Crosshair tab ──────────────────────────────────────────

func _build_crosshair_tab() -> void:
	var tab := _crosshair_tab

	# Live preview on a dark panel (the real crosshair behind the pause menu updates too)
	var preview_panel := PanelContainer.new()
	preview_panel.custom_minimum_size = Vector2(0, 84)
	var preview_style := StyleBoxFlat.new()
	preview_style.bg_color = Color(0.11, 0.13, 0.17)
	preview_panel.add_theme_stylebox_override("panel", preview_style)
	tab.add_child(preview_panel)
	var preview := Crosshair.new()
	preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview_panel.add_child(preview)

	# Style
	var style_row := HBoxContainer.new()
	tab.add_child(style_row)
	var style_label := Label.new()
	style_label.text = "Style"
	style_label.custom_minimum_size.x = 100
	style_row.add_child(style_label)
	var style_option := OptionButton.new()
	style_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for i in range(Crosshair.STYLE_NAMES.size()):
		style_option.add_item(Crosshair.STYLE_NAMES[i], i)
	style_option.select(style_option.get_item_index(GameSettings.crosshair_style))
	style_option.item_selected.connect(func(index: int) -> void:
		GameSettings.crosshair_style = style_option.get_item_id(index)
		_crosshair_changed())
	style_row.add_child(style_option)

	# Color: a few quick swatches, plus a full picker
	var color_row := HBoxContainer.new()
	color_row.add_theme_constant_override("separation", 6)
	tab.add_child(color_row)
	var color_label := Label.new()
	color_label.text = "Color"
	color_label.custom_minimum_size.x = 100
	color_row.add_child(color_label)

	var picker := ColorPickerButton.new()
	picker.color = GameSettings.crosshair_color
	picker.edit_alpha = false
	picker.custom_minimum_size = Vector2(64, 26)
	picker.color_changed.connect(func(c: Color) -> void:
		GameSettings.crosshair_color = c
		_crosshair_changed())

	for swatch_color in [Color.WHITE, Color(0.3, 1.0, 0.4), Color(0.2, 0.9, 1.0),
			Color(1.0, 0.9, 0.2), Color(1.0, 0.3, 0.3), Color(1.0, 0.4, 1.0)]:
		color_row.add_child(_make_swatch(swatch_color, picker))
	color_row.add_child(picker)

	# Size, thickness, gap, opacity (each slider calls the same two helpers, told which field it is)
	for field in ["size", "thickness", "gap", "opacity"]:
		_add_slider(tab, field.capitalize(), _crosshair_min(field), _crosshair_max(field),
			0.05 if field == "opacity" else 1.0, _get_crosshair_field(field),
			_set_crosshair_field.bind(field), _format_crosshair.bind(field))

	# Toggles and reset
	var toggles := HBoxContainer.new()
	toggles.add_theme_constant_override("separation", 14)
	tab.add_child(toggles)
	var outline_check := CheckBox.new()
	outline_check.text = "Outline"
	outline_check.button_pressed = GameSettings.crosshair_outline
	outline_check.toggled.connect(func(on: bool) -> void:
		GameSettings.crosshair_outline = on
		_crosshair_changed())
	toggles.add_child(outline_check)
	var dot_check := CheckBox.new()
	dot_check.text = "Center dot"
	dot_check.button_pressed = GameSettings.crosshair_dot
	dot_check.toggled.connect(func(on: bool) -> void:
		GameSettings.crosshair_dot = on
		_crosshair_changed())
	toggles.add_child(dot_check)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toggles.add_child(spacer)
	var reset := Button.new()
	reset.text = "Reset"
	reset.pressed.connect(_reset_crosshair)
	toggles.add_child(reset)

func _crosshair_min(field: String) -> float:
	match field:
		"size": return 2.0
		"thickness": return 1.0
		"opacity": return 0.2
	return 0.0 # gap

func _crosshair_max(field: String) -> float:
	match field:
		"size": return 30.0
		"thickness": return 8.0
		"gap": return 20.0
	return 1.0 # opacity

func _get_crosshair_field(field: String) -> float:
	match field:
		"size": return GameSettings.crosshair_size
		"thickness": return GameSettings.crosshair_thickness
		"gap": return GameSettings.crosshair_gap
	return GameSettings.crosshair_opacity

# Note the argument order: `v` comes from the slider, `field` is attached with bind()
func _set_crosshair_field(v: float, field: String) -> void:
	match field:
		"size": GameSettings.crosshair_size = v
		"thickness": GameSettings.crosshair_thickness = v
		"gap": GameSettings.crosshair_gap = v
		"opacity": GameSettings.crosshair_opacity = v
	_crosshair_changed()

func _format_crosshair(v: float, field: String) -> String:
	if field == "opacity":
		return "%d%%" % int(round(v * 100.0))
	return "%d" % int(v)

func _make_swatch(swatch_color: Color, picker: ColorPickerButton) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(26, 26)
	var style := StyleBoxFlat.new()
	style.bg_color = swatch_color
	style.set_border_width_all(1)
	style.border_color = Color(1, 1, 1, 0.5)
	style.set_corner_radius_all(3)
	for state in ["normal", "hover", "pressed", "focus"]:
		button.add_theme_stylebox_override(state, style)
	button.pressed.connect(func() -> void:
		GameSettings.crosshair_color = swatch_color
		picker.color = swatch_color
		_crosshair_changed())
	return button

func _crosshair_changed() -> void:
	get_tree().call_group("crosshairs", "refresh")

func _reset_crosshair() -> void:
	GameSettings.reset_crosshair()
	# Rebuild the tab so every control shows the defaults
	for child in _crosshair_tab.get_children():
		_crosshair_tab.remove_child(child)
		child.queue_free()
	_build_crosshair_tab()
	_crosshair_changed()

# ─── Shared ─────────────────────────────────────────────────

## One labelled slider row. Returns {slider, label}; `label` is the value readout on the right.
## `formatter` (optional) turns the value into the text shown there, and is kept up to date.
func _add_slider(parent: Control, text: String, min_v: float, max_v: float, step: float,
		value: float, on_change: Callable, formatter: Callable = Callable()) -> Dictionary:
	var row := HBoxContainer.new()
	parent.add_child(row)

	var name_label := Label.new()
	name_label.text = text
	name_label.custom_minimum_size.x = 170 if not formatter.is_valid() else 100
	row.add_child(name_label)

	var slider := HSlider.new()
	slider.min_value = min_v
	slider.max_value = max_v
	slider.step = step
	slider.value = value # Set BEFORE connecting, so setting it doesn't fire the callback
	slider.custom_minimum_size.x = 200
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(slider)

	var value_label := Label.new()
	value_label.custom_minimum_size.x = 56
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value_label)
	if formatter.is_valid():
		value_label.text = formatter.call(value)

	slider.value_changed.connect(func(v: float) -> void:
		on_change.call(v)
		if formatter.is_valid():
			value_label.text = formatter.call(v))
	return {"slider": slider, "label": value_label}

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_close()

func _close() -> void:
	GameSettings.save_settings()
	closed.emit()
	queue_free()
