extends Node

## Headless checks for task-4 (player movement / zoom / action layers).
## Run from the Godot project root with Godot 4.3+:
##   godot --headless --path . res://tests/test_player_ship.tscn
## Exits with status 0 when every check passes, 1 otherwise.
##
## This runs as a scene (not with --script) so the project autoloads and global
## class_name registrations exist when the player controller is compiled.

const MOVE_ACTIONS = ["move_up", "move_down", "move_left", "move_right"]
const EXPECTED_WASD := {"move_up": 87, "move_down": 83, "move_left": 65, "move_right": 68}
const EXPECTED_ARROWS := {
	"move_up": 4194320,
	"move_down": 4194322,
	"move_left": 4194319,
	"move_right": 4194321,
}
const EXPECTED_DPAD := {"move_up": 11, "move_down": 12, "move_left": 13, "move_right": 14}
const EXPECTED_AXIS := {
	"move_up": [1, -1.0],
	"move_down": [1, 1.0],
	"move_left": [0, -1.0],
	"move_right": [0, 1.0],
}

var _failures: Array[String] = []
var _ship: PlayerShip
var _layer_events: Array[Dictionary] = []


func _ready() -> void:
	# Deferred so the SceneTree and autoloads are fully ready.
	call_deferred("_run_tests")


func _run_tests() -> void:
	print("[task-4] Input Map")
	_test_input_map()
	print("[task-4] PlayerShip")
	if not _test_player_ship():
		# A runtime error can abort the checks without appending a failure.
		_check(false, "all player ship checks executed")
	if _failures.is_empty():
		print("[task-4] ALL CHECKS PASSED")
		get_tree().quit(0)
	else:
		printerr("[task-4] %d CHECK(S) FAILED" % _failures.size())
		get_tree().quit(1)


func _check(ok: bool, label: String) -> void:
	if ok:
		print("  PASS  ", label)
	else:
		printerr("  FAIL  ", label)
		_failures.append(label)


func _test_input_map() -> void:
	for action in MOVE_ACTIONS:
		_check(InputMap.has_action(action), "action exists: %s" % action)

	for action in MOVE_ACTIONS:
		if not InputMap.has_action(action):
			continue
		var events := InputMap.action_get_events(action)
		var has_wasd := false
		var has_arrow := false
		var has_dpad := false
		var has_axis := false
		var axis: Array = EXPECTED_AXIS[action]
		for event in events:
			if event is InputEventKey:
				if event.physical_keycode == EXPECTED_WASD[action]:
					has_wasd = true
				if (event.physical_keycode == EXPECTED_ARROWS[action]
						or event.keycode == EXPECTED_ARROWS[action]):
					has_arrow = true
			elif event is InputEventJoypadButton:
				if event.button_index == EXPECTED_DPAD[action]:
					has_dpad = true
			elif event is InputEventJoypadMotion:
				if event.axis == axis[0] and is_equal_approx(event.axis_value, axis[1]):
					has_axis = true
		_check(has_wasd, "%s: WASD key bound" % action)
		_check(has_arrow, "%s: arrow key bound" % action)
		_check(has_dpad, "%s: gamepad D-pad bound" % action)
		_check(has_axis, "%s: gamepad left stick bound" % action)

	_check(InputMap.has_action("zoom_in"), "action exists: zoom_in")
	_check(InputMap.has_action("zoom_out"), "action exists: zoom_out")
	if InputMap.has_action("zoom_in"):
		_check(_has_pad_button("zoom_in", JOY_BUTTON_RIGHT_SHOULDER), "zoom_in: R1 bound")
	if InputMap.has_action("zoom_out"):
		_check(_has_pad_button("zoom_out", JOY_BUTTON_LEFT_SHOULDER), "zoom_out: L1 bound")


func _has_pad_button(action: String, button: int) -> bool:
	for event in InputMap.action_get_events(action):
		if event is InputEventJoypadButton and event.button_index == button:
			return true
	return false


func _advance_depth() -> void:
	# zoom_speed * 1.0 always exceeds the remaining distance in these checks.
	_ship._handle_depth(1.0)


func _on_layer_changed(new_layer: int) -> void:
	_layer_events.append({"layer": new_layer, "depth": _ship.get_depth()})


func _test_player_ship() -> bool:
	var packed: PackedScene = load("res://scenes/player/player_ship.tscn")
	_check(packed != null, "player scene loads")
	if packed == null:
		return false

	# Do not assume the controller compiled: an untyped intermediate lets the
	# guard report a failed check instead of aborting on a bad downcast.
	var instance: Node = packed.instantiate()
	var script: Script = instance.get_script()
	var script_ok := script != null and script.can_instantiate()
	_check(script_ok, "player script compiled")
	if not script_ok:
		return false
	if not instance is PlayerShip:
		_check(false, "player instance is a PlayerShip")
		return false

	var ship: PlayerShip = instance as PlayerShip
	_ship = ship
	add_child(ship)
	ship.layer_changed.connect(_on_layer_changed)

	# GDAS-1 damage control per docs/game_design.md.
	_check(ship.max_hull == 3 and ship.current_hull == 3, "GDAS-1 hull = 3")
	_check(ship.max_front_shield == 3 and ship.current_front_shield == 3, "GDAS-1 front shield = 3")
	_check(ship.max_back_shield == 3 and ship.current_back_shield == 3, "GDAS-1 back shield = 3")

	# Four-direction movement through the configured input actions.
	for action in MOVE_ACTIONS:
		ship.position = Vector2(240, 135)
		Input.action_press(action)
		ship._handle_movement(0.1)
		Input.action_release(action)
		var moved: Vector2 = ship.position - Vector2(240, 135)
		var ok := false
		match action:
			"move_right":
				ok = moved.x > 0.0
			"move_left":
				ok = moved.x < 0.0
			"move_up":
				ok = moved.y < 0.0
			"move_down":
				ok = moved.y > 0.0
		_check(ok, "%s moves the ship" % action)

	# Zoom depth is clamped at both bounds.
	for i in range(20):
		ship.change_depth(ship.depth_step)
	_check(is_equal_approx(ship.get_target_depth(), ship.max_depth), "zoom_in clamps at max_depth")
	for i in range(20):
		ship.change_depth(-ship.depth_step)
	_check(is_equal_approx(ship.get_target_depth(), ship.min_depth), "zoom_out clamps at min_depth")

	# Discrete action layers follow the interpolated depth, not the target.
	ship.set_action_layer(PlayerShip.ActionLayer.FRONT)
	_check(is_equal_approx(ship.get_target_depth(), 1.0), "FRONT layer targets depth 1.0")
	_advance_depth()
	_check(ship.get_action_layer() == PlayerShip.ActionLayer.FRONT, "switch to FRONT layer")

	ship.set_action_layer(PlayerShip.ActionLayer.BACK)
	_check(is_equal_approx(ship.get_target_depth(), 0.0), "BACK layer targets depth 0.0")
	_advance_depth()
	_check(ship.get_action_layer() == PlayerShip.ActionLayer.BACK, "switch to BACK layer")

	ship.change_depth(ship.depth_step * 2.0)
	_advance_depth()
	_check(ship.get_action_layer() == PlayerShip.ActionLayer.MIDDLE, "zoom into MIDDLE layer")

	# set_action_layer() must respect a restricted [min_depth, max_depth] range.
	ship.max_depth = 0.8
	ship.set_action_layer(PlayerShip.ActionLayer.FRONT)
	_check(is_equal_approx(ship.get_target_depth(), 0.8), "set_action_layer clamps to max_depth")
	ship.max_depth = 1.0
	ship.set_action_layer(PlayerShip.ActionLayer.MIDDLE)
	_advance_depth()

	# layer_changed reports the ship's actual layer once depth crosses it.
	_layer_events.clear()
	ship.change_depth(ship.depth_step)
	_check(_layer_events.is_empty(), "layer_changed not emitted while depth stays in MIDDLE")
	_advance_depth()
	_check(_layer_events.size() == 1, "layer_changed emitted once on threshold crossing")
	if _layer_events.size() == 1:
		var event: Dictionary = _layer_events[0]
		_check(int(event["layer"]) == PlayerShip.ActionLayer.FRONT, "layer_changed reports FRONT")
		_check(is_equal_approx(float(event["depth"]), 0.75), "layer_changed depth matches layer")

	# Shields absorb damage before the hull.
	ship._is_invincible = false
	ship.take_damage(1, true)
	_check(ship.current_front_shield == 2 and ship.current_hull == 3, "front hit drains front shield")
	ship._is_invincible = false
	ship.take_damage(1, false)
	_check(ship.current_back_shield == 2 and ship.current_hull == 3, "back hit drains back shield")
	ship.current_front_shield = 0
	ship._is_invincible = false
	ship.take_damage(1, true)
	_check(ship.current_hull == 2, "hull takes damage after front shield is down")

	return true
