class_name AsepriteSheet
extends RefCounted

## Builds Godot SpriteFrames from an Aseprite "json-array" export and the
## matching sheet PNG. This only consumes sprites already imported on dev;
## no new art is authored here.

const DEFAULT_FRAME_RATE := 10.0


## Returns SpriteFrames with one animation built from the metadata's frames.
## The caller can change looping/speed afterwards (e.g. one-shot explosions).
static func build_sprite_frames(
	sheet_path: String,
	metadata_path: String,
	animation: StringName = &"default",
	frame_rate: float = DEFAULT_FRAME_RATE
) -> SpriteFrames:
	var frames := SpriteFrames.new()
	if frames.has_animation(animation):
		frames.remove_animation(animation)
	frames.add_animation(animation)
	frames.set_animation_loop(animation, true)

	var texture := load(sheet_path) as Texture2D
	if texture == null:
		push_error("AsepriteSheet: cannot load sprite sheet: %s" % sheet_path)
		return frames

	var metadata := _read_metadata(metadata_path)
	var entries: Array = metadata.get("frames", []) as Array
	if entries.is_empty():
		push_error("AsepriteSheet: no frames in metadata: %s" % metadata_path)
		return frames

	for i in range(entries.size()):
		var entry: Dictionary = entries[i] as Dictionary
		var rect: Dictionary = entry.get("frame", {}) as Dictionary
		if rect.is_empty():
			continue
		var atlas := AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = Rect2(
			float(rect.get("x", 0)),
			float(rect.get("y", 0)),
			float(rect.get("w", 0)),
			float(rect.get("h", 0))
		)
		var fallback_duration := 1000.0 / maxf(frame_rate, 0.01)
		var duration_ms := float(entry.get("duration", fallback_duration))
		frames.add_frame(animation, atlas, i, maxf(0.01, duration_ms / 1000.0))
	return frames


static func _read_metadata(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("AsepriteSheet: metadata not found: %s" % path)
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("AsepriteSheet: cannot open metadata: %s" % path)
		return {}
	var text := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		return parsed as Dictionary
	push_error("AsepriteSheet: invalid JSON metadata: %s" % path)
	return {}
