extends Control

@onready var health_bar: ProgressBar = $MarginContainer/HBoxContainer/HealthBar
@onready var health_label: Label = $MarginContainer/HBoxContainer/HealthLabel
@onready var crosshair: Label = $CenterContainer/Crosshair
@onready var alpha_score_label: Label = $HBoxContainer/AlphaScore
@onready var bravo_score_label: Label = $HBoxContainer/BravoScore
@onready var ability_label: Label = $MarginContainer2/AbilityLabel
@onready var objective_label: Label = $ObjectiveLabel
@onready var class_label: Label = $ClassLabel
@onready var timer_label: Label = $VBoxContainer/TimerLabel
@onready var countdown_label: Label = $CountdownLabel
@onready var ammo_label: Label = $AmmoLabel

var _player: CharacterBody3D = null
var _hit_tween: Tween = null

func _ready():
	if GameManager:
		GameManager.score_updated.connect(_on_score_updated)
		GameManager.objective_updated.connect(_on_objective_updated)
		GameManager.match_timer_updated.connect(_on_match_timer_updated)
		GameManager.match_state_changed.connect(_on_match_state_changed)

func _process(_delta: float):
	if not _player:
		_player = _find_player()
		if _player:
			_player.health_changed.connect(_on_health_changed)
			_player.ability_status_changed.connect(_on_ability_status_changed)
			_player.class_changed.connect(_on_class_changed)
			
			# FIX: Manually trigger the UI update right now for the starting class!
			if _player.character_class:
				_on_class_changed(_player.character_class.class_name_str)
				_on_health_changed(_player.current_health, _player.max_health)
				
func _on_match_timer_updated(time_left: float):
	if not timer_label: return
	var minutes = int(time_left) / 60
	var seconds = int(time_left) % 60
	var time_str = "%d:%02d" % [minutes, seconds]
	
	if GameManager.is_overtime:
		timer_label.text = "OVERTIME"
		timer_label.add_theme_color_override("font_color", Color.RED)
	else:
		timer_label.text = time_str
		if time_left < 30.0:
			timer_label.add_theme_color_override("font_color", Color.RED) # Urgency!
		else:
			timer_label.add_theme_color_override("font_color", Color.WHITE)

func _on_match_state_changed(new_state: String):
	if not countdown_label: return
	
	if new_state == "PLAYING":
		countdown_label.visible = false
	else:
		countdown_label.visible = true
		countdown_label.text = new_state
		
		if new_state == "GO!":
			countdown_label.add_theme_color_override("font_color", Color.GREEN)
		elif new_state == "OVERTIME":
			countdown_label.add_theme_color_override("font_color", Color.RED)
		else:
			countdown_label.add_theme_color_override("font_color", Color.WHITE)

func show_hit_marker():
	if crosshair:
		if _hit_tween and _hit_tween.is_running():
			_hit_tween.kill()
			
		crosshair.text = "X"
		crosshair.add_theme_color_override("font_color", Color.RED)
		
		_hit_tween = create_tween()
		_hit_tween.tween_interval(0.12)
		_hit_tween.tween_callback(func(): crosshair.text = "+")
		_hit_tween.tween_callback(func(): crosshair.add_theme_color_override("font_color", Color.WHITE))
		
func update_ammo(current: int, max_ammo: int, is_reloading: bool):
	if not ammo_label: return
	if is_reloading:
		ammo_label.text = "RELOADING..."
		ammo_label.add_theme_color_override("font_color", Color.RED)
	else:
		ammo_label.text = "%d / %d" % [current, max_ammo]
		if current <= 0:
			ammo_label.add_theme_color_override("font_color", Color.RED)
		else:
			ammo_label.add_theme_color_override("font_color", Color.WHITE)

func _on_health_changed(new_health: float, max_health: float):
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = new_health
	if health_label:
		health_label.text = "%d / %d" % [int(new_health), int(max_health)]

func _on_score_updated(alpha_score: int, bravo_score: int):
	if alpha_score_label:
		alpha_score_label.text = "Alpha: %d" % alpha_score
	if bravo_score_label:
		bravo_score_label.text = "Bravo: %d" % bravo_score

func _find_player() -> CharacterBody3D:
	var players = get_tree().get_nodes_in_group("players")
	if players.size() > 0:
		return players[0]
	return null
	
# We use variables to store the status of all 3 abilities
var _ability_timers: Array = [0.0, 0.0, 0.0]
var _ability_ready: Array = [true, true, true]

func _on_ability_status_changed(slot: int, is_ready: bool, time_left: float):
	# Store the data for the slot that just updated
	_ability_timers[slot] = time_left
	_ability_ready[slot] = is_ready
	
	# Update the UI label
	if not ability_label:
		return
		
	var keys = ["Q", "E", "Shift"]
	var text_lines = []
	
	# Build a string for all 3 abilities
	for i in range(3):
		if _ability_ready[i]:
			text_lines.append("%s: [Ready]" % keys[i])
		else:
			text_lines.append("%s: [%.1f]" % [keys[i], _ability_timers[i]])
			
	# Join them with line breaks so they stack nicely in the corner
	ability_label.text = "\n".join(text_lines)
	
	# Turn green if the first ability is ready, white otherwise
	if _ability_ready[0]:
		ability_label.add_theme_color_override("font_color", Color.GREEN)
	else:
		ability_label.add_theme_color_override("font_color", Color.WHITE)
		
func _on_objective_updated(active_point_order: int):
	if objective_label:
		var point_letter = char(65 + active_point_order) # 0=A, 1=B, 2=C
		objective_label.text = "Objective: Capture Point %s" % point_letter
		
func _on_class_changed(new_class_name: String):
	if class_label:
		class_label.text = "Class: %s" % new_class_name
