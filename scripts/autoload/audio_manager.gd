extends Node

## AudioManager (Autoload)
## Dynamic layered audio system using AudioServer buses.
## Manages base beat, drums, instruments, and vocals as separate stems.
## Stems are mixed in/out based on gameplay events (stage, enemies, cutscenes).

# ---- Signals ----
signal beat_triggered(beat_count: int)
signal bar_triggered(bar_count: int)

# ---- Constants ----
const BPM := 140.0
const BEATS_PER_BAR := 4
const SAMPLE_RATE := 44100.0

# Stem bus names — each gets its own AudioBus in Godot
const STEM_MASTER := "Music"
const STEM_BASE_BEAT := "BaseBeat"
const STEM_DRUMS := "Drums"
const STEM_INSTRUMENTS := "Instruments"
const STEM_VOCALS := "Vocals"
const STEM_SFX := "SFX"

# ---- State ----
var _beat_count: int = 0
var _bar_count: int = 0
var _sec_per_beat: float = 0.0
var _song_position: float = 0.0
var _song_position_dsp: float = 0.0
var _last_beat_time: float = 0.0
var _is_playing: bool = false

# AudioStreamPlayer references per stem
var _players: Dictionary = {}


func _ready() -> void:
	_setup_buses()
	_setup_players()
	_sec_per_beat = 60.0 / BPM


func _process(_delta: float) -> void:
	if not _is_playing:
		return
	_song_position = Time.get_ticks_msec() / 1000.0 - _song_position_dsp
	var beat_time := _song_position - _last_beat_time
	if beat_time >= _sec_per_beat:
		_beat_count += 1
		_last_beat_time += _sec_per_beat
		beat_triggered.emit(_beat_count)
		if _beat_count % BEATS_PER_BAR == 0:
			_bar_count += 1
			bar_triggered.emit(_bar_count)


# ---- Bus Setup ----
func _setup_buses() -> void:
	# Master bus already exists; create stem buses as children
	_create_bus(STEM_BASE_BEAT)
	_create_bus(STEM_DRUMS)
	_create_bus(STEM_INSTRUMENTS)
	_create_bus(STEM_VOCALS)
	_create_bus(STEM_SFX)


func _create_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) == -1:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, bus_name)
		var idx := AudioServer.get_bus_index(bus_name)
		AudioServer.set_bus_send(idx, "Master")


# ---- Player Setup ----
func _setup_players() -> void:
	for stem_name in [STEM_BASE_BEAT, STEM_DRUMS, STEM_INSTRUMENTS, STEM_VOCALS]:
		var player := AudioStreamPlayer.new()
		player.name = stem_name + "Player"
		player.bus = stem_name
		add_child(player)
		_players[stem_name] = player


# ---- Public API ----
func play_music(stream: AudioStream, stem: String = STEM_BASE_BEAT) -> void:
	if not _players.has(stem):
		push_warning("AudioManager: unknown stem '%s'" % stem)
		return
	var player: AudioStreamPlayer = _players[stem]
	player.stream = stream
	player.play()
	if not _is_playing:
		_is_playing = true
		_song_position_dsp = Time.get_ticks_msec() / 1000.0
		_last_beat_time = 0.0
		_beat_count = 0
		_bar_count = 0


func stop_music() -> void:
	for stem_name in _players:
		var player: AudioStreamPlayer = _players[stem_name]
		player.stop()
	_is_playing = false


func set_stem_volume(stem: String, volume_db: float) -> void:
	var idx := AudioServer.get_bus_index(stem)
	if idx != -1:
		AudioServer.set_bus_volume_db(idx, volume_db)


func fade_stem(stem: String, target_db: float, duration: float = 1.0) -> void:
	var idx := AudioServer.get_bus_index(stem)
	if idx == -1:
		return
	var current_db := AudioServer.get_bus_volume_db(idx)
	var tween := create_tween()
	tween.tween_method(
		func(v): AudioServer.set_bus_volume_db(idx, v),
		current_db, target_db, duration
	)


func play_sfx(stream: AudioStream, volume_db: float = 0.0) -> void:
	var player := AudioStreamPlayer.new()
	player.bus = STEM_SFX
	player.volume_db = volume_db
	player.stream = stream
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()


# ---- Cutscene vocals ----
func play_vocals(stream: AudioStream) -> void:
	var player: AudioStreamPlayer = _players.get(STEM_VOCALS, null)
	if player:
		player.stream = stream
		player.play()
		set_stem_volume(STEM_VOCALS, 0.0)


func stop_vocals() -> void:
	var player: AudioStreamPlayer = _players.get(STEM_VOCALS, null)
	if player:
		player.stop()


# ---- Beat info ----
func get_beat_count() -> int:
	return _beat_count


func get_bar_count() -> int:
	return _bar_count


func get_sec_per_beat() -> float:
	return _sec_per_beat


func is_on_beat(window: float = 0.1) -> bool:
	var time_since_beat := _song_position - _last_beat_time
	return time_since_beat <= window
