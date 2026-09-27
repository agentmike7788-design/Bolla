@tool
extends EditorScenePostImport
## Runs for every imported .glb (set as importer default in project.godot).
## Blender material names are mapped to shared Godot materials:
##   Blender material "mat_painted"  ->  res://assets/materials/mat_painted.tres
## Unknown names keep the imported material and print a warning.

const MATERIAL_DIR := "res://assets/materials/"


func _post_import(scene: Node) -> Object:
	for node: Node in scene.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh == null:
			continue
		for i: int in mi.mesh.get_surface_count():
			var mat := mi.mesh.surface_get_material(i)
			if mat == null:
				continue
			var path := MATERIAL_DIR + mat.resource_name + ".tres"
			if ResourceLoader.exists(path):
				mi.mesh.surface_set_material(i, load(path))
			else:
				push_warning("[Import] %s: no Godot material for '%s'" % [get_source_file(), mat.resource_name])
	return scene
