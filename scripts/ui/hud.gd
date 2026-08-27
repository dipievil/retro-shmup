class_name HUD
extends CanvasLayer

## Heads-up display: hull, front/back shields, score, weapon, stage info.
## Subscribes to GameManager signals for reactive updates.

# ---- Internal ----
var _hull_bar: ProgressBar
var _front_shield_bar: ProgressBar
var _back_shield_bar: ProgressBar
var _score_label: Label
var _stage_label: Label
var _weapon_label: Label


func _ready() -> void:
	_build_ui()
	_connect_signals()


func _connect_signals() -> void:
	GameManager.score_changed.connect(_on_score_changed)
	GameManager.hull_changed.connect(_on_hull_changed)
	GameManager.shield_changed.connect(_on_shield_changed)
	GameManager.stage_changed.connect(_on_stage_changed)
	GameManager.weapon_changed.connect(_on_weapon_changed)


# ---- UI Construction ----
func _build_ui() -> void:
	_layer_setup()

	# Root container
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	# Top-left: ship stats
	var stats_vbox := VBoxContainer.new()
	stats_vbox.position = Vector2(8, 4)
	stats_vbox.custom_minimum_size = Vector2(140, 80)
	root.add_child(stats_vbox)

	_hull_bar = _make_bar("Hull")
	_front_shield_bar = _make_bar("Front")
	_back_shield_bar = _make_bar("Back")
	stats_vbox.add_child(_hull_bar)
	stats_vbox.add_child(_front_shield_bar)
	stats_vbox.add_child(_back_shield_bar)

	# Top-right: score + stage
	var info_vbox := VBoxContainer.new()
	info_vbox.position = Vector2(340, 4)
	info_vbox.custom_minimum_size = Vector2(132, 40)
	root.add_child(info_vbox)

	_score_label = Label.new()
	_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_score_label.text = "SCORE: 0"
	info_vbox.add_child(_score_label)

	_stage_label = Label.new()
	_stage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_stage_label.text = "STAGE 1"
	info_vbox.add_child(_stage_label)

	# Bottom-left: weapon
	_weapon_label = Label.new()
	_weapon_label.position = Vector2(8, 250)
	_weapon_label.text = "WEAPON: LASER Lv1"
	root.add_child(_weapon_label)

	# Initialize bar values
	_init_bar_values()


func _layer_setup() -> void:
	layer = 10


func _make_bar(label_text: String) -> ProgressBar:
	var container := HBoxContainer.new()

	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(40, 12)
	label.add_theme_font_size_override("font_size", 8)
	container.add_child(label)

	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(80, 10)
	bar.min_value = 0
	bar.max_value = 3
	bar.value = 3
	container.add_child(bar)

	return bar


func _init_bar_values() -> void:
	var data := GameManager.get_ship_data()
	_hull_bar.max_value = data.get("max_hull", 3)
	_hull_bar.value = data.get("max_hull", 3)
	_front_shield_bar.max_value = data.get("max_front_shield", 3)
	_front_shield_bar.value = data.get("max_front_shield", 3)
	_back_shield_bar.max_value = data.get("max_back_shield", 3)
	_back_shield_bar.value = data.get("max_back_shield", 3)


# ---- Signal Handlers ----
func _on_score_changed(new_score: int) -> void:
	_score_label.text = "SCORE: %d" % new_score


func _on_hull_changed(_ship_index: int, new_hull: int) -> void:
	_hull_bar.value = new_hull


func _on_shield_changed(_ship_index: int, shield_side: String, new_value: int) -> void:
	match shield_side:
		"front":
			_front_shield_bar.value = new_value
		"back":
			_back_shield_bar.value = new_value


func _on_stage_changed(stage_id: int) -> void:
	_stage_label.text = "STAGE %d" % stage_id


func _on_weapon_changed(weapon_name: String, level: int) -> void:
	_weapon_label.text = "WEAPON: %s Lv%d" % [weapon_name.to_upper(), level]
