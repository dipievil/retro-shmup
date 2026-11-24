extends Node

## Regression for task-10: HUD stat rows must be parented exactly once.
## Run from the Godot project root with Godot 4.3+:
##   godot --headless --path . res://tests/test_hud_bars.tscn
##
## Runs as a scene (not --script) so autoloads and class_name registrations
## exist while hud.tscn is instantiated. Exits 0 only when every check passes.

const EXPECTED_LABELS := ["Hull", "Front", "Back"]

var _failures: Array[String] = []


func _ready() -> void:
	# Deferred so the SceneTree and autoloads are fully ready.
	call_deferred("_run_tests")


func _run_tests() -> void:
	print("[task-10] HUD stat bars")
	_test_hud_bars()
	if _failures.is_empty():
		print("[task-10] ALL CHECKS PASSED")
		get_tree().quit(0)
	else:
		printerr("[task-10] %d CHECK(S) FAILED" % _failures.size())
		get_tree().quit(1)


func _check(ok: bool, label: String) -> void:
	if ok:
		print("  PASS  ", label)
	else:
		printerr("  FAIL  ", label)
		_failures.append(label)


func _descendants(node: Node) -> Array[Node]:
	var result: Array[Node] = []
	for child in node.get_children():
		result.append(child)
		result.append_array(_descendants(child))
	return result


func _texts_in(nodes: Array[Node]) -> Dictionary:
	var counts := {}
	for node in nodes:
		if node is Label:
			var text: String = (node as Label).text
			counts[text] = int(counts.get(text, 0)) + 1
	return counts


func _test_hud_bars() -> void:
	var packed: PackedScene = load("res://scenes/ui/hud.tscn")
	_check(packed != null, "HUD scene loads")
	if packed == null:
		return

	var hud: Node = packed.instantiate()
	add_child(hud) # Triggers HUD._ready() -> _build_ui().

	var nodes: Array[Node] = _descendants(hud)
	var bars: Array[ProgressBar] = []
	for node in nodes:
		if node is ProgressBar:
			bars.append(node as ProgressBar)
	_check(bars.size() == 3, "exactly three ProgressBars are in the HUD tree")
	if bars.size() != 3:
		return

	# The original bug called add_child(bar) after the bar was already inside
	# the HBoxContainer: Godot logged "already has a parent" and the label
	# containers never reached the scene tree.
	for bar in bars:
		_check(bar.get_parent() != null, "%s: bar has a parent" % bar.get_index())
		var row: Node = bar.get_parent()
		_check(row is HBoxContainer, "%s: bar parent is the label row" % bar.get_index())
		if row != null:
			_check(row.get_parent() is VBoxContainer, "%s: row is in stats_vbox" % bar.get_index())

	var counts := _texts_in(nodes)
	for text in EXPECTED_LABELS:
		_check(int(counts.get(text, 0)) == 1, "label '%s' appears once in the HUD tree" % text)

	# The named fields must refer to the very bars that are in the tree,
	# so value updates and _init_bar_values() keep working.
	var refs := {
		"Hull": hud.get("_hull_bar"),
		"Front": hud.get("_front_shield_bar"),
		"Back": hud.get("_back_shield_bar"),
	}
	for text in EXPECTED_LABELS:
		var bar: ProgressBar = refs.get(text) as ProgressBar
		_check(bar != null, "%s: named bar reference is set" % text)
		if bar == null:
			continue
		_check(bar in bars, "%s: named bar reference is the node in the tree" % text)
		_check(bar.get_parent() is HBoxContainer, "%s: named bar is inside its label row" % text)
		_check(is_equal_approx(bar.max_value, 3.0) and is_equal_approx(bar.value, 3.0),
				"%s: bar initialized from ship data" % text)
