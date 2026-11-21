class_name Missile
extends Weapon

## Missile weapon (docs/game_design.md): slow rate of fire, missile-shaped and
## homing projectiles that steer toward the nearest enemy.

@export var homing_radius: float = 280.0
@export var turn_rate: float = 4.5  # radians per second

func _do_fire(direction: Vector2, origin: Vector2) -> void:
	match current_level:
		1:
			_spawn_projectile(direction, origin)
		2:
			_spawn_projectile(direction, origin + Vector2.LEFT * 6)
			_spawn_projectile(direction, origin + Vector2.RIGHT * 6)
		3:
			_spawn_projectile(direction, origin)
			_spawn_projectile(direction, origin + Vector2.LEFT * 10)
			_spawn_projectile(direction, origin + Vector2.RIGHT * 10)


func _configure_projectile(proj: Projectile) -> void:
	if proj is MissileProjectile:
		proj.homing_radius = homing_radius
		proj.turn_rate = turn_rate
