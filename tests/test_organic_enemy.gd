extends Node

## Headless checks for task-9 (organic enemy: movement, beam, one-hit death,
## mutual explosion). Run as a scene so autoloads and global class names exist:
##   godot --headless --path . res://tests/test_organic_enemy.tscn
## Exits 0 when every check passes, 1 otherwise.

const EnemyScene := preload("res://scenes/enemies/organic_enemy.tscn")
const PlayerScene := preload("res://scenes/player/player_ship.tscn")
const EffectScript := preload("res://scripts/effects/explosion_effect.gd")

var _failures: Array[String] = []
var _beam_events: int = 0
var _died_events: int = 0
var _destroyed_events: int = 0


func _ready() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	print("[task-9] Organic enemy")
	_test_movement()
	_test_beam()
	_test_one_hit_death()
	_test_player_collision()
	if _failures.is_empty():
		print("[task-9] ALL CHECKS PASSED")
		get_tree().quit(0)
	else:
		printerr("[task-9] %d CHECK(S) FAILED" % _failures.size())
		get_tree().quit(1)


func _check(ok: bool, label: String) -> void:
	if ok:
		print("  PASS  ", label)
	else:
		printerr("  FAIL  ", label)
		_failures.append(label)


func _holder() -> Node2D:
	var node := Node2D.new()
	add_child(node)
	return node


func _spawn_enemy(parent: Node2D) -> OrganicEnemy:
	var enemy := EnemyScene.instantiate() as OrganicEnemy
	parent.add_child(enemy)
	enemy.position = Vector2(300, 120)
	return enemy


func _count_beams(node: Node) -> int:
	var count := 0
	for child in node.get_children():
		if child.is_in_group("enemy_projectile"):
			count += 1
	return count


func _count_effects(node: Node) -> int:
	var count := 0
	for child in node.get_children():
		if child.get_script() == EffectScript:
			count += 1
	return count


func _on_beam_spawned(_beam: Projectile) -> void:
	_beam_events += 1


func _on_enemy_died(_score: int) -> void:
	_died_events += 1


func _on_player_destroyed() -> void:
	_destroyed_events += 1


func _test_movement() -> void:
	var parent := _holder()
	var enemy := _spawn_enemy(parent)
	enemy._ai_update(0.1)
	_check(enemy._velocity.x < 0.0, "AI velocity is right-to-left (x < 0)")
	_check(is_equal_approx(enemy._velocity.y, 0.0), "AI velocity has no vertical component")

	var before := enemy.position
	enemy._physics_process(0.1)
	_check(enemy.position.x < before.x, "physics step moves the enemy left")
	_check(is_equal_approx(enemy.position.y, before.y), "physics step keeps the same y")

	# BaseEnemy bounces at x > 500; the organic enemy must keep flying left.
	enemy.position = Vector2(510, 120)
	enemy._physics_process(0.1)
	_check(enemy._velocity.x < 0.0, "spawn at x=510 does not bounce back to the right")


func _test_beam() -> void:
	var parent := _holder()
	var enemy := _spawn_enemy(parent)
	enemy.beam_spawned.connect(_on_beam_spawned)

	var first := enemy.fire()
	_check(first != null, "fire() returns a projectile")
	_check(_beam_events == 1 and _count_beams(parent) == 1, "one firing event spawns exactly one beam")
	var second := enemy.fire()
	_check(_beam_events == 2 and _count_beams(parent) == 2, "a second event spawns exactly one more beam")
	if first == null:
		return
	_check(first.direction == Vector2.LEFT, "beam travels left")
	_check(not first.is_player_projectile, "beam is an enemy projectile")
	_check(first.lifetime <= 1.0, "beam is short-lived")
	_check(first.modulate.g > first.modulate.r and first.modulate.g > first.modulate.b, "beam is green-tinted")
	var unused := second
	_check(unused != null, "second beam is a valid projectile")


func _test_one_hit_death() -> void:
	var parent := _holder()
	var enemy := _spawn_enemy(parent)
	enemy.died.connect(_on_enemy_died)
	_check(enemy.current_health == 1, "organic enemy has exactly one HP")
	enemy.take_damage(1)
	_check(_died_events == 1, "one player hit emits died once")
	_check(enemy.is_queued_for_deletion(), "one player hit queues the enemy for deletion")
	_check(_count_effects(parent) == 1, "enemy death spawns one explosion effect")


func _test_player_collision() -> void:
	var parent := _holder()
	var enemy := _spawn_enemy(parent)
	var player := PlayerScene.instantiate() as PlayerShip
	parent.add_child(player)
	player.position = Vector2(300, 120)
	player.destroyed.connect(_on_player_destroyed)
	var effects_before := _count_effects(parent)

	enemy._on_area_entered(player)
	_check(_destroyed_events == 1, "player/enemy collision triggers player destroyed signal")
	_check(player.is_queued_for_deletion(), "player is destroyed on enemy collision")
	_check(enemy.is_queued_for_deletion(), "enemy is destroyed on player collision")
	_check(_count_effects(parent) == effects_before + 2, "collision spawns an explosion for both ships")
