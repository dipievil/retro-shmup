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
	# Side-scrolling baseline: enter from the right and travel left.
	_velocity = Vector2.LEFT * speed


func _constrain_to_screen() -> void:
	if position.y > 300:
		queue_free()
	# Offscreen right spawns (x > 480) must survive; left-movers despawn once
	# they have fully passed the left edge, with no bounce back into view.
	if position.x < -40 or position.x > 560:
		queue_free()


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
	Explosion.spawn(get_parent(), global_position)
	queue_free()


func _on_area_entered(other: Area2D) -> void:
	if other.is_in_group("player_projectile"):
		var proj: Projectile = other
		take_damage(proj.damage)
		proj.queue_free()
	elif other.is_in_group("player"):
		var player: PlayerShip = other
		# Front shield faces right, so an enemy to the ship's right is a front hit.
		player.take_damage(contact_damage, position.x > player.position.x)
