extends Control

var _chosen_class: int = 0

func _ready():
	HUD.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	$VBoxContainer/DeployButton.grab_focus()

func _on_breacher_pressed():
	_chosen_class = 0

func _on_warden_pressed():
	_chosen_class = 1

func _on_ghost_pressed():
	_chosen_class = 2

func _on_deploy_pressed():
	PlayerSetup.selected_class_index = _chosen_class
	# For now, default to Apes. Later you can add a faction toggle!
	PlayerSetup.selected_faction = 0 
	get_tree().change_scene_to_file("res://level.tscn")
