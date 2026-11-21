class_name Laser
extends Weapon

## Laser weapon (docs/game_design.md): fast small pieces of light, rapid-fire.
## Higher upgrade levels fire multiple bolts in a tight spread.

func _do_fire(direction: Vector2, origin: Vector2) -> void:
	match current_level:
		1:
			_spawn_projectile(direction, origin)
		2:
			_spawn_projectile(direction, origin + Vector2.LEFT * 4)
			_spawn_projectile(direction, origin + Vector2.RIGHT * 4)
		3:
			_spawn_projectile(direction, origin)
			_spawn_projectile(direction.rotated(0.08), origin + Vector2.LEFT * 4)
			_spawn_projectile(direction.rotated(-0.08), origin + Vector2.RIGHT * 4)
