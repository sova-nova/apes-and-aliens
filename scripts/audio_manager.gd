extends Node

const MAX_3D_VOICES := 24      # Skip new 3D sounds past this many playing at once
const MAX_3D_DISTANCE := 80.0  # Beyond this, sounds are inaudible

# Core sounds (the game expects these to exist)
var shoot_sfx = preload("res://assets/audio/shoot.ogg")
var hit_sfx = preload("res://assets/audio/hit.ogg")
var capture_sfx = preload("res://assets/audio/capture.ogg")
var bulwark_sfx = preload("res://assets/audio/bulwark.ogg")

# Everything below is optional: if a file is missing, that sound is silent and nothing breaks.
# (tools/make_sfx.py generates placeholder versions of all of these.)
var gate_sfx: AudioStream = _load_optional("res://assets/audio/gate_open.ogg")
var ready_sfx: AudioStream = _load_optional("res://assets/audio/ability_ready.ogg")
var respawn_sfx: AudioStream = _load_optional("res://assets/audio/respawn.ogg")
var tick_sfx: AudioStream = _load_optional("res://assets/audio/countdown_tick.ogg")
var go_sfx: AudioStream = _load_optional("res://assets/audio/countdown_go.ogg")
var kill_sfx: AudioStream = _load_optional("res://assets/audio/kill_confirm.ogg")
var win_sfx: AudioStream = _load_optional("res://assets/audio/round_win.ogg")
var lose_sfx: AudioStream = _load_optional("res://assets/audio/round_lose.ogg")

# Ability sound for each AbilityType. Players and bots both use play_ability().
var _ability_sfx: Dictionary = {}

var _active_3d_voices: int = 0
var _last_ready_ms: int = -1000

func _ready() -> void:
	_ability_sfx = {
		CharacterClass.AbilityType.PHASE_DASH: _load_optional("res://assets/audio/dash.ogg"),
		CharacterClass.AbilityType.OVERCHARGE: _load_optional("res://assets/audio/overcharge.ogg"),
		CharacterClass.AbilityType.ADRENALINE_SPIKE: _load_optional("res://assets/audio/adrenaline.ogg"),
		CharacterClass.AbilityType.DEPLOY_COVER: _load_optional("res://assets/audio/cover.ogg"),
		CharacterClass.AbilityType.BULWARK: bulwark_sfx,
		CharacterClass.AbilityType.SHOCKWAVE: _load_optional("res://assets/audio/shockwave.ogg"),
		CharacterClass.AbilityType.GRAPPLE_HOOK: _load_optional("res://assets/audio/grapple.ogg"),
		CharacterClass.AbilityType.TARGET_LOCK: _load_optional("res://assets/audio/target_lock.ogg"),
		CharacterClass.AbilityType.LIFE_SIPHON: _load_optional("res://assets/audio/siphon.ogg"),
	}

# --- POSITIONAL 3D SOUNDS ---

func play_shoot(pos: Vector3):
	_play_3d(shoot_sfx, pos)

func play_hit(pos: Vector3):
	_play_3d(hit_sfx, pos)

func play_bulwark(pos: Vector3):
	play_ability(CharacterClass.AbilityType.BULWARK, pos)

func play_gate(pos: Vector3):
	_play_3d(gate_sfx, pos)

## The sound for an ability, heard from where it was used (so you can hear enemies use theirs).
func play_ability(type: int, pos: Vector3):
	_play_3d(_ability_sfx.get(type), pos, -2.0)

# --- GLOBAL 2D SOUNDS ---

func play_capture():
	_play_global(capture_sfx)

## A soft pip when an ability finishes recharging.
func play_ability_ready():
	# Adrenaline can ready two abilities in the same frame: don't double the pip
	var now := Time.get_ticks_msec()
	if now - _last_ready_ms < 150:
		return
	_last_ready_ms = now
	_play_global(ready_sfx, -8.0)

func play_respawn():
	_play_global(respawn_sfx, -4.0)

func play_countdown_tick():
	_play_global(tick_sfx, -6.0)

func play_countdown_go():
	_play_global(go_sfx, -4.0)

## The satisfying ding when your shot kills something.
func play_kill_confirm():
	_play_global(kill_sfx, -4.0)

func play_round_result(victory: bool):
	_play_global(win_sfx if victory else lose_sfx, -3.0)

# --- INTERNAL ENGINE ---

func _load_optional(path: String) -> AudioStream:
	if ResourceLoader.exists(path):
		return load(path)
	return null

func _play_3d(stream: AudioStream, pos: Vector3, volume_db: float = 0.0):
	if stream == null:
		return
	if _active_3d_voices >= MAX_3D_VOICES:
		return

	var player = AudioStreamPlayer3D.new()
	player.stream = stream
	player.max_distance = MAX_3D_DISTANCE
	player.volume_db = volume_db

	# Add to the tree FIRST: global_position only works on nodes inside the tree
	get_tree().root.add_child(player)
	player.global_position = pos

	_active_3d_voices += 1
	player.finished.connect(_on_3d_finished.bind(player))
	player.play()

func _on_3d_finished(player: AudioStreamPlayer3D):
	_active_3d_voices -= 1
	player.queue_free()

func _play_global(stream: AudioStream, volume_db: float = 0.0):
	if stream == null:
		return

	var player = AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = volume_db
	add_child(player)
	player.play()

	player.finished.connect(player.queue_free)
