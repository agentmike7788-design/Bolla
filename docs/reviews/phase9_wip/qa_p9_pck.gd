extends SceneTree
## W3 QA (docs/PHASE9_DESIGN.md §12 W3 „Prüfung im exportierten pck"): the Phase-9 content inside the exported Web pck in
## the Compatibility renderer. Run from the project root:
##   godot --headless --path . --export-debug "Web" build/webqa/index.html
##   GODOT=<godot> tools/godot_run.sh --main-pack build/webqa/index.pck --rendering-method gl_compatibility \
##       --rendering-driver opengl3 --resolution 1280x720 -s /abs/docs/reviews/phase9_wip/qa_p9_pck.gd -- \
##       --out=/abs/dir --fixture=/abs/tests/fixtures/saves_v7/slot_p8_day63_kindly.json
## The checks are in qa_p9_pck_body.gd (next to this file), loaded once the autoloads are there.

var _body: RefCounted


func _initialize() -> void:
	_start.call_deferred()


func _start() -> void:
	await process_frame
	var script := load(get_script().resource_path.get_base_dir().path_join("qa_p9_pck_body.gd")) as GDScript
	_body = script.new()
	await _body.call(&"run", self)
