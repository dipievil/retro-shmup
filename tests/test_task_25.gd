extends Node

## Headless checks for card [0.9]: laser, missile and bomb shots fire right.
## Run by tools/run_all.sh through tests/test_task_25.tscn so autoloads and
## global class_name registrations are available.

const PLAYER_SCENE := "res://scenes/player/player_ship.tscn"
const BASE_PROJECTILE_SCENE := "res://scenes/weapons/projectile.tscn"
const SHIP_POSITION := Vector2(120.0, 135.0)
const MUZZLE_X := SHIP_POSITION.x + 20.0
const LAUNCH_DEPTH := 0.75

var _failures: Array[String] = []


func _ready() -> void:
	call_deferred("_run_tests")


func _check(ok: bool, label: String) -> void:
	if ok:
		print("  PASS  ", label)
	else:
		printerr("  FAIL  ", label)
		_failures.append(label)


func _run_tests() -> void:
	print("[task-25] Projectile defaults")
	_test_defaults()
	print("[task-25] Fired projectiles")
	_test_fired_projectiles()
	if _failures.is_empty():
		print("[task-25] ALL CHECKS PASSED")
		get_tree().quit(0)
	else:
		printerr("[task-25] %d CHECK(S) FAILED" % _failures.size())
		get_tree().quit(1)


func _test_defaults() -> void:
	var packed := load(BASE_PROJECTILE_SCENE) as PackedScene
	_check(packed != null, "base projectile scene loads")
	if packed == null:
		return
	var projectile := packed.instantiate() as Projectile
	_check(projectile != null and projectile.direction == Vector2.RIGHT,
		"projectile defaults to Vector2.RIGHT")
	projectile.free()


func _test_fired_projectiles() -> void:
	var packed := load(PLAYER_SCENE) as PackedScene
	_check(packed != null, "player scene loads")
	if packed == null:
		return
	var ship := packed.instantiate() as PlayerShip
	_check(ship != null, "player scene instantiates")
	if ship == null:
		return
	add_child(ship)
	ship.position = SHIP_POSITION
	ship.depth = LAUNCH_DEPTH

	var muzzle := ship.get_node_or_null("MuzzleMarker") as Marker2D
	_check(muzzle != null and is_equal_approx(muzzle.position.x, 20.0)
		and is_equal_approx(muzzle.position.y, 0.0),
		"muzzle marker is at the ship's right-hand nose")

	ship._fire_weapon("laser")
	ship._fire_weapon("missile")
	ship._fire_weapon("bomb")

	var all_shots := _collect_projectiles()
	for kind in ["laser", "missile", "bomb"]:
		_check_shots(_shots_of_kind(all_shots, kind), kind)

	for shot in all_shots:
		if is_instance_valid(shot):
			shot.free()
	ship.free()


func _check_shots(shots: Array[Projectile], kind: String) -> void:
	_check(not shots.is_empty(), "%s fired at least one projectile" % kind)
	if shots.is_empty():
		return
	if kind == "bomb":
		_check(shots.size() == 5, "bomb volley still has five blasts")

	var directions_right := true
	var visuals_unrotated := true
	var launched_from_nose := true
	var depth_preserved := true
	for shot in shots:
		if not (shot.direction.x > 0.0 and is_equal_approx(shot.direction.y, 0.0)):
			directions_right = false
		var visual := shot.get_node_or_null("Visual") as Sprite2D
		if visual == null or absf(visual.rotation) > 0.0001 or absf(shot.rotation) > 0.0001:
			visuals_unrotated = false
		if not is_equal_approx(shot.global_position.x, MUZZLE_X):
			launched_from_nose = false
		if not is_equal_approx(shot.depth, LAUNCH_DEPTH):
			depth_preserved = false

	_check(directions_right, "%s direction is +X with no Y component" % kind)
	_check(visuals_unrotated, "%s visual is not rotated -PI/2 while travelling right" % kind)
	_check(launched_from_nose, "%s launches from the right-hand muzzle" % kind)
	_check(depth_preserved, "%s keeps the ship's depth layer" % kind)

	var first := shots[0]
	var before := first.global_position
	first._physics_process(0.1)
	var moved := first.global_position - before
	_check(moved.x > 0.0 and is_equal_approx(moved.y, 0.0),
		"%s actually travels right" % kind)


func _shots_of_kind(shots: Array[Projectile], kind: String) -> Array[Projectile]:
	var matches: Array[Projectile] = []
	for shot in shots:
		if shot.weapon_kind == kind:
			matches.append(shot)
	return matches


func _collect_projectiles() -> Array[Projectile]:
	var found: Array[Projectile] = []
	_collect_from(get_tree().root, found)
	return found


func _collect_from(node: Node, found: Array[Projectile]) -> void:
	for child in node.get_children():
		if child is Projectile:
			found.append(child)
		_collect_from(child, found)
