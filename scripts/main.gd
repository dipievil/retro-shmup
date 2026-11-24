extends Node2D

## Main entry point. Orchestrates stage, player, HUD, and cutscenes.
## Starts directly in PLAYING state (the demo startup) with stage 1 and GDAS-1.

const Stage1EndScene := preload("res://scenes/cutscenes/stage_1_end.tscn")

@export var start_ship_id: String = "gdas_1"

var _player: PlayerShip
var _stage: Stage1
var _hud: HUD
var stage_end_cutscene: Node = null


func _ready() -> void:
	_player = $PlayerShip
	_stage = $Stage1
	_hud = $HUD
	_stage.stage_completed.connect(_on_stage_completed)
	GameManager.start_game(start_ship_id)
	# Greybox: skip menu, go straight to gameplay. Stage1 supplies the waves.
	GameManager.change_state(GameManager.GameState.PLAYING)


## End-of-stage hook. The stage emits stage_completed once; this instantiates
## the placeholder Control/AnimationPlayer cutscene as a CanvasLayer child.
func _on_stage_completed(_stage_id: int) -> void:
	if stage_end_cutscene != null and is_instance_valid(stage_end_cutscene):
		return
	var cutscene: Node = Stage1EndScene.instantiate()
	$CutsceneManager.add_child(cutscene)
	stage_end_cutscene = cutscene
	if cutscene.has_method("play"):
		cutscene.play()
	else:
		push_error("[task-19] stage 1 end cutscene scene has no play() method")


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("start") and GameManager.current_state == GameManager.GameState.MENU:
		GameManager.start_game(start_ship_id)
		GameManager.change_state(GameManager.GameState.PLAYING)
