extends Control

var _chosen_class: int = 0
var _chosen_faction: int = 0 # 0 = Apes (Attackers), 1 = Aliens (Defenders)

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	HUD.visible = false
	$VBoxContainer/DeployButton.grab_focus()

func _on_apes_button_pressed():
	_chosen_faction = 0
	# Visual feedback (optional but helpful)
	$VBoxContainer/FactionHBox/ApesButton.modulate = Color.GREEN
	$VBoxContainer/FactionHBox/AliensButton.modulate = Color.WHITE

func _on_aliens_button_pressed():
	_chosen_faction = 1
	$VBoxContainer/FactionHBox/ApesButton.modulate = Color.WHITE
	$VBoxContainer/FactionHBox/AliensButton.modulate = Color.GREEN

func _on_breacher_pressed():
	_chosen_class = 0

func _on_warden_pressed():
	_chosen_class = 1

func _on_ghost_pressed():
	_chosen_class = 2

func _on_deploy_pressed():
	PlayerSetup.selected_class_index = _chosen_class
	PlayerSetup.selected_faction = _chosen_faction
	get_tree().change_scene_to_file("res://level.tscn")
