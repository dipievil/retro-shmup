class_name PlayerExplosion
extends Node2D

## One-shot player explosion used by the Phase 2 kamikaze collision.
## Reuses the stage-1 explosion sheet and SFX already present on dev.

signal played

const SHEET_PATH := "res://assets/sprites/effects/explosion_sheet.png"
const METADATA_PATH := "res://assets/sprites/effects/explosion_sheet.json"
const ANIMATION := &"explode"
const SFX_PATH := "res://assets/audio/sfx/explosion.wav"

## Number of animation frames actually loaded (0 means the sheet failed).
var frame_count: int = 0
var _sprite: AnimatedSprite2D


func _ready() -> void:
	add_to_group("player_explosion")
	_sprite = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if _sprite == null:
		push_error("PlayerExplosion: AnimatedSprite2D child missing")
		return
	_sprite.sprite_frames = AsepriteSheet.build_sprite_frames(
		SHEET_PATH, METADATA_PATH, ANIMATION, 14.0
	)
	if _sprite.sprite_frames != null:
		_sprite.sprite_frames.set_animation_loop(ANIMATION, false)
	_sprite.animation_finished.connect(_on_animation_finished)
	play()


## Idempotent: a caller can invoke this after adding the effect to the tree
## without restarting an animation that already began in _ready().
func play() -> void:
	if _sprite == null or _sprite.sprite_frames == null:
		return
	var count := _sprite.sprite_frames.get_frame_count(ANIMATION)
	if count <= 0:
		return
	frame_count = count
	if not _sprite.is_playing():
		_sprite.play(ANIMATION)
		played.emit()
		_play_sfx()


func _play_sfx() -> void:
	# Headless CI has no audio output; skipping avoids orphaned stream players
	# when the test suite quits immediately after the collision assertion.
	if DisplayServer.get_name() == "headless":
		return
	var tree := get_tree()
	if tree == null:
		return
	var manager := tree.root.get_node_or_null("AudioManager")
	if manager == null or not manager.has_method("play_sfx"):
		return
	var stream := load(SFX_PATH) as AudioStream
	if stream != null:
		manager.call("play_sfx", stream, -4.0)


func _on_animation_finished() -> void:
	queue_free()
