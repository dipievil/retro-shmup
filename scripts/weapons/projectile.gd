class_name Projectile
extends Area2D

## Base projectile for all weapon types (Area2D per docs/plan.md Technical Solutions).
## Handles movement, collision, sprite fallback and cleanup.
## Weapon subclasses configure speed, damage and direction before add_child().

# ---- Signals ----
signal hit(target: Node2D)

# ---- Exported ----
@export var speed: float = 600.0
@export var damage: int = 1
@export var direction: Vector2 = Vector2.UP
@export var lifetime: float = 3.0
@export var is_player_projectile: bool = true

# "laser" | "missile" | "bomb" — selects the authored Aseprite sheet.
@export var weapon_kind: String = "laser"

# Depth layer the shot was launched from (0 = back, 0.5 = middle, 1 = front).
# Mirrors PlayerShip/BaseEnemy; homing projectiles use it to stay on their plane.
# Laser/bomb carry it too but ignore it, so their behaviour is unchanged.
var depth: float = 0.5

# ---- Internal ----
var _timer: float = 0.0
const _OFFSCREEN_MARGIN := 32.0
const _FALLBACK_SCREEN_SIZE := Vector2(480, 270)


func _ready() -> void:
	# Collision bitmask: bit0=player, bit1=player_proj, bit2=enemies,
	# bit3=enemy_proj, bit4=pickups, bit5=environment (see project.godot).
	if is_player_projectile:
		collision_layer = 2  # player_projectiles (bit 1)
		collision_mask = 4 | 32  # enemies + environment (bits 2, 5)
		add_to_group("player_projectile")
	else:
		collision_layer = 8  # enemy_projectiles (bit 3)
		collision_mask = 1  # player (bit 0)
		add_to_group("enemy_projectile")
	area_entered.connect(_on_area_entered)
	_apply_visual()


func _physics_process(delta: float) -> void:
	position += direction * speed * delta
	_timer += delta
	# Lifetime AND bounds both free shots — no off-screen leaks.
	if _timer >= lifetime or _is_off_screen():
		_cleanup()


func _on_area_entered(other: Area2D) -> void:
	hit.emit(other)
	_cleanup()


func _cleanup() -> void:
	if is_instance_valid(self):
		queue_free()


func _is_off_screen() -> bool:
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		viewport_size = _FALLBACK_SCREEN_SIZE
	var p := global_position
	return (p.x < -_OFFSCREEN_MARGIN or p.x > viewport_size.x + _OFFSCREEN_MARGIN
		or p.y < -_OFFSCREEN_MARGIN or p.y > viewport_size.y + _OFFSCREEN_MARGIN)


## Uses the authored Aseprite sheet frame for this weapon kind. A missing sheet
## leaves the Visual node empty instead of erroring or drawing a placeholder.
func _apply_visual() -> void:
	var sprite := get_node_or_null("Visual") as Sprite2D
	if sprite == null:
		return
	var texture := WeaponResources.sprite_texture(weapon_kind)
	if texture == null:
		return
	sprite.texture = texture
	sprite.visible = true
