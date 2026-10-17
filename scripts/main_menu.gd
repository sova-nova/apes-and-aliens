extends Control

func _ready():
	PlayerSetup.reset_series() # Coming back to the menu starts a fresh series
	HUD.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	$VBoxContainer/PlayButton.grab_focus()

func _on_button_pressed():
	get_tree().change_scene_to_file("res://class_select.tscn")
