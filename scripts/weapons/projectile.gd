class_name Projectile
extends Area2D

## Base projectile for all weapon types.
## Handles movement, collision, and cleanup.
## Weapon subclasses or scenes configure speed, damage, and direction.

# ---- Signals ----
signal hit(target: Node2D)

# ---- Exported ----
@export var speed: float = 600.0
@export var damage: int = 1
@export var direction: Vector2 = Vector2.UP
@export var lifetime: float = 3.0
@export var is_player_projectile: bool = true

# ---- Internal ----
var _timer: float = 0.0


func _ready() -> void:
	# Configure collision layers (bitmask: bit0=player, bit1=player_proj, bit2=enemies, bit3=enemy_proj, bit4=pickups, bit5=environment)
	if is_player_projectile:
		collision_layer = 2  # player_projectiles (bit 1)
		collision_mask = 4 | 32  # enemies + environment (bits 2, 5)
		add_to_group("player_projectile")
	else:
		collision_layer = 8  # enemy_projectiles (bit 3)
		collision_mask = 1  # player (bit 0)
		add_to_group("enemy_projectile")
	area_entered.connect(_on_area_entered)


func _physics_process(delta: float) -> void:
	position += direction * speed * delta
	_timer += delta
	if _timer >= lifetime:
		_cleanup()


func _on_area_entered(other: Area2D) -> void:
	hit.emit(other)
	_cleanup()


func _cleanup() -> void:
	if is_instance_valid(self):
		queue_free()
