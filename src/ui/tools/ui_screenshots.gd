extends SceneTree
## QA tool: screenshots of every UI screen (see ui_screenshot_director.gd).
##   GODOT=<godot> tools/godot_run.sh --resolution 1280x720 -s res://src/ui/tools/ui_screenshots.gd -- --out=<abs dir> [--shots=01,05]
## The work happens in a Node added after the autoloads exist (a main-loop script is
## compiled before them and cannot name them).

const DIRECTOR := "res://src/ui/tools/ui_screenshot_director.gd"


func _initialize() -> void:
	_start.call_deferred()


func _start() -> void:
	var director := (load(DIRECTOR) as GDScript).new() as Node
	director.name = "UiScreenshotDirector"
	root.add_child(director)
