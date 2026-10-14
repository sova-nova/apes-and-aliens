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

# Weapon Stats
@export var gun_damage: float = 25.0
@export var fire_rate: float = 0.12
@export var gun_range: float = 100.0

# Ability 1 (Q)
@export var ability_1_type: AbilityType = AbilityType.NONE
@export var ability_1_cooldown: float = 8.0

# Ability 2 (E)
@export var ability_2_type: AbilityType = AbilityType.NONE
@export var ability_2_cooldown: float = 10.0

# Ability 3 (Shift)
@export var ability_3_type: AbilityType = AbilityType.NONE
@export var ability_3_cooldown: float = 15.0
