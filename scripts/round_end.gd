extends Control

var _player_attacked: bool = false

func _ready():
	HUD.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	var winner = GameManager.winning_team
	var label = $VBoxContainer/ResultLabel
	if winner == GameManager.TEAM_NONE:
		label.text = "MATCH OVER"
	else:
		label.text = "%s WIN!" % GameManager.get_team_name(winner)
		label.add_theme_color_override("font_color", GameManager.get_team_color(winner))

	# Which role did the player just play? (GameManager keeps the last match's roles.)
	_player_attacked = (PlayerSetup.selected_faction == GameManager.attacking_team)

	_build_extras(winner)

# Extra UI is built in code so the scene file doesn't need editing.
func _build_extras(winner: int):
	var vbox: VBoxContainer = $VBoxContainer
	var buttons: HBoxContainer = $VBoxContainer/HBoxContainer

	var info = Label.new()
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.text = _build_info_text(winner)
	vbox.add_child(info)
	vbox.move_child(info, $VBoxContainer/ResultLabel.get_index() + 1)

	var next_round = Button.new()
	next_round.text = "Next Round"
	next_round.pressed.connect(_on_next_round_pressed)
	buttons.add_child(next_round)
	buttons.move_child(next_round, 0)

	# The existing button still goes to class select, so name it for what it does now
	$VBoxContainer/HBoxContainer/PlayAgainButton.text = "Change Loadout"

	next_round.grab_focus()

func _build_info_text(winner: int) -> String:
	var lines: Array[String] = []

	if winner != GameManager.TEAM_NONE:
		var verdict = "VICTORY" if winner == PlayerSetup.selected_faction else "DEFEAT"
		var reason = "the attackers captured every point" if winner == GameManager.attacking_team \
			else "the defenders held until time ran out"
		lines.append("%s: %s" % [verdict, reason])
		lines.append("Round %d:  %s %d - %d %s" % [
			PlayerSetup.rounds_played,
			GameManager.get_team_name(GameManager.TEAM_ALPHA), PlayerSetup.wins[GameManager.TEAM_ALPHA],
			PlayerSetup.wins[GameManager.TEAM_BRAVO], GameManager.get_team_name(GameManager.TEAM_BRAVO)])

	lines.append(_next_round_text())
	return "\n".join(PackedStringArray(lines))

func _next_round_text() -> String:
	if PlayerSetup.swap_each_round:
		return "Next round: you %s" % ("DEFEND" if _player_attacked else "ATTACK")
	if PlayerSetup.side_choice == PlayerSetup.Side.RANDOM:
		return "Next round: random side"
	return "Next round: you %s" % ("ATTACK" if _player_attacked else "DEFEND")

# Same faction and class, straight into the next match (sides swap if that's enabled)
func _on_next_round_pressed():
	PlayerSetup.prepare_next_round(_player_attacked)
	PlayerSetup.resolve_roles()
	get_tree().change_scene_to_file("res://level.tscn")

# Back to class select, which shows the next round's side preselected
func _on_play_again_pressed():
	PlayerSetup.prepare_next_round(_player_attacked)
	get_tree().change_scene_to_file("res://class_select.tscn")

func _on_main_menu_pressed():
	get_tree().change_scene_to_file("res://main_menu.tscn")
