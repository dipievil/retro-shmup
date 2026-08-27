extends Node

## GameManager (Autoload)
## Central hub for game state, stage progression, score, and signaling.
## Acts as an event bus connecting stages, UI, player, and audio.

# ---- Signals ----
signal score_changed(new_score: int)
signal hull_changed(ship_index: int, new_hull: int)
signal shield_changed(ship_index: int, shield_side: String, new_value: int)
signal weapon_changed(weapon_name: String, level: int)
signal game_state_changed(new_state: GameState)
signal stage_changed(stage_id: int)
signal player_died
signal stage_cleared

# ---- Enums ----
enum GameState { MENU, PLAYING, CUTSCENE, PAUSED, GAME_OVER, VICTORY }

# ---- Constants ----
const MAX_STAGES := 12

# ---- Ship data (from game_design.md) ----
const SHIP_DATA := {
	"space_quantum": {
		"name": "Space Quantum",
		"max_hull": 1,
		"max_front_shield": 1,
		"max_back_shield": 1,
		"speed_levels": 1,
		"weapons": ["laser"],
	},
	"gdas_1": {
		"name": "GDAS-1",
		"max_hull": 3,
		"max_front_shield": 3,
		"max_back_shield": 3,
		"speed_levels": 3,
		"weapons": ["laser", "missile", "bomb"],
	},
}

# ---- State ----
var current_state: GameState = GameState.MENU
var current_stage: int = 1
var score: int = 0
var selected_ship: String = "gdas_1"
var player: Node2D = null
var current_stage_node: Node2D = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func change_state(new_state: GameState) -> void:
	if new_state == current_state:
		return
	current_state = new_state
	game_state_changed.emit(new_state)
	match new_state:
		GameState.PAUSED:
			get_tree().paused = true
		GameState.PLAYING:
			get_tree().paused = false
		GameState.GAME_OVER:
			get_tree().paused = false
		GameState.VICTORY:
			get_tree().paused = false


func add_score(amount: int) -> void:
	score += amount
	score_changed.emit(score)


func go_to_stage(stage_id: int) -> void:
	current_stage = stage_id
	stage_changed.emit(stage_id)


func next_stage() -> void:
	if current_stage < MAX_STAGES:
		go_to_stage(current_stage + 1)
	else:
		change_state(GameState.VICTORY)


func start_game(ship_id: String = "gdas_1") -> void:
	selected_ship = ship_id
	score = 0
	current_stage = 1
	score_changed.emit(score)
	stage_changed.emit(current_stage)
	change_state(GameState.PLAYING)


func game_over() -> void:
	player_died.emit()
	change_state(GameState.GAME_OVER)


func clear_stage() -> void:
	stage_cleared.emit()


func get_ship_data() -> Dictionary:
	return SHIP_DATA.get(selected_ship, SHIP_DATA["gdas_1"])
