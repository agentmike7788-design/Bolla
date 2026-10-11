extends "res://src/world/graveyard/graveyard_shots_phase8.gd"
## G8 Runde 2 (Licht, „im Browser wirkt der Lichtgang heller"): measures the brightness of the Phase-8 shots in the
## renderer it runs in – the mean luma of the frame (Rec. 709 over the sRGB pixels), the mean luma of the lantern
## spots (a disc of LANTERN_DISC m round the ground point under every carried lantern in view) and the brightest
## glass pixel of every lantern – and writes one line per shot (and variant) to <out>/light_match<suffix>.txt.
## Run the same shots once per renderer and compare (docs/reviews/phase8_round2/lichtgang_messung.md):
##   tools/godot_run.sh --resolution 1280x720 -s res://tools/qa/qa_light_match.gd -- --out=/abs/dir --shots=p8_22
##   tools/godot_run.sh --rendering-method gl_compatibility --rendering-driver opengl3 --resolution 1280x720 \
##       -s res://tools/qa/qa_light_match.gd -- --out=/abs/dir --shots=p8_22 --suffix=_web
## --variants=/abs/file.json: [{"name": "...", "presets": {"night": {"compat_exposure": 0.8, …}, …},
##   "lanterns": {"spot_energy_compat": 0.3, …}}, …] – every variant is applied to the loaded presets / the lantern
## config in memory (nothing is saved), the frame re-rendered and measured (a tuning sweep in one world load).
## --compat=0|1 forces AtmosphereController.compat_override (e.g. the Forward+ frame with the browser values).

const LANTERN_DISC := 0.9
const STEP := 2

var _variants: Array = []
var _lm_suffix: String = ""
var _match: PackedStringArray = []


func _run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--variants="):
			var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(arg.trim_prefix("--variants=")))
			_variants = raw if raw is Array else []
		elif arg.begins_with("--suffix="):
			_lm_suffix = arg.trim_prefix("--suffix=")
		elif arg.begins_with("--compat="):
			_force_compat = int(arg.trim_prefix("--compat="))
	await super._run()


var _force_compat: int = -1


func _save_frame(world: Node3D, shot_name: String, report: PackedStringArray) -> void:
	var atmo := world.get_node_or_null(^"Atmosphere")
	if atmo != null and _force_compat >= 0:
		atmo.set(&"compat_override", _force_compat)
		atmo.call(&"apply_time", float(root.get_node(^"TimeManager").call(&"get_minute_f")))
		for i: int in 8:
			await process_frame
	var pool := world.get_node_or_null(^"CarriedLanterns")
	if pool != null:
		pool.call(&"settle")
		var care0 := world.get_node_or_null(^"Systems/GraveCare")
		if care0 != null:
			care0.call(&"update_light_pool")
		await process_frame
	# measure the very frame that is saved (the render stats below re-draw the scene with other settings)
	var shot_image := root.get_texture().get_image()
	await super._save_frame(world, shot_name + _lm_suffix, report)
	_measure_line(world, shot_name + _lm_suffix, "base", shot_image)
	var snapshot := _snapshot(world)
	for v: Variant in _variants:
		if not (v is Dictionary):
			continue
		_restore(snapshot)
		_apply_variant(world, v as Dictionary)
		if atmo != null:
			atmo.call(&"apply_time", float(root.get_node(^"TimeManager").call(&"get_minute_f")))
		if pool != null:
			pool.call(&"settle")
		for i: int in 12:
			await process_frame
		var image := root.get_texture().get_image()
		image.save_jpg(_out.path_join("%s%s__%s.jpg" % [shot_name, _lm_suffix, (v as Dictionary).get("name", "v")]), 0.88)
		_measure_line(world, shot_name + _lm_suffix, str((v as Dictionary).get("name", "v")), image)
	_restore(snapshot)
	if atmo != null and not _variants.is_empty():
		atmo.call(&"apply_time", float(root.get_node(^"TimeManager").call(&"get_minute_f")))
	var f := FileAccess.open(_out.path_join("light_match%s.txt" % _lm_suffix), FileAccess.WRITE)
	f.store_string("\n".join(_match) + "\n")
	f.close()


## [resource, property, value] of every preset / lantern config property a variant may touch.
func _snapshot(world: Node3D) -> Array:
	var out: Array = []
	var res: Array = []
	var atmo := world.get_node_or_null(^"Atmosphere")
	if atmo != null:
		res.append_array(atmo.get(&"blend_presets"))
		res.append_array(atmo.get(&"presets"))
	var pool := world.get_node_or_null(^"CarriedLanterns")
	if pool != null:
		res.append(pool.get(&"config"))
	for r: Variant in res:
		var rr := r as Resource
		if rr == null:
			continue
		for prop: Dictionary in rr.get_property_list():
			if int(prop.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE != 0:
				out.append([rr, StringName(prop.name), rr.get(StringName(prop.name))])
	return out


static func _restore(snapshot: Array) -> void:
	for e: Array in snapshot:
		(e[0] as Resource).set(e[1], e[2])


func _apply_variant(world: Node3D, v: Dictionary) -> void:
	var atmo := world.get_node_or_null(^"Atmosphere")
	var presets: Dictionary = v.get("presets", {})
	if atmo != null:
		var all: Array = []
		all.append_array(atmo.get(&"blend_presets"))
		all.append_array(atmo.get(&"presets"))
		for p: Variant in all:
			var res := p as Resource
			if res == null:
				continue
			var id := str(res.get_meta(&"preset_id", res.resource_path.get_file().get_basename()))
			if presets.has(id):
				var values: Dictionary = presets[id]
				for key: String in values:
					var val: Variant = values[key]
					if val is Array:
						val = Color(float(val[0]), float(val[1]), float(val[2]), float(val[3]) if (val as Array).size() > 3 else 1.0)
					res.set(StringName(key), val)
	var pool := world.get_node_or_null(^"CarriedLanterns")
	var lan: Dictionary = v.get("lanterns", {})
	if pool != null and not lan.is_empty():
		var cfg := pool.get(&"config") as Resource
		for key: String in lan:
			cfg.set(StringName(key), lan[key])


func _measure_line(world: Node3D, shot_name: String, variant: String, image: Image) -> void:
	var cam := world.get_viewport().get_camera_3d()
	var w := image.get_width()
	var h := image.get_height()
	var sum := 0.0
	var n := 0
	for y: int in range(0, h, STEP):
		for x: int in range(0, w, STEP):
			sum += _luma(image.get_pixel(x, y))
			n += 1
	var mean := sum / maxf(float(n), 1.0)
	var spots: Array[float] = []
	var glass: Array[float] = []
	var pool := world.get_node_or_null(^"CarriedLanterns")
	if pool != null and cam != null:
		for lantern: Node3D in pool.call(&"visible_lanterns"):
			var c: Vector3 = pool.call(&"lantern_center", lantern)
			if cam.is_position_behind(c):
				continue
			var carrier := lantern
			while carrier != null and not carrier.is_in_group(&"npc") and not carrier.has_method(&"animation_player"):
				carrier = carrier.get_parent() as Node3D
			var ground := Vector3(c.x, carrier.global_position.y if carrier != null else c.y - 0.55, c.z)
			var sp := cam.unproject_position(ground)
			var edge := cam.unproject_position(ground + cam.global_basis.x * LANTERN_DISC)
			var r := maxf(sp.distance_to(edge), 3.0)
			if sp.x < r or sp.y < r or sp.x > w - r or sp.y > h - r:
				continue
			spots.append(_disc(image, sp, r, false))
			glass.append(_disc(image, cam.unproject_position(c), 4.0, true))
	var care := world.get_node_or_null(^"Systems/GraveCare")
	var line := ("%s  %s  renderer=%s  mean_luma=%.4f  spots=%d  spot_luma=%.4f  glass_max=%.4f  candle_lights=%d"
			+ "  lantern_lights=%d") % [shot_name, variant, RenderingServer.get_current_rendering_method(), mean, spots.size(),
			_avg(spots), _avg(glass), int(care.call(&"active_lights")) if care != null else -1,
			int(pool.call(&"lights_in_use")) if pool != null else -1]
	print("[LightMatch] ", line)
	if variant == "base" and cam != null:
		print("[LightMatch] lights in view: ", ", ".join(_lights_in_view(world, cam)))
	_match.append(line)


## Names (parent/name) of the visible omni / spot lights whose range reaches into the view (as the render stats count).
static func _lights_in_view(world: Node3D, cam: Camera3D) -> PackedStringArray:
	var out := PackedStringArray()
	var planes := cam.get_frustum()
	for node: Node in world.find_children("*", "Light3D", true, false):
		var l := node as Light3D
		if l is DirectionalLight3D or not l.is_visible_in_tree() or l.light_energy <= 0.01:
			continue
		var r := float(l.get(&"omni_range")) if l is OmniLight3D else float(l.get(&"spot_range"))
		var inside := true
		for plane: Plane in planes:
			if plane.distance_to(l.global_position) > r:
				inside = false
				break
		if inside:
			out.append("%s/%s" % [l.get_parent().name, l.name])
	return out


static func _disc(image: Image, at: Vector2, r: float, peak: bool) -> float:
	var sum := 0.0
	var n := 0
	var top := 0.0
	for y: int in range(int(at.y - r), int(at.y + r) + 1):
		for x: int in range(int(at.x - r), int(at.x + r) + 1):
			if x < 0 or y < 0 or x >= image.get_width() or y >= image.get_height():
				continue
			if Vector2(x, y).distance_squared_to(at) > r * r:
				continue
			var l := _luma(image.get_pixel(x, y))
			sum += l
			top = maxf(top, l)
			n += 1
	return top if peak else sum / maxf(float(n), 1.0)


static func _avg(values: Array[float]) -> float:
	if values.is_empty():
		return 0.0
	var s := 0.0
	for v: float in values:
		s += v
	return s / float(values.size())


static func _luma(c: Color) -> float:
	return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
