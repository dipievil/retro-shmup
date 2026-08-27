class_name Laser
extends Weapon

## Laser weapon: fast small pieces of light with rapid-fire.
## Higher levels fire multiple projectiles in a spread pattern.

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


func _spawn_projectile(dir: Vector2, origin: Vector2) -> void:
	var proj: Projectile = projectile_scene.instantiate()
	proj.direction = dir
	proj.damage = damage
	proj.speed = projectile_speed
	proj.lifetime = projectile_lifetime
	proj.is_player_projectile = true
	proj.global_position = origin
	_owner_node.get_tree().current_scene.add_child(proj)
