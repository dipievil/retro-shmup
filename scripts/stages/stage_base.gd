class_name StageBase
extends Node2D

## Base stage controller with parallax scrolling, enemy spawning,
## and the multi-layer depth system from game_design.md.
## Subclasses configure spawn patterns, parallax layers, and stage events.

# ---- Signals ----
signal stage_started
signal stage_complete
signal enemy_spawned(enemy: BaseEnemy)

# ---- Exported ----
@export var stage_id: int = 1
@export var scroll_speed: float = 60.0
@export var auto_scroll: bool = true

# ---- Internal ----
var _elapsed_time: float = 0.0
var _spawn_queue: Array[Dictionary] = []
var _parallax: ParallaxBackground = null
var _spawn_timer: float = 0.0
var _enemy_count: int = 0


func _ready() -> void:
	_find_parallax()
	_build_spawn_queue()
	GameManager.current_stage_node = self
	stage_started.emit()


func _process(delta: float) -> void:
	if GameManager.current_state != GameManager.GameState.PLAYING:
		return
	_elapsed_time += delta
	_update_parallax(delta)
	_update_spawning(delta)


# ---- Parallax ----
func _find_parallax() -> void:
	for child in get_children():
		if child is ParallaxBackground:
			_parallax = child
			break


func _update_parallax(delta: float) -> void:
	if not _parallax or not auto_scroll:
		return
	for layer in _parallax.get_children():
		if layer is ParallaxLayer:
			layer.motion_offset.y += scroll_speed * delta


# ---- Spawning ----
func _build_spawn_queue() -> void:
	# Override in subclasses to define spawn patterns
	pass


func _queue_spawn(time_offset: float, enemy_scene: PackedScene, pos: Vector2, depth: float = 0.5) -> void:
	_spawn_queue.append({
		"time": time_offset,
		"scene": enemy_scene,
		"pos": pos,
		"depth": depth,
	})


func _update_spawning(delta: float) -> void:
	_spawn_timer += delta
	var to_remove: Array[int] = []
	for i in range(_spawn_queue.size()):
		var entry: Dictionary = _spawn_queue[i]
		if _spawn_timer >= entry["time"]:
			_spawn_enemy(entry["scene"], entry["pos"], entry["depth"])
			to_remove.append(i)
	for i in range(to_remove.size() - 1, -1, -1):
		_spawn_queue.remove_at(to_remove[i])


func _spawn_enemy(scene: PackedScene, pos: Vector2, depth_val: float) -> void:
	var enemy: BaseEnemy = scene.instantiate()
	enemy.position = pos
	enemy.depth = depth_val
	enemy.died.connect(_on_enemy_died)
	add_child(enemy)
	_enemy_count += 1
	enemy_spawned.emit(enemy)


func _on_enemy_died(_score: int) -> void:
	_enemy_count -= 1


# ---- Layer/Depth ----
func get_layer_scale(depth_val: float) -> float:
	return lerpf(0.6, 1.4, depth_val)


func get_layer_opacity(depth_val: float) -> float:
	return lerpf(0.5, 1.0, depth_val)


# ---- Stage completion ----
func complete_stage() -> void:
	stage_complete.emit()
	GameManager.clear_stage()
	GameManager.next_stage()
