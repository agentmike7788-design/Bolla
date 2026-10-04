extends SceneTree
## Starts the frame-time probe (src/debug/perf_probe.gd) without the title screen:
##   godot --headless --path . -s res://src/debug/perf_probe_run.gd -- [--out=/abs/result.json] [--only=map]


func _initialize() -> void:
	var probe: Node = (load("res://src/debug/perf_probe.gd") as GDScript).new()
	probe.name = "PerfProbe"
	root.add_child.call_deferred(probe)
