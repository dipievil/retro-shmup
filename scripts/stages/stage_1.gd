extends StageBase

## Stage 1: Intro - Training Stage
## Jane learns the basics of piloting and combat.
## Simple enemy waves to test movement and firing cadence (greybox).

const EnemyScene := preload("res://scenes/enemies/base_enemy.tscn")
const OFFSCREEN_RIGHT_X := 510.0  # viewport is 480px wide


func _build_spawn_queue() -> void:
	# Wave 1: single enemies crossing from the right (training)
	for i in range(3):
		_queue_spawn(1.0 + i * 2.0, EnemyScene,
			Vector2(OFFSCREEN_RIGHT_X + i * 14.0, 45.0 + i * 65.0), 0.5)

	# Wave 2: staggered formation entering from the right
	for i in range(5):
		_queue_spawn(8.0 + i * 0.5, EnemyScene,
			Vector2(OFFSCREEN_RIGHT_X + i * 12.0, 40.0 + i * 42.0), 0.5)

	# Wave 3: two depth groups crossing from the right
	for i in range(3):
		_queue_spawn(14.0 + i * 1.5, EnemyScene,
			Vector2(OFFSCREEN_RIGHT_X + i * 16.0, 60.0 + i * 55.0), 0.7)
	for i in range(3):
		_queue_spawn(14.0 + i * 1.5, EnemyScene,
			Vector2(OFFSCREEN_RIGHT_X + i * 18.0, 90.0 + i * 45.0), 0.3)
