class_name PlayerShip
extends Area2D

## Player ship controller.
## Handles movement, depth (zoom) layers, damage control (hull + shields),
## and weapon firing. Based on docs/game_design.md specifications.
##
## Depth is the visual/mechanical representation of the "Screen multiple
## action layers" concept: the middle layer is the main gameplay layer and
## R1 / L1 (zoom_in / zoom_out) move the ship toward the front or back layer
## to evade enemy fire. Enemy ships enter from any layer but converge on the
## player's current layer.
##
## TODO(task-2): replace the Polygon2D placeholder in player_ship.tscn with
## the GDAS-1 sprite (assets/sprites/player/gdas1.png + json-array metadata)
## once that asset is available. The controller does not depend on the
## specific visual node, so no logic changes should be needed.

const ProjectileScene := preload("res://scenes/weapons/projectile.tscn")

# ---- Signals ----
signal hull_changed(new_hull: int)
signal shield_changed(side: String, new_value: int)
signal depth_changed(new_depth: float)
signal layer_changed(new_layer: int)
signal destroyed

# ---- Enums ----
## Discrete action layers, ordered back -> front.
## MIDDLE (1) is the default gameplay layer per docs/game_design.md.
enum ActionLayer { BACK = 0, MIDDLE = 1, FRONT = 2 }

# ---- Constants ----
const _LAYER_DEPTH_BACK: float = 0.0
const _LAYER_DEPTH_MIDDLE: float = 0.5
const _LAYER_DEPTH_FRONT: float = 1.0
const _DEPTH_SCALE_MIN := 0.6
const _DEPTH_SCALE_MAX := 1.4
const _DEPTH_OPACITY_MIN := 0.5
const _INVINCIBLE_TIME := 1.0

# ---- Exported ----
@export var base_speed: float = 200.0
@export var max_depth: float = 1.0
@export var min_depth: float = 0.0
@export var depth_step: float = 0.25
@export var zoom_speed: float = 2.0
@export var shield_regen_delay: float = 5.0
@export var shield_regen_rate: float = 0.5

# ---- Internal: Damage control (GDAS-1: hull 3, front 3, back 3) ----
var max_hull: int = 3
var current_hull: int = 3
var max_front_shield: int = 3
var current_front_shield: int = 3
var max_back_shield: int = 3
var current_back_shield: int = 3

# ---- Internal: Depth/Layers ----
var depth: float = 0.5  # 0 = back layer, 0.5 = middle, 1.0 = front
var _target_depth: float = 0.5
var current_layer: int = ActionLayer.MIDDLE
var _last_emitted_depth: float = -1.0

# ---- Internal: Speed ----
var speed_level: int = 1
var max_speed_level: int = 3

# ---- Internal: Weapons ----
var _weapons: Dictionary = {}  # weapon_name -> Weapon node
var _active_weapon: String = "laser"

# ---- Internal: State ----
var _velocity: Vector2 = Vector2.ZERO
var _shield_regen_timer: float = 0.0
var _invincible_timer: float = 0.0
var _is_invincible: bool = false
var _ship_id: String = "gdas_1"


func _ready() -> void:
	_load_ship_data()
	_setup_weapons()
	collision_layer = 1  # player (bit 0)
	collision_mask = 4 | 8 | 16  # enemies + enemy_projectiles + pickups (bits 2, 3, 4)
	area_entered.connect(_on_area_entered)
	add_to_group("player")
	GameManager.player = self
	current_layer = _layer_for_depth(_target_depth)
	_apply_depth_visuals()


func _load_ship_data() -> void:
	var data := GameManager.get_ship_data()
	_ship_id = GameManager.selected_ship
	max_hull = data.get("max_hull", 3)
	current_hull = max_hull
	max_front_shield = data.get("max_front_shield", 3)
	current_front_shield = max_front_shield
	max_back_shield = data.get("max_back_shield", 3)
	current_back_shield = max_back_shield
	max_speed_level = data.get("speed_levels", 3)
	speed_level = 1


func _setup_weapons() -> void:
	var data := GameManager.get_ship_data()
	var weapon_names: Array = data.get("weapons", ["laser"])
	for wname in weapon_names:
		var weapon_node := _create_weapon(wname)
		if weapon_node:
			add_child(weapon_node)
			_weapons[wname] = weapon_node


func _create_weapon(wname: String) -> Node2D:
	match wname:
		"laser":
			var laser := Laser.new()
			laser.fire_rate = 0.12
			laser.damage = 1
			laser.projectile_speed = 700.0
			laser.projectile_scene = ProjectileScene
			laser.max_level = 3
			return laser
		"missile":
			var missile := Weapon.new()
			missile.fire_rate = 0.8
			missile.damage = 3
			missile.projectile_speed = 350.0
			missile.projectile_scene = ProjectileScene
			missile.max_level = 3
			return missile
		"bomb":
			var bomb := Weapon.new()
			bomb.fire_rate = 2.5
			bomb.damage = 5
			bomb.projectile_speed = 200.0
			bomb.projectile_scene = ProjectileScene
			bomb.max_level = 1
			return bomb
	return null


func _process(delta: float) -> void:
	if GameManager.current_state != GameManager.GameState.PLAYING:
		return
	_handle_movement(delta)
	_handle_depth(delta)
	_handle_firing()
	_handle_shield_regen(delta)
	_handle_invincibility(delta)


# ---- Movement ----
func _handle_movement(delta: float) -> void:
	var input := Vector2.ZERO
	input.x = Input.get_axis("move_left", "move_right")
	input.y = Input.get_axis("move_up", "move_down")
	input = input.normalized()

	var speed_mult := _get_speed_multiplier()
	var depth_speed_mult := lerpf(0.5, 1.0, depth)
	var move_speed := base_speed * speed_mult * depth_speed_mult

	_velocity = input * move_speed
	position += _velocity * delta

	# Clamp to screen bounds (viewport is 480x270)
	var half_size := 16.0
	position.x = clampf(position.x, half_size, 480.0 - half_size)
	position.y = clampf(position.y, half_size, 270.0 - half_size)


func _get_speed_multiplier() -> float:
	return 1.0 + (float(speed_level) - 1.0) * 0.3


func _cycle_speed() -> void:
	if speed_level < max_speed_level:
		speed_level += 1
	else:
		speed_level = 1


# ---- Depth / Action-layer system ----
func _handle_depth(delta: float) -> void:
	# zoom_in = R1 (gamepad) / E (keyboard), zoom_out = L1 / Q.
	if Input.is_action_just_pressed("zoom_in"):
		change_depth(depth_step)
	if Input.is_action_just_pressed("zoom_out"):
		change_depth(-depth_step)

	# move_toward cannot overshoot the clamped target on a long frame,
	# unlike lerp(depth, target, zoom_speed * delta).
	depth = move_toward(depth, _target_depth, zoom_speed * delta)
	_apply_depth_visuals()


## Change the requested depth, clamped to [min_depth, max_depth].
## Public so other systems (and tests) can drive the layer mechanic directly.
func change_depth(delta: float) -> void:
	_target_depth = clampf(_target_depth + delta, min_depth, max_depth)
	_update_layer_from_target()


## Switch to a discrete action layer (BACK=0, MIDDLE=1, FRONT=2).
func set_action_layer(layer: int) -> void:
	var clamped := clampi(layer, ActionLayer.BACK, ActionLayer.FRONT)
	_target_depth = _depth_for_layer(clamped)
	current_layer = clamped
	layer_changed.emit(current_layer)


func get_action_layer() -> int:
	return current_layer


func get_target_depth() -> float:
	return _target_depth


func get_depth() -> float:
	return depth


func _depth_for_layer(layer: int) -> float:
	match layer:
		ActionLayer.BACK:
			return _LAYER_DEPTH_BACK
		ActionLayer.MIDDLE:
			return _LAYER_DEPTH_MIDDLE
		ActionLayer.FRONT:
			return _LAYER_DEPTH_FRONT
	return _LAYER_DEPTH_MIDDLE


func _layer_for_depth(value: float) -> int:
	if value < 0.25:
		return ActionLayer.BACK
	if value < 0.75:
		return ActionLayer.MIDDLE
	return ActionLayer.FRONT


func _update_layer_from_target() -> void:
	var new_layer := _layer_for_depth(_target_depth)
	if new_layer != current_layer:
		current_layer = new_layer
		layer_changed.emit(current_layer)


func _apply_depth_visuals() -> void:
	var scale_mult := lerpf(_DEPTH_SCALE_MIN, _DEPTH_SCALE_MAX, depth)
	scale = Vector2(scale_mult, scale_mult)
	modulate.a = lerpf(_DEPTH_OPACITY_MIN, 1.0, depth)
	if not is_equal_approx(depth, _last_emitted_depth):
		_last_emitted_depth = depth
		depth_changed.emit(depth)


# ---- Firing ----
func _handle_firing() -> void:
	if Input.is_action_pressed("fire"):
		_fire_weapon("laser")
	if Input.is_action_just_pressed("fire_missile") and _weapons.has("missile"):
		_fire_weapon("missile")
	if Input.is_action_just_pressed("fire_bomb") and _weapons.has("bomb"):
		_fire_weapon("bomb")


func _fire_weapon(wname: String) -> void:
	if not _weapons.has(wname):
		return
	var weapon: Weapon = _weapons[wname]
	var muzzle := Vector2(position.x, position.y - 20)
	weapon.fire(Vector2.UP, muzzle)


func switch_weapon(wname: String) -> void:
	if _weapons.has(wname):
		_active_weapon = wname


func get_active_weapon() -> String:
	return _active_weapon


func upgrade_weapon(wname: String) -> void:
	if _weapons.has(wname):
		var w: Weapon = _weapons[wname]
		w.upgrade()


# ---- Damage Control ----
func _handle_shield_regen(delta: float) -> void:
	if current_front_shield < max_front_shield or current_back_shield < max_back_shield:
		_shield_regen_timer += delta
		if _shield_regen_timer >= shield_regen_delay:
			if current_front_shield < max_front_shield:
				current_front_shield = mini(current_front_shield + int(ceil(shield_regen_rate)), max_front_shield)
				shield_changed.emit("front", current_front_shield)
				GameManager.shield_changed.emit(0, "front", current_front_shield)
			if current_back_shield < max_back_shield:
				current_back_shield = mini(current_back_shield + int(ceil(shield_regen_rate)), max_back_shield)
				shield_changed.emit("back", current_back_shield)
				GameManager.shield_changed.emit(0, "back", current_back_shield)


func _handle_invincibility(delta: float) -> void:
	if _is_invincible:
		_invincible_timer -= delta
		# Flicker effect; keep the alpha supplied by the depth visuals.
		modulate.r = 0.5 if fmod(_invincible_timer, 0.1) < 0.05 else 1.0
		if _invincible_timer <= 0.0:
			_is_invincible = false
			modulate = Color(1, 1, 1, modulate.a)


func take_damage(amount: int, from_front: bool = true) -> void:
	if _is_invincible:
		return
	_shield_regen_timer = 0.0

	if from_front and current_front_shield > 0:
		current_front_shield = maxi(0, current_front_shield - amount)
		shield_changed.emit("front", current_front_shield)
		GameManager.shield_changed.emit(0, "front", current_front_shield)
		_start_invincibility()
		return
	if not from_front and current_back_shield > 0:
		current_back_shield = maxi(0, current_back_shield - amount)
		shield_changed.emit("back", current_back_shield)
		GameManager.shield_changed.emit(0, "back", current_back_shield)
		_start_invincibility()
		return

	# Shields down — damage hull
	current_hull = maxi(0, current_hull - amount)
	hull_changed.emit(current_hull)
	GameManager.hull_changed.emit(0, current_hull)
	_start_invincibility()
	if current_hull <= 0:
		_die()


func _start_invincibility() -> void:
	_is_invincible = true
	_invincible_timer = _INVINCIBLE_TIME


func _die() -> void:
	destroyed.emit()
	GameManager.game_over()
	queue_free()


# ---- Collision ----
func _on_area_entered(other: Area2D) -> void:
	if other.is_in_group("enemy_projectile"):
		var proj: Projectile = other
		var from_front := proj.direction.y > 0  # coming from above = front hit
		take_damage(proj.damage, from_front)
		proj.queue_free()
	elif other.is_in_group("enemy"):
		take_damage(1, other.global_position.y < global_position.y)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if GameManager.current_state == GameManager.GameState.PLAYING:
			GameManager.change_state(GameManager.GameState.PAUSED)
		elif GameManager.current_state == GameManager.GameState.PAUSED:
			GameManager.change_state(GameManager.GameState.PLAYING)
