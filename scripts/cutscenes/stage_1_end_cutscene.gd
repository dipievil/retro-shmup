class_name Stage1EndCutscene
extends Control

## Placeholder end-of-stage cutscene for stage 1 (docs/story.md, stage 1).
## Phantasy Star-style sliding text panel + layered pixel-art stills and a
## short screen shake, per docs/game_design.md "Stage transitions".
## The real animated sequence is a later art/audio pass; this hook is real and
## reachable from the stage through Main._on_stage_completed().

signal finished

const ANIMATION_NAME := "play"

@export var line_duration: float = 2.0

## Story beat: training under Lt. Alex Mercer ends with his death in combat.
var story_lines: Array[String] = [
	"LT. ALEX MERCER: Jane, stay on my wing. Watch the controls, then watch the sky.",
	"JANE SILVA: Copy, Lieutenant. Laser, missile and bomb are all green.",
	"NARRATOR: The training run becomes a real intercept as the anomaly opens above the fleet.",
	"LT. ALEX MERCER: Break off, Jane! I'll draw them away—",
	"NARRATOR: Alex Mercer's ship is lost. Jane flies on alone.",
]

var _text: RichTextLabel
var _animation: AnimationPlayer
var _index: int = -1
var _line_timer: float = 0.0
var _played: bool = false
var _done: bool = false


func _ready() -> void:
	_text = get_node_or_null("ShakeRoot/DialoguePanel/DialogueText") as RichTextLabel
	_animation = get_node_or_null("AnimationPlayer") as AnimationPlayer
	if _text == null or _animation == null:
		push_error("[task-19] stage 1 end cutscene is missing text or AnimationPlayer nodes")
	visible = false


func play() -> void:
	if _played:
		return
	_played = true
	visible = true
	GameManager.change_state(GameManager.GameState.CUTSCENE)
	if _animation != null and _animation.has_animation(ANIMATION_NAME):
		_animation.play(ANIMATION_NAME)
	else:
		push_error("[task-19] stage 1 end cutscene has no '%s' animation" % ANIMATION_NAME)
	_advance()


func _process(delta: float) -> void:
	if not _played or _done:
		return
	_line_timer += delta
	if _line_timer >= line_duration:
		_advance()


func _input(event: InputEvent) -> void:
	if not _played or _done:
		return
	if event.is_action_pressed("fire") or event.is_action_pressed("start"):
		_advance()


func _advance() -> void:
	if _done:
		return
	_index += 1
	_line_timer = 0.0
	if _index >= story_lines.size():
		_finish()
		return
	if _text == null:
		push_error("[task-19] stage 1 end cutscene cannot show line %d" % _index)
		return
	_text.text = story_lines[_index]


func _finish() -> void:
	_done = true
	visible = false
	finished.emit()
	GameManager.change_state(GameManager.GameState.PLAYING)
	queue_free()
