extends Control

func _ready():
	HUD.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	$VBoxContainer/HBoxContainer/PlayAgainButton.grab_focus()

	var winner = GameManager.winning_team
	var label = $VBoxContainer/ResultLabel
	if winner == GameManager.TEAM_NONE:
		label.text = "MATCH OVER"
	else:
		label.text = "%s WIN!" % GameManager.get_team_name(winner)
		label.add_theme_color_override("font_color", GameManager.get_team_color(winner))

func _on_play_again_pressed():
	get_tree().change_scene_to_file("res://class_select.tscn")

func _on_main_menu_pressed():
	get_tree().change_scene_to_file("res://main_menu.tscn")
