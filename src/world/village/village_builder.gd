extends SceneTree
## Generates src/world/village/village.tscn (+ village_grass.scn, ground_shape.res) from
## data/world/village_layout.json (docs/PHASE7_DESIGN.md §4.1–§4.5). Needs a real renderer (headless
## drops MultiMesh data):
##   tools/godot_run.sh -s res://src/world/village/village_builder.gd
## graveyard_builder.gd runs the same build before it instances the village into the world (then
## graveyard.tscn has to be rebuilt as well – the world builder does both).

const Build := preload("res://src/world/village/village_build.gd")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame  # autoloads (Database) are ready after the first frame
	Build.build_and_save(self)
	print("BUILD OK")
	quit()
