extends Node3D

func _ready():
	# Tell the Game Manager to find the capture points now that the level is loaded!
	HUD.visible = true
	GameManager.setup_level()
