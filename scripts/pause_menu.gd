class_name PauseMenu
extends Control
## Esc pauses the game and opens this menu: Resume, Restart Round, Settings, Quit to Main Menu.
## Built in code and added by level.gd, so no scene editing is needed.

var _menu_panel: PanelContainer
var _resume_button: Button
var _settings: SettingsMenu = null
var _settings_closed_frame: int = -1

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS # Keep running while the rest of the game is paused
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Dim the game behind the menu, and swallow clicks meant for it
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	_menu_panel = PanelContainer.new()
	_menu_panel.set_anchors_preset(Control.PRESET_CENTER)
	_menu_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_menu_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(_menu_panel)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	_menu_panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	margin.add_child(box)

	var title := Label.new()
	title.text = "PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	box.add_child(title)

	_resume_button = _add_button(box, "Resume", resume)
	_add_button(box, "Restart Round", _restart_round)
	_add_button(box, "Settings", _open_settings)
	_add_button(box, "Quit to Main Menu", _quit_to_menu)

	# A controls reminder, so nobody has to guess what Q, E and Shift do
	box.add_child(HSeparator.new())
	var controls_title := Label.new()
	controls_title.text = "CONTROLS"
	controls_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	controls_title.modulate = Color(1, 1, 1, 0.7)
	box.add_child(controls_title)
	var grid := ControlsHelp.build_grid()
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(grid)

func _add_button(parent: Control, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(280, 44)
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	# The settings panel handles its own Esc. Ignore the same press if it just closed.
	if is_instance_valid(_settings) or Engine.get_process_frames() == _settings_closed_frame:
		return

	get_viewport().set_input_as_handled()
	if get_tree().paused:
		resume()
	elif not GameManager.is_match_over:
		pause() # Not once the match has ended: the round-end screen is already on its way

func pause() -> void:
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	visible = true
	_menu_panel.visible = true
	_resume_button.grab_focus()

func resume() -> void:
	visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _open_settings() -> void:
	_menu_panel.visible = false
	_settings = SettingsMenu.new()
	_settings.closed.connect(_on_settings_closed)
	add_child(_settings)

func _on_settings_closed() -> void:
	_settings = null
	_settings_closed_frame = Engine.get_process_frames()
	_menu_panel.visible = true
	_resume_button.grab_focus()

func _restart_round() -> void:
	get_tree().paused = false
	GameManager.abort_match() # Stops the old match's countdown and timers from touching the new one
	get_tree().reload_current_scene()

func _quit_to_menu() -> void:
	get_tree().paused = false
	GameManager.abort_match() # Otherwise the match timer would keep running in the menu
	get_tree().change_scene_to_file("res://main_menu.tscn")

func _exit_tree() -> void:
	# Never leave the whole game paused if this menu is removed while open
	if is_inside_tree():
		get_tree().paused = false
