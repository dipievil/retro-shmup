extends Node2D

## Main entry point. Orchestrates stage, player, HUD, and cutscenes.
## For the greybox prototype, starts directly in PLAYING state.

const KamikazeScene := preload("res://scenes/enemies/kamikaze_enemy.tscn")

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
	_spawn_kamikaze_wave()


## Phase 2 [2.3]: kamikazes enter from the top at varied x positions. This is
## deliberately independent of the unmerged stage-1 parallax scene.
func _spawn_kamikaze_wave() -> void:
	var view_size := get_viewport_rect().size
	for i in range(3):
		var kamikaze: KamikazeEnemy = KamikazeScene.instantiate()
		kamikaze.position = KamikazeEnemy.spawn_position(i, view_size)
		kamikaze.depth = 0.5
		add_child(kamikaze)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("start") and GameManager.current_state == GameManager.GameState.MENU:
		GameManager.start_game(start_ship_id)
		GameManager.change_state(GameManager.GameState.PLAYING)
