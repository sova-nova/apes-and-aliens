extends Control

func _ready():
	HUD.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	$VBoxContainer/HBoxContainer/PlayAgainButton.grab_focus()
	# Check who won via the GameManager autoload
	if GameManager.team_alpha_score >= GameManager.score_to_win:
		$VBoxContainer/ResultLabel.text = "PRIMAL APES WIN!"
		$VBoxContainer/ResultLabel.add_theme_color_override("font_color", Color.DODGER_BLUE)
	else:
		$VBoxContainer/ResultLabel.text = "CHROME LEGION WINS!"
		$VBoxContainer/ResultLabel.add_theme_color_override("font_color", Color.RED)

func _on_play_again_pressed():
	# Reset scores and go back to class select
	GameManager.team_alpha_score = 0
	GameManager.team_bravo_score = 0
	get_tree().change_scene_to_file("res://class_select.tscn")

func _on_main_menu_pressed():
	GameManager.team_alpha_score = 0
	GameManager.team_bravo_score = 0
	get_tree().change_scene_to_file("res://main_menu.tscn")
