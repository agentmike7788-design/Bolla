extends Node
## Boot scene: prints version info, then hands over to the start scene.

const PERF_PROBE := "res://src/debug/perf_probe.gd"

## Title screen (Fortsetzen / Neues Spiel / Beenden).
@export_file("*.tscn") var start_scene: String = "res://src/ui/title/title_screen.tscn"


func _ready() -> void:
	print("[Boot] The Last Gravekeeper v%s — debug=%s" % [GameConfig.version, GameConfig.debug_enabled])
	EventBus.game_booted.emit()
	if GameConfig.debug_enabled and "--perf-probe" in OS.get_cmdline_user_args():
		# G7 Runde 2: frame-time probe in an exported (browser) build – debug builds only.
		var probe: Node = (load(PERF_PROBE) as GDScript).new()
		probe.name = "PerfProbe"
		get_tree().root.add_child.call_deferred(probe)
	if start_scene != "":
		get_tree().change_scene_to_file.call_deferred(start_scene)
