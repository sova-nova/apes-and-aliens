extends Node

# We will assign these in the Project Settings Inspector!
@export var shoot_sfx: AudioStream
@export var hit_sfx: AudioStream
@export var ability_sfx: AudioStream
@export var capture_sfx: AudioStream

func play_shoot():
	_play(shoot_sfx)

func play_hit():
	_play(hit_sfx)

func play_ability():
	_play(ability_sfx)

func play_capture():
	_play(capture_sfx)

# The internal function that actually plays the sound
func _play(stream: AudioStream):
	if stream == null:
		return # If no sound is assigned, do nothing (prevents crashes!)
		
	# Create a temporary audio player
	var player = AudioStreamPlayer.new()
	player.stream = stream
	player.bus = "Master"
	add_child(player)
	player.play()
	
	# Clean up the player when the sound finishes so we don't leak memory
	player.finished.connect(player.queue_free)
