extends Node

## Headless checks for task-19 (stage 1 playable training stage).
## Run from the Godot project root with Godot 4.3+:
##   godot --headless --path . res://tests/test_stage_1.tscn
## Runs as a scene (not --script) so autoloads and global class_name
## registrations exist. Exits 0 only when every check passes.

var _failures: Array[String] = []
var _main: Node
var _stage: Stage1
var _waves: Array[Dictionary] = []
var _completed: Array[int] = []


func _ready() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	GameManager.start_game("gdas_1")
	GameManager.change_state(GameManager.GameState.PLAYING)
	if not _check_startup():
		_check(false, "all stage 1 checks executed")
	if not _check_parallax():
		_check(false, "all stage 1 checks executed")
	if not _check_waves():
		_check(false, "all stage 1 checks executed")
	_check_end_hook()
	if _failures.is_empty():
		print("[task-19] ALL CHECKS PASSED")
		get_tree().quit(0)
	else:
		printerr("[task-19] %d CHECK(S) FAILED" % _failures.size())
		for failure in _failures:
			printerr("  - " + failure)
		get_tree().quit(1)


func _check(ok: bool, label: String) -> void:
	if ok:
		print("  PASS  ", label)
	else:
		printerr("  FAIL  ", label)
		_failures.append(label)


func _check_startup() -> bool:
	var packed: PackedScene = load("res://scenes/main.tscn") as PackedScene
	_check(packed != null, "main scene loads")
	if packed == null:
		return false
	_main = packed.instantiate()
	add_child(_main)
	_stage = _main.get_node_or_null("Stage1") as Stage1
	_check(_stage != null, "main scene starts stage 1")
	if _stage == null:
		return false

	var player := _main.get_node_or_null("PlayerShip") as PlayerShip
	_check(player != null, "GDAS-1 player instance present")
	if player != null:
		_check(player.max_hull == 3 and player.max_front_shield == 3 and player.max_back_shield == 3,
			"GDAS-1 damage stats loaded")
		var weapons: Dictionary = player.get("_weapons")
		_check(weapons.has("laser") and weapons.has("missile") and weapons.has("bomb"),
			"laser, missile and bomb all available")
	for action in ["move_up", "move_down", "move_left", "move_right", "zoom_in", "zoom_out",
			"fire", "fire_missile", "fire_bomb", "select_laser", "select_missile", "select_bomb"]:
		_check(InputMap.has_action(action), "stage control bound: %s" % action)
	return true


func _check_parallax() -> bool:
	var parallax := _stage.get_node_or_null("ParallaxBackground") as ParallaxBackground
	_check(parallax != null, "stage 1 parallax background present")
	if parallax == null:
		return false
	var far := parallax.get_node_or_null("FarLayer") as ParallaxLayer
	var mid := parallax.get_node_or_null("MidLayer") as ParallaxLayer
	var near := parallax.get_node_or_null("NearLayer") as ParallaxLayer
	_check(far != null and mid != null and near != null, "far/mid/near parallax layers present")
	if far == null or mid == null or near == null:
		return false
	_check(far.motion_scale.y < mid.motion_scale.y and mid.motion_scale.y < near.motion_scale.y,
		"parallax layers have distinct depth scales")
	_check(_stage.auto_scroll and _stage.scroll_speed > 0.0, "stage parallax auto-scroll configured")

	var far_before := far.motion_offset.y
	var near_before := near.motion_offset.y
	_stage._process(0.5)
	var far_delta := far.motion_offset.y - far_before
	var near_delta := near.motion_offset.y - near_before
	_check(near_delta > 0.0, "near layer scrolls during play")
	# StageBase advances motion_offset uniformly; ParallaxLayer.motion_scale
	# supplies the depth, so compare the effective (scaled) scroll rates.
	var far_effective := far_delta * far.motion_scale.y
	var near_effective := near_delta * near.motion_scale.y
	_check(far_effective > 0.0 and near_effective > far_effective,
		"near layer scrolls faster than far layer after motion_scale")
	return true


func _on_wave_started(wave_index: int, wave_name: String) -> void:
	_waves.append({"index": wave_index, "name": wave_name})


func _check_waves() -> bool:
	_stage.wave_started.connect(_on_wave_started)
	for _i in range(48):
		_stage._process(0.5)
	_check(_stage.get_wave_count() == 4, "stage 1 wave table has four waves")
	_check(_stage.current_wave == 4, "all four waves started in order")
	_check(_waves.size() == 4, "wave_started emitted for every wave")
	if not _waves.is_empty():
		_check(int(_waves[0]["index"]) == 1 and str(_waves[0]["name"]) == "01_first_contact",
			"first wave signal carries index and name")

	var enemies: Array[Node] = []
	for child in _stage.get_children():
		if child is BaseEnemy:
			enemies.append(child)
	_check(enemies.size() >= 20, "waves spawned escalating enemy groups")
	var scouts := 0
	var interceptors := 0
	for enemy in enemies:
		if enemy is Stage1Scout:
			scouts += 1
		elif enemy is Stage1Interceptor:
			interceptors += 1
	_check(scouts > 0 and interceptors > 0,
		"stage-1 scout and interceptor sheets are used by the waves")
	return not enemies.is_empty()


func _on_stage_completed(stage_id: int) -> void:
	_completed.append(stage_id)


func _check_end_hook() -> void:
	_stage.stage_completed.connect(_on_stage_completed)
	var end_time := _stage.get_end_time()
	_check(end_time > 20.0, "stage has a reachable end time after the final wave")
	_stage._elapsed_time = end_time
	_stage._process(0.016)
	_check(_completed.size() == 1, "end condition emits stage_completed once")
	_stage._process(0.016)
	_check(_completed.size() == 1, "stage_completed is not emitted twice")

	var manager: Node = _main.get_node_or_null("CutsceneManager")
	var cutscene: Node = manager.get_node_or_null("Stage1EndCutscene") if manager != null else null
	_check(cutscene != null, "stage completion instantiates the cutscene hook")
	if cutscene == null:
		return
	var animation := cutscene.get_node_or_null("AnimationPlayer") as AnimationPlayer
	_check(animation != null and animation.has_animation("play"),
		"cutscene is a Control with a playable AnimationPlayer")
	var lines: Array = cutscene.get("story_lines")
	var story := ""
	for line in lines:
		story += str(line) + " "
	_check(story.contains("Alex Mercer"), "cutscene text carries the stage-1 story beat")
	_check(GameManager.current_state == GameManager.GameState.CUTSCENE,
		"cutscene suspends gameplay while it plays")
