class_name Projectile
extends Node3D
## A shot that travels (rocket, grenade, ...) and can be dodged.
##
## It moves in simple steps and, each frame, checks a line from its old position to its new one, so a
## fast projectile can't skip through a wall or a player. That is much cheaper than physics bodies,
## which matters for the low-end hardware target. Projectiles are recycled through a pool, so firing
## doesn't create and destroy nodes constantly.

static var _pool: Array = []

var _data: WeaponData
var _velocity := Vector3.ZERO
var _age := 0.0
var _damage := 0.0
var _faction := 0
var _shooter_ref: WeakRef = null
var _attacker_name := ""
var _origin := Vector3.ZERO # Where it was fired from (damage falls off with distance travelled)
var _excludes: Array[RID] = []
var _active := false
var _mesh: MeshInstance3D = null

## Fire one. Reuses a recycled projectile if there is one.
static func launch(shooter: Node3D, data: WeaponData, from: Vector3, direction: Vector3,
		damage: float, excludes: Array[RID], attacker_name: String) -> void:
	var p: Projectile = null
	while p == null and not _pool.is_empty():
		var candidate = _pool.pop_back()
		if is_instance_valid(candidate):
			p = candidate
	if p == null:
		p = Projectile.new()
		p._mesh = MeshInstance3D.new()
		p._mesh.mesh = CombatFx.sphere_mesh(0.5) # Unit diameter; scaled to size below
		p.add_child(p._mesh)
	if p.get_parent() == null:
		shooter.get_tree().root.add_child(p)
	p._start(shooter, data, from, direction, damage, excludes, attacker_name)

func _start(shooter: Node3D, data: WeaponData, from: Vector3, direction: Vector3,
		damage: float, excludes: Array[RID], attacker_name: String) -> void:
	_data = data
	_damage = damage
	_faction = shooter.faction
	_shooter_ref = weakref(shooter)
	_attacker_name = attacker_name
	_origin = from
	_excludes = excludes
	_age = 0.0
	_velocity = direction.normalized() * data.projectile_speed

	_mesh.material_override = CombatFx.material(data.tracer_color)
	_mesh.scale = Vector3.ONE * data.projectile_size
	global_position = from # Already in the tree by now
	visible = true
	_active = true
	set_physics_process(true)

func _physics_process(delta: float) -> void:
	if not _active:
		return

	_age += delta
	if _age >= _data.projectile_lifetime:
		# Out of time. Something with splash goes off, like a grenade fuse; anything else just vanishes.
		if _data.splash_radius > 0.0:
			_explode(global_position, Vector3.UP)
		_deactivate()
		return

	_velocity.y -= _data.projectile_gravity * delta
	var from := global_position
	var to := from + _velocity * delta

	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = _excludes
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		global_position = to
		return

	global_position = hit.position
	if _data.splash_radius > 0.0:
		_explode(hit.position, hit.normal)
	else:
		_direct_hit(hit.collider, hit.position, hit.normal)
	_deactivate()

func _get_shooter() -> Node3D:
	var shooter = _shooter_ref.get_ref() if _shooter_ref != null else null
	return shooter if is_instance_valid(shooter) else null

func _is_enemy(target) -> bool:
	return is_instance_valid(target) and target.has_method("take_damage") \
		and "faction" in target and target.faction != _faction

## A projectile with no splash: it simply hits what it touches.
func _direct_hit(target, position: Vector3, normal: Vector3) -> void:
	CombatFx.spark(self, position, normal)
	if not _is_enemy(target):
		return
	var shooter := _get_shooter()
	var dealt := _damage * _data.damage_multiplier_at(_origin.distance_to(position))
	target.take_damage(dealt, _faction, _attacker_name, _origin, shooter)
	if shooter != null:
		GameManager.report_hit(shooter.stats_id)

## An explosion: damage and a push that fade toward the edge, blocked by cover.
func _explode(center: Vector3, normal: Vector3) -> void:
	CombatFx.explosion(self, center, _data.splash_radius, _data.tracer_color)
	AudioManager.play_ability(CharacterClass.AbilityType.SHOCKWAVE, center)

	var shape := SphereShape3D.new()
	shape.radius = _data.splash_radius
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = shape
	params.transform = Transform3D(Basis.IDENTITY, center)
	var found := get_world_3d().direct_space_state.intersect_shape(params, 32)

	var shooter := _get_shooter()
	var seen := {}
	var landed_on_enemy := false
	for entry in found:
		var target = entry["collider"]
		if seen.has(target):
			continue
		seen[target] = true
		if not is_instance_valid(target) or not target.has_method("take_damage") or not ("faction" in target):
			continue # Walls and the like

		var is_self: bool = shooter != null and target == shooter
		if not is_self and target.faction == _faction:
			continue # Never hurts teammates
		var chest: Vector3 = target.global_position + Vector3(0, 0.6, 0)
		if not _has_clear_line(center + normal * 0.1, chest, target):
			continue # Cover shields from the blast

		var fade := clampf(center.distance_to(chest) / _data.splash_radius, 0.0, 1.0)
		var factor := lerpf(1.0, _data.splash_min_multiplier, fade)
		var dealt := _damage * factor
		var push: Vector3 = target.global_position - center
		push = push.normalized() * _data.knockback_force * factor + Vector3.UP * _data.knockback_force * 0.25 * factor

		if is_self:
			dealt *= _data.self_damage_multiplier
			push *= _data.self_knockback_multiplier
		else:
			landed_on_enemy = true

		if dealt > 0.0:
			target.take_damage(dealt, _faction, _attacker_name, center, shooter)
		if push.length_squared() > 0.01 and target.has_method("apply_knockback"):
			target.apply_knockback(push)

	if landed_on_enemy and shooter != null:
		GameManager.report_hit(shooter.stats_id)

func _has_clear_line(from: Vector3, to: Vector3, target) -> bool:
	var query := PhysicsRayQueryParameters3D.create(from, to)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit.is_empty() or hit.collider == target

func _deactivate() -> void:
	if not _active:
		return
	_active = false
	visible = false
	set_physics_process(false)
	_pool.append(self)
