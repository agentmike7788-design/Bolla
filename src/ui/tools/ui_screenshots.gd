extends SceneTree
## QA tool: screenshots of every UI screen (see ui_screenshot_director.gd).
##   GODOT=<godot> tools/godot_run.sh --resolution 1280x720 -s res://src/ui/tools/ui_screenshots.gd -- --out=<abs dir> [--shots=01,05]
## Phase 3 (over the graveyard world, ui_screenshot_director_phase3.gd): add --phase3.
## Phase 4 (panels of docs/PHASE4_DESIGN.md §7, ui_screenshot_director_phase4.gd): add --phase4.
## Phase 5 (panels of docs/PHASE5_DESIGN.md §7, ui_screenshot_director_phase5.gd): add --phase5.
## Phase 6 (panels of docs/PHASE6_DESIGN.md §7, ui_screenshot_director_phase6.gd): add --phase6.
## Phase 7 (panels of docs/PHASE7_DESIGN.md §7, ui_screenshot_director_phase7.gd): add --phase7.
## Phase 8 (panels of docs/PHASE8_DESIGN.md §7, ui_screenshot_director_phase8.gd): add --phase8.
## The work happens in a Node added after the autoloads exist (a main-loop script is
## compiled before them and cannot name them).

const DIRECTOR := "res://src/ui/tools/ui_screenshot_director.gd"
const DIRECTOR_PHASE3 := "res://src/ui/tools/ui_screenshot_director_phase3.gd"
const DIRECTOR_PHASE4 := "res://src/ui/tools/ui_screenshot_director_phase4.gd"
const DIRECTOR_PHASE5 := "res://src/ui/tools/ui_screenshot_director_phase5.gd"
const DIRECTOR_PHASE6 := "res://src/ui/tools/ui_screenshot_director_phase6.gd"
const DIRECTOR_PHASE7 := "res://src/ui/tools/ui_screenshot_director_phase7.gd"
const DIRECTOR_PHASE8 := "res://src/ui/tools/ui_screenshot_director_phase8.gd"


func _initialize() -> void:
	_start.call_deferred()


func _start() -> void:
	var args := OS.get_cmdline_user_args()
	var path := DIRECTOR_PHASE8 if "--phase8" in args else DIRECTOR_PHASE7 if "--phase7" in args else DIRECTOR_PHASE6 if "--phase6" in args else DIRECTOR_PHASE5 if "--phase5" in args else (DIRECTOR_PHASE4 if "--phase4" in args else (DIRECTOR_PHASE3 if "--phase3" in args else DIRECTOR))
	var director := (load(path) as GDScript).new() as Node
	director.name = "UiScreenshotDirector"
	root.add_child(director)
