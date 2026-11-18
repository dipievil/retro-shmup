class_name WeaponResources
extends RefCounted

## Shared lookup of optional weapon assets.
##
## Sprites (task-2) and SFX (task-3) are authored in sibling tasks and may not be
## present yet. Keeping the expected paths here lets weapons reference them now
## without hard failures: first_existing() returns null when nothing is imported.
## See docs/game_design.md ("Weapon types") and docs/plan.md ("Assets").

const SPRITE_PATHS := {
	"laser": [
		"res://assets/sprites/player/laser.png",
		"res://assets/sprites/player/laser_projectile.png",
		"res://assets/sprites/player/ship_laser.png",
		"res://assets/sprites/effects/laser.png",
	],
	"missile": [
		"res://assets/sprites/player/missile.png",
		"res://assets/sprites/player/missile_projectile.png",
		"res://assets/sprites/player/ship_missile.png",
		"res://assets/sprites/effects/missile.png",
	],
	"bomb": [
		"res://assets/sprites/player/bomb.png",
		"res://assets/sprites/player/bomb_projectile.png",
		"res://assets/sprites/player/ship_bomb.png",
		"res://assets/sprites/effects/bomb.png",
	],
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


## Returns the first path that is actually imported, or null when none exists.
static func first_existing(paths: Array) -> Resource:
	for path in paths:
		if path is String and not path.is_empty() and ResourceLoader.exists(path):
			var resource: Resource = load(path)
			if resource != null:
				return resource
	return null
