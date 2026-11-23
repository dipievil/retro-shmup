class_name DamageControl
extends Node

## Direction-aware damage control model (docs/game_design.md, GDAS-1: 3/3/3).
##
## Owns three independent pools: hull, front shield and back shield. A front hit
## drains only the front shield, a back hit drains only the back shield, and any
## damage left over after that shield is empty reaches the hull. The model knows
## nothing about the HUD, scenes or game state; it only owns values and signals.
## Shield regeneration is intentionally absent (off by default).

signal shield_changed(side: String, new_value: int)
signal hull_changed(new_hull: int)
signal ship_destroyed

## Accepted by apply_damage() alongside "front"/"back", a bool and a Vector2.
enum Direction { FRONT = 0, BACK = 1 }

const SIDE_FRONT := "front"
const SIDE_BACK := "back"

var max_hull: int = 3
var current_hull: int = 3
var max_front_shield: int = 3
var current_front_shield: int = 3
var max_back_shield: int = 3
var current_back_shield: int = 3


func _init(hull: int = 3, front_shield: int = 3, back_shield: int = 3) -> void:
	configure(hull, front_shield, back_shield)


## Resets all three pools to full. Configuration alone emits no signals.
func configure(hull: int, front_shield: int, back_shield: int) -> void:
	max_hull = maxi(0, hull)
	max_front_shield = maxi(0, front_shield)
	max_back_shield = maxi(0, back_shield)
	current_hull = max_hull
	current_front_shield = max_front_shield
	current_back_shield = max_back_shield


## Applies damage from a direction and returns a small report:
## {shield_damage, hull_damage, remaining, destroyed, side}.
##
## `direction` accepts Direction.FRONT/BACK, "front"/"back" (also "rear"), a
## bool (true = front), or an incoming Vector2 whose Y is the travel direction
## (positive Y = hit from above/front, matching the projectile convention).
func apply_damage(amount: int, direction = Direction.FRONT) -> Dictionary:
	var remaining := maxi(0, amount)
	var from_front := _is_front(direction)
	var shield_damage := 0
	var hull_damage := 0
	var side := SIDE_FRONT if from_front else SIDE_BACK

	# Only the shield facing the hit can absorb damage; the other one is isolated.
	if remaining > 0 and get_shield_value(from_front) > 0:
		shield_damage = mini(remaining, get_shield_value(from_front))
		set_shield_value(from_front, get_shield_value(from_front) - shield_damage)
		remaining -= shield_damage
		shield_changed.emit(side, get_shield_value(from_front))

	# Overflow (or a hit on an already-empty shield) reaches the hull.
	if remaining > 0 and current_hull > 0:
		hull_damage = mini(remaining, current_hull)
		current_hull -= hull_damage
		remaining -= hull_damage
		hull_changed.emit(current_hull)
		if current_hull == 0:
			ship_destroyed.emit()

	return {
		"shield_damage": shield_damage,
		"hull_damage": hull_damage,
		"remaining": remaining,
		"destroyed": current_hull == 0,
		"side": side,
	}


func get_hull() -> int:
	return current_hull


func get_front_shield() -> int:
	return current_front_shield


func get_back_shield() -> int:
	return current_back_shield


func get_shield(side: String) -> int:
	return current_back_shield if side.to_lower() == SIDE_BACK else current_front_shield


func get_shield_value(from_front: bool) -> int:
	return current_front_shield if from_front else current_back_shield


func set_shield_value(from_front: bool, value: int) -> void:
	if from_front:
		current_front_shield = maxi(0, value)
	else:
		current_back_shield = maxi(0, value)


func is_destroyed() -> bool:
	return current_hull <= 0


func _is_front(direction) -> bool:
	if direction is bool:
		return direction
	if direction is String or direction is StringName:
		var side := String(direction).to_lower()
		return side != SIDE_BACK and side != "rear" and side != "from_back"
	if direction is Vector2:
		return direction.y > 0.0
	if direction is int:
		return direction != Direction.BACK
	return true
