class_name GameSettings
extends RefCounted
## Player-adjustable settings, saved to user://settings.cfg.
## Static, so no autoload is needed: any script can read GameSettings.<value>.

const SAVE_PATH := "user://settings.cfg"

enum Difficulty { EASY, NORMAL, HARD }

## Difficulty only changes the player's OPPONENTS. Allied bots always play at Normal.
## spread / reaction / damage multiply the bots' own values (spread: higher = worse aim).
## "bots" is added to the enemy team's bot count.
const DIFFICULTY_DATA := {
	Difficulty.EASY: {
		"name": "Easy", "spread": 1.4, "reaction": 1.4, "damage": 0.8, "bots": -1,
		"blurb": "Enemy bots aim worse, react slower and hit softer, and there's one fewer of them.",
	},
	Difficulty.NORMAL: {
		"name": "Normal", "spread": 1.0, "reaction": 1.0, "damage": 1.0, "bots": 0,
		"blurb": "The intended experience.",
	},
	Difficulty.HARD: {
		"name": "Hard", "spread": 0.75, "reaction": 0.75, "damage": 1.1, "bots": 1,
		"blurb": "Enemy bots aim tighter, react faster and hit harder, and there's one more of them.",
	},
}

# Multiplies the player's base mouse sensitivity (1.0 = unchanged)
static var mouse_sensitivity_scale: float = 1.0
# Master volume, 0.0 (muted) to 1.0
static var master_volume: float = 1.0
static var difficulty: int = Difficulty.NORMAL

static var _loaded: bool = false

# ─── Loading and saving ─────────────────────────────────────

## Loads the saved settings the first time anything needs them (and applies the volume).
static func ensure_loaded() -> void:
	if not _loaded:
		load_settings()

static func load_settings() -> void:
	_loaded = true
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		mouse_sensitivity_scale = clampf(float(cfg.get_value("controls", "sensitivity", 1.0)), 0.2, 3.0)
		master_volume = clampf(float(cfg.get_value("audio", "master_volume", 1.0)), 0.0, 1.0)
		difficulty = clampi(int(cfg.get_value("game", "difficulty", Difficulty.NORMAL)), Difficulty.EASY, Difficulty.HARD)
	apply_audio()

static func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("controls", "sensitivity", mouse_sensitivity_scale)
	cfg.set_value("audio", "master_volume", master_volume)
	cfg.set_value("game", "difficulty", difficulty)
	cfg.save(SAVE_PATH)

static func apply_audio() -> void:
	var bus := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_mute(bus, master_volume <= 0.001)
	AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(master_volume, 0.001)))

# ─── Difficulty ─────────────────────────────────────────────

static func _opponent_mult(bot_faction: int, key: String) -> float:
	ensure_loaded()
	if bot_faction == PlayerSetup.selected_faction:
		return 1.0 # Allies are never affected
	return float(DIFFICULTY_DATA[difficulty][key])

static func bot_spread_mult(bot_faction: int) -> float:
	return _opponent_mult(bot_faction, "spread")

static func bot_reaction_mult(bot_faction: int) -> float:
	return _opponent_mult(bot_faction, "reaction")

static func bot_damage_mult(bot_faction: int) -> float:
	return _opponent_mult(bot_faction, "damage")

## How many more (or fewer) bots each ENEMY team gets than max_bots_per_team.
static func enemy_bot_adjust() -> int:
	ensure_loaded()
	return int(DIFFICULTY_DATA[difficulty]["bots"])
