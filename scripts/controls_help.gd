class_name ControlsHelp
extends RefCounted
## The controls text shown on class select and in the pause menu, in one place.
## If you rebind an input action, update BINDINGS here.

const BINDINGS := [
	["WASD", "Move"],
	["Space", "Jump"],
	["Mouse", "Aim"],
	["Left click", "Shoot"],
	["R", "Reload"],
	["Q / E / Shift", "Abilities"],
	["Esc", "Pause"],
]

## A compact one-liner: "WASD move · Space jump · ..."
static func one_line() -> String:
	var parts := PackedStringArray()
	for b in BINDINGS:
		parts.append("%s %s" % [b[0], String(b[1]).to_lower()])
	return "   ·   ".join(parts)

## A tidy key / action grid for the pause menu.
static func build_grid() -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = 4 # key, action, key, action
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 4)
	for b in BINDINGS:
		var key := Label.new()
		key.text = b[0]
		key.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
		grid.add_child(key)
		var action := Label.new()
		action.text = b[1]
		action.custom_minimum_size.x = 80
		grid.add_child(action)
	return grid
