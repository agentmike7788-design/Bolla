extends SceneTree
## Bakes the map's parchment (MapPaint.paper_image with the colours of data/config/map_config.tres) into
## assets/ui/map/map_paper_<paper>_<dark>.png, so the game never computes it at runtime (G7 Runde 2).
##   godot --headless --path . -s res://tools/map/bake_map_paper.gd
## Afterwards: godot --headless --path . --import

const CONFIG := "res://data/config/map_config.tres"


func _initialize() -> void:
	var cfg := load(CONFIG)
	var paper: Color = cfg.get(&"paper")
	var dark: Color = cfg.get(&"paper_dark")
	var painter: GDScript = load("res://src/ui/map/map_paint.gd")
	var img: Image = painter.call(&"paper_image", paper, dark)
	var path: String = painter.call(&"paper_asset_path", paper, dark)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var err := img.save_png(ProjectSettings.globalize_path(path))
	print("[MapPaper] %s → %s" % [path, error_string(err)])
	quit(0 if err == OK else 1)
