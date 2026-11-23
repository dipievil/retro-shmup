extends Node

## Headless checks for task-18 (dynamic audio sync).
## Run from the Godot project root with Godot 4.3+:
##   godot --headless --path . res://tests/test_audio_manager.tscn
## Exits with status 0 when every check passes, 1 otherwise.
##
## This runs as a scene (not --script) so the GameManager/AudioManager autoloads
## and the imported WAV streams are available.

const MANAGER_SCRIPT := "res://scripts/autoload/audio_manager.gd"
const MISSING_BASE := "res://assets/audio/music/__missing_base_beat.wav"
const MISSING_DRUM := "res://assets/audio/music/__missing_drums.wav"
const MISSING_VOCAL := "res://assets/audio/music/__missing_vocals.wav"

var _failures: Array[String] = []


func _ready() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	print("[task-18] AudioManager looping")
	var all_ok := _test_looping()
	print("[task-18] AudioManager event mix")
	all_ok = _test_event_mix() and all_ok
	print("[task-18] AudioManager event wiring")
	all_ok = _test_event_wiring() and all_ok
	print("[task-18] AudioManager missing stems")
	all_ok = _test_missing_stems() and all_ok
	if not all_ok:
		# A runtime error can abort a check before it appends a failure.
		_check(false, "all audio sync checks executed")
	if _failures.is_empty():
		print("[task-18] ALL CHECKS PASSED")
		get_tree().quit(0)
	else:
		printerr("[task-18] %d CHECK(S) FAILED" % _failures.size())
		get_tree().quit(1)


func _check(ok: bool, label: String) -> void:
	if ok:
		print("  PASS  ", label)
	else:
		printerr("  FAIL  ", label)
		_failures.append(label)


func _near(a: float, b: float) -> bool:
	return absf(a - b) < 0.01


func _test_looping() -> bool:
	# Loop configuration is checked on the stream already assigned to the base
	# player. Starting playback here would leave AudioStreamPlayback objects
	# alive at quit under the headless audio driver, so that is covered by the
	# structural validator instead (tests/validate_audio_sync.py).
	var base: AudioStreamPlayer = AudioManager.get_player(AudioManager.STEM_BASE_BEAT)
	_check(base != null, "base beat AudioStreamPlayer exists")
	if base == null:
		return false
	_check(base.bus == AudioManager.STEM_BASE_BEAT, "base beat uses its own AudioServer bus")
	_check(AudioManager.is_layer_available(AudioManager.STEM_BASE_BEAT),
			"base beat stem is available")
	_check(base.stream != null, "base beat stem loaded from task-3 assets")
	if base.stream == null:
		return false
	_check(base.stream is AudioStreamWAV, "base beat is an AudioStreamWAV")
	if base.stream is AudioStreamWAV:
		var wav := base.stream as AudioStreamWAV
		_check(wav.loop_mode == AudioStreamWAV.LOOP_FORWARD, "base beat stream loops forward")
		_check(wav.loop_begin == 0, "base beat loop starts at frame 0")
		var expected_frames := int(round(wav.get_length() * float(wav.get_mix_rate())))
		_check(wav.loop_end == expected_frames, "base beat loop covers the whole stem")
		var loop_seconds := float(wav.loop_end) / float(wav.get_mix_rate())
		_check(_near(loop_seconds, 16.0 * AudioManager.get_sec_per_beat()),
				"base beat loop is 16 beats at the configured BPM")
	_check(_near(AudioManager.get_sec_per_beat(), 60.0 / AudioManager.BPM),
			"beat interval derived from the engine-synced BPM")
	_check(AudioServer.get_bus_index(AudioManager.STEM_MASTER) != -1,
			"Music bus created via AudioServer")
	for layer in AudioManager.LAYERS:
		_check(AudioServer.get_bus_index(layer) != -1, "bus exists for layer %s" % layer)
	return true


func _test_event_mix() -> bool:
	var saved_fade := AudioManager.default_fade
	AudioManager.default_fade = 0.0

	AudioManager.on_event(AudioManager.EVENT_STAGE_START, 0.0)
	_check(AudioManager.get_active_event() == AudioManager.EVENT_STAGE_START,
			"stage_start becomes the active event")
	_check(_near(AudioManager.get_layer_db(AudioManager.STEM_DRUMS), -9.0),
			"stage_start sets the drum layer to -9 dB")
	_check(_near(AudioManager.get_layer_db(AudioManager.STEM_VOCALS), AudioManager.SILENT_DB),
			"stage_start silences the vocal layer")

	AudioManager.on_event(AudioManager.EVENT_CUTSCENE_START, 0.0)
	_check(_near(AudioManager.get_layer_db(AudioManager.STEM_DRUMS), AudioManager.SILENT_DB),
			"cutscene_start fades drums out")
	_check(_near(AudioManager.get_layer_db(AudioManager.STEM_VOCALS), 0.0),
			"cutscene_start fades vocals in")
	_check(_near(AudioManager.get_layer_db(AudioManager.STEM_BASE_BEAT), 0.0),
			"base beat stays audible during cutscenes")

	AudioManager.on_event(AudioManager.EVENT_CUTSCENE_END, 0.0)
	_check(_near(AudioManager.get_layer_db(AudioManager.STEM_DRUMS), -9.0),
			"cutscene_end brings drums back")
	_check(_near(AudioManager.get_layer_db(AudioManager.STEM_VOCALS), AudioManager.SILENT_DB),
			"cutscene_end fades vocals out")

	# Non-zero fade must return a live Tween that moves the bus when stepped.
	AudioManager.set_layer(AudioManager.STEM_VOCALS, AudioManager.SILENT_DB, 0.0)
	var tween: Tween = AudioManager.set_layer(AudioManager.STEM_VOCALS, 0.0, 0.05)
	_check(tween != null, "set_layer returns a Tween for a smooth transition")
	if tween != null:
		tween.custom_step(1.0)
		_check(_near(AudioManager.get_layer_db(AudioManager.STEM_VOCALS), 0.0),
				"tween reaches the target layer volume")

	AudioManager.default_fade = saved_fade
	return true


func _test_event_wiring() -> bool:
	var saved_fade := AudioManager.default_fade
	var saved_state := GameManager.current_state
	AudioManager.default_fade = 0.0

	GameManager.change_state(GameManager.GameState.CUTSCENE)
	_check(_near(AudioManager.get_layer_db(AudioManager.STEM_VOCALS), 0.0),
			"GameManager CUTSCENE state drives cutscene_start mix")
	GameManager.change_state(GameManager.GameState.PLAYING)
	_check(_near(AudioManager.get_layer_db(AudioManager.STEM_VOCALS), AudioManager.SILENT_DB),
			"GameManager PLAYING state drives cutscene_end mix")

	GameManager.hull_changed.emit(0, 2)
	_check(_near(AudioManager.get_layer_db(AudioManager.STEM_DRUMS), -18.0),
			"player damage signal drives player_hit mix")

	GameManager.change_state(saved_state)
	AudioManager.default_fade = saved_fade
	return true


func _test_missing_stems() -> bool:
	var script: Script = load(MANAGER_SCRIPT)
	_check(script != null, "AudioManager script loads")
	if script == null:
		return false
	var manager: Node = script.new()
	manager.autoplay_music = false
	manager.connect_game_events = false
	manager.stem_paths = {
		AudioManager.STEM_BASE_BEAT: MISSING_BASE,
		AudioManager.STEM_DRUMS: MISSING_DRUM,
		AudioManager.STEM_VOCALS: MISSING_VOCAL,
	}
	add_child(manager)

	var loaded: Dictionary = manager.load_stems()
	for layer in AudioManager.LAYERS:
		_check(loaded.has(layer) and loaded[layer] == false,
				"missing stem skipped for layer %s" % layer)
		_check(not manager.is_layer_available(layer),
				"layer %s marked unavailable" % layer)
	manager.play_default_music()
	_check(not manager.is_playing(), "no stems means no music playback is attempted")

	var drums_before: float = manager.get_layer_db(AudioManager.STEM_DRUMS)
	var vocals_before: float = manager.get_layer_db(AudioManager.STEM_VOCALS)
	manager.on_event(AudioManager.EVENT_CUTSCENE_START, 0.0)
	_check(_near(manager.get_layer_db(AudioManager.STEM_DRUMS), drums_before),
			"events do not touch a missing drum stem")
	_check(_near(manager.get_layer_db(AudioManager.STEM_VOCALS), vocals_before),
			"events do not touch a missing vocal stem")
	_check(manager.get_active_event() == AudioManager.EVENT_CUTSCENE_START,
			"event still recorded with all stems missing")

	manager.queue_free()
	return true
