class_name Weapon
extends Node2D

## Base weapon class.
## Manages fire-rate cooldown and spawning projectiles (Area2D).
## Subclasses override fire() for specific weapon behaviors.
## Per docs/game_design.md: GDAS-1 carries laser, missile and bomb.

# ---- Signals ----
signal fired

# ---- Exported ----
@export var fire_rate: float = 0.15
@export var damage: int = 1
@export var projectile_scene: PackedScene
@export var projectile_speed: float = 600.0
@export var projectile_lifetime: float = 3.0
@export var max_level: int = 3

# "laser" | "missile" | "bomb" — selects optional sprite/SFX path sets.
@export var weapon_kind: String = "laser"
@export var sfx_paths: Array = []
@export var sfx_volume_db: float = -6.0

# ---- Internal ----
var sfx_stream: AudioStream
var current_level: int = 1
var _cooldown: float = 0.0
var _is_on_cooldown: bool = false
var _owner_node: Node2D = null


func _ready() -> void:
	_owner_node = get_parent()
	if sfx_paths.is_empty():
		sfx_paths = WeaponResources.SFX_PATHS.get(weapon_kind, []) as Array
	if sfx_stream == null:
		sfx_stream = WeaponResources.first_existing(sfx_paths) as AudioStream


func _process(delta: float) -> void:
	if _is_on_cooldown:
		_cooldown -= delta
		if _cooldown <= 0.0:
			_is_on_cooldown = false


func can_fire() -> bool:
	return not _is_on_cooldown and projectile_scene != null


func fire(direction: Vector2 = Vector2.RIGHT, origin: Vector2 = Vector2.ZERO) -> void:
	if not can_fire():
		return
	_do_fire(direction, origin)
	_is_on_cooldown = true
	_cooldown = fire_rate
	_play_sfx()
	fired.emit()


func _do_fire(direction: Vector2, origin: Vector2) -> void:
	_spawn_projectile(direction, origin)


## Spawns one configured projectile. Subclasses override _configure_projectile()
## to add weapon-specific behaviour (homing, blast radius, ...).
func _spawn_projectile(direction: Vector2, origin: Vector2) -> Projectile:
	if projectile_scene == null:
		return null
	var proj := projectile_scene.instantiate() as Projectile
	if proj == null:
		push_warning("Weapon: projectile_scene does not instantiate a Projectile")
		return null
	# Configure before add_child so _ready() sees the final values.
	proj.direction = direction.normalized() if direction != Vector2.ZERO else Vector2.RIGHT
	proj.damage = damage
	proj.speed = projectile_speed
	proj.lifetime = projectile_lifetime
	proj.is_player_projectile = true
	proj.weapon_kind = weapon_kind
	proj.global_position = origin
	# Carry the launch layer forward so homing missiles only chase enemies on
	# the same plane (game_design.md). Set before _configure_projectile/add_child.
	var launch_depth: Variant = _launch_depth()
	if launch_depth != null:
		proj.depth = launch_depth
	_configure_projectile(proj)
	var parent := _projectile_parent()
	if parent != null:
		parent.add_child(proj)
	return proj


func _configure_projectile(_proj: Projectile) -> void:
	pass


## Depth of the node that owns this weapon (the player ship). Returns null when
## no owner exposes one, leaving the projectile's default depth untouched — this
## keeps standalone/headless weapons harmless.
func _launch_depth() -> Variant:
	var owner_node: Node = _owner_node if _owner_node != null else get_parent()
	if owner_node == null:
		return null
	if "depth" in owner_node:
		var value: Variant = owner_node.get("depth")
		if value is float or value is int:
			return float(value)
	if owner_node.has_method("get_depth"):
		return float(owner_node.call("get_depth"))
	return null


func _projectile_parent() -> Node:
	var tree := get_tree()
	if tree == null:
		return null
	# current_scene keeps shots above stage layers; root is a safe fallback
	# for headless/structural tests where current_scene may be unset.
	return tree.current_scene if tree.current_scene != null else tree.root


## Missing SFX is expected until task-3 assets land — no error, just a TODO.
func _play_sfx() -> void:
	if sfx_stream == null:
		# TODO(task-3): import laser/missile/bomb fire SFX into assets/audio/sfx.
		return
	var tree := get_tree()
	if tree == null:
		return
	var manager := tree.root.get_node_or_null("AudioManager")
	if manager != null and manager.has_method("play_sfx"):
		manager.call("play_sfx", sfx_stream, sfx_volume_db)


func upgrade() -> void:
	if current_level < max_level:
		current_level += 1


func reset() -> void:
	current_level = 1
