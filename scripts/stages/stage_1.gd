extends StageBase

## Stage 1: Intro - Training Stage
## Jane learns the basics of piloting and combat.
## Simple enemy waves to test movement and firing cadence (greybox).

const EnemyScene := preload("res://scenes/enemies/base_enemy.tscn")


func _build_spawn_queue() -> void:
	# Wave 1: single enemies descending (training)
	for i in range(3):
		_queue_spawn(1.0 + i * 2.0, EnemyScene, Vector2(120 + i * 120, -30), 0.5)

	# Wave 2: staggered formation
	for i in range(5):
		_queue_spawn(8.0 + i * 0.5, EnemyScene, Vector2(60 + i * 90, -30), 0.5)

	# Wave 3: from sides
	for i in range(3):
		_queue_spawn(14.0 + i * 1.5, EnemyScene, Vector2(-30, 60 + i * 50), 0.7)
	for i in range(3):
		_queue_spawn(14.0 + i * 1.5, EnemyScene, Vector2(510, 60 + i * 50), 0.3)
