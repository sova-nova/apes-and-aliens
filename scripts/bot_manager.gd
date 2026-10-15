extends Node

@export var max_bots_per_team: int = 5
@export var spawn_interval: float = 4.0

# Automatically load the classes from your filesystem, no Inspector setup needed!
var bot_classes: Array[CharacterClass] = [
	preload("res://classes/breacher.tres"), # Replace with your actual filenames!
	preload("res://classes/warden.tres"),
	preload("res://classes/ghost.tres")
]

var enemy_scene = preload("res://bot.tscn")

var _spawn_timer: float = 0.0

func _process(delta):
	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn_timer = spawn_interval
		_try_spawn_team(0) # Team Alpha
		_try_spawn_team(1) # Team Bravo

func _try_spawn_team(team: int):
	# Count how many bots of this team are currently alive
	var current_bots = 0
	for bot in get_tree().get_nodes_in_group("bots"):
		if is_instance_valid(bot) and bot.faction == team:
			current_bots += 1
			
	# If we haven't hit the limit, spawn a new one
	if current_bots < max_bots_per_team:
		_spawn_bot(team)

func _spawn_bot(team: int):
	if not enemy_scene:
		print("Bot Manager: Bot scene is missing!")
		return
		
	var spawn_group = "team_alpha_spawns" if team == 0 else "team_bravo_spawns"
	var spawns = get_tree().get_nodes_in_group(spawn_group)
	
	if spawns.size() == 0:
		return 
		
	var spawn_point = spawns.pick_random()
	
	var new_bot = enemy_scene.instantiate()
	new_bot.faction = team
	new_bot.add_to_group("bots")
	
	# Assign a random class to the bot
	if bot_classes.size() > 0:
		new_bot.character_class = bot_classes.pick_random()
		
	# Position the bot randomly inside the spawn area
	if spawn_point.has_method("get_random_point_inside"):
		new_bot.global_position = spawn_point.get_random_point_inside()
	else:
		new_bot.global_position = spawn_point.global_position
		
	get_tree().current_scene.add_child(new_bot)
