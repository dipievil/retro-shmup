class_name Explosion
extends AnimatedSprite2D

## One-shot explosion played from the authored Aseprite sheet.
## Spawns under the same parent as the destroyed object and frees itself when
## the animation ends, so callers never have to manage its lifetime.

const SHEET_PATH := "res://assets/sprites/effects/explosion_sheet.png"
const METADATA_PATH := "res://assets/sprites/effects/explosion_sheet.json"

static var _shared_frames: SpriteFrames = null


## Adds an explosion at `at` under `parent`. Returns null when no parent is in
## the tree (e.g. headless unit tests that instantiate nodes in isolation).
static func spawn(parent: Node, at: Vector2) -> Explosion:
	if parent == null or not parent.is_inside_tree():
		return null
	var scene := load("res://scenes/effects/explosion.tscn") as PackedScene
	if scene == null:
		return null
	var effect := scene.instantiate() as Explosion
	if effect == null:
		return null
	parent.add_child(effect)
	effect.global_position = at
	return effect


func _ready() -> void:
	if _shared_frames == null:
		_shared_frames = SpriteSheet.load_frames(SHEET_PATH, METADATA_PATH)
	if not SpriteSheet.has_frames(_shared_frames):
		queue_free()
		return
	sprite_frames = _shared_frames
	animation = SpriteSheet.DEFAULT_ANIMATION
	animation_finished.connect(_on_animation_finished)
	play()


func _on_animation_finished() -> void:
	queue_free()
