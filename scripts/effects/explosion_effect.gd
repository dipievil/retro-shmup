class_name ExplosionEffect
extends Node2D

## One-shot explosion animation shared by enemy and player deaths (Phase 2).
## Reuses assets/sprites/effects/explosion_sheet.png from task-1; no new sprite
## asset is authored here. Spawn with ExplosionEffect.spawn(parent, position).

const SHEET_PATH := "res://assets/sprites/effects/explosion_sheet.png"
const FRAME_SIZE := Vector2i(32, 32)
const FRAME_COUNT := 8
const FRAME_RATE := 14.0


## Spawns the effect under `parent` at a global position and returns it.
## Callers must pass a persistent parent (e.g. the stage), not a node that is
## about to be freed with the exploding ship.
static func spawn(parent: Node, at: Vector2) -> ExplosionEffect:
	if parent == null:
		return null
	var packed := load("res://scenes/effects/explosion.tscn") as PackedScene
	if packed == null:
		return null
	var effect := packed.instantiate() as ExplosionEffect
	if effect == null:
		return null
	parent.add_child(effect)
	effect.global_position = at
	return effect


func _ready() -> void:
	var sprite := get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if sprite == null:
		return
	_sprite_setup(sprite)

	var timer := Timer.new()
	timer.one_shot = true
	timer.wait_time = float(FRAME_COUNT) / FRAME_RATE
	timer.timeout.connect(queue_free)
	add_child(timer)
	timer.start()


func _sprite_setup(sprite: AnimatedSprite2D) -> void:
	var frames := SpriteFrames.new()
	if not frames.has_animation("default"):
		frames.add_animation("default")
	frames.set_animation_speed("default", FRAME_RATE)
	frames.set_animation_loop("default", false)
	var texture := load(SHEET_PATH) as Texture2D
	if texture != null:
		for i in FRAME_COUNT:
			var atlas := AtlasTexture.new()
			atlas.atlas = texture
			atlas.region = Rect2(i * FRAME_SIZE.x, 0, FRAME_SIZE.x, FRAME_SIZE.y)
			frames.add_frame("default", atlas)
	sprite.sprite_frames = frames
	sprite.play("default")
