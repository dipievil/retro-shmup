class_name Stage1Scout
extends BaseEnemy

## Stage 1 scout: the light, weaving enemy from the training waves.
## Reuses BaseEnemy's health/collision/AI interface and the stage-1 scout sheet
## already present on dev. Animation is a simple region flip over the sheet.

const FRAME_COUNT := 4
const FRAME_WIDTH := 28
const FRAME_DURATION := 0.11

var _anim_time: float = 0.0
var _phase: float = 0.0


func _ready() -> void:
	super._ready()
	# Deterministic opening phase keeps the training wave readable on retry.
	_phase = 0.0


func _ai_update(delta: float) -> void:
	_anim_time += delta
	_phase += delta * 2.0
	_velocity = Vector2(sin(_phase) * 16.0, speed)
	_tick_animation()


func _tick_animation() -> void:
	var sprite := get_node_or_null("Visual") as Sprite2D
	if sprite == null:
		return
	var frame := int(_anim_time / FRAME_DURATION) % FRAME_COUNT
	var rect := sprite.region_rect
	rect.position.x = float(frame * FRAME_WIDTH)
	sprite.region_rect = rect
