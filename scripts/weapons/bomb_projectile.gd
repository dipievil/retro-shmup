class_name BombProjectile
extends Projectile

## Bomb blast: falls from the top and detonates on contact, on lifetime expiry
## or when it leaves the screen, damaging every enemy in explosion_radius.

@export var explosion_radius: float = 48.0

var _detonated: bool = false


func _ready() -> void:
	super._ready()
	# The blast applies damage itself; base_enemy.gd also reacts to
	# "player_projectile" on direct contact, which would hit twice.
	remove_from_group("player_projectile")


func _on_area_entered(_other: Area2D) -> void:
	_detonate()


func _cleanup() -> void:
	_detonate()


func _detonate() -> void:
	if _detonated:
		return
	_detonated = true
	_damage_enemies_in_radius()
	hit.emit(null)
	if is_instance_valid(self):
		queue_free()


func _damage_enemies_in_radius() -> void:
	var tree := get_tree()
	if tree == null:
		return
	for enemy in tree.get_nodes_in_group("enemy"):
		if not enemy is Node2D or not is_instance_valid(enemy):
			continue
		if global_position.distance_to(enemy.global_position) > explosion_radius:
			continue
		if enemy.has_method("take_damage"):
			enemy.call("take_damage", damage)
