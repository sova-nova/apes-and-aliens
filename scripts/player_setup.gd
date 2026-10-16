extends Node

# This holds the player's choices between scenes
var selected_faction: int = 0 # 0 = Apes, 1 = Aliens
var selected_class_index: int = 0 # 0, 1, or 2

# Which team attacks this match. Independent of the player's faction,
# so any faction can attack or defend. 0 = Apes, 1 = Aliens.
var attacking_team: int = 0
