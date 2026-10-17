extends Control

var _settings: SettingsMenu = null

func _ready():
	GameSettings.ensure_loaded() # Applies the saved volume right at startup
	PlayerSetup.reset_series() # Coming back to the menu starts a fresh series
	HUD.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_add_extra_buttons()
	$VBoxContainer/PlayButton.grab_focus()

# Settings and Quit are built in code so the scene file doesn't need editing.
func _add_extra_buttons():
	var vbox: VBoxContainer = $VBoxContainer
	var play_index = $VBoxContainer/PlayButton.get_index()

	var settings_button = Button.new()
	settings_button.text = "Settings"
	settings_button.pressed.connect(_open_settings)
	vbox.add_child(settings_button)
	vbox.move_child(settings_button, play_index + 1)

	var quit_button = Button.new()
	quit_button.text = "Quit"
	quit_button.pressed.connect(get_tree().quit)
	vbox.add_child(quit_button)
	vbox.move_child(quit_button, play_index + 2)

func _open_settings():
	if is_instance_valid(_settings):
		return
	$VBoxContainer.visible = false
	_settings = SettingsMenu.new()
	_settings.closed.connect(_on_settings_closed)
	add_child(_settings)

func _on_settings_closed():
	_settings = null
	$VBoxContainer.visible = true
	$VBoxContainer/PlayButton.grab_focus()

func _on_button_pressed():
	get_tree().change_scene_to_file("res://class_select.tscn")
