extends Node

## Regression check for PR #10: the organic-enemy wave must run through the
## stage that main.tscn actually instantiates, not only when stage_1.tscn is
## loaded directly by a unit test.
## Run as a scene so autoloads and global class names exist:
##   godot --headless --path . res://tests/test_active_stage.tscn

const MainScene := preload("res://scenes/main.tscn")
const Stage1Script := preload("res://scripts/stages/stage_1.gd")

var _failures: Array[String] = []
var _organic_spawn_events: Array[OrganicEnemy] = []


func _ready() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	print("[task-9] Active stage wave")
	var main := MainScene.instantiate()
	add_child(main)

	var stage := main.get_node_or_null("Stage1") as StageBase
	_check(stage != null and stage.get_script() == Stage1Script,
			"main.tscn instantiates Stage1 as the active stage")
	if stage == null:
		_finish()
		return

	_check(GameManager.current_state == GameManager.GameState.PLAYING,
			"main sets PLAYING so the active stage processes its queue")
	_check(_find_organic(main) == null, "no organic enemy before wave 4")

	stage.enemy_spawned.connect(_on_enemy_spawned)
	# Jump to wave 4's timestamp; _process(0.0) drains every queued wave due at
	# or before 20s without waiting twenty real seconds.
	stage._spawn_timer = 20.0
	stage._process(0.0)

	var spawned := _find_organic(stage)
	_check(spawned != null, "active stage spawns an OrganicEnemy from Stage 1 wave 4")
	_check(_organic_spawn_events.size() == 1,
			"active stage emits enemy_spawned for exactly one OrganicEnemy")
	if spawned != null:
		_check(spawned.is_inside_tree(), "spawned OrganicEnemy is in the running scene tree")
		_check(spawned.get_parent() == stage, "spawned OrganicEnemy is parented to the active stage")
		_check(is_equal_approx(spawned.position.x, 510.0),
				"wave 4 organic enemy enters from the right edge")
	_finish()


func _check(ok: bool, label: String) -> void:
	if ok:
		print("  PASS  ", label)
	else:
		printerr("  FAIL  ", label)
		_failures.append(label)


func _on_enemy_spawned(enemy: BaseEnemy) -> void:
	if enemy is OrganicEnemy:
		_organic_spawn_events.append(enemy as OrganicEnemy)


func _find_organic(node: Node) -> OrganicEnemy:
	if node is OrganicEnemy:
		return node as OrganicEnemy
	for child in node.get_children():
		var found := _find_organic(child)
		if found != null:
			return found
	return null


func _finish() -> void:
	if _failures.is_empty():
		print("[task-9] ALL ACTIVE-STAGE CHECKS PASSED")
		get_tree().quit(0)
	else:
		printerr("[task-9] %d ACTIVE-STAGE CHECK(S) FAILED" % _failures.size())
		get_tree().quit(1)
