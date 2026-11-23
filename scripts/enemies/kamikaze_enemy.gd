class_name KamikazeEnemy
extends BaseEnemy

## Phase 2 [2.3] kamikaze ship: dives from the top of the screen at 15 degrees
## from vertical and destroys both ships on player contact, playing the shared
## player explosion effect. Uses the stage-1 interceptor sheet already on dev.
##
## Sign convention: +x is right and +y is down, so a 15-degree dive from
## vertical is Vector2(sin(15deg), cos(15deg)): down and slightly to the right.

## Emitted once when a player is rammed; carries the spawned explosion.
signal player_hit(effect: Node2D)

const DIVE_ANGLE_DEG: float = 15.0
const SPAWN_Y_OFFSET: float = 24.0
const DESPAWN_MARGIN: float = 32.0
const DEFAULT_VIEWPORT_SIZE := Vector2(480.0, 270.0)
const SPAWN_X_FRACTIONS := [0.2, 0.5, 0.8]
const SPRITE_PATH := "res://assets/sprites/enemies/stage1_interceptor_sheet.png"
const SPRITE_METADATA_PATH := "res://assets/sprites/enemies/stage1_interceptor_sheet.json"
const EXPLOSION_SCENE := preload("res://scenes/effects/player_explosion.tscn")

## Overridable so headless tests can use an exact viewport size.
@export var viewport_size: Vector2 = DEFAULT_VIEWPORT_SIZE

## Set by _impact() so callers/tests can inspect the spawned effect.
var last_explosion: Node2D = null


func _ready() -> void:
	# One-hit kamikaze; set before super() so max_health seeds current_health.
	max_health = 1
	speed = 120.0
	super._ready()
	_setup_visual()


func _setup_visual() -> void:
	var sprite := get_node_or_null("Visual") as AnimatedSprite2D
	if sprite == null:
		return
	sprite.sprite_frames = AsepriteSheet.build_sprite_frames(
		SPRITE_PATH, SPRITE_METADATA_PATH, &"dive", 10.0
	)
	# Tint the existing interceptor sheet to read as a distinct kamikaze unit.
	sprite.modulate = Color(1.0, 0.62, 0.32)
	sprite.play(&"dive")


## Unit-length direction times speed, 15 degrees to the right of straight down.
static func dive_velocity(speed_value: float) -> Vector2:
	var angle := deg_to_rad(DIVE_ANGLE_DEG)
	return Vector2(sin(angle), cos(angle)) * speed_value


## Top-of-viewport spawn slots; index wraps so waves repeat across the screen.
static func spawn_position(index: int, view_size: Vector2 = DEFAULT_VIEWPORT_SIZE) -> Vector2:
	var count := SPAWN_X_FRACTIONS.size()
	var slot: float = SPAWN_X_FRACTIONS[abs(index) % count]
	return Vector2(view_size.x * slot, -SPAWN_Y_OFFSET)


func _ai_update(_delta: float) -> void:
	_velocity = dive_velocity(speed)


## Kamikazes never bounce: they leave the screen and are freed.
func _constrain_to_screen() -> void:
	var p := global_position
	var outside_bottom := p.y > viewport_size.y + DESPAWN_MARGIN
	var outside_side := (p.x > viewport_size.x + DESPAWN_MARGIN
			or p.x < -DESPAWN_MARGIN)
	if outside_bottom or outside_side:
		queue_free()


## BaseEnemy connects area_entered to this method, so the override is the
## single collision entry point for both the player and projectiles.
func _on_area_entered(other: Area2D) -> void:
	if not _is_alive:
		return
	if other.is_in_group("player"):
		_impact(other as PlayerShip)
		return
	if other.is_in_group("player_projectile"):
		super._on_area_entered(other)


func _impact(player: PlayerShip) -> void:
	_is_alive = false
	last_explosion = _spawn_explosion(global_position)
	if player != null and is_instance_valid(player):
		# Shared player death path; ignores shields and invincibility frames.
		player.explode()
	# Ramming the player scores nothing, but still releases the stage slot.
	died.emit(0)
	player_hit.emit(last_explosion)
	queue_free()


func _spawn_explosion(at: Vector2) -> Node2D:
	var effect := EXPLOSION_SCENE.instantiate() as Node2D
	if effect == null:
		push_error("KamikazeEnemy: explosion scene did not instantiate a Node2D")
		return null
	var parent := get_tree().current_scene if get_tree().current_scene != null else get_tree().root
	parent.add_child(effect)
	effect.global_position = at
	if effect.has_method("play"):
		effect.call("play")
	return effect
