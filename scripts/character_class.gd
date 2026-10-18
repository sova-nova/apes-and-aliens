extends Resource
class_name CharacterClass

enum AbilityType {
	NONE,
	PHASE_DASH,
	OVERCHARGE,
	ADRENALINE_SPIKE,
	DEPLOY_COVER,
	BULWARK,
	SHOCKWAVE,
	GRAPPLE_HOOK,
	TARGET_LOCK,
	LIFE_SIPHON
}

@export var class_name_str: String = "Grunt"
@export var max_health: float = 100.0
@export var move_speed: float = 5.0

# The weapon this class fires (see WeaponData). If it's left empty, a plain one is built from the
# older gun fields below, so a class still works without one.
@export var weapon: WeaponData

# Older gun fields: used ONLY when no Weapon is set above.
@export var gun_damage: float = 25.0
@export var fire_rate: float = 0.12
@export var gun_range: float = 100.0
@export var mag_size: int = 30
@export var reload_time: float = 1.5

# Ability 1 (Q)
@export var ability_1_type: AbilityType = AbilityType.NONE
@export var ability_1_cooldown: float = 8.0

# Ability 2 (E)
@export var ability_2_type: AbilityType = AbilityType.NONE
@export var ability_2_cooldown: float = 10.0

# Ability 3 (Shift)
@export var ability_3_type: AbilityType = AbilityType.NONE
@export var ability_3_cooldown: float = 15.0

# Bot AI tuning (the player ignores these)
@export_group("Bot Aim")
## Standard deviation of the bot's aim error, in degrees. Lower = more accurate.
@export var bot_spread_degrees: float = 2.0
## A bot that newly spots an enemy waits a random time in this range before its first shot.
@export var bot_reaction_min: float = 0.3
@export var bot_reaction_max: float = 0.5

## The weapon this class fires: its own, or a plain one built from the older gun fields.
func get_weapon() -> WeaponData:
	if weapon:
		return weapon
	return WeaponData.from_class(self)

# ─── Display info ───────────────────────────────────────────
## Names and one-line descriptions for every ability, shared by class select and the HUD.
## The numbers in the text mirror the values in player.gd and bot.gd:
## if you retune an ability, update its line here too.
const ABILITY_INFO := {
	AbilityType.NONE: {"name": "None", "desc": ""},
	AbilityType.PHASE_DASH: {
		"name": "Phase Dash",
		"desc": "Burst forward in the direction you move. Untouchable while dashing.",
	},
	AbilityType.OVERCHARGE: {
		"name": "Overcharge",
		"desc": "4s of +50% damage and double fire rate, but you move at half speed.",
	},
	AbilityType.ADRENALINE_SPIKE: {
		"name": "Adrenaline Spike",
		"desc": "Costs 20 HP. Refreshes your first two abilities and speeds you up for 2s.",
	},
	AbilityType.DEPLOY_COVER: {
		"name": "Deploy Cover",
		"desc": "Raise a wall where you aim for 6s. It blocks enemies; your team fires through it.",
	},
	AbilityType.BULWARK: {
		"name": "Bulwark",
		"desc": "4s of 50% damage reduction.",
	},
	AbilityType.SHOCKWAVE: {
		"name": "Shockwave",
		"desc": "Blast enemies within 5m away from you and into the air.",
	},
	AbilityType.GRAPPLE_HOOK: {
		"name": "Grapple Hook",
		"desc": "Yank yourself toward the spot you're aiming at.",
	},
	AbilityType.TARGET_LOCK: {
		"name": "Target Lock",
		"desc": "Mark an enemy for 5s: you deal +30% to them, and they take +10% from everyone.",
	},
	AbilityType.LIFE_SIPHON: {
		"name": "Life Siphon",
		"desc": "Tether an enemy within 10m for 3s, draining their health into yours.",
	},
}

static func ability_name(type: int) -> String:
	return ABILITY_INFO.get(type, ABILITY_INFO[AbilityType.NONE])["name"]

static func ability_desc(type: int) -> String:
	return ABILITY_INFO.get(type, ABILITY_INFO[AbilityType.NONE])["desc"]
