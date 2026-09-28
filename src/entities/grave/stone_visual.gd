class_name StoneVisual
extends RefCounted
## The visual of one designed gravestone (docs/PHASE5_DESIGN.md §2.5, §8): shape model, relief
## ornament at the model's marker `ornament`, the inscription as a shaded Label3D at the marker
## `inscription` (front face, local +Z). Used by GravePlotVisuals (at the grave) and usable for
## the bench rack (stone_slot_n) and the stone preview.
## Models: StoneShapeData.model / OrnamentData.model, else P5's ph_prop_gravestone_<shape> /
## ph_prop_orn_<ornament> by name (§8), else a procedural grey placeholder built here (same painted
## material, vertex colours) with the same markers – until P5's assets land.

const NAME := "Stone"
const LABEL_NAME := "Inscription"
const MARKER_INSCRIPTION := "inscription"
const MARKER_ORNAMENT := "ornament"
const SHAPE_MODEL_PATH := "res://assets/models/props/ph_prop_gravestone_%s.glb"
const ORNAMENT_MODEL_PATH := "res://assets/models/props/ph_prop_%s.glb"
const PAINTED_MATERIAL := "res://assets/materials/mat_painted.tres"
## §8 Label3D contract.
const SURFACE_OFFSET := 0.012
const VISIBILITY_END := 40.0
## Label pixel size (m per font pixel); font sizes as em in metres per line role. Each line
## shrinks until it fills at most FILL of StoneShapeData.label_width.
const PIXEL_SIZE := 0.0005
const ROLE_NAME := &"name"
const ROLE_DATE := &"date"
const ROLE_SAYING := &"saying"
const EM_MAX := {ROLE_NAME: 0.095, ROLE_DATE: 0.05, ROLE_SAYING: 0.046}
const EM_MIN := 0.024
## A date line whose fitted em would fall below this splits at DATE_SPLIT into two lines.
const EM_DATE_SPLIT := 0.036
const DATE_SPLIT := " – "
const FILL := 0.94
## W-UI readability fix (P5 review, 10 m zoom): heavier cut letters.
const EMBOLDEN := 0.62
## Gilded letters: the fill is StoneConfig.gold_color, darkened a little, with a dark cut edge
## (outline in the ink colour) so light gold reads on light stone (P5 finding). Ink letters keep
## no outline (§8).
const GOLD_DARKEN := 0.12
const GOLD_EDGE_SHARE := 0.07
const LINE_HEIGHT := 1.25
## Placeholder stone colours (vertex colours, linearised like the glTF import; darker than
## asset_gravestones.py STONE because those meshes also carry painted AO / moss variation).
const STONE_COLOR := Color("#5C6066")
const STONE_DARK := Color("#4C4F4A")
const IRON_COLOR := Color("#2A2624")
const RELIEF_COLOR := Color("#686C70")


## A Node3D "Stone" with model, ornament and inscription for `design` (null for an empty one).
static func build(design: StoneDesign, cfg: StoneConfig = null) -> Node3D:
	if design == null or design.is_empty():
		return null
	var root := Node3D.new()
	root.name = NAME
	var shape := Database.stone_shape(design.shape) as StoneShapeData
	var model := _shape_model(design.shape, shape)
	root.add_child(model)
	var orn := Database.ornament(design.ornament) as OrnamentData if design.ornament != &"" else null
	if orn != null:
		var marker := model.find_child(MARKER_ORNAMENT, true, false) as Node3D
		var relief := _ornament_model(orn)
		relief.name = "Ornament"
		relief.transform = _relative(marker, root) if marker != null else Transform3D(Basis.IDENTITY, Vector3(0, 0.3, 0.08))
		root.add_child(relief)
	if not design.text.is_empty():
		var marker := model.find_child(MARKER_INSCRIPTION, true, false) as Node3D
		var width := shape.label_width if shape != null else 0.5
		var inscription := build_inscription(design, width, cfg)
		inscription.transform = (_relative(marker, root) if marker != null else Transform3D(Basis.IDENTITY, Vector3(0, 0.55, 0.08))) \
				* Transform3D(Basis.IDENTITY, Vector3(0, 0, SURFACE_OFFSET))
		root.add_child(inscription)
	return root


## Node3D "Inscription" (centred on the marker) with one Label3D per line, stacked top-down. Line
## roles from the inscription template: the name large, "Hier ruht" / dates / saying smaller (like
## a cut stone of the time); every line shrinks until it fits `width` metres, a date line that
## still does not fit splits at " – " (visual only – the carved text stays as stored).
static func build_inscription(design: StoneDesign, width: float, cfg: StoneConfig = null) -> Node3D:
	var root := Node3D.new()
	root.name = LABEL_NAME
	var rows := _rows(design, width)
	var sizes: Array[float] = []
	var total := 0.0
	for row: Dictionary in rows:
		var em := fitted_em(row.text, width, float(EM_MAX[row.role]))
		sizes.append(em)
		total += em * LINE_HEIGHT
	var y := total * 0.5
	for i: int in rows.size():
		var em := sizes[i]
		y -= em * LINE_HEIGHT * 0.5
		var label := make_label(rows[i].text, em, width, design.gilded, cfg)
		label.name = "Line%d" % (i + 1)
		label.position = Vector3(0, y, 0)
		root.add_child(label)
		y -= em * LINE_HEIGHT * 0.5
	return root


## One inscription line (§8): shaded, single-sided, alpha cut, no outline, ink or gold colour.
static func make_label(text: String, em: float, width: float, gilded: bool, cfg: StoneConfig = null) -> Label3D:
	var sc := cfg if cfg != null else (Database.config(&"stone_config") as StoneConfig)
	if sc == null:
		sc = StoneConfig.new()
	var l := Label3D.new()
	l.text = text
	l.pixel_size = PIXEL_SIZE
	l.font = _carved_font()
	l.font_size = maxi(1, roundi(em / PIXEL_SIZE))
	l.modulate = gilded_fill(sc) if gilded else sc.ink_color
	l.outline_size = maxi(2, roundi(l.font_size * GOLD_EDGE_SHARE)) if gilded else 0
	l.outline_modulate = sc.ink_color
	l.shaded = true
	l.double_sided = false
	l.alpha_cut = Label3D.ALPHA_CUT_DISCARD
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.width = width / PIXEL_SIZE
	l.visibility_range_end = VISIBILITY_END
	l.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return l


## Fill colour of gilded letters (StoneConfig.gold_color, slightly darker for contrast on stone).
static func gilded_fill(cfg: StoneConfig) -> Color:
	var sc := cfg if cfg != null else StoneConfig.new()
	return sc.gold_color.darkened(GOLD_DARKEN)


## The placeholder font (§8 "Schriftwahl" is open) slightly emboldened: reads like cut letters.
static func _carved_font() -> Font:
	var f := FontVariation.new()
	f.base_font = ThemeDB.fallback_font
	f.variation_embolden = EMBOLDEN
	return f


## Largest em (m) ≤ `em_max` at which `text` fits `width` (never below EM_MIN).
static func fitted_em(text: String, width: float, em_max: float) -> float:
	var probe := 64
	var w := ThemeDB.fallback_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, probe).x
	if w <= 0.0:
		return em_max
	var fit := probe * PIXEL_SIZE * (width * FILL / (w * PIXEL_SIZE))
	return clampf(fit, EM_MIN, em_max)


## [{text, role}] – roles name / date / saying from the template; wrapped name lines stay "name".
static func _rows(design: StoneDesign, width: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var ins := Database.inscription(design.inscription) as InscriptionData if design.inscription != &"" else null
	var roles: Array[StringName] = []
	if ins != null:
		var extra := maxi(0, design.text.size() - ins.lines.size())
		for template: String in ins.lines:
			if template.strip_edges() == "{name}":
				for k: int in 1 + extra:
					roles.append(ROLE_NAME)
			elif template.contains("{"):
				roles.append(ROLE_DATE)
			else:
				roles.append(ROLE_SAYING)
	for i: int in design.text.size():
		var role: StringName = roles[i] if i < roles.size() else ROLE_SAYING
		var line := design.text[i]
		if role == ROLE_DATE and line.contains(DATE_SPLIT) and fitted_em(line, width, 1.0) < EM_DATE_SPLIT:
			for part: String in line.split(DATE_SPLIT):
				out.append({"text": part.strip_edges(), "role": role})
			continue
		out.append({"text": line, "role": role})
	return out


# --- models ---------------------------------------------------------------------------------

static func _shape_model(shape_id: StringName, shape: StoneShapeData) -> Node3D:
	var scene: PackedScene = shape.model if shape != null else null
	var path := SHAPE_MODEL_PATH % String(shape_id).trim_prefix("stone_")
	if scene == null and ResourceLoader.exists(path):
		scene = load(path) as PackedScene
	var node: Node3D = scene.instantiate() as Node3D if scene != null else placeholder_shape(shape_id)
	node.name = "Model"
	return node


static func _ornament_model(orn: OrnamentData) -> Node3D:
	var scene: PackedScene = orn.model
	var path := ORNAMENT_MODEL_PATH % String(orn.id)
	if scene == null and ResourceLoader.exists(path):
		scene = load(path) as PackedScene
	return scene.instantiate() as Node3D if scene != null else placeholder_ornament(orn.id)


## Placeholder shapes (≈ §8 proportions), markers inscription (face centre, +Z) and ornament.
static func placeholder_shape(shape_id: StringName) -> Node3D:
	var root := Node3D.new()
	var st := _surface()
	var ins_pos := Vector3.ZERO
	var orn_pos := Vector3.ZERO
	match shape_id:
		&"stone_arch":
			_plinth(st, 0.74, 0.26, 0.1)
			var arch := PackedVector2Array([Vector2(-0.3, 0.1), Vector2(0.3, 0.1), Vector2(0.3, 0.74)])
			for i: int in range(1, 16):
				var a := PI * i / 16.0
				arch.append(Vector2(0.3 * cos(a), 0.74 + 0.3 * sin(a)))
			arch.append(Vector2(-0.3, 0.74))
			_extrude(st, arch, -0.07, 0.07, STONE_COLOR)
			ins_pos = Vector3(0, 0.5, 0.07)
			orn_pos = Vector3(0, 0.86, 0.07)
		&"stone_master":
			_plinth(st, 1.0, 0.4, 0.2)
			_box(st, Vector3(0, 0.235, 0), Vector3(0.86, 0.07, 0.32), STONE_DARK)
			var body := PackedVector2Array([Vector2(-0.38, 0.27), Vector2(0.38, 0.27), Vector2(0.38, 1.08),
					Vector2(-0.38, 1.08)])
			_extrude(st, body, -0.1, 0.1, STONE_COLOR)
			_box(st, Vector3(0, 1.11, 0), Vector3(0.88, 0.06, 0.24), STONE_DARK)
			var gable := PackedVector2Array([Vector2(-0.44, 1.14), Vector2(0.44, 1.14), Vector2(0.0, 1.36)])
			_extrude(st, gable, -0.11, 0.11, STONE_COLOR)
			for side: float in [-1.0, 1.0]:
				_box(st, Vector3(side * 0.39, 0.62, 0.0), Vector3(0.035, 0.16, 0.22), IRON_COLOR)
				_box(st, Vector3(side * 0.39, 0.9, 0.0), Vector3(0.035, 0.16, 0.22), IRON_COLOR)
			ins_pos = Vector3(0, 0.62, 0.1)
			orn_pos = Vector3(0, 1.225, 0.11)
		_:
			_plinth(st, 0.62, 0.24, 0.08)
			var stele := PackedVector2Array([Vector2(-0.25, 0.08), Vector2(0.25, 0.08), Vector2(0.25, 0.9),
					Vector2(0.0, 0.98), Vector2(-0.25, 0.9)])
			_extrude(st, stele, -0.06, 0.06, STONE_COLOR)
			ins_pos = Vector3(0, 0.42, 0.06)
			orn_pos = Vector3(0, 0.78, 0.06)
	root.add_child(_mesh_instance(st, "Mesh"))
	root.add_child(_marker(MARKER_INSCRIPTION, ins_pos))
	root.add_child(_marker(MARKER_ORNAMENT, orn_pos))
	return root


## Flat relief placeholders (0.02 m, stone colour, front at local z 0 → +Z).
static func placeholder_ornament(orn_id: StringName) -> Node3D:
	var st := _surface()
	match orn_id:
		&"orn_ivy":
			for i: int in 5:
				var x := -0.14 + i * 0.07
				var y := 0.02 * sin(i * 1.7)
				_extrude(st, _leaf(Vector2(x, y), 0.035, 0.6 if i % 2 == 0 else -0.6), 0.0, 0.02, RELIEF_COLOR)
			_extrude(st, _bar(Vector2(-0.17, -0.005), Vector2(0.17, 0.005), 0.008), 0.0, 0.012, RELIEF_COLOR)
		&"orn_poppy":
			_extrude(st, _ellipse(Vector2(0, 0), 0.045, 0.055, 14), 0.0, 0.02, RELIEF_COLOR)
			_extrude(st, _crown(Vector2(0, 0.055), 0.05, 0.02), 0.0, 0.02, RELIEF_COLOR)
			_extrude(st, _bar(Vector2(0, -0.055), Vector2(0.01, -0.13), 0.008), 0.0, 0.014, RELIEF_COLOR)
		&"orn_elder":
			for i: int in 9:
				var a := PI * (0.12 + 0.76 * i / 8.0)
				_extrude(st, _ellipse(Vector2(0.09 * cos(a), 0.035 * sin(a) + 0.02), 0.014, 0.014, 8), 0.0, 0.02, RELIEF_COLOR)
				_extrude(st, _bar(Vector2(0, -0.07), Vector2(0.08 * cos(a), 0.03 * sin(a) + 0.01), 0.004), 0.0, 0.01, RELIEF_COLOR)
		&"orn_torch":
			_extrude(st, _bar(Vector2(0, 0.09), Vector2(0, -0.04), 0.012), 0.0, 0.02, RELIEF_COLOR)
			var flame := PackedVector2Array([Vector2(-0.03, -0.04), Vector2(0.03, -0.04), Vector2(0.018, -0.08),
					Vector2(0.0, -0.12), Vector2(-0.018, -0.08)])
			_extrude(st, flame, 0.0, 0.02, RELIEF_COLOR)
			_extrude(st, _bar(Vector2(-0.035, -0.035), Vector2(0.035, -0.035), 0.01), 0.0, 0.024, RELIEF_COLOR)
	var root := Node3D.new()
	root.add_child(_mesh_instance(st, "Mesh"))
	return root


# --- procedural helpers -------------------------------------------------------------------

static func _surface() -> SurfaceTool:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	return st


static func _mesh_instance(st: SurfaceTool, name: String) -> MeshInstance3D:
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.name = name
	mi.mesh = st.commit()
	if ResourceLoader.exists(PAINTED_MATERIAL):
		mi.material_override = load(PAINTED_MATERIAL) as Material
	return mi


static func _marker(name: String, pos: Vector3) -> Node3D:
	var m := Node3D.new()
	m.name = name
	m.position = pos
	return m


static func _plinth(st: SurfaceTool, w: float, d: float, h: float) -> void:
	_box(st, Vector3(0, h * 0.5, 0), Vector3(w, h, d), STONE_DARK)


static func _box(st: SurfaceTool, center: Vector3, size: Vector3, color: Color) -> void:
	var h := size * 0.5
	var poly := PackedVector2Array([Vector2(center.x - h.x, center.y - h.y), Vector2(center.x + h.x, center.y - h.y),
			Vector2(center.x + h.x, center.y + h.y), Vector2(center.x - h.x, center.y + h.y)])
	_extrude(st, poly, center.z - h.z, center.z + h.z, color)


## Extrudes the XY polygon from z0 (back) to z1 (front), flat shaded, outward-facing.
static func _extrude(st: SurfaceTool, poly_in: PackedVector2Array, z0: float, z1: float, color: Color) -> void:
	var poly := poly_in.duplicate()
	var area := 0.0
	for i: int in poly.size():
		area += poly[i].cross(poly[(i + 1) % poly.size()])
	if area < 0.0:
		poly.reverse()  # counter-clockwise (y up) from here on
	st.set_smooth_group(-1)
	st.set_color(color.srgb_to_linear())
	var tris := Geometry2D.triangulate_polygon(poly)
	for i: int in range(0, tris.size(), 3):
		var a := poly[tris[i]]
		var b := poly[tris[i + 1]]
		var d := poly[tris[i + 2]]
		_tri(st, Vector3(a.x, a.y, z1), Vector3(b.x, b.y, z1), Vector3(d.x, d.y, z1), Vector3.BACK)
		_tri(st, Vector3(a.x, a.y, z0), Vector3(b.x, b.y, z0), Vector3(d.x, d.y, z0), Vector3.FORWARD)
	for i: int in poly.size():
		var p := poly[i]
		var q := poly[(i + 1) % poly.size()]
		var out := Vector3(q.y - p.y, p.x - q.x, 0.0)
		_tri(st, Vector3(p.x, p.y, z0), Vector3(q.x, q.y, z0), Vector3(q.x, q.y, z1), out)
		_tri(st, Vector3(p.x, p.y, z0), Vector3(q.x, q.y, z1), Vector3(p.x, p.y, z1), out)


## One triangle wound so that its front face (Godot: clockwise) looks along `outward`.
static func _tri(st: SurfaceTool, v0: Vector3, v1: Vector3, v2: Vector3, outward: Vector3) -> void:
	if (v1 - v0).cross(v2 - v0).dot(outward) > 0.0:
		var t := v1
		v1 = v2
		v2 = t
	st.add_vertex(v0)
	st.add_vertex(v1)
	st.add_vertex(v2)


static func _ellipse(c: Vector2, rx: float, ry: float, n: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i: int in n:
		var a := TAU * i / n
		out.append(c + Vector2(rx * cos(a), ry * sin(a)))
	return out


static func _leaf(c: Vector2, size: float, tilt: float) -> PackedVector2Array:
	var pts := PackedVector2Array([Vector2(0, -size), Vector2(size * 0.6, -size * 0.2), Vector2(size * 0.8, size * 0.5),
			Vector2(0, size * 0.25), Vector2(-size * 0.8, size * 0.5), Vector2(-size * 0.6, -size * 0.2)])
	var out := PackedVector2Array()
	for p: Vector2 in pts:
		out.append(c + p.rotated(tilt))
	return out


static func _crown(base: Vector2, w: float, h: float) -> PackedVector2Array:
	return PackedVector2Array([base + Vector2(-w * 0.5, -h * 0.3), base + Vector2(w * 0.5, -h * 0.3), base + Vector2(w * 0.4, h),
			base + Vector2(w * 0.15, h * 0.35), base + Vector2(0, h), base + Vector2(-w * 0.15, h * 0.35), base + Vector2(-w * 0.4, h)])


static func _bar(a: Vector2, b: Vector2, half_width: float) -> PackedVector2Array:
	var n := (b - a).orthogonal().normalized() * half_width
	return PackedVector2Array([a - n, b - n, b + n, a + n])


## Transform of `node` relative to `ancestor`.
static func _relative(node: Node3D, ancestor: Node) -> Transform3D:
	var t := Transform3D.IDENTITY
	var n: Node = node
	while n != null and n != ancestor:
		if n is Node3D:
			t = (n as Node3D).transform * t
		n = n.get_parent()
	return t
