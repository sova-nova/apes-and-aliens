extends CharacterBody3D

enum DefendRole { ANCHOR, HOLDER, FORWARD }

@export_enum("Alpha (Apes):0", "Bravo (Chrome Legion):1") var faction: int = 1
@export var character_class: CharacterClass

@export_group("Aim")
## Spread multiplier right after the bot takes damage (1.0 = no penalty).
@export var flinch_spread_multiplier: float = 2.0
## Seconds for the flinch penalty to fade back to normal.
@export var flinch_duration: float = 1.0

@export_group("Defender AI")
## Chance a defender is an ANCHOR (holds close to the point).
@export_range(0.0, 1.0) var anchor_chance: float = 0.3
## Chance a defender is FORWARD (skirmishes out ahead). The rest are HOLDERs.
@export_range(0.0, 1.0) var forward_chance: float = 0.2
## Guard-post distance from the point as (min, max) metres, per role.
@export var anchor_radius: Vector2 = Vector2(0.0, 4.0)
@export var holder_radius: Vector2 = Vector2(5.0, 10.0)
@export var forward_radius: Vector2 = Vector2(11.0, 16.0)
## Defenders never post closer than this to the attackers' spawn.
@export var min_spawn_distance: float = 12.0
## How often (min, max seconds) holders and forwards move to a fresh post.
@export var reposition_interval: Vector2 = Vector2(10.0, 20.0)

@export_group("Debug")
## Draws each bot's navigation path. Costly with many bots, so leave it off unless diagnosing pathing.
@export var debug_navigation: bool = false

@export_group("Performance")
## How often (seconds) a bot looks for the nearest enemy. Staggered per bot.
@export var target_scan_interval: float = 0.2
## How often (seconds) a bot re-checks line of sight to its target.
@export var los_check_interval: float = 0.1

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var move_speed: float = 3.0
var attack_damage: float = 10.0
var attack_range: float = 10.0
var attack_cooldown: float = 1.0
var _attack_timer: float = 0.0
var _knockback_velocity: Vector3 = Vector3.ZERO
var is_vulnerable: bool = false

var _repath_timer: float = randf() # Randomized so bots don't all repath on the same frame

var health_bar_pivot: Node3D
var health_bar_mesh: MeshInstance3D
var health_bar_mat: StandardMaterial3D

var _target_point_ref: Node3D = null # Tracks which point we are heading to
var _current_point_target: Vector3 = Vector3.ZERO # The specific random spot we chose inside the point

var last_attacker_name: String = ""

# Identity for the scoreboard. BotManager sets display_name before the bot enters the tree.
var display_name: String = ""
var stats_id: String = ""
var _last_attacker_id: String = "" # Who hurt us last: they get the kill if we die

@onready var health_component: HealthComponent = $HealthComponent
@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var original_material: Material = mesh_instance.material_override if mesh_instance else null
@onready var nav_agent: NavigationAgent3D = $NavAgent

# --- AI Ability System ---
var ability_cooldowns: Array[float] = [0.0, 0.0, 0.0]
var _ability_eval_timer: float = 0.0
var _is_invulnerable: bool = false
var _damage_reduction_multiplier: float = 1.0
var _speed_multiplier: float = 1.0
var _damage_multiplier: float = 1.0   # Overcharge. Replaces mutating attack_damage directly.

# Effect timers (ticked every physics frame, so they are safe if the bot dies mid-effect)
var _dash_left: float = 0.0
var _overcharge_left: float = 0.0
var _bulwark_left: float = 0.0
var _adrenaline_left: float = 0.0
var _flash_left: float = 0.0

# Short forced movement (dash retreat, grapple lunge)
var _burst_left: float = 0.0
var _burst_velocity: Vector3 = Vector3.ZERO

# Target lock / life siphon
var _locked_target: Node3D = null
var _lock_time_left: float = 0.0
var _siphon_target: Node3D = null
var _siphon_time_left: float = 0.0
var _siphon_tick_timer: float = 0.0

var _since_damage: float = 99.0       # Seconds since we last took damage ("under fire" check)

# --- Aim & reaction (values come from the CharacterClass in apply_class) ---
var aim_spread_degrees: float = 2.0
var reaction_min: float = 0.3
var reaction_max: float = 0.5
var _engaged_target: Node3D = null    # Who we are currently fighting
var _reaction_left: float = 0.0       # Time until we may fire after spotting someone
var _disengaged_time: float = 0.0     # How long we have been out of a fight

# --- Targeting cache (scans and line-of-sight checks are throttled, see _get_combat_target / _can_see) ---
var _cached_target: Node3D = null
var _has_cached_target: bool = false
var _scan_timer: float = randf() * 0.2   # Staggered so bots don't all scan on the same frame
var _los_target: Node3D = null
var _los_cache: bool = false
var _los_timer: float = 0.0
var _cover_group: String = ""            # Group our team's cover walls join (see _ray_exclude)

# --- Defender AI state ---
var defend_role: DefendRole = DefendRole.HOLDER
var _guard_post: Vector3 = Vector3.ZERO
var _post_facing: Vector3 = Vector3.ZERO   # Which way to look while holding (toward attackers)
var _post_timer: float = 0.0
var _defender_at_post: bool = false        # True while holding a post (vs contesting the point)

func _ready():
	# --- Apply Team Color ---
	if mesh_instance:
		var team_mat = CombatFx.team_material(faction) # Shared by every bot on this team
		mesh_instance.material_override = team_mat
		original_material = team_mat
		
	health_component.died.connect(_on_died)
	nav_agent.debug_enabled = debug_navigation
	add_to_group("bots")
	add_to_group(GameManager.TEAM_GROUPS[faction]) # Enemies find us through this group
	_cover_group = "cover_walls_%d" % faction

	if display_name == "":
		display_name = "Bot %d" % (get_instance_id() % 100)
	stats_id = "%d:%s" % [faction, display_name]
	GameManager.register_combatant(stats_id, display_name, faction,
		character_class.class_name_str if character_class else "")
	
	if character_class:
		apply_class()

	_assign_defend_role()
		
	# --- Generate Health Bar ---
	var bar_container = Node3D.new()
	bar_container.position.y = 1.8 # Float above head
	add_child(bar_container)
	
	
	# 2. Foreground Bar (The green/yellow/red bar)
	health_bar_mesh = MeshInstance3D.new()
	var fg_mesh = QuadMesh.new()
	fg_mesh.size = Vector2(1.0, 0.1) # Vector2 for QuadMesh!
	health_bar_mesh.mesh = fg_mesh
	
	# Push slightly forward in Z so it renders IN FRONT of the grey bar
	health_bar_mesh.position.z = 0.001
	
	health_bar_mat = StandardMaterial3D.new()
	health_bar_mat.albedo_color = Color.GREEN
	health_bar_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	health_bar_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED # Ignore sun
	health_bar_mat.cull_mode = BaseMaterial3D.CULL_DISABLED # Visible from both sides
	health_bar_mesh.material_override = health_bar_mat
	
	bar_container.add_child(health_bar_mesh)
	
	# Hide health bar if they are an enemy
	if faction != PlayerSetup.selected_faction:
		bar_container.visible = false

func apply_class():
	if not character_class:
		push_warning("Bot is missing a CharacterClass!")
		return
		
	move_speed = character_class.move_speed
	attack_damage = character_class.gun_damage
	attack_cooldown = character_class.fire_rate
	attack_range = 15 # character_class.gun_range later
	aim_spread_degrees = character_class.bot_spread_degrees
	reaction_min = character_class.bot_reaction_min
	reaction_max = maxf(character_class.bot_reaction_max, reaction_min)
	
	if health_component:
		health_component.max_health = character_class.max_health
		health_component.current_health = character_class.max_health

func apply_knockback(force: Vector3):
	# Horizontal part decays over time; vertical part is a one-shot impulse
	# so gravity can bring the bot back down.
	_knockback_velocity = Vector3(force.x, 0.0, force.z)
	velocity.y = maxf(velocity.y, force.y)

func take_damage(amount: float, _source_faction: int = -1, attacker_name: String = "", _source_pos: Vector3 = Vector3.INF, attacker: Node = null):
	if health_component.is_dead():
		return
	if _is_invulnerable:
		return 
		
	_since_damage = 0.0
	var final_damage = amount * _damage_reduction_multiplier
	if is_vulnerable:
		final_damage *= 1.1 
		
	# Remember who shot us!
	if attacker_name != "":
		last_attacker_name = attacker_name

	# Credit the damage (scoreboard, assists), capped at what we had left so overkill doesn't inflate it
	if attacker != null and "stats_id" in attacker:
		_last_attacker_id = attacker.stats_id
		GameManager.report_damage(stats_id, attacker.stats_id, minf(final_damage, health_component.current_health))

	health_component.take_damage(final_damage)
	_flash_damage()
	update_health_bar()
	if AudioManager:
		AudioManager.play_hit(global_position)
		
func update_health_bar():
	if not health_bar_mesh or not health_bar_mesh.visible:
		return
		
	if not health_component:
		return
		
	var health_pct = health_component.current_health / health_component.max_health
	var new_width = 1.0 * health_pct
	
	# 1. Change the size of the QuadMesh (Uses Vector2)
	health_bar_mesh.mesh.size = Vector2(new_width, 0.1)
	
	# 2. Shift the mesh so its left edge stays pinned at -0.5
	health_bar_mesh.position.x = -0.5 + (new_width / 2.0)
	
	# 3. Change color based on health percentage
	if health_pct > 0.6:
		health_bar_mat.albedo_color = Color.GREEN
	elif health_pct > 0.3:
		health_bar_mat.albedo_color = Color.YELLOW
	else:
		health_bar_mat.albedo_color = Color.RED
	
func set_vulnerable(state: bool):
	is_vulnerable = state
	if state:
		_flash_color(Color.ORANGE, 0.2)

func _flash_damage():
	_flash_color(Color.RED, 0.1)

func _on_died():
	# Don't leave an enemy permanently marked vulnerable
	_end_target_lock()
	_siphon_target = null

	# Awards the kill (and any assists) and tells the kill feed
	GameManager.report_death(stats_id, _last_attacker_id)
	
	# Death Effect (We'll add this below)
	CombatFx.death_debris(self, global_position, faction)
	
	# The corpse shouldn't block shots, bodies, or the capture point while it shrinks
	$CollisionShape3D.set_deferred("disabled", true)

	# Shrink to a tiny size, never exactly zero: a zero-scale transform is singular
	# and makes the engine log "invert: Condition det == 0".
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector3.ONE * 0.01, 0.3).set_ease(Tween.EASE_IN)
	tween.tween_callback(queue_free)

func _physics_process(delta: float):
	if health_component.is_dead():
		return

	# --- MATCH COUNTDOWN GATE ---
	if not GameManager.is_match_playing:
		if not is_on_floor():
			velocity.y -= gravity * delta
		move_and_slide()
		return # Bots stand still during countdown

	if not is_on_floor():
		velocity.y -= gravity * delta

	_tick_effects(delta)

	# --- Abilities are evaluated in EVERY state, including mid-fight ---
	_los_timer -= delta
	var combat_target = _get_combat_target(delta)
	_ability_eval_timer -= delta
	if _ability_eval_timer <= 0.0:
		_ability_eval_timer = 0.5
		_evaluate_abilities(combat_target)

	# --- Movement: knockback and bursts override normal AI movement ---
	if _knockback_velocity.length() > 0.1:
		velocity.x = _knockback_velocity.x
		velocity.z = _knockback_velocity.z
		_knockback_velocity = _knockback_velocity.move_toward(Vector3.ZERO, delta * 15.0)
	elif _burst_left > 0.0:
		velocity.x = _burst_velocity.x
		velocity.z = _burst_velocity.z
	else:
		_knockback_velocity = Vector3.ZERO
		_move_and_fight(delta, combat_target)

	move_and_slide()

## Sets velocity for this frame (does not call move_and_slide).
func _move_and_fight(delta: float, combat_target: Node3D):
	var target_destination = Vector3.ZERO

	# Out of a fight for over a second? The next enemy we see is a fresh engagement.
	_disengaged_time += delta
	if _disengaged_time > 1.0:
		_engaged_target = null

	# Priority 1: If an opponent is in range and visible, fight them!
	if combat_target:
		var to_target = combat_target.global_position - global_position
		to_target.y = 0.0
		var dist = to_target.length()

		if dist <= attack_range and _can_see(combat_target):
			# ATTACK MODE
			velocity.x = move_toward(velocity.x, 0.0, move_speed)
			velocity.z = move_toward(velocity.z, 0.0, move_speed)

			if to_target.length_squared() > 0.01:
				rotation.y = atan2(-to_target.x, -to_target.z)

			# Reaction delay: a fresh engagement (or a new target after a kill)
			# costs a short random "spotting" time before the first shot.
			_disengaged_time = 0.0
			if not _is_valid_target(_engaged_target):
				_reaction_left = randf_range(reaction_min, reaction_max) * GameSettings.bot_reaction_mult(faction)
			_engaged_target = combat_target
			if _reaction_left > 0.0:
				_reaction_left -= delta
				return # Spotted them, still reacting: no shot yet

			_attack_timer -= delta
			if _attack_timer <= 0.0:
				_attack(combat_target)
				_attack_timer = attack_cooldown
			return # Skip pathfinding if we are shooting

	# Priority 2: If not fighting, move towards the active Capture Point!
	if GameManager and GameManager.active_capture_point:
		# Check if the active point has changed, or if we haven't picked a spot yet
		if GameManager.active_capture_point != _target_point_ref:
			_target_point_ref = GameManager.active_capture_point

			# Ask the capture point for a random position inside it!
			if _target_point_ref.has_method("get_random_point_inside"):
				_current_point_target = _target_point_ref.get_random_point_inside()
			else:
				_current_point_target = _target_point_ref.global_position

			# New objective: defenders pick where to hold
			if faction == GameManager.defending_team:
				_choose_guard_post()

		if faction == GameManager.defending_team:
			# DEFENDERS hold a post and only step onto the point when it's threatened
			target_destination = _get_defender_destination(delta)
		else:
			# ATTACKERS push onto the point
			target_destination = _current_point_target

	elif combat_target:
		# Fallback: If no point exists, just walk toward the nearest opponent
		target_destination = combat_target.global_position
	else:
		# Stand still if nothing to do
		velocity.x = move_toward(velocity.x, 0.0, move_speed)
		velocity.z = move_toward(velocity.z, 0.0, move_speed)
		return

	# --- PATHFINDING MOVEMENT ---
	# Re-set the target when it moved > 1 m, and at least once per second so the
	# agent notices navmesh changes (e.g. a gate's NavLink turning on).
	_repath_timer -= delta
	if _repath_timer <= 0.0 or nav_agent.target_position.distance_to(target_destination) > 1.0:
		_repath_timer = 1.0
		nav_agent.target_position = target_destination

	if not nav_agent.is_navigation_finished():
		var next_position = nav_agent.get_next_path_position()
		var direction = (next_position - global_position)
		direction.y = 0.0

		if direction.length() > 0.05:
			direction = direction.normalized()
			velocity.x = direction.x * move_speed * _speed_multiplier
			velocity.z = direction.z * move_speed * _speed_multiplier
			rotation.y = atan2(-direction.x, -direction.z)
		else:
			velocity.x = move_toward(velocity.x, 0.0, move_speed)
			velocity.z = move_toward(velocity.z, 0.0, move_speed)
	else:
		# Path is finished (We reached the capture point)
		# Stop moving, but face the center of the point so we contest it!
		velocity.x = move_toward(velocity.x, 0.0, move_speed)
		velocity.z = move_toward(velocity.z, 0.0, move_speed)

		var to_point = target_destination - global_position
		to_point.y = 0.0
		if _defender_at_post and _post_facing != Vector3.ZERO:
			# Holding a post: look toward where the attackers will come from
			rotation.y = atan2(-_post_facing.x, -_post_facing.z)
		elif to_point.length_squared() > 0.01:
			rotation.y = atan2(-to_point.x, -to_point.z)

## True if the node is a living, valid target (players, bots, anything with health).
# ─── Defender AI ────────────────────────────────────────────

func _assign_defend_role():
	var roll = randf()
	if roll < anchor_chance:
		defend_role = DefendRole.ANCHOR
	elif roll < anchor_chance + forward_chance:
		defend_role = DefendRole.FORWARD
	else:
		defend_role = DefendRole.HOLDER

## Where a defender wants to be this frame: on the point if it's threatened, else at its post.
func _get_defender_destination(delta: float) -> Vector3:
	var point = _target_point_ref
	var under_attack = point.attackers_on_point > 0 or point.capture_progress > 0.0
	var critical = point.capture_progress >= 50.0

	var contest = false
	match defend_role:
		DefendRole.ANCHOR, DefendRole.HOLDER:
			contest = under_attack   # Step in as soon as attackers touch the point
		DefendRole.FORWARD:
			contest = critical       # Skirmishers only fall back when it's getting serious

	if contest:
		_defender_at_post = false
		return _current_point_target

	# Holding: non-anchors drift to a fresh post now and then so they aren't sitting ducks
	_defender_at_post = true
	if defend_role != DefendRole.ANCHOR:
		_post_timer -= delta
		if _post_timer <= 0.0:
			_choose_guard_post()
	return _guard_post

## Picks a spot around the active point for this bot's role: on the navmesh,
## and never inside the attackers' spawn zone. Falls back to standing on the point.
func _choose_guard_post():
	var point = _target_point_ref
	if not is_instance_valid(point):
		return
	var center = point.global_position

	var radius: Vector2
	match defend_role:
		DefendRole.ANCHOR: radius = anchor_radius
		DefendRole.FORWARD: radius = forward_radius
		_: radius = holder_radius

	_post_timer = randf_range(reposition_interval.x, reposition_interval.y)
	_post_facing = GameManager.get_attacker_direction(center)
	_guard_post = _current_point_target # Fallback: stand on the point

	var nav_map = nav_agent.get_navigation_map()
	for attempt in range(8):
		var angle = randf() * TAU
		var r = randf_range(radius.x, radius.y)
		var candidate = center + Vector3(cos(angle) * r, 0.0, sin(angle) * r)
		candidate = NavigationServer3D.map_get_closest_point(nav_map, candidate)

		# Snapping can drag a spot through a wall: reject if it landed far from where we wanted
		if Vector2(candidate.x - center.x, candidate.z - center.z).length() > radius.y + 3.0:
			continue
		# Never hold a post inside the attackers' spawn zone
		if GameManager.distance_to_attacker_spawn(candidate) < min_spawn_distance:
			continue

		_guard_post = candidate
		return

# NOTE: deliberately untyped. A typed parameter (t: Node3D) is checked BEFORE the
# body runs, so passing a freed object would crash before is_instance_valid() could catch it.
func _is_valid_target(t) -> bool:
	if not is_instance_valid(t):
		return false
	if "is_alive" in t and not t.is_alive:
		return false
	if "health_component" in t and t.health_component and t.health_component.is_dead():
		return false
	return true

## Our own team's cover walls never block our shots.
func _ray_exclude() -> Array[RID]:
	var ex: Array[RID] = [get_rid()]
	for w in get_tree().get_nodes_in_group(_cover_group):
		if w is CollisionObject3D and is_instance_valid(w):
			ex.append(w.get_rid())
	return ex

# Untyped for the same reason as _is_valid_target: callers may hold a freed reference.
func has_line_of_sight(target) -> bool:
	# Safety check: If the target doesn't exist anymore, we don't have line of sight!
	if not is_instance_valid(target):
		return false
		
	var space_state = get_world_3d().direct_space_state
	var origin = global_position + Vector3(0, 0.5, 0)
	var target_pos = target.global_position + Vector3(0, 0.5, 0)
	var query = PhysicsRayQueryParameters3D.create(origin, target_pos)
	query.exclude = _ray_exclude() 
	var result = space_state.intersect_ray(query)
	if result.is_empty():
		return true
	if result.collider == target:
		return true
	return false

## The nearest living enemy. Only scans the enemy team's group, so no team or self checks needed.
func _find_nearest_target() -> Node3D:
	var enemy_group = GameManager.TEAM_GROUPS[GameManager.get_opposing_team(faction)]
	var my_pos = global_position
	var nearest: Node3D = null
	var nearest_dist_sq: float = INF

	for t in get_tree().get_nodes_in_group(enemy_group):
		if not _is_valid_target(t): # Skips dead players/bots, including ones still shrinking away
			continue
		var dist_sq = my_pos.distance_squared_to(t.global_position)
		if dist_sq < nearest_dist_sq:
			nearest_dist_sq = dist_sq
			nearest = t

	return nearest

## The enemy we're fighting. Rescans every `target_scan_interval`, or at once when our target dies.
func _get_combat_target(delta: float) -> Node3D:
	_scan_timer -= delta

	if _has_cached_target and not _is_valid_target(_cached_target):
		_cached_target = null
		_has_cached_target = false
		_scan_timer = 0.0 # Lost our target: look for a new one right away

	if _scan_timer <= 0.0:
		_scan_timer = target_scan_interval * randf_range(0.8, 1.2)
		_cached_target = _find_nearest_target()
		_has_cached_target = _cached_target != null
	return _cached_target

## Line of sight, re-checked every `los_check_interval` (or at once for a new target) instead of every frame.
func _can_see(target) -> bool:
	if target != _los_target or _los_timer <= 0.0:
		_los_target = target
		_los_cache = has_line_of_sight(target)
		_los_timer = los_check_interval * randf_range(0.8, 1.2)
	return _los_cache

## Current aim error (std-dev, degrees). Gets worse right after the bot is hit.
func _current_spread_degrees() -> float:
	var flinch = clampf(1.0 - _since_damage / maxf(flinch_duration, 0.01), 0.0, 1.0)
	return aim_spread_degrees * GameSettings.bot_spread_mult(faction) * (1.0 + (flinch_spread_multiplier - 1.0) * flinch)

## Deflects a direction by a random gaussian error on two axes.
## The miss DISTANCE grows with range automatically, since the error is angular.
func _apply_spread(dir: Vector3, sigma_deg: float) -> Vector3:
	if sigma_deg <= 0.0:
		return dir
	var right = dir.cross(Vector3.UP)
	if right.length_squared() < 0.001:
		right = Vector3.RIGHT
	right = right.normalized()
	var up = right.cross(dir).normalized()
	return dir.rotated(up, deg_to_rad(randfn(0.0, sigma_deg))) \
		.rotated(right, deg_to_rad(randfn(0.0, sigma_deg))).normalized()

func _attack(target: Node3D):
	_attack_timer = attack_cooldown
	var to_target = target.global_position - global_position
	to_target.y = 0.0
	rotation.y = atan2(-to_target.x, -to_target.z)

	# Aim at the target, then add aim error
	var origin = global_position + Vector3(0, 0.5, 0)
	var aim_point = target.global_position + Vector3(0, 0.5, 0)
	var dir = _apply_spread((aim_point - origin).normalized(), _current_spread_degrees())

	var shot_length = attack_range + 5.0
	var end_point = origin + dir * shot_length

	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(origin, end_point)
	query.exclude = _ray_exclude()
	var result = space_state.intersect_ray(query)

	var did_hit := false
	if result:
		end_point = result.position
		# Whatever the shot actually hits takes the damage. Enemies only (no friendly fire),
		# so a wide shot can clip a different enemy, and walls block it.
		var hit = result.collider
		if hit.has_method("take_damage") and "faction" in hit and hit.faction != faction and _is_valid_target(hit):
			var my_name = character_class.class_name_str if character_class else "Bot"
			var damage = attack_damage * _damage_multiplier * GameSettings.bot_damage_mult(faction)
			if hit == _locked_target:
				damage *= 1.3 # Target Lock bonus, same as the player's version
			hit.take_damage(damage, faction, my_name, global_position, self)
			did_hit = true

	GameManager.report_shot(stats_id, did_hit)

	# Tracer on every shot, so you can SEE bots miss
	CombatFx.tracer(self, origin, end_point, Color.RED, 0.05, 0.05)

	if AudioManager:
		AudioManager.play_shoot(global_position)

# ─── AI Abilities ───────────────────────────────────────────

func _get_slot_type(slot: int) -> int:
	match slot:
		0: return character_class.ability_1_type
		1: return character_class.ability_2_type
	return character_class.ability_3_type

func _get_slot_cooldown(slot: int) -> float:
	match slot:
		0: return character_class.ability_1_cooldown
		1: return character_class.ability_2_cooldown
	return character_class.ability_3_cooldown

func _evaluate_abilities(target: Node3D):
	if not character_class:
		return

	var has_target = _is_valid_target(target)
	var dist = INF
	var los = false
	if has_target:
		dist = global_position.distance_to(target.global_position)
		los = _can_see(target)
	var health_pct = health_component.current_health / health_component.max_health

	for slot in range(3):
		if ability_cooldowns[slot] > 0.0:
			continue
		var type = _get_slot_type(slot)
		if _should_use(type, health_pct, dist, los, has_target):
			_use_ability(slot, type, target)
			return # At most one ability per evaluation, so they don't all dump at once

## The decision table. Conditions are by ability TYPE, not by slot.
func _should_use(type: int, health_pct: float, dist: float, los: bool, has_target: bool) -> bool:
	var under_fire = _since_damage < 2.0
	match type:
		CharacterClass.AbilityType.PHASE_DASH:
			# Retreat when hurt and an enemy is close
			return has_target and health_pct < 0.4 and dist < 8.0
		CharacterClass.AbilityType.OVERCHARGE:
			return has_target and los and health_pct > 0.7 and dist < attack_range
		CharacterClass.AbilityType.ADRENALINE_SPIKE:
			# Costs HP and refreshes slots 1 and 2, so use it when those are down and we're healthy
			var refreshable = ability_cooldowns[0] > 2.0 or ability_cooldowns[1] > 2.0
			return has_target and los and health_pct > 0.5 and refreshable
		CharacterClass.AbilityType.DEPLOY_COVER:
			return has_target and los and under_fire and health_pct < 0.8
		CharacterClass.AbilityType.BULWARK:
			return under_fire and health_pct < 0.6
		CharacterClass.AbilityType.SHOCKWAVE:
			return has_target and dist < 5.0
		CharacterClass.AbilityType.GRAPPLE_HOOK:
			# Close the gap on a distant but visible enemy
			return has_target and los and dist > 15.0
		CharacterClass.AbilityType.TARGET_LOCK:
			return has_target and los and dist < attack_range and not is_instance_valid(_locked_target)
		CharacterClass.AbilityType.LIFE_SIPHON:
			return has_target and los and dist < 10.0 and health_pct < 0.5
	return false

func _use_ability(slot: int, type: int, target: Node3D):
	ability_cooldowns[slot] = _get_slot_cooldown(slot)
	AudioManager.play_ability(type, global_position) # Heard from where the bot is
	match type:
		CharacterClass.AbilityType.PHASE_DASH: _bot_dash(target)
		CharacterClass.AbilityType.OVERCHARGE: _bot_overcharge()
		CharacterClass.AbilityType.ADRENALINE_SPIKE: _bot_adrenaline()
		CharacterClass.AbilityType.DEPLOY_COVER: _bot_deploy_cover(target)
		CharacterClass.AbilityType.BULWARK: _bot_bulwark()
		CharacterClass.AbilityType.SHOCKWAVE: _bot_shockwave()
		CharacterClass.AbilityType.GRAPPLE_HOOK: _bot_grapple(target)
		CharacterClass.AbilityType.TARGET_LOCK: _bot_target_lock(target)
		CharacterClass.AbilityType.LIFE_SIPHON: _bot_life_siphon(target)

## Runs every physics frame: cooldowns, effect timers, and derived multipliers.
func _tick_effects(delta: float):
	_since_damage += delta

	for i in range(3):
		if ability_cooldowns[i] > 0.0:
			ability_cooldowns[i] = maxf(0.0, ability_cooldowns[i] - delta)

	_dash_left = maxf(0.0, _dash_left - delta)
	_overcharge_left = maxf(0.0, _overcharge_left - delta)
	_bulwark_left = maxf(0.0, _bulwark_left - delta)
	_adrenaline_left = maxf(0.0, _adrenaline_left - delta)
	_burst_left = maxf(0.0, _burst_left - delta)

	_is_invulnerable = _dash_left > 0.0
	_damage_multiplier = 1.5 if _overcharge_left > 0.0 else 1.0
	_damage_reduction_multiplier = 0.5 if _bulwark_left > 0.0 else 1.0
	_speed_multiplier = 1.5 if _adrenaline_left > 0.0 else 1.0

	if _flash_left > 0.0:
		_flash_left -= delta
		if _flash_left <= 0.0 and mesh_instance:
			mesh_instance.material_override = original_material

	_tick_target_lock(delta)
	_tick_siphon(delta)

func _start_burst(vel: Vector3, duration: float):
	_burst_velocity = Vector3(vel.x, 0.0, vel.z)
	_burst_left = duration

# --- Breacher ---

func _bot_dash(target: Node3D):
	# Phase dash: a brief invulnerable retreat away from the enemy
	var away = global_position - target.global_position
	away.y = 0.0
	if away.length_squared() < 0.01:
		away = -global_transform.basis.z
	_start_burst(away.normalized() * move_speed * 6.0, 0.25)
	_dash_left = 0.25
	_flash_color(Color.CYAN, 0.25)

func _bot_overcharge():
	_overcharge_left = 4.0
	_flash_color(Color.ORANGE, 0.4) # Short flash so team color stays readable

func _bot_adrenaline():
	# Mirrors the player's version: costs 20 HP (never lethal), refreshes slots 1 and 2, brief speed boost
	health_component.current_health = maxf(1.0, health_component.current_health - 20.0)
	update_health_bar()
	ability_cooldowns[0] = 0.0
	ability_cooldowns[1] = 0.0
	_adrenaline_left = 2.0
	_flash_color(Color.YELLOW, 0.15)

# --- Warden ---

func _bot_deploy_cover(target: Node3D):
	# Wall placed 2 m toward the enemy, facing them
	var dir = target.global_position - global_position
	dir.y = 0.0
	if dir.length_squared() < 0.01:
		dir = -global_transform.basis.z
	dir = dir.normalized()

	var wall_size = Vector3(3.0, 2.0, 0.2)
	var wall = StaticBody3D.new()

	var col = CollisionShape3D.new()
	var box_shape = BoxShape3D.new()
	box_shape.size = wall_size
	col.shape = box_shape

	var mesh_inst = MeshInstance3D.new()
	var box_mesh = BoxMesh.new()
	box_mesh.size = wall_size
	mesh_inst.mesh = box_mesh
	var mat = StandardMaterial3D.new()
	var team_color = GameManager.get_team_color(faction)
	mat.albedo_color = Color(team_color.r, team_color.g, team_color.b, 0.5)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh_inst.material_override = mat

	wall.add_child(col)
	wall.add_child(mesh_inst)

	# Add to the tree FIRST, then position
	get_tree().root.add_child(wall)
	var floor_y = global_position.y - 0.75 # Capsule is 1.5 m tall
	wall.global_position = Vector3(global_position.x, floor_y + wall_size.y / 2.0, global_position.z) + dir * 2.0
	wall.rotation.y = atan2(dir.x, dir.z)

	# Allies shoot through it (same rule the player's own walls follow)
	wall.add_to_group(_cover_group)
	for p in get_tree().get_nodes_in_group("players"):
		if "faction" in p and p.faction == faction and "aim_ray" in p and p.aim_ray:
			p.aim_ray.add_exception(wall)

	# The wall owns its own expiry, so it still cleans up if this bot dies first
	var tween = wall.create_tween()
	tween.tween_interval(6.0)
	tween.tween_callback(wall.queue_free)

	_flash_color(Color.DODGER_BLUE, 0.2)

func _bot_bulwark():
	_bulwark_left = 4.0
	_flash_color(Color.DODGER_BLUE, 0.4)

func _bot_shockwave():
	# Knocks back every enemy within 5 m, same as the player's version
	var enemy_group = GameManager.TEAM_GROUPS[GameManager.get_opposing_team(faction)]
	for t in get_tree().get_nodes_in_group(enemy_group):
		if not _is_valid_target(t):
			continue
		if global_position.distance_to(t.global_position) < 5.0 and t.has_method("apply_knockback"):
			var push_dir = (t.global_position - global_position).normalized()
			t.apply_knockback(push_dir * 15.0 + Vector3.UP * 5.0)

	_flash_color(Color.RED, 0.2)

# --- Ghost ---

func _bot_grapple(target: Node3D):
	# Lunge toward the enemy
	var toward = target.global_position - global_position
	toward.y = 0.0
	if toward.length_squared() < 0.01:
		return
	_start_burst(toward.normalized() * move_speed * 5.0, 0.35)
	_flash_color(Color.CYAN, 0.35)

func _bot_target_lock(target: Node3D):
	_end_target_lock()
	_locked_target = target
	_lock_time_left = 5.0
	# Bots take +10% from this; the player has no set_vulnerable yet, so for the
	# player the lock only gives the bot's +30% damage bonus (see _attack).
	if target.has_method("set_vulnerable"):
		target.set_vulnerable(true)
	_flash_color(Color.RED, 0.2)

func _tick_target_lock(delta: float):
	if _locked_target == null:
		return
	_lock_time_left -= delta
	if _lock_time_left <= 0.0 or not _is_valid_target(_locked_target):
		_end_target_lock()

func _end_target_lock():
	if is_instance_valid(_locked_target) and _locked_target.has_method("set_vulnerable"):
		_locked_target.set_vulnerable(false)
	_locked_target = null

func _bot_life_siphon(target: Node3D):
	_siphon_target = target
	_siphon_time_left = 3.0
	_siphon_tick_timer = 0.5
	_flash_color(Color.MEDIUM_PURPLE, 0.4)

func _tick_siphon(delta: float):
	if _siphon_time_left <= 0.0:
		return
	_siphon_time_left -= delta

	# Tether breaks on timeout, death, or distance (> 10 m)
	var broken = _siphon_time_left <= 0.0 or not _is_valid_target(_siphon_target) \
		or global_position.distance_to(_siphon_target.global_position) > 10.0
	if broken:
		_siphon_time_left = 0.0
		_siphon_target = null
		return

	_siphon_tick_timer -= delta
	if _siphon_tick_timer <= 0.0:
		_siphon_tick_timer = 0.5
		var my_name = character_class.class_name_str if character_class else "Bot"
		_siphon_target.take_damage(8.0, faction, my_name, global_position, self)
		health_component.heal(8.0)
		update_health_bar()

## Briefly tints the bot. The material is shared, and _tick_effects restores the team color.
func _flash_color(color: Color, duration: float = 0.3):
	if not mesh_instance: return
	mesh_instance.material_override = CombatFx.material(color)
	_flash_left = duration

func spawn_damage_number(amount: float):
	CombatFx.damage_number(self, global_position + Vector3(0, 1.5, 0), amount)
