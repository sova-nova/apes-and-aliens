extends Control

@onready var health_bar: ProgressBar = $MarginContainer/HBoxContainer/HealthBar
@onready var health_label: Label = $MarginContainer/HBoxContainer/HealthLabel
@onready var crosshair: Label = $CenterContainer/Crosshair
@onready var points_label: Label = $VBoxContainer/HBoxContainer/AlphaScore
@onready var role_label: Label = $VBoxContainer/HBoxContainer/BravoScore
@onready var ability_label: Label = $MarginContainer2/AbilityLabel
@onready var objective_label: Label = $ObjectiveLabel
@onready var class_label: Label = $ClassLabel
@onready var timer_label: Label = $VBoxContainer/TimerLabel
@onready var countdown_label: Label = $CountdownLabel
@onready var ammo_label: Label = $AmmoLabel
@onready var kill_feed_vbox: VBoxContainer = $KillFeedVBox
@onready var vignette_rect: ColorRect = $VignetteRect

var _player: CharacterBody3D = null

var _crosshair: Crosshair
var _scoreboard_holder: Control
var _scoreboard: ScoreboardPanel
var _scoreboard_timer: float = 0.0
var _death_screen: DeathScreen

func _ready():
	_build_crosshair()
	_build_ability_bar()
	_build_damage_indicator()
	_build_scoreboard()
	_build_death_screen()

	if GameManager:
		GameManager.score_updated.connect(_on_score_updated)
		GameManager.objective_updated.connect(_on_objective_updated)
		GameManager.match_timer_updated.connect(_on_match_timer_updated)
		GameManager.match_state_changed.connect(_on_match_state_changed)
		if not GameManager.kill_occurred.is_connected(_on_kill_occurred):
			GameManager.kill_occurred.connect(_on_kill_occurred)

func _process(_delta: float):
	if not visible:
		return # Menus: nothing to bind or refresh

	_update_scoreboard(_delta)

	# (Re)bind to the player. is_instance_valid also catches a player freed by a scene reload,
	# which a plain `if not _player` can't tell apart from a live one.
	if not is_instance_valid(_player):
		_player = _find_player()
		if _player:
			_player.health_changed.connect(_on_health_changed)
			_player.ability_status_changed.connect(_on_ability_status_changed)
			_player.class_changed.connect(_on_class_changed)
			_player.ammo_changed.connect(_on_ammo_changed)
			_player.damage_taken.connect(_damage_indicator.show_hit_from)
			_player.death_info_ready.connect(_on_player_died)
			_player.respawned.connect(_on_player_respawned)
			_on_player_respawned() # A new match: make sure nothing from the last death is still showing

			# Show the starting state right away
			if _player.character_class:
				_on_class_changed(_player.character_class.class_name_str)
				_on_health_changed(_player.current_health, _player.max_health)
				_on_ammo_changed(_player.current_ammo, _player.max_ammo, _player.is_reloading)

	# The ability readout is rebuilt at most once per frame, and only if something changed
	if _ability_dirty:
		_ability_dirty = false
		_refresh_ability_label()

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
			
func _on_kill_occurred(killer_name: String, victim_name: String, victim_faction: int):
	if not kill_feed_vbox: return
	
	var label = Label.new()
	# Format: "Killer -> Victim"
	if killer_name == "":
		label.text = "%s died" % victim_name
	else:
		label.text = "%s -> %s" % [killer_name, victim_name]
	
	# Color the text based on who died
	if victim_faction == PlayerSetup.selected_faction:
		label.add_theme_color_override("font_color", Color.RED) # Ally died
	else:
		label.add_theme_color_override("font_color", Color.DODGER_BLUE) # Enemy died
		
	kill_feed_vbox.add_child(label)
	
	# Fade out and delete after 4 seconds
	await get_tree().create_timer(4.0, false).timeout
	if is_instance_valid(label):
		var tween = label.create_tween()
		tween.tween_property(label, "modulate:a", 0.0, 1.0)
		tween.tween_callback(label.queue_free)

func show_hit_marker(is_kill: bool = false):
	if _crosshair:
		_crosshair.flash_hit(is_kill)

func _on_ammo_changed(current: int, max_ammo: int, is_reloading: bool):
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
		
	# --- Vignette Logic ---
	if vignette_rect and max_health > 0:
		var health_pct = new_health / max_health
		if health_pct < 0.3:
			# Fade in red (Alpha goes up to 0.4)
			var target_alpha = (0.3 - health_pct) / 0.3 * 0.4
			vignette_rect.color.a = target_alpha
		else:
			vignette_rect.color.a = 0.0 # Fully transparent

func _on_score_updated(points_captured: int, total_points: int):
	if points_label:
		points_label.text = "Points: %d/%d" % [points_captured, total_points]
	_update_role_label()
	
func _update_role_label():
	if not role_label:
		return
	var is_attacker = PlayerSetup.selected_faction == GameManager.attacking_team
	role_label.text = "ATTACKING" if is_attacker else "DEFENDING"
	role_label.add_theme_color_override("font_color", GameManager.get_team_color(PlayerSetup.selected_faction))

func _find_player() -> CharacterBody3D:
	var players = get_tree().get_nodes_in_group("players")
	if players.size() > 0:
		return players[0]
	return null
	
# ─── Ability bar ────────────────────────────────────────────
# Three slots along the bottom: key, name, a recharge bar, and the seconds left while cooling down.
const ABILITY_KEYS := ["Q", "E", "Shift"]

var _ability_timers: Array = [0.0, 0.0, 0.0]
var _ability_ready: Array = [true, true, true]
var _ability_dirty: bool = false  # The bar is refreshed at most once per frame, and only when this is set
var _slots: Array = []            # One Dictionary per ability slot: {panel, time, title, bar}
var _damage_indicator: DamageIndicator

func _build_ability_bar() -> void:
	if ability_label:
		ability_label.visible = false # The bar replaces the old text readout

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_bottom", 22)
	add_child(margin)

	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_END # Sit at the bottom of the screen
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(column)

	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(row)

	for i in range(3):
		var panel := PanelContainer.new()
		panel.custom_minimum_size = Vector2(124, 0)
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(panel)

		var inner := VBoxContainer.new()
		inner.add_theme_constant_override("separation", 2)
		inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(inner)

		var top := HBoxContainer.new()
		top.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.add_child(top)

		var key_label := Label.new()
		key_label.text = ABILITY_KEYS[i]
		key_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
		key_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top.add_child(key_label)

		var time_label := Label.new()
		time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		top.add_child(time_label)

		var title_label := Label.new()
		title_label.add_theme_font_size_override("font_size", 14)
		inner.add_child(title_label)

		var bar := ProgressBar.new()
		bar.min_value = 0.0
		bar.max_value = 1.0
		bar.value = 1.0
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(0, 8)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.add_child(bar)

		_slots.append({"panel": panel, "time": time_label, "title": title_label, "bar": bar})

## The drawn, customizable crosshair replaces the old "+" label.
func _build_crosshair() -> void:
	if crosshair:
		crosshair.visible = false
	_crosshair = Crosshair.new()
	_crosshair.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_crosshair)

## Hold Tab to see everyone's stats.
func _build_scoreboard() -> void:
	_scoreboard_holder = CenterContainer.new()
	_scoreboard_holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_scoreboard_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scoreboard_holder.visible = false
	add_child(_scoreboard_holder)

	_scoreboard = ScoreboardPanel.new()
	_scoreboard_holder.add_child(_scoreboard)

func _build_death_screen() -> void:
	_death_screen = DeathScreen.new()
	add_child(_death_screen)

## Shows the scoreboard while Tab is held, refreshing it a few times a second.
func _update_scoreboard(delta: float) -> void:
	var want := Input.is_key_pressed(KEY_TAB) and not GameManager.stats.is_empty()
	if want != _scoreboard_holder.visible:
		_scoreboard_holder.visible = want
		if want:
			_scoreboard.refresh()
			_scoreboard_timer = 0.25
	elif want:
		_scoreboard_timer -= delta
		if _scoreboard_timer <= 0.0:
			_scoreboard_timer = 0.25
			_scoreboard.refresh()

func _on_player_died(info: Dictionary) -> void:
	_crosshair.visible = false # No crosshair while you're watching your killer
	_death_screen.show_death(info)

func _on_player_respawned() -> void:
	_death_screen.hide_screen()
	_crosshair.visible = true

func _build_damage_indicator() -> void:
	_damage_indicator = DamageIndicator.new()
	add_child(_damage_indicator) # Added last, so it draws above everything else

## Fills in each slot's ability name from the player's class (and hides slots with no ability).
func _update_ability_names() -> void:
	if _slots.is_empty() or not is_instance_valid(_player) or not _player.character_class:
		return
	var c = _player.character_class
	var types := [c.ability_1_type, c.ability_2_type, c.ability_3_type]
	for i in range(3):
		_slots[i].panel.visible = types[i] != CharacterClass.AbilityType.NONE
		_slots[i].title.text = CharacterClass.ability_name(types[i])

func _ability_total_cooldown(slot: int) -> float:
	if not is_instance_valid(_player) or not _player.character_class:
		return 1.0
	var c = _player.character_class
	match slot:
		0: return c.ability_1_cooldown
		1: return c.ability_2_cooldown
	return c.ability_3_cooldown

func _on_ability_status_changed(slot: int, is_ready: bool, time_left: float):
	_ability_timers[slot] = time_left
	_ability_ready[slot] = is_ready
	_ability_dirty = true

func _refresh_ability_label() -> void:
	if _slots.is_empty():
		return
	for i in range(3):
		var slot = _slots[i]
		var is_ready: bool = _ability_ready[i]
		var left: float = _ability_timers[i]
		var total := _ability_total_cooldown(i)

		slot.time.text = "" if is_ready else "%.1f" % left
		# The bar fills as the ability recharges, and glows green once it's ready
		slot.bar.value = 1.0 if is_ready else clampf(1.0 - left / maxf(total, 0.01), 0.0, 1.0)
		slot.bar.modulate = Color(0.45, 1.0, 0.55) if is_ready else Color(0.6, 0.75, 1.0)
		slot.panel.modulate = Color(1, 1, 1, 1.0 if is_ready else 0.7)

func _on_objective_updated(active_point_order: int):
	if not objective_label:
		return
	var point_letter = char(65 + active_point_order) # 0=A, 1=B, 2=C
	if PlayerSetup.selected_faction == GameManager.attacking_team:
		objective_label.text = "Objective: Capture Point %s" % point_letter
	else:
		objective_label.text = "Objective: Defend Point %s" % point_letter
		
func _on_class_changed(new_class_name: String):
	if class_label:
		class_label.text = "Class: %s" % new_class_name
	_update_ability_names()
	_ability_dirty = true # Redraw the bar (new cooldown lengths)
