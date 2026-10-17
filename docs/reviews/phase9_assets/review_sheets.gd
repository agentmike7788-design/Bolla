extends SceneTree
## Phase 9 asset review sheets (P7, docs/PHASE9_DESIGN.md §8, §11; copy of the Phase-8 tool): the lineup (the
## stranger beside the people he meets: Veit, Hanne, Quast, Johann, the gravekeeper; day and lantern light), the
## faces close up, one contact sheet per figure with every clip as a frame sequence, the props / items sheet and
## the scenes (Brenneisen at the inn table, Johann on a bench, the case at the gate). Needs a real renderer:
##   GODOT=<godot> tools/godot_run.sh --resolution 1600x900 -s res://docs/reviews/phase9_assets/review_sheets.gd \
##       -- --out=/abs/dir --mode=lineup|faces|clips|props|scenes [--filter=<name part>]
## Child meshes follow their glTF extras "show_with" (the clip shown); figures face +Z (the camera).

const DIR := "res://assets/models/characters/"
const NEW: Array[String] = ["ph_chr_stranger", "ph_chr_mourner_m_b"]
const OLD: Array[String] = ["ph_chr_gravekeeper", "ph_chr_beggar", "ph_chr_peddler", "ph_chr_v_surgeon", "ph_chr_v_mayor",
		"ph_chr_v_innkeeper", "ph_chr_carter"]
const LABELS := {
	"ph_chr_apprentice": "Jakob Wackernagel", "ph_chr_mourner_w_a": "Martha Kehr", "ph_chr_mourner_w_b": "Gesa Ott",
	"ph_chr_mourner_m_a": "Hinrich Brandt", "ph_chr_mourner_m_b": "Johann Sieber", "ph_chr_beggar": "Veit Ammer",
	"ph_chr_peddler": "Hanne Vogelsang", "ph_chr_robber": "Lambert Grell", "ph_chr_gravekeeper": "Totengräber",
	"ph_chr_v_innkeeper": "Rosine", "ph_chr_v_smith": "Esch", "ph_chr_v_grocer": "Theres", "ph_chr_v_priest": "Lenz",
	"ph_chr_v_mayor": "Fenner", "ph_chr_v_surgeon": "Quast", "ph_chr_v_washer": "Liesel", "ph_chr_v_oldwoman": "Hagedorn",
	"ph_chr_carter": "Osric", "ph_chr_kranich": "Ilse", "ph_chr_fiddler": "Spielmann",
	"ph_chr_stranger": "Cornelius Brenneisen",
}
const PROPS: Array[String] = [
	"props/ph_prop_letter", "props/ph_prop_letter_open", "props/ph_prop_case", "props/ph_prop_notebook",
	"props/ph_prop_watch_lantern", "props/ph_prop_bundle", "props/ph_prop_soil_pouch",
	"items/ph_item_letter", "items/ph_item_letter_reply", "items/ph_item_nameless_letter", "items/ph_item_stranger_case",
	"items/ph_item_case_card", "items/ph_item_soil_pouch", "items/ph_item_straw_bouquet",
]

var _out := ""
var _mode := "lineup"
var _filter := ""
var _stage: Node3D
var _cam: Camera3D
var _sun: DirectionalLight3D
var _env: Environment


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
		elif arg.begins_with("--mode="):
			_mode = arg.trim_prefix("--mode=")
		elif arg.begins_with("--filter="):
			_filter = arg.trim_prefix("--filter=")
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()


func _run() -> void:
	_stage = Node3D.new()
	root.add_child(_stage)
	var we := WorldEnvironment.new()
	_env = Environment.new()
	_env.background_mode = Environment.BG_COLOR
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.tonemap_mode = Environment.TONE_MAPPER_AGX
	we.environment = _env
	_stage.add_child(we)
	_sun = DirectionalLight3D.new()
	_sun.rotation_degrees = Vector3(-38, -30, 0)
	_sun.shadow_enabled = true
	_stage.add_child(_sun)
	_cam = Camera3D.new()
	_stage.add_child(_cam)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(40, 40)
	ground.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.36, 0.33, 0.27)
	ground.material_override = gm
	_stage.add_child(ground)
	_day()
	match _mode:
		"lineup":
			await _lineup()
		"faces":
			await _faces()
		"clips":
			for n: String in _all():
				if _match(n) and ResourceLoader.exists(DIR + n + ".glb"):
					await _clips(n)
		"props":
			await _props()
		"scenes":
			await _scenes()
	quit()


## The clips in their places: Brenneisen at the inn table (seat_1 of ph_int_inn_table), waiting outside the gate,
## writing; Johann on the wooden bench, showing the mark, leaving with his bundle, on the cart bed.
func _scenes() -> void:
	var tiles: Array = []
	var specs := [
		["ph_chr_stranger", "sit_inn", 0.3, "interior/ph_int_inn_table", Vector3(0, 0, 0.68), 0.0],
		["ph_chr_stranger", "wait_gate", 0.2, "", Vector3.ZERO, 0.0],
		["ph_chr_stranger", "write_notebook", 0.4, "", Vector3.ZERO, 0.0],
		["ph_chr_stranger", "tip_hat", 0.5, "", Vector3.ZERO, 0.0],
		["ph_chr_mourner_m_b", "sit_bench", 0.3, "decor/ph_deco_bench_wood", Vector3(0, 0, -0.05), 0.0],
		["ph_chr_mourner_m_b", "show_mark", 0.5, "", Vector3.ZERO, 0.0],
		["ph_chr_mourner_m_b", "walk_bundle", 0.3, "", Vector3.ZERO, 0.0],
		["ph_chr_mourner_m_b", "sit_cart", 0.3, "", Vector3.ZERO, 0.0],
	]
	for s: Array in specs:
		var inst := _load(s[0])
		_stage.add_child(inst)
		var prop: Node3D = null
		if String(s[3]) != "":
			prop = (load("res://assets/models/%s.glb" % s[3]) as PackedScene).instantiate() as Node3D
			prop.position = s[4]
			_stage.add_child(prop)
		var ap := inst.get_node("AnimationPlayer") as AnimationPlayer
		var len := ap.get_animation(s[1]).length if ap.has_animation(s[1]) else 1.0
		_pose(inst, s[1], len * float(s[2]))
		_cam.fov = 30
		for view: Vector3 in [Vector3(2.2, 1.4, 2.6), Vector3(-1.6, 1.2, 2.9)]:
			_cam.position = view
			_cam.look_at(Vector3(0, 0.75, 0.15))
			var lab := _label("%s  %s" % [LABELS.get(s[0], s[0]), s[1]], Vector3(0.0, 1.95, -0.3), 30)
			lab.pixel_size = 0.0035
			lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			tiles.append(await _shot())
			lab.queue_free()
		inst.queue_free()
		if prop != null:
			prop.queue_free()
		await process_frame
	_sheet(tiles, 4, Vector2i(400, 400)).save_jpg(_out.path_join("scenes.jpg"), 0.9)


func _match(n: String) -> bool:
	if _filter == "":
		return true
	for f: String in _filter.split(","):
		if n.contains(f):
			return true
	return false


func _all() -> Array[String]:
	var out: Array[String] = []
	out.append_array(NEW)
	out.append_array(OLD)
	return out


func _day() -> void:
	_env.background_color = Color(0.5, 0.55, 0.58)
	_env.ambient_light_color = Color(0.62, 0.66, 0.74)
	_env.ambient_light_energy = 0.7
	_sun.light_energy = 1.5
	_sun.light_color = Color(1.0, 0.95, 0.86)


func _night() -> void:
	_env.background_color = Color(0.07, 0.08, 0.11)
	_env.ambient_light_color = Color(0.3, 0.36, 0.5)
	_env.ambient_light_energy = 0.25
	_sun.light_energy = 0.08


func _load(name: String) -> Node3D:
	return (load(DIR + name + ".glb") as PackedScene).instantiate() as Node3D


## Plays `clip` at time t and shows the child meshes listed for it.
func _pose(inst: Node3D, clip: String, t: float) -> void:
	var ap := inst.get_node_or_null("AnimationPlayer") as AnimationPlayer
	if ap != null and ap.has_animation(clip):
		ap.play(clip)
		ap.seek(t, true)
		ap.pause()
	for mi: Node in inst.find_children("*", "MeshInstance3D", true, false):
		if mi.has_meta("extras"):
			var ex: Dictionary = mi.get_meta("extras")
			if ex.has("show_with"):
				(mi as Node3D).visible = clip in String(ex["show_with"]).split(",")


func _shot() -> Image:
	for i: int in 4:
		await process_frame
	return root.get_viewport().get_texture().get_image()


func _sheet(tiles: Array, cols: int, tile: Vector2i) -> Image:
	var rows := ceili(float(tiles.size()) / cols)
	var img := Image.create(tile.x * cols, tile.y * rows, false, Image.FORMAT_RGB8)
	img.fill(Color(0.2, 0.2, 0.2))
	for i: int in tiles.size():
		var t: Image = tiles[i]
		t.convert(Image.FORMAT_RGB8)
		t.resize(tile.x, tile.y, Image.INTERPOLATE_LANCZOS)
		img.blit_rect(t, Rect2i(Vector2i.ZERO, tile), Vector2i((i % cols) * tile.x, (i / cols) * tile.y))
	return img


func _label(text: String, pos: Vector3, size: int = 48) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.pixel_size = 0.0028
	l.position = pos
	l.outline_size = 8
	l.modulate = Color(0.95, 0.92, 0.85)
	_stage.add_child(l)
	return l


func _lineup() -> void:
	var names: Array[String] = []
	names.append_array(NEW)
	names.append_array(OLD.slice(0, 9))   # the gravekeeper and the eight villagers
	var nodes: Array[Node] = []
	var gap := 0.82
	var x0 := -gap * (names.size() - 1) * 0.5
	var lights: Array[OmniLight3D] = []
	names.assign(names.filter(func(n: String) -> bool: return ResourceLoader.exists(DIR + n + ".glb")))
	x0 = -gap * (names.size() - 1) * 0.5
	for i: int in names.size():
		var inst := _load(names[i])
		inst.position = Vector3(x0 + gap * i, 0, 0)
		_stage.add_child(inst)
		_pose(inst, "idle", 0.0)
		nodes.append(inst)
		nodes.append(_label(LABELS.get(names[i], names[i]), Vector3(x0 + gap * i, 0.08, 0.55), 30))
		var lamp := OmniLight3D.new()
		lamp.light_color = Color(1.0, 0.72, 0.42)
		lamp.light_energy = 0.0
		lamp.omni_range = 2.2
		lamp.position = Vector3(x0 + gap * i + 0.35, 1.0, 0.8)
		_stage.add_child(lamp)
		lights.append(lamp)
	_cam.fov = 26
	_cam.position = Vector3(0, 1.25, 10.5)
	_cam.look_at(Vector3(0, 0.75, 0))
	_day()
	(await _shot()).save_jpg(_out.path_join("lineup_day.jpg"), 0.9)
	_night()
	for l: OmniLight3D in lights:
		l.light_energy = 1.6
	(await _shot()).save_jpg(_out.path_join("lineup_lantern.jpg"), 0.9)
	for l: OmniLight3D in lights:
		l.queue_free()
	for n: Node in nodes:
		n.queue_free()
	_day()
	await process_frame


func _face_point(inst: Node3D) -> Vector3:
	var m := inst.find_child("face", true, false) as Node3D
	if m != null:
		return m.global_position
	var sk := inst.get_node("Armature/Skeleton3D") as Skeleton3D
	var hb := sk.find_bone("head")
	var p := sk.global_transform * sk.get_bone_global_pose(hb)
	return p.origin + Vector3(0, 0.13, 0.12)


func _faces() -> void:
	var tiles: Array = []
	for n: String in _all():
		if not _match(n) or not ResourceLoader.exists(DIR + n + ".glb"):
			continue
		var inst := _load(n)
		_stage.add_child(inst)
		_pose(inst, "idle", 0.0)
		if n == "ph_chr_robber":
			_pose(inst, "sit_ground", 0.0)
		await process_frame
		var f := _face_point(inst)
		_cam.fov = 24
		_cam.position = f + Vector3(0.18, 0.05, 0.85)
		_cam.look_at(f + Vector3(0, -0.02, -0.04))
		var lab := _label(LABELS.get(n, n), f + Vector3(0.0, -0.17, 0.08), 22)
		lab.pixel_size = 0.0012
		tiles.append(await _shot())
		lab.queue_free()
		inst.queue_free()
		await process_frame
	_sheet(tiles, 5, Vector2i(360, 400)).save_jpg(_out.path_join("faces_close.jpg"), 0.9)


func _clips(n: String) -> void:
	var inst := _load(n)
	_stage.add_child(inst)
	var ap := inst.get_node("AnimationPlayer") as AnimationPlayer
	var tiles: Array = []
	var clips: Array[String] = []
	for a: StringName in ap.get_animation_list():
		clips.append(String(a))
	clips.sort()
	var per := 6
	_cam.fov = 30
	_cam.position = Vector3(2.9, 1.5, 2.9)
	_cam.look_at(Vector3(0, 0.78, 0))
	for c: String in clips:
		var anim := ap.get_animation(c)
		for k: int in per:
			var t := anim.length * k / float(per - 1) if anim.loop_mode == Animation.LOOP_NONE else anim.length * k / float(per)
			_pose(inst, c, t)
			var lab := _label("%s  %d/%d" % [c, k + 1, per], Vector3(0.3, 1.78, -0.3), 30)
			lab.pixel_size = 0.0035
			tiles.append(await _shot())
			lab.queue_free()
	_sheet(tiles, per, Vector2i(240, 300)).save_jpg(_out.path_join("anim_%s.jpg" % n.trim_prefix("ph_chr_")), 0.88)
	inst.queue_free()
	await process_frame


func _props() -> void:
	var tiles: Array = []
	for p: String in PROPS:
		var path := "res://assets/models/%s.glb" % p
		if not ResourceLoader.exists(path) or not _match(p):
			continue
		var inst := (load(path) as PackedScene).instantiate() as Node3D
		_stage.add_child(inst)
		await process_frame
		var box := _aabb(inst)
		var c := box.get_center()
		var r := maxf(box.size.length() * 0.5, 0.12)
		_cam.fov = 30
		_cam.position = c + Vector3(0.55, 0.5, 1.0).normalized() * r / tan(deg_to_rad(15.0)) * 1.1
		_cam.look_at(c)
		var lab := _label(p.get_file().trim_prefix("ph_"), c + Vector3(0, -r * 0.9, 0), 24)
		lab.pixel_size = r * 0.004
		lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		tiles.append(await _shot())
		lab.queue_free()
		inst.queue_free()
		await process_frame
	_sheet(tiles, 6, Vector2i(320, 320)).save_jpg(_out.path_join("props_sheet.jpg"), 0.88)


func _aabb(node: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for mi: Node in node.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		var b := m.global_transform * m.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box
