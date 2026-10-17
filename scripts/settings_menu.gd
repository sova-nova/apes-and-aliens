class_name SettingsMenu
extends Control
## The settings panel: mouse sensitivity, volume, and bot difficulty.
## Built in code and shared by the main menu and the pause menu.
## Changes apply immediately and are saved to disk when the panel closes.

signal closed

var _sensitivity_label: Label
var _volume_label: Label
var _difficulty_option: OptionButton
var _difficulty_blurb: Label

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
	panel.custom_minimum_size = Vector2(460, 0)
	center.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 22)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	margin.add_child(box)

	var title := Label.new()
	title.text = "SETTINGS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	box.add_child(title)

	# Mouse sensitivity
	var sensitivity := _add_slider(box, "Mouse sensitivity", 0.2, 3.0, 0.05,
		GameSettings.mouse_sensitivity_scale, _on_sensitivity_changed)
	_sensitivity_label = sensitivity.label
	_sensitivity_label.text = "%.2fx" % GameSettings.mouse_sensitivity_scale

	# Volume
	var volume := _add_slider(box, "Volume", 0.0, 1.0, 0.05,
		GameSettings.master_volume, _on_volume_changed)
	_volume_label = volume.label
	_volume_label.text = "%d%%" % int(round(GameSettings.master_volume * 100.0))

	# Fullscreen
	var fullscreen_check := CheckButton.new()
	fullscreen_check.text = "Fullscreen"
	fullscreen_check.button_pressed = GameSettings.fullscreen # Set before connecting, so it doesn't fire
	fullscreen_check.toggled.connect(_on_fullscreen_toggled)
	box.add_child(fullscreen_check)

	# Difficulty
	var diff_row := HBoxContainer.new()
	box.add_child(diff_row)
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
	_difficulty_blurb.custom_minimum_size = Vector2(416, 0)
	_difficulty_blurb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_difficulty_blurb.modulate = Color(1, 1, 1, 0.7)
	box.add_child(_difficulty_blurb)
	_update_blurb()

	var back := Button.new()
	back.text = "Back"
	back.custom_minimum_size = Vector2(0, 44)
	back.pressed.connect(_close)
	box.add_child(back)

	back.grab_focus()

## One labelled slider row. Returns {slider, label}; `label` is the value readout on the right.
func _add_slider(parent: Control, text: String, min_v: float, max_v: float, step: float,
		value: float, on_change: Callable) -> Dictionary:
	var row := HBoxContainer.new()
	parent.add_child(row)

	var name_label := Label.new()
	name_label.text = text
	name_label.custom_minimum_size.x = 170
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

	slider.value_changed.connect(on_change)
	return {"slider": slider, "label": value_label}

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

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_close()

func _close() -> void:
	GameSettings.save_settings()
	closed.emit()
	queue_free()
