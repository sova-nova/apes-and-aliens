extends Control

const SIDE_NAMES := ["Attack", "Defend", "Random"]

# Same order as the buttons (and the player's available_classes)
const CLASSES := [
	preload("res://classes/breacher.tres"),
	preload("res://classes/warden.tres"),
	preload("res://classes/ghost.tres"),
]
const CLASS_TITLES := ["Breacher", "Warden", "Ghost"]
const CLASS_TAGLINES := [
	"Fast-firing all-rounder with an escape dash.",
	"Heavy tank that holds ground with cover and blasts.",
	"Fragile sniper that hits hard from range.",
]
const ABILITY_KEYS := ["Q", "E", "Shift"]

var _chosen_class: int = 0
var _chosen_faction: int = 0 # 0 = Apes, 1 = Aliens
var _chosen_side: int = 0    # 0 = Attack, 1 = Defend, 2 = Random (see PlayerSetup.Side)

var _side_buttons: Array[Button] = []
var _swap_check: CheckButton
var _summary_label: Label
var _info_title: Label
var _info_stats: Label
var _info_weapon: Label
var _info_abilities: Array[Label] = []

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
	_build_info_panel()
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

# The class info panel is built in code so the scene file doesn't need editing.
func _build_info_panel():
	var vbox: VBoxContainer = $VBoxContainer
	var deploy_index = $VBoxContainer/DeployButton.get_index()

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(680, 0) # Fixed width, so switching classes never jiggles the layout

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	margin.add_child(box)

	_info_title = Label.new()
	_info_title.add_theme_font_size_override("font_size", 20)
	box.add_child(_info_title)

	_info_stats = Label.new()
	_info_stats.modulate = Color(1, 1, 1, 0.85)
	box.add_child(_info_stats)

	_info_weapon = Label.new()
	_info_weapon.modulate = Color(1, 1, 1, 0.85)
	box.add_child(_info_weapon)

	box.add_child(HSeparator.new())

	for i in range(3):
		var label := Label.new()
		box.add_child(label)
		_info_abilities.append(label)

	vbox.add_child(panel)
	vbox.move_child(panel, deploy_index)

	# A one-line controls reminder between the panel and the Deploy button
	var controls := Label.new()
	controls.text = ControlsHelp.one_line()
	controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	controls.add_theme_font_size_override("font_size", 14)
	controls.modulate = Color(1, 1, 1, 0.65)
	vbox.add_child(controls)
	vbox.move_child(controls, deploy_index + 1)

func _update_info_panel():
	if _info_title == null:
		return
	var c: CharacterClass = CLASSES[_chosen_class]

	_info_title.text = "%s  —  %s" % [CLASS_TITLES[_chosen_class].to_upper(), CLASS_TAGLINES[_chosen_class]]
	var w := c.get_weapon()
	_info_stats.text = "HP %d   ·   Speed %.1f   ·   Weapon: %s" % [int(c.max_health), c.move_speed, w.weapon_name]
	if w.range_text() != "":
		_info_stats.text += "   ·   Best at %s" % w.range_text()
	_info_weapon.text = "%s   ·   Mag %d   ·   Reload %s" % [w.damage_text(), w.magazine_size, w.reload_text()]

	var types := [c.ability_1_type, c.ability_2_type, c.ability_3_type]
	var cooldowns := [c.ability_1_cooldown, c.ability_2_cooldown, c.ability_3_cooldown]
	for i in range(3):
		if types[i] == CharacterClass.AbilityType.NONE:
			_info_abilities[i].text = "[%s]  —" % ABILITY_KEYS[i]
		else:
			_info_abilities[i].text = "[%s]  %s (%ds)  —  %s" % [
				ABILITY_KEYS[i], CharacterClass.ability_name(types[i]), int(cooldowns[i]),
				CharacterClass.ability_desc(types[i])]

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
	_update_info_panel()

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
