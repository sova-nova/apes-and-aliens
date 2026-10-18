class_name WeaponData
extends Resource
## A weapon, described as data. A class has one (CharacterClass.weapon), and players and bots fire
## it through the same code (WeaponController). See docs/WEAPONS.md for the design.

enum Behavior {
	HITSCAN,    ## The shot lands instantly.
	PROJECTILE, ## A shot that travels, and can be dodged.
}

enum ReloadStyle {
	MAGAZINE,    ## One reload refills the whole magazine, and can't be interrupted.
	INCREMENTAL, ## One round at a time (shotgun style). Firing interrupts it.
}

@export var weapon_name: String = "Rifle"
@export var behavior: Behavior = Behavior.HITSCAN

@export_group("Firing")
## Damage per pellet (or per projectile) at point-blank range.
@export var damage: float = 25.0
## Seconds between shots.
@export var fire_interval: float = 0.12
## Pellets per shot. More than 1 makes a shotgun.
@export_range(1, 30) var pellets: int = 1
## How far a hitscan shot reaches.
@export var max_range: float = 100.0

@export_group("Ammo")
@export var magazine_size: int = 30
@export var reload_style: ReloadStyle = ReloadStyle.MAGAZINE
## MAGAZINE: seconds for the whole reload. INCREMENTAL: seconds per round.
@export var reload_time: float = 1.5

@export_group("Spread")
## Cone half-angle, in degrees, with no bloom. Moving does NOT widen it (a design decision).
@export var spread_base: float = 0.0
## How much the cone widens with each shot...
@export var spread_bloom_per_shot: float = 0.0
## ...up to this much extra.
@export var spread_bloom_max: float = 0.0
## Degrees per second that the bloom shrinks while you aren't firing.
@export var spread_recovery: float = 3.0
## After a pause, the next shot has no spread at all (rewards controlled bursts).
@export var first_shot_accurate: bool = false
## How long a pause counts as "a pause" for the above.
@export var accuracy_reset_time: float = 0.3

@export_group("Falloff")
## Full damage out to this distance (meters)...
@export var falloff_start: float = 20.0
## ...fading to the minimum at this distance, and staying there beyond it.
@export var falloff_end: float = 50.0
## The damage multiplier at and beyond falloff_end. 1.0 means no falloff at all.
@export_range(0.0, 1.0) var falloff_min: float = 1.0
## 1.0 fades evenly. Above 1.0 holds full damage longer, then drops faster.
@export var falloff_shape: float = 1.0

@export_group("Bots")
## How far away a bot starts shooting with this weapon (meters).
@export var engage_range: float = 15.0

@export_group("Projectile")
## Meters per second.
@export var projectile_speed: float = 30.0
## Downward pull, in meters per second squared. 0 flies straight.
@export var projectile_gravity: float = 0.0
## Seconds before it gives up (or explodes, if it has splash).
@export var projectile_lifetime: float = 3.0
## Visual diameter in meters.
@export var projectile_size: float = 0.25
## 0 = no explosion, the projectile just hits what it touches.
@export var splash_radius: float = 0.0
## Damage fraction at the very edge of the explosion (full damage at the center).
@export_range(0.0, 1.0) var splash_min_multiplier: float = 0.3
## Push at the center of the explosion (0 = none).
@export var knockback_force: float = 0.0
## How much of the damage the shooter takes from their own explosion (0 = none).
@export_range(0.0, 2.0) var self_damage_multiplier: float = 0.0
## How much of the push the shooter gets from their own explosion.
@export_range(0.0, 2.0) var self_knockback_multiplier: float = 1.0

@export_group("Look")
@export var tracer_color: Color = Color(1.0, 0.85, 0.3)

# ─── Calculations ───────────────────────────────────────────

## Damage multiplier at a distance: 1.0 up to falloff_start, then fading to falloff_min.
func damage_multiplier_at(distance: float) -> float:
	if falloff_min >= 0.999 or distance <= falloff_start:
		return 1.0
	var span := maxf(falloff_end - falloff_start, 0.001)
	var t := clampf((distance - falloff_start) / span, 0.0, 1.0)
	return lerpf(1.0, falloff_min, pow(t, falloff_shape))

## Damage per second if every pellet hit at point-blank range.
func dps() -> float:
	return damage * pellets / maxf(fire_interval, 0.001)

# ─── Text for menus ─────────────────────────────────────────

func damage_text() -> String:
	var per_shot := "%d" % int(damage)
	if pellets > 1:
		per_shot = "%d×%d" % [int(damage), pellets]
	return "%s dmg × %.1f/s  (%d DPS)" % [per_shot, 1.0 / maxf(fire_interval, 0.001), int(dps())]

func reload_text() -> String:
	if reload_style == ReloadStyle.INCREMENTAL:
		return "%.1fs per round" % reload_time
	return "%.1fs" % reload_time

# ─── Older classes ──────────────────────────────────────────

## Builds a plain hitscan weapon from a class's older gun fields, so a class with no Weapon assigned
## still works. (Its numbers match what the game did before weapons were data.)
static func from_class(c: CharacterClass) -> WeaponData:
	var w := WeaponData.new()
	w.weapon_name = "%s Gun" % c.class_name_str
	w.damage = c.gun_damage
	w.fire_interval = c.fire_rate
	w.max_range = c.gun_range
	w.magazine_size = c.mag_size
	w.reload_time = c.reload_time
	return w
