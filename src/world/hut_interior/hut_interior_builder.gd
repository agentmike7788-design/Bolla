extends SceneTree
## Generates src/world/hut_interior/hut_interior.tscn from data/world/hut_interior_layout.json
## (docs §11). Headless is fine (no MultiMesh):
##   godot --headless --path . -s res://src/world/hut_interior/hut_interior_builder.gd
## graveyard_builder.gd runs the same build before it instances the scene into the world.

const Build := preload("res://src/world/hut_interior/hut_interior_build.gd")
const OUT_SCENE := "res://src/world/hut_interior/hut_interior.tscn"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame  # autoloads (Database) are ready after the first frame
	save_scene(Build.build(Build.load_layout()))
	print("BUILD OK")
	quit()


## Packs and saves the interior (frees `node`).
static func save_scene(node: Node) -> void:
	var ps := PackedScene.new()
	var err := ps.pack(node)
	assert(err == OK, "pack failed: %s" % OUT_SCENE)
	err = ResourceSaver.save(ps, OUT_SCENE)
	assert(err == OK, "save failed: %s" % OUT_SCENE)
	print("  saved ", OUT_SCENE)
	node.free()
