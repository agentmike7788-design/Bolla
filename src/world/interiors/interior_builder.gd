extends SceneTree
## Generates src/world/interiors/<room>_interior.tscn from data/world/interiors/<room>_layout.json
## (docs/PHASE6_DESIGN.md §4.7). Headless is fine (no MultiMesh):
##   godot --headless --path . -s res://src/world/interiors/interior_builder.gd -- --room=crypt
## Without --room all three rooms are built. graveyard_builder.gd runs the same build before it
## instances the rooms into the world (then graveyard.tscn has to be rebuilt as well).

const Build := preload("res://src/world/interiors/interior_build.gd")
const ROOMS: Array[String] = ["crypt", "chapel", "shed"]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame  # autoloads (Database) are ready after the first frame
	var rooms := ROOMS.duplicate()
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--room="):
			rooms = [arg.trim_prefix("--room=")]
	for room: String in rooms:
		Build.save_scene(Build.build(Build.load_layout(room)), room)
	print("BUILD OK")
	quit()
