class_name Laser
extends Weapon

## Laser weapon (docs/game_design.md): fast small pieces of light, rapid-fire.
## Higher upgrade levels fire multiple bolts in a tight spread.

func _do_fire(direction: Vector2, origin: Vector2) -> void:
	# Spread paired bolts across the firing lane, not along the flight path.
	# For the default rightward shot this offsets on Y instead of stacking on X.
	var lateral := Vector2(-direction.y, direction.x)
	match current_level:
		1:
			_spawn_projectile(direction, origin)
		2:
			_spawn_projectile(direction, origin - lateral * 4)
			_spawn_projectile(direction, origin + lateral * 4)
		3:
			_spawn_projectile(direction, origin)
			_spawn_projectile(direction.rotated(0.08), origin - lateral * 4)
			_spawn_projectile(direction.rotated(-0.08), origin + lateral * 4)
