extends Node

## Headless checks for task-23: authored sprites and design-aligned controls.
## Run by tools/run_all.sh through tests/test_task_23.tscn so autoloads and
## global class_name registrations are available.

const SHIP_SHEET := "res://assets/sprites/player/gdas1_sheet.png"
const SHIP_META := "res://assets/sprites/player/gdas1_sheet.json"
const LASER_SHEET := "res://assets/sprites/player/laser_sheet.png"
const LASER_META := "res://assets/sprites/player/laser_sheet.json"
const PLAYER_SCENE := "res://scenes/player/player_ship.tscn"
const EXPLOSION_SCENE := "res://scenes/effects/explosion.tscn"
const PROJECTILE_SCENES := {
	"laser": "res://scenes/weapons/laser_projectile.tscn",
	"missile": "res://scenes/weapons/missile_projectile.tscn",
	"bomb": "res://scenes/weapons/bomb_projectile.tscn",
}

var _failures: Array[String] = []


func _ready() -> void:
	call_deferred("_run_tests")


func _check(ok: bool, label: String) -> void:
	if ok:
		print("  PASS  ", label)
	else:
		printerr("  FAIL  ", label)
		_failures.append(label)


func _run_tests() -> void:
	print("[task-23] Sprite sheets")
	_test_sheets()
	print("[task-23] Player visual")
	_test_player_visual()
	print("[task-23] Projectile visuals")
	_test_projectiles()
	print("[task-23] Explosion")
	_test_explosion()
	print("[task-23] Input Map")
	_test_input_map()
	print("[task-23] Speed control")
	_test_speed_control()

	if _failures.is_empty():
		print("[task-23] ALL CHECKS PASSED")
		get_tree().quit(0)
	else:
		printerr("[task-23] %d CHECK(S) FAILED" % _failures.size())
		get_tree().quit(1)


func _test_sheets() -> void:
	var frames := SpriteSheet.load_frames(SHIP_SHEET, SHIP_META)
	_check(SpriteSheet.has_frames(frames), "GDAS-1 default animation exists")
	_check(frames.get_frame_count(&"default") == 8, "GDAS-1 sheet has 8 frames")
	_check(frames.get_animation_loop(&"default"), "GDAS-1 sheet still loops by default")
	var atlas := SpriteSheet.load_texture(LASER_SHEET, LASER_META)
	_check(atlas != null, "laser frame is an AtlasTexture")
	_check(atlas != null and atlas.region.size == Vector2(16, 8), "laser frame uses 16x8 region")


func _test_player_visual() -> void:
	var packed := load(PLAYER_SCENE) as PackedScene
	_check(packed != null, "player scene loads")
	if packed == null:
		return
	var ship := packed.instantiate() as PlayerShip
	add_child(ship)
	var visual := ship.get_node_or_null("Visual") as AnimatedSprite2D
	_check(visual != null, "player Visual is AnimatedSprite2D")
	_check(visual != null and SpriteSheet.has_frames(visual.sprite_frames),
		"player Visual has GDAS-1 frames")
	ship.queue_free()


func _test_projectiles() -> void:
	for kind in PROJECTILE_SCENES.keys():
		var packed := load(PROJECTILE_SCENES[kind]) as PackedScene
		_check(packed != null, "%s projectile scene loads" % kind)
		if packed == null:
			continue
		var projectile := packed.instantiate() as Node2D
		add_child(projectile)
		var visual := projectile.get_node_or_null("Visual") as Sprite2D
		_check(visual != null and visual.texture != null, "%s uses an atlas frame" % kind)
		_check(projectile.get_node_or_null("FallbackVisual") == null,
			"%s placeholder removed" % kind)
		_check(visual != null and is_equal_approx(visual.rotation, 0.0),
			"%s art points right at rest" % kind)
		projectile.queue_free()


func _test_explosion() -> void:
	var packed := load(EXPLOSION_SCENE) as PackedScene
	_check(packed != null, "explosion scene loads")
	if packed == null:
		return
	var effect := packed.instantiate() as AnimatedSprite2D
	add_child(effect)
	_check(effect != null and SpriteSheet.has_frames(effect.sprite_frames),
		"explosion plays authored frames")
	_check(effect.sprite_frames != null
		and not effect.sprite_frames.get_animation_loop(SpriteSheet.DEFAULT_ANIMATION),
		"explosion animation is non-looping")
	effect.animation_finished.emit()
	_check(effect.is_queued_for_deletion(), "explosion frees itself when the animation ends")


func _has_key(action: String, code: int) -> bool:
	if not InputMap.has_action(action):
		return false
	for event in InputMap.action_get_events(action):
		if event is InputEventKey and event.physical_keycode == code:
			return true
	return false


func _has_pad_button(action: String, index: int) -> bool:
	if not InputMap.has_action(action):
		return false
	for event in InputMap.action_get_events(action):
		if event is InputEventJoypadButton and event.button_index == index:
			return true
	return false


func _has_pad_axis(action: String, axis: int, value: float) -> bool:
	if not InputMap.has_action(action):
		return false
	for event in InputMap.action_get_events(action):
		if (event is InputEventJoypadMotion and event.axis == axis
				and is_equal_approx(event.axis_value, value)):
			return true
	return false


func _test_input_map() -> void:
	_check(_has_key("zoom_in", KEY_SHIFT) and not _has_key("zoom_in", KEY_E),
		"zoom_in uses Left Shift, not E")
	_check(_has_key("zoom_out", KEY_CTRL) and not _has_key("zoom_out", KEY_Q),
		"zoom_out uses Left Ctrl, not Q")
	_check(_has_key("fire_laser", KEY_Q) and _has_key("fire_missile", KEY_W)
		and _has_key("fire_bomb", KEY_E), "weapons use Q/W/E")
	_check(_has_key("fire", KEY_SPACE) and not _has_key("fire", 4194324),
		"held fire is Space, not PageDown")
	_check(_has_key("cycle_speed", KEY_C), "speed cycle is C")
	_check(_has_key("pause", KEY_ESCAPE) and _has_key("start", KEY_ENTER),
		"pause/start use Escape/Enter")
	_check(_has_pad_button("zoom_in", JOY_BUTTON_RIGHT_SHOULDER)
		and _has_pad_button("zoom_out", JOY_BUTTON_LEFT_SHOULDER), "gamepad shoulders zoom")
	_check(_has_pad_axis("fire_laser", JOY_AXIS_TRIGGER_RIGHT, 1.0), "R2 fires laser")
	_check(_has_pad_axis("fire_missile", JOY_AXIS_TRIGGER_LEFT, 1.0), "L2 fires missile")
	_check(_has_pad_button("fire_bomb", JOY_BUTTON_A), "A fires bomb - L1 conflict resolved")


func _test_speed_control() -> void:
	var packed := load(PLAYER_SCENE) as PackedScene
	if packed == null:
		return
	var ship := packed.instantiate() as PlayerShip
	add_child(ship)
	GameManager.current_state = GameManager.GameState.PLAYING
	var event := InputEventAction.new()
	event.action = "cycle_speed"
	event.pressed = true
	_check(ship.speed_level == 1, "speed starts at level 1")
	ship._input(event)
	_check(ship.speed_level == 2, "cycle_speed raises the level")
	ship._input(event)
	ship._input(event)
	_check(ship.speed_level == 1, "cycle_speed wraps at level 3")
	GameManager.current_state = GameManager.GameState.MENU
	ship.queue_free()
