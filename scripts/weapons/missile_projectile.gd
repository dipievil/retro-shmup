class_name MissileProjectile
extends Projectile

## Homing projectile for the missile weapon.
## Re-targets the nearest enemy inside homing_radius and turns toward it with a
## limited turn rate, so missiles can miss fast movers (keeps the weapon fair).

@export var homing_radius: float = 280.0
@export var turn_rate: float = 4.5  # radians per second
@export var depth_tolerance: float = 0.3

var target: Node2D = null


func _physics_process(delta: float) -> void:
	_update_homing(delta)
	# Sprite points up in the source art; rotate it to face travel direction.
	rotation = direction.angle() + PI * 0.5
	super._physics_process(delta)


func _update_homing(delta: float) -> void:
	if not _is_target_valid():
		_acquire_target()
	if target == null:
		return
	var to_target := target.global_position - global_position
	if to_target.length_squared() <= 0.0001:
		return
	var desired := to_target.normalized()
	var max_step := turn_rate * delta
	direction = direction.rotated(clampf(direction.angle_to(desired), -max_step, max_step))


func _is_target_valid() -> bool:
	if not is_instance_valid(target):
		return false
	if global_position.distance_to(target.global_position) > homing_radius:
		return false
	return _is_on_same_layer(target)


func _acquire_target() -> void:
	target = null
	var tree := get_tree()
	if tree == null:
		return
	var best_distance := homing_radius
	for enemy in tree.get_nodes_in_group("enemy"):
		if not enemy is Node2D or not is_instance_valid(enemy):
			continue
		if not _is_on_same_layer(enemy):
			continue
		var distance := global_position.distance_to(enemy.global_position)
		if distance < best_distance:
			best_distance = distance
			target = enemy


## Depth layers are a core mechanic (game_design.md): missiles should not chase
## enemies on another plane. Projectiles do not carry depth yet, so when either
## node lacks it we fall back to targeting every enemy.
func _is_on_same_layer(other: Node2D) -> bool:
	if not ("depth" in self) or not ("depth" in other):
		return true
	var mine := get("depth")
	var theirs := other.get("depth")
	if not (mine is float or mine is int) or not (theirs is float or theirs is int):
		return true
	return absf(float(mine) - float(theirs)) <= depth_tolerance
