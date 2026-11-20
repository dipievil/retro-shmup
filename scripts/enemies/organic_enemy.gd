class_name OrganicEnemy
extends BaseEnemy

## Phase 2 organic enemy: enters from the right, flies straight left and fires
## one short green beam per firing event. A single player hit destroys it;
## ramming the player destroys both ships.
##
## Public API:
##   fire() -> Projectile          spawns exactly one enemy beam (beam_spawned emitted)
##   beam_spawned(beam)            signal emitted for each spawned beam
##   explode() on PlayerShip       shared death path used on mutual collisions

signal beam_spawned(beam: Projectile)

const PROJECTILE_SCENE := preload("res://scenes/weapons/projectile.tscn")
const SPRITE_PATH := "res://assets/sprites/enemies/stage1_scout_sheet.png"
const FRAME_SIZE := Vector2i(28, 24)
const FRAME_COUNT := 4
const FRAME_RATE := 9.0

@export var fire_interval: float = 2.0
@export var first_shot_delay: float = 1.0
@export var beam_speed: float = 240.0
@export var beam_lifetime: float = 0.9
@export var beam_damage: int = 1

var _fire_timer: float = 0.0


func _ready() -> void:
	# One-hit death: set before super() so it seeds current_health.
	max_health = 1
	speed = 90.0
	super._ready()
	_setup_visual()
	_fire_timer = first_shot_delay


func _setup_visual() -> void:
	var sprite := get_node_or_null("Visual") as AnimatedSprite2D
	if sprite == null:
		return
	var frames := SpriteFrames.new()
	if not frames.has_animation("default"):
		frames.add_animation("default")
	frames.set_animation_speed("default", FRAME_RATE)
	frames.set_animation_loop("default", true)
	var texture := load(SPRITE_PATH) as Texture2D
	if texture != null:
		for i in FRAME_COUNT:
			var atlas := AtlasTexture.new()
			atlas.atlas = texture
			atlas.region = Rect2(i * FRAME_SIZE.x, 0, FRAME_SIZE.x, FRAME_SIZE.y)
			frames.add_sprite_frame("default", atlas)
	sprite.sprite_frames = frames
	sprite.play("default")
	# The task-1 export is the authored enemy sheet; tint it towards green for
	# the Phase 2 "organic green ship" look without authoring a new sprite.
	sprite.modulate = Color(0.35, 1.0, 0.45)


## Right-to-left only; no vertical drift and no base-class horizontal bounce.
func _ai_update(_delta: float) -> void:
	_velocity = Vector2.LEFT * speed
	_fire_timer -= _delta
	if _fire_timer <= 0.0:
		fire()
		_fire_timer = fire_interval


func _constrain_to_screen() -> void:
	if global_position.x < -24.0 or global_position.y < -48.0 or global_position.y > 318.0:
		queue_free()


## Spawns one short green beam travelling left, reusing the base projectile.
func fire() -> Projectile:
	var parent := get_parent()
	if parent == null or not _is_alive:
		return null
	var beam := PROJECTILE_SCENE.instantiate() as Projectile
	if beam == null:
		return null
	beam.is_player_projectile = false
	beam.direction = Vector2.LEFT
	beam.speed = beam_speed
	beam.lifetime = beam_lifetime
	beam.damage = beam_damage
	beam.modulate = Color(0.3, 1.0, 0.4)
	beam.global_position = global_position + Vector2(-14.0, 0.0)
	parent.add_child(beam)
	beam_spawned.emit(beam)
	return beam


func _die() -> void:
	if not _is_alive:
		return
	ExplosionEffect.spawn(get_parent(), global_position)
	super._die()


func _on_area_entered(other: Area2D) -> void:
	if not _is_alive:
		return
	if other.is_in_group("player"):
		# Mutual destruction: reuse the player's normal death/explosion path.
		var player := other as PlayerShip
		if player != null:
			player.explode()
		_die()
		return
	super._on_area_entered(other)
