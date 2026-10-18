class_name WeaponController
extends RefCounted
## One shooter's weapon in action: ammo, reloading, spread bloom, the fire cooldown, and the act of
## firing. The player and every bot each have one, so they all follow the same rules.
##
## It decides what a shot DOES: where it goes, who it hits, how much damage that is. Showing the shot
## (tracers, sounds, hit markers) is the caller's job. That split matters for online play, where the
## server decides what happened and each player's game shows it.

var data: WeaponData
var ammo: int = 0
var reloading: bool = false

## Abilities adjust these (Overcharge: more damage, a shorter delay between shots).
var damage_multiplier: float = 1.0
var fire_interval_multiplier: float = 1.0
## Never runs dry. (A switch for bots, for tuning.)
var unlimited_ammo: bool = false
## What the kill feed and stats call the shooter's weapon owner.
var attacker_name: String = ""

var _cooldown: float = 0.0
var _reload_left: float = 0.0
var _bloom: float = 0.0
var _since_last_shot: float = 999.0
var _shot_index: int = 0
var _seed_base: int = 0
var _rng := RandomNumberGenerator.new()

## Gives the shooter a weapon and a full magazine. `seed_base` identifies the shooter, so that every
## shot's spread comes from (shooter, shot number): the same on a server and on a player's own game.
func setup(weapon: WeaponData, seed_base: int) -> void:
	data = weapon
	_seed_base = seed_base
	_shot_index = 0
	refill()

func refill() -> void:
	ammo = data.magazine_size
	reloading = false
	_reload_left = 0.0
	_cooldown = 0.0
	_bloom = 0.0
	_since_last_shot = 999.0

## Call once per physics frame.
func tick(delta: float) -> void:
	if data == null:
		return
	_cooldown = maxf(0.0, _cooldown - delta)
	_since_last_shot += delta
	_bloom = maxf(0.0, _bloom - data.spread_recovery * delta)

	if reloading:
		_reload_left -= delta
		# A loop, so one long frame can't swallow two rounds of an incremental reload
		while reloading and _reload_left <= 0.0:
			if data.reload_style == WeaponData.ReloadStyle.MAGAZINE:
				ammo = data.magazine_size
				reloading = false
			else:
				ammo += 1
				if ammo >= data.magazine_size:
					ammo = data.magazine_size
					reloading = false
				else:
					_reload_left += maxf(data.reload_time, 0.05)
	elif ammo <= 0 and not unlimited_ammo:
		start_reload() # Empty: reload by itself

func start_reload() -> void:
	if data == null or reloading or ammo >= data.magazine_size:
		return
	reloading = true
	_reload_left = maxf(data.reload_time, 0.05)

func can_fire() -> bool:
	if data == null or _cooldown > 0.0:
		return false
	if not unlimited_ammo and ammo <= 0:
		return false
	# A magazine reload can't be interrupted. A round-by-round one can.
	if reloading and data.reload_style == WeaponData.ReloadStyle.MAGAZINE:
		return false
	return true

## The cone (in degrees) the next shot will be fired inside. The HUD can show this on the crosshair.
func current_spread() -> float:
	if data.first_shot_accurate and _since_last_shot >= data.accuracy_reset_time:
		return 0.0
	return data.spread_base + _bloom

## Fires if it can. `result` is:
##   fired        whether a shot went out
##   shots        (hitscan) one Dictionary per pellet: from, to, hit, normal, enemy_hit, damage, killed
##   projectiles  how many projectiles were launched
##
## origin        where the shot is aimed from (the camera, for the player)
## aim_dir       the direction you're aiming (normalized), before spread
## muzzle_pos    where tracers and projectiles visually start
## excludes      RIDs the shot passes through (the shooter, their team's cover walls)
## target_bonus  optional Callable(target) -> float, a damage multiplier for specific targets
func fire(shooter: Node3D, origin: Vector3, aim_dir: Vector3, muzzle_pos: Vector3,
		excludes: Array[RID], target_bonus: Callable = Callable()) -> Dictionary:
	var result := {"fired": false, "shots": [], "projectiles": 0}
	if not can_fire():
		return result

	# Firing interrupts a round-by-round reload
	reloading = false
	if not unlimited_ammo:
		ammo -= 1
	_cooldown = data.fire_interval * fire_interval_multiplier
	var spread := current_spread()
	result["fired"] = true

	for pellet in range(data.pellets):
		var dir := _spread_direction(aim_dir, spread, pellet)
		if data.behavior == WeaponData.Behavior.PROJECTILE:
			_launch_projectile(shooter, origin, dir, muzzle_pos, excludes)
			result["projectiles"] += 1
		else:
			result["shots"].append(_hitscan(shooter, origin, dir, muzzle_pos, excludes, target_bonus))

	_bloom = minf(_bloom + data.spread_bloom_per_shot, data.spread_bloom_max)
	_since_last_shot = 0.0
	_shot_index += 1
	return result

# ─── Internals ──────────────────────────────────────────────

## A random direction inside a cone around `dir`. Seeded by (shooter, shot number, pellet), so the
## server and the shooter's own game agree on exactly where every shot went.
func _spread_direction(dir: Vector3, spread_degrees: float, pellet: int) -> Vector3:
	if spread_degrees <= 0.0:
		return dir
	_rng.seed = _seed_base * 100003 + _shot_index * 131 + pellet
	var radius := deg_to_rad(spread_degrees) * sqrt(_rng.randf()) # sqrt: even coverage across the cone
	var angle := _rng.randf() * TAU
	var right := dir.cross(Vector3.UP)
	right = right.normalized() if right.length_squared() > 0.0001 else Vector3.RIGHT
	var up := right.cross(dir).normalized()
	return (dir + (right * cos(angle) + up * sin(angle)) * tan(radius)).normalized()

func _is_enemy(shooter: Node3D, target) -> bool:
	return is_instance_valid(target) and target.has_method("take_damage") \
		and "faction" in target and target.faction != shooter.faction

func _hitscan(shooter: Node3D, origin: Vector3, dir: Vector3, muzzle_pos: Vector3,
		excludes: Array[RID], target_bonus: Callable) -> Dictionary:
	var end := origin + dir * data.max_range
	var query := PhysicsRayQueryParameters3D.create(origin, end)
	query.exclude = excludes
	var hit := shooter.get_world_3d().direct_space_state.intersect_ray(query)

	var shot := {
		"from": muzzle_pos, "to": end, "hit": null, "normal": Vector3.UP,
		"enemy_hit": false, "damage": 0.0, "killed": false,
	}
	if hit.is_empty():
		return shot

	shot["to"] = hit.position
	shot["normal"] = hit.normal
	var target = hit.collider
	shot["hit"] = target

	# Enemies only (no friendly fire). Walls and cover just stop the shot.
	if _is_enemy(shooter, target):
		var distance := shooter.global_position.distance_to(hit.position)
		var dealt := data.damage * data.damage_multiplier_at(distance) * damage_multiplier
		if target_bonus.is_valid():
			dealt *= float(target_bonus.call(target))
		target.take_damage(dealt, shooter.faction, attacker_name, shooter.global_position, shooter)
		shot["enemy_hit"] = true
		shot["damage"] = dealt
		shot["killed"] = "health_component" in target and target.health_component.is_dead()
	return shot

func _launch_projectile(shooter: Node3D, origin: Vector3, dir: Vector3, muzzle_pos: Vector3, excludes: Array[RID]) -> void:
	# The aim ray starts at the camera but the projectile starts at the gun. Find what the crosshair is
	# pointing at, and fly from the gun toward THAT, so the projectile still lands where you aimed.
	var reach := data.projectile_speed * data.projectile_lifetime
	var query := PhysicsRayQueryParameters3D.create(origin, origin + dir * reach)
	query.exclude = excludes
	var hit := shooter.get_world_3d().direct_space_state.intersect_ray(query)
	var aim_point: Vector3 = hit.position if not hit.is_empty() else origin + dir * reach

	var launch_dir := aim_point - muzzle_pos
	launch_dir = launch_dir.normalized() if launch_dir.length_squared() > 0.25 else dir
	Projectile.launch(shooter, data, muzzle_pos, launch_dir, data.damage * damage_multiplier, excludes, attacker_name)
