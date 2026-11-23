class_name Stage1Interceptor
extends BaseEnemy

## Stage 1 interceptor: faster, tankier enemy used when the training waves
## escalate. Reuses BaseEnemy and the stage-1 interceptor sheet on dev.

const FRAME_COUNT := 4
const FRAME_WIDTH := 36
const FRAME_DURATION := 0.10

var _anim_time: float = 0.0


func _ai_update(delta: float) -> void:
	_anim_time += delta
	# Converge gently on the middle layer so side spawns stay in play.
	var drift := clampf(240.0 - global_position.x, -30.0, 30.0)
	_velocity = Vector2(drift, speed)
	_tick_animation()


func _tick_animation() -> void:
	var sprite := get_node_or_null("Visual") as Sprite2D
	if sprite == null:
		return
	var frame := int(_anim_time / FRAME_DURATION) % FRAME_COUNT
	var rect := sprite.region_rect
	rect.x = float(frame * FRAME_WIDTH)
	sprite.region_rect = rect
