extends SceneTree
## Scratch probe (G8 Runde 2): renders the lantern spot MultiMesh over a grey plane – does it draw in this renderer?
##   tools/godot_run.sh [--rendering-method gl_compatibility --rendering-driver opengl3] -s res://tools/qa/qa_spot_probe.gd -- --out=/abs/file.png


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var out := "/tmp/spot_probe.png"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
	var world := Node3D.new()
	root.add_child(world)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.05, 0.05, 0.08)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.3, 0.3, 0.4)
	world.add_child(env)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(20, 20)
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.3, 0.3, 0.3)
	pm.material = gm
	ground.mesh = pm
	world.add_child(ground)
	var cam := Camera3D.new()
	world.add_child(cam)
	cam.position = Vector3(0, 8, 8)
	cam.look_at(Vector3.ZERO)
	cam.current = true
	var pool := CarriedLanterns.new()
	world.add_child(pool)
	var mm := (pool.get_node("LanternSpots") as MultiMeshInstance3D).multimesh
	mm.visible_instance_count = 2
	mm.set_instance_transform(0, Transform3D(Basis().scaled(Vector3(1.6, 1, 1.6)), Vector3(-2, 0.05, 0)))
	mm.set_instance_color(0, Color(0.3, 0.19, 0.09))
	mm.set_instance_transform(1, Transform3D(Basis().scaled(Vector3(1.6, 1, 1.6)), Vector3(2, 0.05, 0)))
	mm.set_instance_color(1, Color(0.1, 0.06, 0.03))
	pool.set_process(false)
	for i: int in 20:
		await process_frame
	root.get_texture().get_image().save_png(out)
	quit()
