extends Node3D
## Art-direction prototype scene controller: camera/time toggles, HUD hint,
## automated screenshot series (see ScreenshotCapture).

@onready var atmosphere: AtmosphereController = $Atmosphere
@onready var rig: CameraRig = $CameraRig
@onready var player: Node3D = $Player
@onready var hud_label: Label = $HUD/Hint


func _ready() -> void:
	atmosphere.preset_changed.connect(func(_p: AtmospherePreset) -> void: _update_hud())
	rig.projection_changed.connect(func(_o: bool) -> void: _update_hud())
	_update_hud()
	var dir := ScreenshotCapture.requested_dir()
	if dir != "":
		_start_capture(dir)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("proto_toggle_camera"):
		rig.toggle_projection()
	elif event.is_action_pressed("proto_toggle_time"):
		atmosphere.cycle()


func _update_hud() -> void:
	hud_label.text = "WASD  Bewegen     Mausrad  Zoom     C  Kamera: %s     N  Zeit: %s" % [
		"Orthografisch" if rig.orthographic else "Perspektive", atmosphere.current().display_name]


func _start_capture(dir: String) -> void:
	var cap := ScreenshotCapture.new()
	cap.output_dir = dir
	var overview := Vector3(-0.5, 0.0, -0.8)
	var close := Vector3(1.8, 0.0, 0.0)
	cap.shots = [
		{"name": "01_day_perspective", "atmosphere": 0, "ortho": false, "distance": 28.0, "focus": overview},
		{"name": "02_day_orthographic", "atmosphere": 0, "ortho": true, "distance": 28.0, "focus": overview},
		{"name": "03_night_perspective", "atmosphere": 1, "ortho": false, "distance": 28.0, "focus": overview},
		{"name": "04_night_orthographic", "atmosphere": 1, "ortho": true, "distance": 28.0, "focus": overview},
		{"name": "05_day_closeup", "atmosphere": 0, "ortho": false, "distance": 12.0, "focus": close},
		{"name": "06_night_closeup", "atmosphere": 1, "ortho": false, "distance": 12.0, "focus": close},
	]
	var only := ScreenshotCapture.requested_filter()
	if not only.is_empty():
		cap.shots = cap.shots.filter(func(shot: Dictionary) -> bool: return String(shot.name).left(2) in only)
	add_child(cap)
	# Park the player where the close-ups look at, then run the series.
	player.global_position = Vector3(1.4, 0.0, -1.0)
	var anchor := Node3D.new()
	add_child(anchor)
	rig.target = anchor
	cap.run(atmosphere, rig, anchor, $HUD)
