extends Node

## Headless checks for task-8 (stage 1 parallax backdrop).
## Run from the Godot project root:
##   godot --headless --path . res://tests/test_stage_1_parallax.tscn
## Exits with status 0 when every check passes, 1 otherwise.

const STAGE_SCENE := "res://scenes/stages/stage_1.tscn"
const EXPECTED_TEXTURES := [
	"res://assets/sprites/props/bg_stars_far_sheet.png",
	"res://assets/sprites/props/bg_nebula_sheet.png",
	"res://assets/sprites/props/bg_debris_sheet.png",
]
const EXPECTED_SCALES := [0.3, 0.6, 1.0]

var _failures: Array[String] = []


func _ready() -> void:
	# Deferred so autoloads and global class_name registrations are ready.
	call_deferred("_run_tests")


func _check(ok: bool, label: String) -> void:
	if ok:
		print("  PASS  ", label)
	else:
		printerr("  FAIL  ", label)
		_failures.append(label)


func _finish() -> void:
	if _failures.is_empty():
		print("[task-8] ALL CHECKS PASSED")
		get_tree().quit(0)
	else:
		printerr("[task-8] %d CHECK(S) FAILED" % _failures.size())
		get_tree().quit(1)


func _run_tests() -> void:
	print("[task-8] Stage 1 parallax")
	var packed: PackedScene = load(STAGE_SCENE)
	_check(packed != null, "stage 1 scene loads")
	if packed == null:
		_finish()
		return

	var stage: Node = packed.instantiate()
	add_child(stage)
	var background := stage.get_node_or_null("ParallaxBackground") as ParallaxBackground
	_check(background != null, "ParallaxBackground exists")
	if background == null:
		_finish()
		return

	var layers: Array[ParallaxLayer] = []
	for child in background.get_children():
		if child is ParallaxLayer:
			layers.append(child as ParallaxLayer)
	_check(layers.size() == 3, "exactly three ParallaxLayer children")
	if layers.size() != 3:
		_finish()
		return

	var scales: Array[float] = []
	for i in range(layers.size()):
		var layer: ParallaxLayer = layers[i]
		scales.append(layer.motion_scale.y)
		_check(layer.motion_scale.x > 0.0 and layer.motion_scale.y > 0.0,
				"layer %d has a positive motion_scale" % i)
		_check(is_equal_approx(layer.motion_scale.y, float(EXPECTED_SCALES[i])),
				"layer %d motion_scale.y = %.2f" % [i, float(EXPECTED_SCALES[i])])
		_check(layer.motion_mirroring.x > 0.0 and layer.motion_mirroring.y > 0.0,
				"layer %d mirrors for clean scrolling" % i)

		var sprite: Sprite2D = null
		for child in layer.get_children():
			if child is Sprite2D:
				sprite = child as Sprite2D
				break
		_check(sprite != null, "layer %d has a Sprite2D visual" % i)
		if sprite == null:
			continue
		_check(sprite.texture != null, "layer %d has a valid texture" % i)
		if sprite.texture == null:
			continue

		var expected: Texture2D = load(EXPECTED_TEXTURES[i])
		var expected_size: Vector2 = expected.get_size()
		_check(sprite.texture.get_size() == expected_size,
				"layer %d uses %s" % [i, String(EXPECTED_TEXTURES[i]).get_file()])
		var scaled_size: Vector2 = sprite.texture.get_size() * sprite.scale
		_check(is_equal_approx(scaled_size.x, layer.motion_mirroring.x)
				and is_equal_approx(scaled_size.y, layer.motion_mirroring.y),
				"layer %d mirror matches its scaled texture" % i)

	_check(scales[0] < scales[1] and scales[1] < scales[2],
			"motion scales strictly increase from far to near")
	_finish()
