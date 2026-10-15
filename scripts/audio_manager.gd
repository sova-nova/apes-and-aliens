extends Node

# Preload the sounds
var shoot_sfx = preload("res://assets/audio/shoot.ogg")
var hit_sfx = preload("res://assets/audio/hit.ogg")
var capture_sfx = preload("res://assets/audio/capture.ogg")

# Ability SFX
var bulwark_sfx = preload("res://assets/audio/bulwark.ogg")

# --- POSITIONAL 3D SOUNDS ---
# These take a Vector3 position so they play in the 3D world

func play_shoot(pos: Vector3):
	_play_3d(shoot_sfx, pos)

func play_hit(pos: Vector3):
	_play_3d(hit_sfx, pos)

func play_bulwark(pos: Vector3):
	_play_3d(bulwark_sfx, pos)

# --- GLOBAL 2D SOUNDS ---
# Capture points are global, so they don't need a position

func play_capture():
	_play_global(capture_sfx)

# --- INTERNAL ENGINE ---

func _play_3d(stream: AudioStream, pos: Vector3):
	if stream == null:
		return 
		
	var player = AudioStreamPlayer3D.new()
	player.stream = stream
	player.global_position = pos # Set the 3D position!
	
	# We must add 3D sounds to the actual game scene, not the Autoload root
	get_tree().root.add_child(player)
	player.play()
	
	player.finished.connect(player.queue_free)

func _play_global(stream: AudioStream):
	if stream == null:
		return 
		
	var player = AudioStreamPlayer.new()
	player.stream = stream
	add_child(player)
	player.play()
	
	player.finished.connect(player.queue_free)
