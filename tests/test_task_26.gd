extends Node

## Headless checks for task-26: demo enemies enter from the right, move left,
## and damage is assigned to the right-facing front shield / left-facing back
## shield. Run by tools/run_all.sh through the companion .tscn so autoloads and
## global class_name registrations are available.

const ENEMY_SCENE := "res://scenes/enemies/base_enemy.tscn"
const PLAYER_SCENE := "res://scenes/player/player_ship.tscn"
const STAGE_SCENE := "res://scenes/stages/stage_1.tscn"

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
	# Keep the stage's _process from spawning/advancing parallax behind the
	# synchronous checks.
	GameManager.current_state = GameManager.GameState.MENU
	print("[task-26] Enemy movement")
	_test_enemy_movement()
	print("[task-26] Stage spawn queue and parallax")
	_test_stage()
	print("[task-26] Shield hit direction")
	_test_shield_direction()

	if _failures.is_empty():
		print("[task-26] ALL CHECKS PASSED")
		get_tree().quit(0)
	else:
		printerr("[task-26] %d CHECK(S) FAILED" % _failures.size())
		get_tree().quit(1)


func _test_enemy_movement() -> void:
	var packed := load(ENEMY_SCENE) as PackedScene
	_check(packed != null, "enemy scene loads")
	if packed == null:
		return
	var enemy := packed.instantiate() as BaseEnemy
	add_child(enemy)

	enemy.position = Vector2(500.0, 120.0)
	enemy._physics_process(0.1)
	_check(enemy.position.x < 500.0 and is_equal_approx(enemy.position.y, 120.0),
		"default AI moves left without changing altitude")
	_check(enemy._velocity.x < 0.0, "default velocity points left")

	enemy.position = Vector2(510.0, 120.0)
	enemy._physics_process(0.1)
	_check(not enemy.is_queued_for_deletion() and enemy.position.x < 510.0,
		"offscreen right spawn survives and keeps moving left")

	enemy.position = Vector2(-45.0, 120.0)
	enemy._physics_process(0.1)
	_check(enemy.is_queued_for_deletion(), "enemy despawns past the left edge")


func _test_stage() -> void:
	var packed := load(STAGE_SCENE) as PackedScene
	_check(packed != null, "stage 1 scene loads")
	if packed == null:
		return
	var stage := packed.instantiate() as StageBase
	add_child(stage)

	var queue: Array[Dictionary] = stage._spawn_queue
	_check(queue.size() == 14, "stage 1 keeps its 14 enemies")
	var all_from_right := true
	for entry in queue:
		var pos: Vector2 = entry["pos"]
		if pos.x <= 480.0:
			all_from_right = false
	_check(all_from_right, "every spawn is off the right edge (x > 480)")

	var parallax := stage.get_node_or_null("ParallaxBackground") as ParallaxBackground
	_check(parallax != null, "stage has a ParallaxBackground")
	if parallax == null:
		return
	var offsets_before: Array[float] = []
	for child in parallax.get_children():
		if child is ParallaxLayer:
			offsets_before.append((child as ParallaxLayer).motion_offset.y)
	stage._update_parallax(0.1)
	var scrolls_left := true
	var no_vertical_scroll := true
	var i := 0
	for child in parallax.get_children():
		if child is ParallaxLayer:
			var layer := child as ParallaxLayer
			if not is_equal_approx(layer.motion_offset.x, -stage.scroll_speed * 0.1):
				scrolls_left = false
			if not is_equal_approx(layer.motion_offset.y, offsets_before[i]):
				no_vertical_scroll = false
			i += 1
	_check(i > 0 and scrolls_left, "parallax layers scroll right-to-left")
	_check(no_vertical_scroll, "parallax no longer scrolls vertically")


func _reset_shield_state(ship: PlayerShip) -> void:
	ship.current_front_shield = ship.max_front_shield
	ship.current_back_shield = ship.max_back_shield
	ship.current_hull = ship.max_hull
	ship._is_invincible = false


func _make_enemy_projectile(direction: Vector2) -> Projectile:
	var proj := Projectile.new()
	proj.is_player_projectile = false
	proj.direction = direction
	proj.damage = 1
	add_child(proj)
	return proj


func _test_shield_direction() -> void:
	var packed := load(PLAYER_SCENE) as PackedScene
	_check(packed != null, "player scene loads")
	if packed == null:
		return
	var ship := packed.instantiate() as PlayerShip
	add_child(ship)
	ship.position = Vector2(240.0, 135.0)

	_reset_shield_state(ship)
	var from_right := _make_enemy_projectile(Vector2.LEFT)
	ship._on_area_entered(from_right)
	_check(ship.current_front_shield == ship.max_front_shield - 1
		and ship.current_back_shield == ship.max_back_shield,
		"left-travelling projectile hits the front shield")

	_reset_shield_state(ship)
	var from_left := _make_enemy_projectile(Vector2.RIGHT)
	ship._on_area_entered(from_left)
	_check(ship.current_back_shield == ship.max_back_shield - 1
		and ship.current_front_shield == ship.max_front_shield,
		"right-travelling projectile hits the back shield")

	var enemy_packed := load(ENEMY_SCENE) as PackedScene
	if enemy_packed == null:
		return
	var enemy := enemy_packed.instantiate() as BaseEnemy
	add_child(enemy)

	_reset_shield_state(ship)
	enemy.global_position = ship.global_position + Vector2(24.0, 0.0)
	enemy._on_area_entered(ship)
	_check(ship.current_front_shield == ship.max_front_shield - 1,
		"enemy contact from the right hits the front shield")

	_reset_shield_state(ship)
	enemy.global_position = ship.global_position + Vector2(-24.0, 0.0)
	enemy._on_area_entered(ship)
	_check(ship.current_back_shield == ship.max_back_shield - 1,
		"enemy contact from the left hits the back shield")
