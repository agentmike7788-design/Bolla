extends SceneTree
## Writes data/config/map_config.tres from the defaults of MapConfig (every value spelled out, so the
## data file is the one place to change them). Run once after adding a field:
##   godot --headless --path . -s res://tools/ui/gen_map_config.gd
## Existing values in the .tres are kept (the file is loaded first when present).

const SCRIPT_PATH := "res://src/ui/map/map_config.gd"
const OUT := "res://data/config/map_config.tres"


func _initialize() -> void:
	var script := load(SCRIPT_PATH) as GDScript
	var res: Resource = script.new()
	if ResourceLoader.exists(OUT):
		var old := load(OUT)
		if old != null and old.get_script() == script:
			res = old
	var lines := PackedStringArray([
		'[gd_resource type="Resource" script_class="MapConfig" load_steps=2 format=3]', "",
		'[ext_resource type="Script" path="%s" id="1"]' % SCRIPT_PATH, "", "[resource]", 'script = ExtResource("1")'])
	for p: Dictionary in res.get_property_list():
		if p.usage & PROPERTY_USAGE_SCRIPT_VARIABLE and p.usage & PROPERTY_USAGE_STORAGE:
			lines.append("%s = %s" % [p.name, var_to_str(res.get(p.name))])
	var f := FileAccess.open(OUT, FileAccess.WRITE)
	f.store_string("\n".join(lines) + "\n")
	f.close()
	print("[gen_map_config] ", OUT)
	quit()
