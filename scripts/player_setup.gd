extends Node

# This holds the player's choices between scenes (and a small series tally between rounds)

enum Side { ATTACK, DEFEND, RANDOM }

var selected_faction: int = 0 # 0 = Apes, 1 = Aliens
var selected_class_index: int = 0 # 0, 1, or 2

# What the player asked for. RANDOM is rolled when a match is deployed.
var side_choice: int = Side.ATTACK
var swap_each_round: bool = false

# Which team attacks this match. Independent of the player's faction,
# so any faction can attack or defend. 0 = Apes, 1 = Aliens.
# Set by resolve_roles(); GameManager reads it when a level starts.
var attacking_team: int = 0

# Series tally (reset from the main menu). wins[0] = Apes, wins[1] = Aliens.
var wins: Array[int] = [0, 0]
var rounds_played: int = 0

## Turns the player's faction + side choice into the match's attacking team.
func resolve_roles():
	var other = 1 - selected_faction
	if side_choice == Side.ATTACK:
		attacking_team = selected_faction
	elif side_choice == Side.DEFEND:
		attacking_team = other
	else:
		attacking_team = [selected_faction, other].pick_random()

## Call between rounds. With swapping on, the player takes the side they did NOT just play.
func prepare_next_round(player_attacked: bool):
	if swap_each_round:
		side_choice = Side.DEFEND if player_attacked else Side.ATTACK

## Called once by GameManager when a match ends.
func record_result(winner: int):
	if winner == 0 or winner == 1:
		wins[winner] += 1
		rounds_played += 1

func reset_series():
	wins = [0, 0]
	rounds_played = 0
