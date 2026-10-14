extends Node
class_name HealthComponent

signal health_changed(new_health: float, max_health: float)
signal died

@export var max_health: float = 100.0

var current_health: float:
	set(value):
		current_health = clampf(value, 0.0, max_health)
		health_changed.emit(current_health, max_health)
		if current_health <= 0.0 and not _is_dead:
			_is_dead = true
			died.emit()

var _is_dead: bool = false

func _ready():
	current_health = max_health

func take_damage(amount: float) -> void:
	if _is_dead:
		return
	current_health -= amount

func heal(amount: float) -> void:
	if _is_dead:
		return
	current_health += amount

func is_dead() -> bool:
	return _is_dead

func revive() -> void:
	_is_dead = false
	current_health = max_health
