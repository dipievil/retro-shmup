extends Node

## Headless checks for task-20 (damage control model):
##   godot --headless --path . res://tests/test_damage_control.tscn
## Exits 0 when every assertion passes, 1 otherwise. Every mismatch is printed
## twice (inline FAIL plus a final FAILED summary) so a regression is loud.

var _failures: Array[String] = []
var _shield_events: Array = []
var _hull_events: Array = []
var _destroyed_count: int = 0
var _ship_destroyed_count: int = 0


func _ready() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	print("[task-20] DamageControl model")
	_test_model()
	print("[task-20] PlayerShip integration")
	_test_player_ship()
	if _failures.is_empty():
		print("[task-20] ALL CHECKS PASSED")
		get_tree().quit(0)
	else:
		printerr("[task-20] %d CHECK(S) FAILED" % _failures.size())
		for failure in _failures:
			printerr("  FAILED: ", failure)
		get_tree().quit(1)


func _expect_eq(actual, expected, label: String) -> void:
	if actual == expected:
		print("  PASS  ", label)
		return
	var message := "%s (expected %s, got %s)" % [label, str(expected), str(actual)]
	printerr("  FAIL  ", message)
	_failures.append(message)


func _on_shield_changed(side: String, value: int) -> void:
	_shield_events.append([side, value])


func _on_hull_changed(value: int) -> void:
	_hull_events.append(value)


func _on_ship_destroyed() -> void:
	_destroyed_count += 1


func _on_ship_destroyed_integration() -> void:
	_ship_destroyed_count += 1


func _test_model() -> void:
	var model := DamageControl.new()
	_expect_eq(model.current_hull, 3, "initial hull = 3")
	_expect_eq(model.current_front_shield, 3, "initial front shield = 3")
	_expect_eq(model.current_back_shield, 3, "initial back shield = 3")
	model.shield_changed.connect(_on_shield_changed)
	model.hull_changed.connect(_on_hull_changed)
	model.ship_destroyed.connect(_on_ship_destroyed)

	# A front hit drains only the front shield.
	model.apply_damage(1, "front")
	_expect_eq(model.current_front_shield, 2, "front hit drains front shield")
	_expect_eq(model.current_back_shield, 3, "front hit leaves back shield intact")
	_expect_eq(model.current_hull, 3, "front hit leaves hull intact")
	_expect_eq(_shield_events.size(), 1, "front hit emits one shield_changed")
	if _shield_events.size() == 1:
		_expect_eq(_shield_events[0][0], "front", "shield_changed side = front")
		_expect_eq(_shield_events[0][1], 2, "shield_changed value = 2")
	_expect_eq(_hull_events.size(), 0, "front hit emits no hull_changed")

	# A back hit drains only the back shield.
	_shield_events.clear()
	model.apply_damage(1, "back")
	_expect_eq(model.current_back_shield, 2, "back hit drains back shield")
	_expect_eq(model.current_front_shield, 2, "back hit leaves front shield intact")
	_expect_eq(model.current_hull, 3, "back hit leaves hull intact")
	_expect_eq(_shield_events.size(), 1, "back hit emits one shield_changed")
	if _shield_events.size() == 1:
		_expect_eq(_shield_events[0][0], "back", "shield_changed side = back")
		_expect_eq(_shield_events[0][1], 2, "shield_changed value = 2")

	# An empty front shield must not redirect a back hit, and vice versa.
	model.apply_damage(2, "front")
	_expect_eq(model.current_front_shield, 0, "front shield reaches 0")
	_expect_eq(model.current_back_shield, 2, "back shield untouched by front hit")
	_expect_eq(model.current_hull, 3, "front shield absorbs exactly its remaining value")
	model.apply_damage(1, "back")
	_expect_eq(model.current_back_shield, 1, "back hit still drains back shield")
	_expect_eq(model.current_hull, 3, "empty front shield does not steal back hit")

	# Overflow after the relevant shield is empty reaches the hull only.
	_hull_events.clear()
	model.apply_damage(1, "front")
	_expect_eq(model.current_hull, 2, "overflow reaches hull after front shield is empty")
	_expect_eq(model.current_back_shield, 1, "hull damage does not touch back shield")
	_expect_eq(_hull_events.size(), 1, "overflow emits hull_changed")
	if _hull_events.size() == 1:
		_expect_eq(_hull_events[0], 2, "hull_changed value = 2")

	# A single large front hit drains the front shield then overflows to hull.
	var big := DamageControl.new()
	big.apply_damage(5, DamageControl.Direction.FRONT)
	_expect_eq(big.current_front_shield, 0, "large front hit empties front shield")
	_expect_eq(big.current_hull, 1, "large front hit overflows 2 points to hull")
	_expect_eq(big.current_back_shield, 3, "large front hit leaves back shield intact")

	# Hull reaching 0 emits ship_destroyed exactly once; further hits are inert.
	_destroyed_count = 0
	model.apply_damage(5, "back")
	_expect_eq(model.current_hull, 0, "hull reaches 0")
	_expect_eq(model.current_back_shield, 0, "back shield empties before hull damage")
	_expect_eq(_destroyed_count, 1, "ship_destroyed emitted exactly once")
	_expect_eq(model.is_destroyed(), true, "model reports destroyed")
	model.apply_damage(3, "front")
	_expect_eq(model.current_hull, 0, "hull stays 0 after destruction")
	_expect_eq(_destroyed_count, 1, "ship_destroyed not re-emitted after destruction")

	# Direction aliases (bool, enum, Vector2 travel direction) stay consistent.
	var aliases := DamageControl.new()
	aliases.apply_damage(1, true)
	aliases.apply_damage(1, DamageControl.Direction.BACK)
	aliases.apply_damage(1, Vector2.DOWN)
	_expect_eq(aliases.current_front_shield, 1, "bool true and Vector2.DOWN are front hits")
	_expect_eq(aliases.current_back_shield, 2, "Direction.BACK is a back hit")

	model.free()
	big.free()
	aliases.free()


func _test_player_ship() -> void:
	var packed: PackedScene = load("res://scenes/player/player_ship.tscn")
	_expect_eq(packed != null, true, "player scene loads")
	if packed == null:
		return

	var instance: Node = packed.instantiate()
	var ship := instance as PlayerShip
	_expect_eq(ship != null, true, "player instance is a PlayerShip")
	if ship == null:
		return
	add_child(ship)
	ship.ship_destroyed.connect(_on_ship_destroyed_integration)

	_expect_eq(ship.damage_control != null, true, "ship owns a DamageControl model")
	_expect_eq(ship.current_hull, 3, "ship initial hull = 3")
	_expect_eq(ship.current_front_shield, 3, "ship initial front shield = 3")
	_expect_eq(ship.current_back_shield, 3, "ship initial back shield = 3")

	ship.apply_damage(2, "front")
	_expect_eq(ship.current_front_shield, 1, "apply_damage drains front shield")
	_expect_eq(ship.current_back_shield, 3, "apply_damage leaves back shield intact")
	_expect_eq(ship.current_hull, 3, "apply_damage leaves hull intact")

	ship.apply_damage(2, "front")
	_expect_eq(ship.current_front_shield, 0, "apply_damage empties front shield")
	_expect_eq(ship.current_hull, 2, "apply_damage overflows to hull")

	# The collision-facing wrapper still works and still overflows.
	ship._is_invincible = false
	ship.take_damage(1, false)
	_expect_eq(ship.current_back_shield, 2, "take_damage drains back shield")
	_expect_eq(ship.current_hull, 2, "take_damage leaves hull intact while shield holds")

	ship.apply_damage(3, "back")
	_expect_eq(ship.current_back_shield, 0, "back shield empties before hull damage")
	_expect_eq(ship.current_hull, 1, "back hit overflows to hull")

	ship.apply_damage(2, "front")
	_expect_eq(ship.current_hull, 0, "ship destroyed when hull reaches 0")
	_expect_eq(_ship_destroyed_count, 1, "ship_destroyed emitted once by PlayerShip")
	ship.free()
