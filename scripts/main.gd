extends Node2D

## Main entry point. Orchestrates stage, player, HUD, and cutscenes.
## For the greybox prototype, starts directly in PLAYING state.

@export var start_ship_id: String = "gdas_1"

var _player: PlayerShip
var _stage: StageBase
var _hud: HUD


func _ready() -> void:
	_player = $PlayerShip
	_stage = $StageBase
	_hud = $HUD
	GameManager.start_game(start_ship_id)
	# Greybox: skip menu, go straight to gameplay
	GameManager.change_state(GameManager.GameState.PLAYING)
	_spawn_test_wave()


func _spawn_test_wave() -> void:
	var enemy_scene: PackedScene = preload("res://scenes/enemies/base_enemy.tscn")
	# Spawn a few test enemies at intervals
	for i in range(5):
		var enemy: BaseEnemy = enemy_scene.instantiate()
		enemy.position = Vector2(80 + i * 80, -40 - i * 30)
		enemy.depth = 0.5
		add_child(enemy)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("start") and GameManager.current_state == GameManager.GameState.MENU:
		GameManager.start_game(start_ship_id)
		GameManager.change_state(GameManager.GameState.PLAYING)
