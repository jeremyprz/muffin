extends Node

## 3-tier version identifier: MAJOR.MINOR.PATCH
## MAJOR (0): pre-release. 1 = first full release.
## MINOR (X): feature milestones, new systems, gameplay changes.
## PATCH (Y): visual-only changes, art tweaks, UI polish. No gameplay impact.

const MAJOR := 0
const MINOR := 10
const PATCH := 63

static func get_string() -> String:
	return "%d.%d.%d" % [MAJOR, MINOR, PATCH]


static func is_source_mode() -> bool:
	## Returns true when running from source code (dev environment).
	## Checks if project.godot exists as a real file on the filesystem.
	return FileAccess.file_exists("res://project.godot")
