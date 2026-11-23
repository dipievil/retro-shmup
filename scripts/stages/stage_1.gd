class_name Stage1
extends StageBase

## Stage 1: Intro / training stage (docs/story.md, stage 1).
##
## Reuses StageBase's ParallaxBackground, ParallaxLayers and spawn queue from
## dev. This script only adds the stage-1 orchestration: a documented wave
## table, wave signals, a reachable end condition and the cutscene hook.
##
## Wave table (time in seconds from stage start, `gap` between spawns):
##   1. 01_first_contact  t=1.0  3 scouts,   gap 2.00  top, slow introduction
##   2. 02_formation      t=8.0  5 scouts,   gap 0.60  top, tighter pattern
##   3. 03_flank          t=13.0 6 interceptors, gap 1.00  both sides, mixed depth
##   4. 04_surge          t=20.0 8 interceptors, gap 0.45  top + sides, pressure
## The stage ends POST_WAVE_DELAY seconds after the last spawn, or early when
## every spawned enemy has left the screen. No branch beyond dev is required.

const SCOUT_SCENE := preload("res://scenes/enemies/stage1_scout.tscn")
const INTERCEPTOR_SCENE := preload("res://scenes/enemies/stage1_interceptor.tscn")

const WAVE_TABLE := [
	{"name": "01_first_contact", "at": 1.0, "gap": 2.0, "count": 3, "kind": "scout", "lane": "top", "depths": [0.5]},
	{"name": "02_formation", "at": 8.0, "gap": 0.6, "count": 5, "kind": "scout", "lane": "top", "depths": [0.5]},
	{"name": "03_flank", "at": 13.0, "gap": 1.0, "count": 6, "kind": "interceptor", "lane": "sides", "depths": [0.3, 0.7]},
	{"name": "04_surge", "at": 20.0, "gap": 0.45, "count": 8, "kind": "interceptor", "lane": "mixed", "depths": [0.4, 0.6]},
]

# ---- Signals ----
## Emitted once when the stage reaches its end condition. Main uses this to
## instantiate the placeholder stage-1 end cutscene.
signal stage_completed(stage_id: int)
signal wave_started(wave_index: int, wave_name: String)

# ---- Exported ----
@export var post_wave_delay: float = 6.0

# ---- Internal ----
var current_wave: int = 0
var _end_time: float = 0.0
var _is_completed: bool = false


func _build_spawn_queue() -> void:
	current_wave = 0
	_is_completed = false
	var last_spawn := 0.0
	for i in range(WAVE_TABLE.size()):
		var wave: Dictionary = WAVE_TABLE[i]
		var count := int(wave["count"])
		for j in range(count):
			var at := float(wave["at"]) + float(j) * float(wave["gap"])
			var depths: Array = wave["depths"]
			var depth := float(depths[j % depths.size()])
			_queue_spawn(at, _scene_for(str(wave["kind"])), _spawn_position(wave, j), depth)
			last_spawn = maxf(last_spawn, at)
	_end_time = last_spawn + post_wave_delay


func _scene_for(kind: String) -> PackedScene:
	match kind:
		"scout":
			return SCOUT_SCENE
		"interceptor":
			return INTERCEPTOR_SCENE
		_:
			push_error("[task-19] unknown stage-1 enemy kind: %s" % kind)
			return SCOUT_SCENE


func _spawn_position(wave: Dictionary, index: int) -> Vector2:
	var lane := str(wave.get("lane", "top"))
	var count := int(wave["count"])
	match lane:
		"sides":
			var row := float(index / 2)
			if index % 2 == 0:
				return Vector2(-10.0, 60.0 + row * 45.0)
			return Vector2(490.0, 60.0 + row * 45.0)
		"mixed":
			if index % 2 == 0:
				return Vector2(60.0 + float(index) * 45.0, -30.0)
			return Vector2(-10.0 if index % 4 == 1 else 490.0, 90.0 + float(index) * 12.0)
		_:
			var span := 360.0
			var x := 60.0 + span * (float(index) / float(maxi(count - 1, 1)))
			return Vector2(x, -30.0)


func _update_spawning(delta: float) -> void:
	super._update_spawning(delta)
	# StageBase increments _elapsed_time immediately before this call.
	while current_wave < WAVE_TABLE.size() and _elapsed_time >= float(WAVE_TABLE[current_wave]["at"]):
		var wave: Dictionary = WAVE_TABLE[current_wave]
		current_wave += 1
		wave_started.emit(current_wave, str(wave["name"]))


func _process(delta: float) -> void:
	super._process(delta)
	if _is_completed or GameManager.current_state != GameManager.GameState.PLAYING:
		return
	# Early finish: all spawned enemies killed or flown off, and no more queued.
	if current_wave >= WAVE_TABLE.size() and _spawn_queue.is_empty():
		if get_tree().get_nodes_in_group("enemy").is_empty():
			complete_stage()
			return
	# Timeline finish: always reachable even if the player lets enemies escape.
	if _elapsed_time >= _end_time:
		complete_stage()


func complete_stage() -> void:
	if _is_completed:
		return
	_is_completed = true
	stage_completed.emit(stage_id)
	super.complete_stage()


func get_end_time() -> float:
	return _end_time


func get_wave_count() -> int:
	return WAVE_TABLE.size()
