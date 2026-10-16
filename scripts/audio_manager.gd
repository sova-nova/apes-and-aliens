extends Node

const MAX_3D_VOICES := 24      # Skip new 3D sounds past this many playing at once
const MAX_3D_DISTANCE := 80.0  # Beyond this, sounds are inaudible

# Preload the sounds
var shoot_sfx = preload("res://assets/audio/shoot.ogg")
var hit_sfx = preload("res://assets/audio/hit.ogg")
var capture_sfx = preload("res://assets/audio/capture.ogg")

# Ability SFX
var bulwark_sfx = preload("res://assets/audio/bulwark.ogg")

# Optional: add a file at this path to enable the sound. Missing = silent, no error.
var gate_sfx: AudioStream = _load_optional("res://assets/audio/gate_open.ogg")

var _active_3d_voices: int = 0

# --- POSITIONAL 3D SOUNDS ---

func play_shoot(pos: Vector3):
	_play_3d(shoot_sfx, pos)

func play_hit(pos: Vector3):
	_play_3d(hit_sfx, pos)

func play_bulwark(pos: Vector3):
	_play_3d(bulwark_sfx, pos)

func play_gate(pos: Vector3):
	_play_3d(gate_sfx, pos)

# --- GLOBAL 2D SOUNDS ---

func play_capture():
	_play_global(capture_sfx)

# --- INTERNAL ENGINE ---

func _load_optional(path: String) -> AudioStream:
	if ResourceLoader.exists(path):
		return load(path)
	return null

func _play_3d(stream: AudioStream, pos: Vector3):
	if stream == null:
		return
	if _active_3d_voices >= MAX_3D_VOICES:
		return

	var player = AudioStreamPlayer3D.new()
	player.stream = stream
	player.max_distance = MAX_3D_DISTANCE

	# Add to the tree FIRST: global_position only works on nodes inside the tree
	get_tree().root.add_child(player)
	player.global_position = pos

	_active_3d_voices += 1
	player.finished.connect(_on_3d_finished.bind(player))
	player.play()

func _on_3d_finished(player: AudioStreamPlayer3D):
	_active_3d_voices -= 1
	player.queue_free()

func _play_global(stream: AudioStream):
	if stream == null:
		return

	var player = AudioStreamPlayer.new()
	player.stream = stream
	add_child(player)
	player.play()

	player.finished.connect(player.queue_free)
