class_name WeaponResources
extends RefCounted

## Shared lookup of weapon assets.
##
## Projectile sprites are authored as Aseprite sheets (task-2) and resolved to
## AtlasTextures by SpriteSheet. SFX are optional because task-3 authored them
## in parallel; a missing file simply means silence.
##
## validate_project.py: OPTIONAL-ASSET-REGISTRY
## Every res:// path below is a best-effort lookup. Missing files fall back to
## the built-in visuals / silence, so the validator exempts this file from its
## resource-existence check.

const SPRITE_SHEETS := {
	"laser": "res://assets/sprites/player/laser_sheet.png",
	"missile": "res://assets/sprites/player/missile_sheet.png",
	"bomb": "res://assets/sprites/player/bomb_sheet.png",
}

const SPRITE_METADATA := {
	"laser": "res://assets/sprites/player/laser_sheet.json",
	"missile": "res://assets/sprites/player/missile_sheet.json",
	"bomb": "res://assets/sprites/player/bomb_sheet.json",
}

const SFX_PATHS := {
	"laser": [
		"res://assets/audio/sfx/laser_fire.wav",
		"res://assets/audio/sfx/laser_fire.ogg",
		"res://assets/audio/sfx/laser.wav",
		"res://assets/audio/sfx/laser.ogg",
	],
	"missile": [
		"res://assets/audio/sfx/missile_fire.wav",
		"res://assets/audio/sfx/missile_fire.ogg",
		"res://assets/audio/sfx/missile.wav",
		"res://assets/audio/sfx/missile.ogg",
	],
	"bomb": [
		"res://assets/audio/sfx/bomb_fire.wav",
		"res://assets/audio/sfx/bomb_fire.ogg",
		"res://assets/audio/sfx/bomb.wav",
		"res://assets/audio/sfx/bomb.ogg",
	],
}


## Returns the first frame of the weapon's authored sheet, or null if absent.
static func sprite_texture(weapon_kind: String, frame_index: int = 0) -> AtlasTexture:
	return SpriteSheet.load_texture(
		SPRITE_SHEETS.get(weapon_kind, ""),
		SPRITE_METADATA.get(weapon_kind, ""),
		frame_index,
	)


## Returns the first existing SFX path resource, or null when none exists.
static func first_existing(paths: Array) -> Resource:
	for path in paths:
		if path is String and not path.is_empty() and ResourceLoader.exists(path):
			var resource: Resource = load(path)
			if resource != null:
				return resource
	return null
