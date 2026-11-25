extends Node

## AudioManager (Autoload)
## Dynamic layered audio using AudioServer buses and one AudioStreamPlayer per stem.
##
## Public API (see README.md, "Dynamic audio API"):
##   load_stems()                 -> Dictionary: stem -> loaded (false = skipped)
##   play_default_music()         -> void: start the base loop + available stems
##   play_music(stream, stem)     -> void: set/play an explicit stream (legacy API)
##   stop_music()                 -> void
##   set_layer(stem, db, fade)    -> Tween: tween a stem bus to a volume (fade < 0 uses default_fade)
##   get_layer_db(stem)           -> float
##   on_event(event, fade)        -> void: apply a named mix preset to available stems
##   play_sfx(stream, db)         -> void: one-shot SFX (never looped)
##   play_vocals(stream)/stop_vocals() -> legacy cutscene vocal helpers
##
## The base beat loops for the whole game. Drum/vocal stems are mixed through
## separate AudioServer buses; game events change the bus volumes with tweens.
## The tempo is never retimed: all stems are 16 beats at BPM and the engine's
## own playback position drives beat/bar signals. Missing stem files are simply
## skipped (no error, no player stream), so an incomplete asset checkout works.

# ---- Signals ----
signal beat_triggered(beat_count: int)
signal bar_triggered(bar_count: int)

# ---- Constants ----
const BPM := 140.0
const BEATS_PER_BAR := 4
const LOOP_BEATS := 16
const DEFAULT_FADE := 1.2
const SILENT_DB := -60.0

# Bus names. Music is the parent of every music stem; SFX stays on Master.
const STEM_MASTER := "Music"
const STEM_BASE_BEAT := "BaseBeat"
const STEM_DRUMS := "Drums"
const STEM_INSTRUMENTS := "Instruments"
const STEM_VOCALS := "Vocals"
const STEM_SFX := "SFX"
const LAYERS: Array[String] = [STEM_BASE_BEAT, STEM_DRUMS, STEM_INSTRUMENTS, STEM_VOCALS]

# Only stems delivered by task [3.1] are referenced. Instruments is intentionally
# absent: its layer is created but skipped until an asset exists.
const STEM_PATHS := {
	STEM_BASE_BEAT: "res://assets/audio/music/base_beat.wav",
	STEM_DRUMS: "res://assets/audio/music/drums.wav",
	STEM_VOCALS: "res://assets/audio/music/vocals.wav",
}

# Event names accepted by on_event().
const EVENT_STAGE_START := "stage_start"
const EVENT_ENEMY_SPAWNED := "enemy_spawned"
const EVENT_ENEMY_DESTROYED := "enemy_destroyed"
const EVENT_PLAYER_HIT := "player_hit"
const EVENT_STAGE_CLEAR := "stage_clear"
const EVENT_CUTSCENE_START := "cutscene_start"
const EVENT_CUTSCENE_END := "cutscene_end"
const EVENT_GAME_OVER := "game_over"

# Mix presets. Omitted stems keep their current volume; the base beat is never
# silenced. Missing stems are skipped by on_event().
const MIXES := {
	EVENT_STAGE_START: {STEM_BASE_BEAT: 0.0, STEM_DRUMS: -9.0, STEM_VOCALS: SILENT_DB},
	EVENT_ENEMY_SPAWNED: {STEM_DRUMS: -3.0, STEM_VOCALS: SILENT_DB},
	EVENT_ENEMY_DESTROYED: {STEM_DRUMS: -6.0},
	EVENT_PLAYER_HIT: {STEM_DRUMS: -18.0, STEM_VOCALS: SILENT_DB},
	EVENT_STAGE_CLEAR: {STEM_DRUMS: SILENT_DB, STEM_VOCALS: -6.0},
	EVENT_CUTSCENE_START: {STEM_DRUMS: SILENT_DB, STEM_VOCALS: 0.0},
	EVENT_CUTSCENE_END: {STEM_DRUMS: -9.0, STEM_VOCALS: SILENT_DB},
	EVENT_GAME_OVER: {STEM_DRUMS: SILENT_DB, STEM_VOCALS: SILENT_DB},
}

# ---- Configuration ----
## Music is started explicitly by the main scene; tests can opt in per instance.
@export var autoplay_music: bool = false
@export var connect_game_events: bool = true
@export var default_fade: float = DEFAULT_FADE
@export var stem_paths: Dictionary = {}

# ---- State ----
var _players: Dictionary = {}
var _available: Dictionary = {}
var _layer_tweens: Dictionary = {}
var _is_playing: bool = false
var _active_event: String = ""
var _sec_per_beat: float = 60.0 / BPM
var _loop_index: int = 0
var _last_playback_position: float = 0.0
var _last_emitted_beat: int = 0
var _bar_count: int = 0


func _ready() -> void:
	_setup_buses()
	_setup_players()
	if stem_paths.is_empty():
		stem_paths = STEM_PATHS.duplicate(true)
	load_stems()
	if connect_game_events:
		_connect_game_events()
	if autoplay_music:
		play_default_music()


func _exit_tree() -> void:
	for layer in _layer_tweens:
		var tween: Tween = _layer_tweens[layer]
		if tween != null and tween.is_valid():
			tween.kill()
	_layer_tweens.clear()


# ---- Bus / player setup ----
func _setup_buses() -> void:
	_create_bus(STEM_MASTER)
	for bus_name in LAYERS:
		_create_bus(bus_name)
		_set_bus_send(bus_name, STEM_MASTER)
	_create_bus(STEM_SFX)
	_set_bus_send(STEM_SFX, "Master")


func _create_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) != -1:
		return
	AudioServer.add_bus()
	var idx := AudioServer.bus_count - 1
	AudioServer.set_bus_name(idx, bus_name)
	AudioServer.set_bus_send(idx, "Master")


func _set_bus_send(bus_name: String, target: String) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx != -1:
		AudioServer.set_bus_send(idx, target)


func _setup_players() -> void:
	for layer in LAYERS:
		if _players.has(layer):
			continue
		var player := AudioStreamPlayer.new()
		player.name = layer + "Player"
		player.bus = layer
		add_child(player)
		_players[layer] = player


# ---- Stem loading ----
## Loads every configured stem. A missing/invalid file marks that layer as
## unavailable and is skipped everywhere else; no error is raised.
func load_stems() -> Dictionary:
	var loaded := {}
	for layer in LAYERS:
		var path: String = str(stem_paths.get(layer, ""))
		var ok := false
		if path != "" and ResourceLoader.exists(path):
			var stream := load(path) as AudioStream
			if stream != null:
				_enable_music_loop(stream)
				var player: AudioStreamPlayer = _players.get(layer, null)
				if player != null:
					player.stream = stream
				ok = true
		_available[layer] = ok
		loaded[layer] = ok
	return loaded


func is_layer_available(layer: String) -> bool:
	return bool(_available.get(layer, false))


## Music stems are 16-beat loops. Godot imports the WAV smpl chunk as a looping
## AudioStreamWAV, but enforce it on the stream in case the preset is overridden.
## SFX use play_sfx() and deliberately stay one-shot.
func _enable_music_loop(stream: AudioStream) -> void:
	if stream is AudioStreamWAV:
		var wav := stream as AudioStreamWAV
		var frames := int(round(wav.get_length() * float(wav.get_mix_rate())))
		if frames <= 0:
			push_warning("AudioManager: cannot loop an empty WAV stream")
			return
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = frames  # Godot loop end is exclusive
	elif stream is AudioStreamOggVorbis:
		var ogg := stream as AudioStreamOggVorbis
		ogg.loop = true
		ogg.loop_offset = 0.0
	elif stream is AudioStreamMP3:
		var mp3 := stream as AudioStreamMP3
		mp3.loop = true
		mp3.loop_offset = 0.0


# ---- Playback ----
## Starts the base beat and every available stem together. Loops keep them
## phase-aligned; no stream is sped up, slowed down or manually re-positioned.
func play_default_music() -> void:
	var started := false
	for layer in LAYERS:
		if not is_layer_available(layer):
			continue
		var player: AudioStreamPlayer = _players.get(layer, null)
		if player == null or player.stream == null:
			continue
		if not player.playing:
			player.play()
		started = true
	if not started:
		return
	_is_playing = true
	_loop_index = 0
	_last_playback_position = 0.0
	_last_emitted_beat = 0
	_bar_count = 0
	on_event(EVENT_STAGE_START, 0.0)


func play_music(stream: AudioStream, stem: String = STEM_BASE_BEAT) -> void:
	var player: AudioStreamPlayer = _players.get(stem, null)
	if player == null:
		push_warning("AudioManager: unknown stem '%s'" % stem)
		return
	if stream == null:
		push_warning("AudioManager: play_music called with no stream")
		return
	_enable_music_loop(stream)
	player.stream = stream
	_available[stem] = true
	player.play()
	if stem == STEM_BASE_BEAT:
		_is_playing = true
		_loop_index = 0
		_last_playback_position = 0.0
		_last_emitted_beat = 0
		_bar_count = 0


func stop_music() -> void:
	for layer in _players:
		var player: AudioStreamPlayer = _players[layer]
		player.stop()
	_is_playing = false


func get_player(layer: String) -> AudioStreamPlayer:
	return _players.get(layer, null)


func is_playing() -> bool:
	return _is_playing


# ---- Layer mix ----
## Tween a stem bus to a target dB. fade < 0 uses default_fade; fade == 0 is
## immediate. Returns the Tween (tests can custom_step it; callers can await it).
func set_layer(layer: String, volume_db: float, fade: float = -1.0) -> Tween:
	var idx := AudioServer.get_bus_index(layer)
	if idx == -1:
		push_warning("AudioManager: unknown layer '%s'" % layer)
		return null
	_stop_layer_tween(layer)
	var duration := default_fade if fade < 0.0 else maxf(0.0, fade)
	if is_equal_approx(duration, 0.0):
		AudioServer.set_bus_volume_db(idx, volume_db)
		return null
	var tween := create_tween()
	tween.tween_method(
		func(value: float): AudioServer.set_bus_volume_db(idx, value),
		AudioServer.get_bus_volume_db(idx), volume_db, duration
	)
	tween.finished.connect(func(): _layer_tweens.erase(layer))
	_layer_tweens[layer] = tween
	return tween


func get_layer_db(layer: String) -> float:
	var idx := AudioServer.get_bus_index(layer)
	if idx == -1:
		push_warning("AudioManager: unknown layer '%s'" % layer)
		return 0.0
	return AudioServer.get_bus_volume_db(idx)


func _stop_layer_tween(layer: String) -> void:
	var tween: Tween = _layer_tweens.get(layer, null)
	if tween != null and tween.is_valid():
		tween.kill()
	_layer_tweens.erase(layer)


## Apply a named mix preset (see MIXES). Layers without a loaded stem are
## skipped; unknown events are ignored. This is the single event entry point.
func on_event(event: String, fade: float = -1.0) -> void:
	if not MIXES.has(event):
		push_warning("AudioManager: unknown event '%s'" % event)
		return
	_active_event = event
	var mix = MIXES[event]
	for layer in mix:
		if not is_layer_available(layer):
			continue
		set_layer(layer, float(mix[layer]), fade)


func get_active_event() -> String:
	return _active_event


# ---- Existing GameManager events ----
func _connect_game_events() -> void:
	GameManager.game_state_changed.connect(_on_game_state_changed)
	GameManager.stage_changed.connect(func(_stage_id: int): on_event(EVENT_STAGE_START))
	GameManager.stage_cleared.connect(func(): on_event(EVENT_STAGE_CLEAR))
	GameManager.player_died.connect(func(): on_event(EVENT_GAME_OVER))
	GameManager.hull_changed.connect(_on_player_damage)
	GameManager.shield_changed.connect(_on_player_shield_damage)


func _on_game_state_changed(state: int) -> void:
	match state:
		GameManager.GameState.CUTSCENE:
			on_event(EVENT_CUTSCENE_START)
		GameManager.GameState.PLAYING:
			on_event(EVENT_CUTSCENE_END)
		GameManager.GameState.GAME_OVER, GameManager.GameState.VICTORY:
			on_event(EVENT_GAME_OVER)


func _on_player_damage(_ship_index: int, _value: int) -> void:
	on_event(EVENT_PLAYER_HIT)


func _on_player_shield_damage(_ship_index: int, _side: String, _value: int) -> void:
	on_event(EVENT_PLAYER_HIT)


# ---- SFX / legacy vocal helpers ----
func play_sfx(stream: AudioStream, volume_db: float = 0.0) -> void:
	if stream == null:
		return
	var player := AudioStreamPlayer.new()
	player.bus = STEM_SFX
	player.volume_db = volume_db
	player.stream = stream
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()


func play_vocals(stream: AudioStream) -> void:
	if stream == null or not is_layer_available(STEM_VOCALS):
		return
	_enable_music_loop(stream)
	var player: AudioStreamPlayer = _players[STEM_VOCALS]
	player.stream = stream
	player.play()
	set_layer(STEM_VOCALS, 0.0, 0.0)


func stop_vocals() -> void:
	var player: AudioStreamPlayer = _players.get(STEM_VOCALS, null)
	if player != null:
		player.stop()


# ---- Beat/bar tracking (engine playback position, never wall clock) ----
func _process(_delta: float) -> void:
	if not _is_playing:
		return
	var player: AudioStreamPlayer = _players.get(STEM_BASE_BEAT, null)
	if player == null or player.stream == null:
		return
	if player.stream.get_length() <= 0.0:
		return
	var position := player.get_playback_position()
	if position < _last_playback_position - 0.1:
		# get_playback_position() wraps at the loop seam; count a new loop.
		_loop_index += 1
	_last_playback_position = position
	var beat_in_loop := clampi(int(floor(position / _sec_per_beat)), 0, LOOP_BEATS - 1)
	var absolute_beat := _loop_index * LOOP_BEATS + beat_in_loop
	while _last_emitted_beat < absolute_beat:
		_last_emitted_beat += 1
		beat_triggered.emit(_last_emitted_beat)
		if _last_emitted_beat % BEATS_PER_BAR == 0:
			_bar_count += 1
			bar_triggered.emit(_bar_count)


func get_beat_count() -> int:
	return _last_emitted_beat


func get_bar_count() -> int:
	return _bar_count


func get_sec_per_beat() -> float:
	return _sec_per_beat
