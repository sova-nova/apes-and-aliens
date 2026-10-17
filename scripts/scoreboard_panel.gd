class_name ScoreboardPanel
extends PanelContainer
## Both teams' stats: score, kills, deaths, assists, damage, captures, and accuracy.
## Held with Tab during a match, and shown in full on the round-end screen.
## Call refresh() to redraw it from GameManager's stats.

## Text size for the table (the round-end screen uses a smaller one).
@export var font_size: int = 16

const COLUMNS := ["Player", "Class", "Score", "K", "D", "A", "Damage", "Caps", "Acc"]
const WIDTHS := [130, 92, 64, 38, 38, 38, 72, 50, 58]
const PLAYER_ID := "player"

var _content: VBoxContainer

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 14)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(margin)

	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 10)
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(_content)
	refresh()

func refresh() -> void:
	if _content == null:
		return
	# Remove the old rows right away (queue_free alone would leave them in the layout for a frame)
	for child in _content.get_children():
		_content.remove_child(child)
		child.queue_free()

	# Your team first
	var mine := PlayerSetup.selected_faction
	_add_team(mine)
	_add_team(GameManager.get_opposing_team(mine))

func _add_team(team: int) -> void:
	var rows := GameManager.get_scoreboard(team)

	var total_kills := 0
	for r in rows:
		total_kills += int(r["kills"])
	var role := "ATTACKING" if team == GameManager.attacking_team else "DEFENDING"
	if team == GameManager.attacking_team:
		role += " (%d/%d points)" % [GameManager.points_captured, GameManager.capture_points.size()]

	var header := Label.new()
	header.text = "%s   ·   %s   ·   %d kills" % [GameManager.get_team_name(team), role, total_kills]
	header.add_theme_color_override("font_color", GameManager.get_team_color(team))
	header.add_theme_font_size_override("font_size", font_size + 2)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(header)

	var grid := GridContainer.new()
	grid.columns = COLUMNS.size()
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 3)
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(grid)

	for i in range(COLUMNS.size()):
		var title := _cell(COLUMNS[i], i, Color(1, 1, 1, 0.55))
		grid.add_child(title)

	for r in rows:
		var color := Color(1.0, 0.85, 0.3) if r["id"] == PLAYER_ID else Color.WHITE
		var accuracy := float(r["accuracy"])
		var cells := [
			r["name"], r["class"], str(r["score"]), str(r["kills"]), str(r["deaths"]),
			str(r["assists"]), str(int(round(float(r["damage"])))), str(r["captures"]),
			"-" if accuracy < 0.0 else "%d%%" % int(round(accuracy * 100.0)),
		]
		for i in range(cells.size()):
			grid.add_child(_cell(str(cells[i]), i, color))

func _cell(text: String, column: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.custom_minimum_size.x = WIDTHS[column]
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if column >= 2:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.clip_text = true
	return label
