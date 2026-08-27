class_name CutsceneManager
extends CanvasLayer

## Cutscene system using Control nodes + AnimationPlayer.
## Supports Phantasy Star-style text panels (sliding rectangles with text)
## and dynamic in-ship cutscenes with screen shake and particle effects.
## Vocals are handled through AudioManager during cutscenes.

# ---- Signals ----
signal cutscene_started(id: String)
signal cutscene_finished(id: String)
signal dialogue_advanced(speaker: String, text: String)

# ---- Internal ----
var _root: Control
var _dialogue_box: PanelContainer
var _speaker_label: Label
var _text_label: RichTextLabel
var _animation: AnimationPlayer
var _current_cutscene: String = ""
var _is_active: bool = false
var _dialogue_queue: Array[Dictionary] = []
var _is_typing: bool = false
var _full_text: String = ""
var _visible_chars: int = 0


func _ready() -> void:
	layer = 20
	_build_ui()
	_connect_signals()


func _connect_signals() -> void:
	AudioManager.bar_triggered.connect(_on_bar)


func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.visible = false
	add_child(_root)

	# Dialogue panel (Phantasy Star style: rectangle sliding in)
	_dialogue_box = PanelContainer.new()
	_dialogue_box.position = Vector2(40, 180)
	_dialogue_box.custom_minimum_size = Vector2(400, 70)
	_dialogue_box.visible = false
	_root.add_child(_dialogue_box)

	var vbox := VBoxContainer.new()
	_dialogue_box.add_child(vbox)

	_speaker_label = Label.new()
	_speaker_label.text = ""
	_speaker_label.add_theme_font_size_override("font_size", 10)
	vbox.add_child(_speaker_label)

	_text_label = RichTextLabel.new()
	_text_label.text = ""
	_text_label.bbcode_enabled = true
	_text_label.fit_content = true
	_text_label.custom_minimum_size = Vector2(380, 40)
	_text_label.add_theme_font_size_override("normal_font_size", 8)
	vbox.add_child(_text_label)

	_animation = AnimationPlayer.new()
	_root.add_child(_animation)


func _process(_delta: float) -> void:
	if _is_typing:
		_visible_chars += 1
		_text_label.visible_characters = _visible_chars
		if _visible_chars >= _full_text.length():
			_is_typing = false


func _input(event: InputEvent) -> void:
	if not _is_active:
		return
	if event.is_action_pressed("fire") or event.is_action_pressed("start"):
		_advance_dialogue()


# ---- Public API ----
func play_cutscene(cutscene_id: String) -> void:
	if _is_active:
		return
	_is_active = true
	_current_cutscene = cutscene_id
	_root.visible = true
	GameManager.change_state(GameManager.GameState.CUTSCENE)
	cutscene_started.emit(cutscene_id)
	_load_cutscene_data(cutscene_id)


func _load_cutscene_data(cutscene_id: String) -> void:
	# Placeholder: cutscene data would be loaded from JSON or script
	# For now, show a simple intro message
	_queue_dialogue("narrator", "Stage %d begins..." % GameManager.current_stage)
	_start_dialogue()


func _queue_dialogue(speaker: String, text: String) -> void:
	_dialogue_queue.append({"speaker": speaker, "text": text})


func _start_dialogue() -> void:
	if _dialogue_queue.is_empty():
		end_cutscene()
		return
	_dialogue_box.visible = true
	_next_dialogue()


func _next_dialogue() -> void:
	if _dialogue_queue.is_empty():
		end_cutscene()
		return
	var entry: Dictionary = _dialogue_queue.pop_front()
	_speaker_label.text = entry["speaker"]
	_full_text = entry["text"]
	_text_label.text = _full_text
	_text_label.visible_characters = 0
	_visible_chars = 0
	_is_typing = true
	dialogue_advanced.emit(entry["speaker"], entry["text"])


func _advance_dialogue() -> void:
	if _is_typing:
		# Skip typing animation
		_visible_chars = _full_text.length()
		_text_label.visible_characters = _visible_chars
		_is_typing = false
		return
	_next_dialogue()


func end_cutscene() -> void:
	_is_active = false
	_current_cutscene = ""
	_root.visible = false
	_dialogue_box.visible = false
	_dialogue_queue.clear()
	cutscene_finished.emit(_current_cutscene)
	GameManager.change_state(GameManager.GameState.PLAYING)


func _on_bar(_bar_count: int) -> void:
	# Sync cutscene animations to music bars
	if _is_active and _animation:
		pass  # Trigger animation keyframes on bar
