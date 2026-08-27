class_name BaseEnemy
extends Area2D

## Base enemy class with virtual AI interface.
## Subclasses override _ai_update() for unique behaviors per stage.
## Supports the depth/layer system for multi-layer combat.

# ---- Signals ----
signal died(score_value: int)

# ---- Exported ----
@export var max_health: int = 2
@export var speed: float = 80.0
@export var score_value: int = 100
@export var contact_damage: int = 1
@export var depth: float = 0.5  # which layer the enemy starts on

# ---- Internal ----
var current_health: int = 2
var _velocity: Vector2 = Vector2.ZERO
var _is_alive: bool = true


func _ready() -> void:
	current_health = max_health
	collision_layer = 4  # enemies (bit 2)
	collision_mask = 1 | 2  # player + player_projectiles (bits 0, 1)
	add_to_group("enemy")
	area_entered.connect(_on_area_entered)


func _physics_process(delta: float) -> void:
	if not _is_alive:
		return
	_ai_update(delta)
	position += _velocity * delta
	_constrain_to_screen()


## Virtual: override in subclasses for stage-specific AI behavior.
func _ai_update(delta: float) -> void:
	# Default: move downward
	_velocity = Vector2.DOWN * speed


func _constrain_to_screen() -> void:
	if position.y > 300:
		queue_free()
	if position.x < -20 or position.x > 500:
		_velocity.x *= -1


func take_damage(amount: int) -> void:
	if not _is_alive:
		return
	current_health = maxi(0, current_health - amount)
	if current_health <= 0:
		_die()


func _die() -> void:
	_is_alive = false
	died.emit(score_value)
	GameManager.add_score(score_value)
	queue_free()


func _on_area_entered(other: Area2D) -> void:
	if other.is_in_group("player_projectile"):
		var proj: Projectile = other
		take_damage(proj.damage)
		proj.queue_free()
	elif other.is_in_group("player"):
		var player: PlayerShip = other
		player.take_damage(contact_damage, position.y < player.position.y)
