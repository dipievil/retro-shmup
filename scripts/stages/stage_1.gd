extends StageBase

## Stage 1: Intro - Training Stage
## Jane learns the basics of piloting and combat.
## Simple enemy waves to test movement and firing cadence (greybox).

const EnemyScene := preload("res://scenes/enemies/base_enemy.tscn")

## Parallax layers, back to front: stars (far/slowest) -> nebula (mid) ->
## debris (near/fastest). Scales, mirrored tile sizes and textures are set in
## scenes/stages/stage_1.tscn; these constants keep the layer wiring in one place.
const PARALLAX_LAYER_NAMES := ["FarLayer", "MidLayer", "NearLayer"]
const PARALLAX_TEXTURES := [
	"res://assets/sprites/props/bg_stars_far_sheet.png",
	"res://assets/sprites/props/bg_nebula_sheet.png",
	"res://assets/sprites/props/bg_debris_sheet.png",
]


func _ready() -> void:
	_apply_parallax_textures()
	super._ready()


func _apply_parallax_textures() -> void:
	var background := get_node_or_null("ParallaxBackground") as ParallaxBackground
	if background == null:
		push_warning("Stage 1: ParallaxBackground is missing")
		return
	for i in range(PARALLAX_LAYER_NAMES.size()):
		var layer := background.get_node_or_null(NodePath(PARALLAX_LAYER_NAMES[i])) as ParallaxLayer
		if layer == null:
			push_warning("Stage 1: parallax layer is missing: %s" % PARALLAX_LAYER_NAMES[i])
			continue
		var texture: Texture2D = load(PARALLAX_TEXTURES[i])
		for child in layer.get_children():
			if child is Sprite2D:
				(child as Sprite2D).texture = texture


func _build_spawn_queue() -> void:
	# Wave 1: single enemies descending (training)
	for i in range(3):
		_queue_spawn(1.0 + i * 2.0, EnemyScene, Vector2(120 + i * 120, -30), 0.5)

	# Wave 2: staggered formation
	for i in range(5):
		_queue_spawn(8.0 + i * 0.5, EnemyScene, Vector2(60 + i * 90, -30), 0.5)

	# Wave 3: from sides
	for i in range(3):
		_queue_spawn(14.0 + i * 1.5, EnemyScene, Vector2(-30, 60 + i * 50), 0.7)
	for i in range(3):
		_queue_spawn(14.0 + i * 1.5, EnemyScene, Vector2(510, 60 + i * 50), 0.3)
