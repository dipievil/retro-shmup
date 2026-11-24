class_name SpriteSheet
extends RefCounted

## Builds Godot visuals from the Aseprite sheet exports in assets/sprites.
##
## Godot 4 loads Aseprite JSON-array metadata as a JSON Resource but does not
## turn it into SpriteFrames, so each frame is rebuilt as an AtlasTexture over
## the exported PNG. Aseprite animation tags become SpriteFrames animations when
## the export includes meta.frameTags; otherwise every sheet gets a "default"
## animation with all of its frames. Missing files produce empty resources so
## callers can keep a graceful fallback.

const DEFAULT_ANIMATION: StringName = &"default"
const FALLBACK_FPS: float = 10.0


## Returns the parsed JSON metadata, or an empty dictionary when unavailable.
static func metadata(json_path: String) -> Dictionary:
	if json_path.is_empty() or not ResourceLoader.exists(json_path):
		return {}
	var resource := load(json_path)
	if resource is not JSON:
		return {}
	var parsed: Variant = (resource as JSON).get_data()
	return parsed if parsed is Dictionary else {}


## Returns an AtlasTexture for one frame entry of an Aseprite JSON-array sheet.
static func frame_texture(sheet: Texture2D, entry: Dictionary) -> AtlasTexture:
	var rect: Dictionary = entry.get("frame", {})
	var atlas := AtlasTexture.new()
	atlas.atlas = sheet
	atlas.region = Rect2(
		float(rect.get("x", 0)),
		float(rect.get("y", 0)),
		float(rect.get("w", 0)),
		float(rect.get("h", 0)),
	)
	return atlas


## Returns the first frame of a sheet, or null when the sheet cannot be loaded.
static func load_texture(
	sheet_path: String,
	json_path: String,
	frame_index: int = 0,
) -> AtlasTexture:
	var sheet := _load_texture(sheet_path)
	var entries: Array = metadata(json_path).get("frames", []) as Array
	if sheet == null or frame_index < 0 or frame_index >= entries.size():
		return null
	var entry: Variant = entries[frame_index]
	return frame_texture(sheet, entry) if entry is Dictionary else null


## Returns SpriteFrames with a "default" animation plus one animation per
## Aseprite tag (if the JSON export carries frameTags). Pass `loop = false` for
## one-shot effects: Godot only emits `animation_finished` for non-looping
## animations, so looping ones never run their cleanup callbacks.
static func load_frames(
	sheet_path: String,
	json_path: String,
	loop: bool = true,
) -> SpriteFrames:
	var frames := SpriteFrames.new()
	var sheet := _load_texture(sheet_path)
	var data := metadata(json_path)
	var entries: Array = data.get("frames", []) as Array
	if sheet == null or entries.is_empty():
		return frames

	var fps := _frames_per_second(entries)
	_fill_animation(frames, DEFAULT_ANIMATION, sheet, entries, 0, entries.size(), fps, loop)

	var meta: Dictionary = data.get("meta", {})
	var tags: Array = meta.get("frameTags", []) as Array
	for tag in tags:
		if not tag is Dictionary:
			continue
		var name := String(tag.get("name", ""))
		if name.is_empty() or name == &"default" or frames.has_animation(name):
			continue
		var from := maxi(int(tag.get("from", 0)), 0)
		var to := mini(int(tag.get("to", entries.size() - 1)), entries.size() - 1)
		if to < from:
			continue
		_fill_animation(frames, name, sheet, entries, from, to + 1, fps, loop)
	return frames


## True when the resource contains at least one usable frame for the animation.
static func has_frames(frames: SpriteFrames, animation: StringName = DEFAULT_ANIMATION) -> bool:
	return (frames != null and frames.has_animation(animation)
		and frames.get_frame_count(animation) > 0)


static func _load_texture(path: String) -> Texture2D:
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D


static func _frames_per_second(entries: Array) -> float:
	var first: Variant = entries[0]
	if first is Dictionary:
		var duration := float((first as Dictionary).get("duration", 0))
		if duration > 0.0:
			return 1000.0 / duration
	return FALLBACK_FPS


static func _fill_animation(
	frames: SpriteFrames,
	animation: StringName,
	sheet: Texture2D,
	entries: Array,
	from: int,
	to: int,
	fps: float,
	loop: bool,
) -> void:
	if not frames.has_animation(animation):
		frames.add_animation(animation)
	for i in range(from, to):
		var entry: Variant = entries[i]
		if entry is Dictionary:
			frames.add_frame(animation, frame_texture(sheet, entry))
	frames.set_animation_speed(animation, fps)
	frames.set_animation_loop(animation, loop)
