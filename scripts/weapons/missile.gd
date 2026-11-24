class_name Missile
extends Weapon

## Missile weapon (docs/game_design.md): slow rate of fire, missile-shaped and
## homing projectiles that steer toward the nearest enemy.

@export var homing_radius: float = 280.0
@export var turn_rate: float = 4.5  # radians per second

func _do_fire(direction: Vector2, origin: Vector2) -> void:
	# Paired missiles spread perpendicular to travel so both occupy the same
	# firing lane instead of one trailing behind the other.
	var lateral := Vector2(-direction.y, direction.x)
	match current_level:
		1:
			_spawn_projectile(direction, origin)
		2:
			_spawn_projectile(direction, origin - lateral * 6)
			_spawn_projectile(direction, origin + lateral * 6)
		3:
			_spawn_projectile(direction, origin)
			_spawn_projectile(direction, origin - lateral * 10)
			_spawn_projectile(direction, origin + lateral * 10)


func _configure_projectile(proj: Projectile) -> void:
	if proj is MissileProjectile:
		proj.homing_radius = homing_radius
		proj.turn_rate = turn_rate
