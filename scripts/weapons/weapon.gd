class_name Weapon
extends Node2D

## Base weapon class.
## Manages fire rate cooldown and spawning projectiles.
## Subclasses override fire() for specific weapon behaviors.

# ---- Signals ----
signal fired

# ---- Exported ----
@export var fire_rate: float = 0.15
@export var damage: int = 1
@export var projectile_scene: PackedScene
@export var projectile_speed: float = 600.0
@export var projectile_lifetime: float = 3.0
@export var max_level: int = 3

# ---- Internal ----
var current_level: int = 1
var _cooldown: float = 0.0
var _is_on_cooldown: bool = false
var _owner_node: Node2D = null


func _ready() -> void:
	_owner_node = get_parent()


func _process(delta: float) -> void:
	if _is_on_cooldown:
		_cooldown -= delta
		if _cooldown <= 0.0:
			_is_on_cooldown = false


func can_fire() -> bool:
	return not _is_on_cooldown and projectile_scene != null


func fire(direction: Vector2 = Vector2.UP, origin: Vector2 = Vector2.ZERO) -> void:
	if not can_fire():
		return
	_do_fire(direction, origin)
	_is_on_cooldown = true
	_cooldown = fire_rate
	fired.emit()


func _do_fire(direction: Vector2, origin: Vector2) -> void:
	var proj: Projectile = projectile_scene.instantiate()
	proj.direction = direction
	proj.damage = damage
	proj.speed = projectile_speed
	proj.lifetime = projectile_lifetime
	proj.is_player_projectile = true
	proj.global_position = origin
	_owner_node.get_tree().current_scene.add_child(proj)


func upgrade() -> void:
	if current_level < max_level:
		current_level += 1


func reset() -> void:
	current_level = 1
