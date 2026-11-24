class_name Bomb
extends Weapon

## Bomb weapon (docs/game_design.md): limited screen bombardment.
## Fires a line of delayed blasts across the screen instead of a single shot.
## Uses an ammo cap plus a slow recharge — both a limit and a cooldown.

signal ammo_changed(current: int, max_ammo: int)

@export var max_ammo: int = 3
@export var recharge_time: float = 8.0
@export var bombs_per_drop: int = 5
@export var explosion_radius: float = 48.0

var ammo: int = 3
var _recharge_timer: float = 0.0


func _ready() -> void:
	super._ready()
	ammo = maxi(1, max_ammo)
	ammo_changed.emit(ammo, max_ammo)


func _process(delta: float) -> void:
	super._process(delta)
	if ammo >= maxi(1, max_ammo):
		return
	_recharge_timer += delta
	if _recharge_timer >= recharge_time:
		_recharge_timer = 0.0
		ammo += 1
		ammo_changed.emit(ammo, max_ammo)


func can_fire() -> bool:
	return ammo > 0 and super.can_fire()


## The bomb keeps its limited volley but follows the side-scrolling baseline:
## every blast leaves the ship's right-facing muzzle and travels right in a
## tight vertical spread instead of dropping from the top of the screen.
func _do_fire(direction: Vector2, origin: Vector2) -> void:
	var travel := direction.normalized() if direction != Vector2.ZERO else Vector2.RIGHT
	var count := maxi(1, bombs_per_drop)
	var spacing := 16.0
	for i in count:
		var offset_y := (float(i) - (float(count) - 1.0) * 0.5) * spacing
		var proj := _spawn_projectile(travel, origin + Vector2(0.0, offset_y))
		if proj is BombProjectile:
			proj.explosion_radius = explosion_radius
	ammo -= 1
	ammo_changed.emit(ammo, max_ammo)
