extends Control

const SIDE_NAMES := ["Attack", "Defend", "Random"]

var _chosen_class: int = 0
var _chosen_faction: int = 0 # 0 = Apes, 1 = Aliens
var _chosen_side: int = 0    # 0 = Attack, 1 = Defend, 2 = Random (see PlayerSetup.Side)

var _side_buttons: Array[Button] = []
var _swap_check: CheckButton
var _summary_label: Label

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	HUD.visible = false

	# Start from the last choices, so coming back from a round shows what you had
	_chosen_faction = PlayerSetup.selected_faction
	_chosen_class = PlayerSetup.selected_class_index
	_chosen_side = PlayerSetup.side_choice

	# Center the faction row like the class row (its buttons were hugging the left edge)
	$VBoxContainer/FactionHBox.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	_build_side_ui()
	_refresh_selection()
	$VBoxContainer/DeployButton.grab_focus()

# The side picker is built in code so the scene file doesn't need editing.
func _build_side_ui():
	var vbox: VBoxContainer = $VBoxContainer
	var insert_at = $VBoxContainer/FactionHBox.get_index() + 1

	var side_box = HBoxContainer.new()
	side_box.name = "SideHBox"
	side_box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	for i in range(SIDE_NAMES.size()):
		var button = Button.new()
		button.text = SIDE_NAMES[i]
		button.pressed.connect(_on_side_pressed.bind(i))
		side_box.add_child(button)
		_side_buttons.append(button)
	vbox.add_child(side_box)
	vbox.move_child(side_box, insert_at)

	_swap_check = CheckButton.new()
	_swap_check.text = "Swap sides each round"
	_swap_check.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_swap_check.button_pressed = PlayerSetup.swap_each_round
	_swap_check.toggled.connect(_on_swap_toggled)
	vbox.add_child(_swap_check)
	vbox.move_child(_swap_check, insert_at + 1)

	_summary_label = Label.new()
	_summary_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_summary_label)
	vbox.move_child(_summary_label, insert_at + 2)

func _mark(button: Button, selected: bool):
	button.modulate = Color.GREEN if selected else Color.WHITE

func _refresh_selection():
	_mark($VBoxContainer/FactionHBox/ApesButton, _chosen_faction == GameManager.TEAM_ALPHA)
	_mark($VBoxContainer/FactionHBox/AliensButton, _chosen_faction == GameManager.TEAM_BRAVO)

	_mark($VBoxContainer/HBoxContainer/BreacherButton, _chosen_class == 0)
	_mark($VBoxContainer/HBoxContainer/WardenButton, _chosen_class == 1)
	_mark($VBoxContainer/HBoxContainer/GhostButton, _chosen_class == 2)

	for i in range(_side_buttons.size()):
		_mark(_side_buttons[i], _chosen_side == i)

	_summary_label.text = _describe_choice()

func _describe_choice() -> String:
	var mine = GameManager.get_team_name(_chosen_faction)
	var theirs = GameManager.get_team_name(GameManager.get_opposing_team(_chosen_faction))

	var text: String
	if _chosen_side == PlayerSetup.Side.ATTACK:
		text = "%s ATTACK, %s DEFEND" % [mine, theirs]
	elif _chosen_side == PlayerSetup.Side.DEFEND:
		text = "%s DEFEND, %s ATTACK" % [mine, theirs]
	else:
		text = "Sides are picked at random when you deploy"

	if _swap_check and _swap_check.button_pressed:
		text += "\n(then swapping every round)"
	return text

func _on_apes_button_pressed():
	_chosen_faction = GameManager.TEAM_ALPHA
	_refresh_selection()

func _on_aliens_button_pressed():
	_chosen_faction = GameManager.TEAM_BRAVO
	_refresh_selection()

func _on_breacher_pressed():
	_chosen_class = 0
	_refresh_selection()

func _on_warden_pressed():
	_chosen_class = 1
	_refresh_selection()

func _on_ghost_pressed():
	_chosen_class = 2
	_refresh_selection()

func _on_side_pressed(side: int):
	_chosen_side = side
	_refresh_selection()

func _on_swap_toggled(_pressed: bool):
	_refresh_selection()

func _on_deploy_pressed():
	PlayerSetup.selected_class_index = _chosen_class
	PlayerSetup.selected_faction = _chosen_faction
	PlayerSetup.side_choice = _chosen_side
	PlayerSetup.swap_each_round = _swap_check.button_pressed
	PlayerSetup.resolve_roles()
	get_tree().change_scene_to_file("res://level.tscn")
