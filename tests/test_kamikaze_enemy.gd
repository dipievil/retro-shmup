extends Node

## Headless behavioural checks for task-17 (kamikaze dive, bounds, collision).
## Run from the Godot project root:
##   godot --headless --path . res://tests/test_kamikaze_enemy.tscn
## Every assertion prints PASS/FAIL and the suite exits non-zero on any failure.
## It runs as a scene (not --script) so autoloads and class_name registrations
## exist when the enemy/player/explosion scripts compile.

const EXPECTED_ANGLE_DEG: float = 15.0
const TEST_SPEED: float = 100.0
const TEST_DELTA: float = 0.1
const TEST_FRAMES: int = 5
const VIEW_SIZE := Vector2(480.0, 270.0)

var _failures: Array[String] = []
var _destroyed_events: int = 0
var _player_hit_events: int = 0


func _ready() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	print("[task-17] Kamikaze movement")
	_test_movement()
	print("[task-17] Kamikaze spawn/despawn bounds")
	_test_spawn_and_despawn()
	print("[task-17] Kamikaze collision + explosion")
	_test_collision()
	if _failures.is_empty():
		print("[task-17] ALL CHECKS PASSED")
		get_tree().quit(0)
	else:
		printerr("[task-17] %d CHECK(S) FAILED" % _failures.size())
		get_tree().quit(1)


func _check(ok: bool, label: String) -> void:
	if ok:
		print("  PASS  ", label)
	else:
		printerr("  FAIL  ", label)
		_failures.append(label)


func _make_enemy() -> KamikazeEnemy:
	var packed := load("res://scenes/enemies/kamikaze_enemy.tscn") as PackedScene
	if packed == null:
		_check(false, "kamikaze scene loads")
		return null
	var enemy := packed.instantiate() as KamikazeEnemy
	if enemy == null:
		_check(false, "kamikaze scene instantiates a KamikazeEnemy")
		return null
	add_child(enemy)
	# The suite drives physics manually; engine ticks would make deltas impure.
	enemy.set_physics_process(false)
	enemy.viewport_size = VIEW_SIZE
	return enemy


func _test_movement() -> void:
	var enemy := _make_enemy()
	if enemy == null:
		return
	enemy.speed = TEST_SPEED
	var velocity := KamikazeEnemy.dive_velocity(TEST_SPEED)
	_check(velocity.x > 0.0 and velocity.y > 0.0, "dive goes down and to the right")
	_check(
		is_equal_approx(rad_to_deg(atan2(velocity.x, velocity.y)), EXPECTED_ANGLE_DEG),
		"velocity is 15 degrees from vertical"
	)
	_check(is_equal_approx(velocity.length(), TEST_SPEED), "velocity length equals speed")

	var start := Vector2(240.0, 120.0)
	enemy.position = start
	for i in range(TEST_FRAMES):
		enemy._physics_process(TEST_DELTA)
	var moved := enemy.position - start
	_check(is_equal_approx(moved.x, velocity.x * TEST_DELTA * float(TEST_FRAMES)),
		"x delta matches the 15-degree dive over 5 frames")
	_check(is_equal_approx(moved.y, velocity.y * TEST_DELTA * float(TEST_FRAMES)),
		"y delta matches the 15-degree dive over 5 frames")
	_check(is_equal_approx(rad_to_deg(atan2(moved.x, moved.y)), EXPECTED_ANGLE_DEG),
		"accumulated movement vector is 15 degrees from vertical")
	enemy.queue_free()


func _test_spawn_and_despawn() -> void:
	var p0 := KamikazeEnemy.spawn_position(0, VIEW_SIZE)
	var p1 := KamikazeEnemy.spawn_position(1, VIEW_SIZE)
	var p2 := KamikazeEnemy.spawn_position(2, VIEW_SIZE)
	_check(is_equal_approx(p0.y, -KamikazeEnemy.SPAWN_Y_OFFSET), "spawns above the top edge")
	_check(is_equal_approx(p1.y, p0.y) and is_equal_approx(p2.y, p0.y),
		"all slots share the same spawn height")
	for point in [p0, p1, p2]:
		_check(point.x > 0.0 and point.x < VIEW_SIZE.x, "spawn x stays inside the viewport")
	_check(p0.x < p1.x and p1.x < p2.x, "spawn x positions vary between slots")
	var wrapped := KamikazeEnemy.spawn_position(3, VIEW_SIZE)
	_check(is_equal_approx(wrapped.x, p0.x), "spawn slots wrap around")

	var enemy := _make_enemy()
	if enemy == null:
		return
	enemy.position = KamikazeEnemy.spawn_position(1, VIEW_SIZE)
	enemy._physics_process(0.016)
	_check(not enemy.is_queued_for_deletion(), "spawn point is inside despawn bounds")

	enemy.position = Vector2(VIEW_SIZE.x * 0.5, VIEW_SIZE.y + KamikazeEnemy.DESPAWN_MARGIN + 1.0)
	enemy._physics_process(0.016)
	_check(enemy.is_queued_for_deletion(), "despawns past the bottom margin")

	var right := _make_enemy()
	if right == null:
		return
	right.position = Vector2(VIEW_SIZE.x + KamikazeEnemy.DESPAWN_MARGIN + 1.0, 100.0)
	right._physics_process(0.016)
	_check(right.is_queued_for_deletion(), "despawns past the right edge")
	_check(right._velocity.x > 0.0, "does not bounce at screen edges")


func _on_player_destroyed() -> void:
	_destroyed_events += 1


func _on_player_hit(_effect: Node2D) -> void:
	_player_hit_events += 1


func _test_collision() -> void:
	var enemy := _make_enemy()
	if enemy == null:
		return
	var player_scene := load("res://scenes/player/player_ship.tscn") as PackedScene
	if player_scene == null:
		_check(false, "player scene loads")
		return
	var player := player_scene.instantiate() as PlayerShip
	if player == null:
		_check(false, "player scene instantiates a PlayerShip")
		return
	add_child(player)
	player.set_physics_process(false)

	var contact := Vector2(150.0, 120.0)
	enemy.global_position = contact
	player.global_position = contact
	_check(enemy is Area2D, "kamikaze root is an Area2D")
	_check(enemy.collision_layer == 4, "kamikaze is on the enemies collision layer")
	_check((enemy.collision_mask & 1) != 0, "kamikaze masks the player collision layer")
	_check(player.is_in_group("player"), "player is in the player group")

	player.destroyed.connect(_on_player_destroyed)
	enemy.player_hit.connect(_on_player_hit)
	enemy._on_area_entered(player)

	_check(enemy.is_queued_for_deletion(), "kamikaze is destroyed on player contact")
	_check(player.is_queued_for_deletion(), "player is destroyed on kamikaze contact")
	_check(_destroyed_events == 1, "player destroyed signal emitted exactly once")
	_check(_player_hit_events == 1, "player_hit emitted exactly once")
	enemy._on_area_entered(player)
	_check(_player_hit_events == 1, "a second contact does not spawn another explosion")

	var effect := enemy.last_explosion
	_check(effect != null, "explosion effect was spawned")
	if effect == null:
		return
	_check(effect is PlayerExplosion, "effect is the player explosion scene")
	_check(effect.is_in_group("player_explosion"), "effect is tagged for lookup")
	_check(effect.global_position.distance_to(contact) < 1.0,
		"effect spawns at the collision point")
	_check(effect.frame_count == 8, "effect loaded all 8 explosion frames")
	var sprite := effect.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	_check(sprite != null, "effect has an AnimatedSprite2D")
	if sprite != null:
		_check(sprite.sprite_frames != null
			and sprite.sprite_frames.get_frame_count(&"explode") == 8,
			"explosion frames were built from the sheet metadata")
		_check(sprite.is_playing(), "explosion animation is playing")
		_check(sprite.sprite_frames != null
			and not sprite.sprite_frames.get_animation_loop(&"explode"),
			"explosion plays once (does not loop)")
	_check(GameManager.current_state == GameManager.GameState.GAME_OVER,
		"player death switches the game to GAME_OVER")
