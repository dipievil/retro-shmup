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


## The bomb ignores the ship muzzle: bombs enter from the top and sweep downward
## across the whole viewport (screen bombardment).
func _do_fire(_direction: Vector2, _origin: Vector2) -> void:
	var viewport_size := get_viewport_rect().size
	var screen_width := viewport_size.x if viewport_size.x > 0.0 else 480.0
	var margin := 40.0
	var span := maxf(1.0, screen_width - margin * 2.0)
	var count := maxi(1, bombs_per_drop)
	for i in count:
		var x := margin + span * ((float(i) + 0.5) / float(count))
		var proj := _spawn_projectile(Vector2.DOWN, Vector2(x, -12.0))
		if proj is BombProjectile:
			proj.explosion_radius = explosion_radius
	ammo -= 1
	ammo_changed.emit(ammo, max_ammo)
