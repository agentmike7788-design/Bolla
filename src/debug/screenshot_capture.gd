class_name ScreenshotCapture
extends Node
## Automated screenshot series for art-direction reviews.
## Start the game with:  -- --capture=<absolute output dir> [--shots=01,05]
## Each shot: atmosphere index, orthographic flag, camera distance, focus point.

@export var settle_frames: int = 45

var shots: Array[Dictionary] = []
var output_dir: String = ""


static func requested_dir() -> String:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="):
			return arg.trim_prefix("--capture=")
	return ""


## Optional  --shots=01,05  limits the series to shots with these number prefixes.
static func requested_filter() -> PackedStringArray:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			return arg.trim_prefix("--shots=").split(",", false)
	return PackedStringArray()


func run(atmosphere: AtmosphereController, rig: CameraRig, focus: Node3D, hud: CanvasLayer) -> void:
	DirAccess.make_dir_recursive_absolute(output_dir)
	hud.visible = false
	var report: PackedStringArray = []
	for shot: Dictionary in shots:
		atmosphere.apply(shot.get("atmosphere", 0))
		rig.orthographic = shot.get("ortho", false)
		rig.set_distance(shot.get("distance", rig.distance))
		rig.pitch_deg = shot.get("pitch", rig.pitch_deg)
		focus.global_position = shot.get("focus", focus.global_position)
		rig.snap()
		for i: int in settle_frames:
			await get_tree().process_frame
		var path := output_dir.path_join("%s.png" % shot.name)
		get_viewport().get_texture().get_image().save_png(path)
		var info := "%s  draw_calls=%d  objects=%d  primitives=%d" % [
			shot.name,
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME),
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)]
		print("[Capture] ", info)
		report.append(info)
	var f := FileAccess.open(output_dir.path_join("render_stats.txt"), FileAccess.WRITE)
	f.store_string("\n".join(report) + "\n")
	f.close()
	get_tree().quit()
