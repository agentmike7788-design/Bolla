class_name LayoutPlaceholderMesh
extends RefCounted
## ph_layout_placeholder: stand-in for P5's ph_prop_layout_sprig (docs/PHASE4_DESIGN.md §8)
## until the asset exists – an elder sprig with a few leaves and white umbels plus a candle
## stub without light, lying on the chest of a laid-out corpse. Vertex-painted for mat_painted,
## origin on the chest surface, sprig along local X. Built in code so tests never depend on
## the asset.

const NAME := "ph_layout_placeholder"
const PAINTED := "res://assets/materials/mat_painted.tres"
const STEM := Color("5B4A34")
const LEAF := Color("4F5F3A")
const LEAF_LIGHT := Color("66744A")
const BLOSSOM := Color("D8D2BC")
const WAX := Color("D9CBA6")
const WICK := Color("2A2622")

static var _cached: ArrayMesh


static func build() -> ArrayMesh:
	if _cached != null:
		return _cached
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Stem, slightly diagonal over the chest.
	_box(st, Vector3(0.0, 0.008, 0.0), Vector3(0.24, 0.008, 0.008), 0.35, STEM)
	# Leaves in pairs along the stem.
	for i: int in 3:
		var x := -0.07 + 0.06 * float(i)
		for side: int in [-1, 1]:
			_box(st, Vector3(x, 0.012, side * 0.028), Vector3(0.05, 0.004, 0.022), 0.35 + side * 0.5,
					LEAF if (i + side) % 2 == 0 else LEAF_LIGHT)
	# A small white umbel at the tip.
	for j: int in 5:
		var a := TAU * float(j) / 5.0
		_box(st, Vector3(0.13 + cos(a) * 0.012, 0.018, sin(a) * 0.012), Vector3(0.012, 0.01, 0.012), a, BLOSSOM)
	# Candle stub beside the sprig (no light).
	_cylinder(st, Vector3(-0.02, 0.0, -0.075), 0.017, 0.055, WAX)
	_box(st, Vector3(-0.02, 0.062, -0.075), Vector3(0.003, 0.012, 0.003), 0.0, WICK)
	st.generate_normals()
	_cached = st.commit()
	return _cached


static func material() -> Material:
	return load(PAINTED) as Material


static func _box(st: SurfaceTool, centre: Vector3, size: Vector3, yaw: float, colour: Color) -> void:
	var b := Basis(Vector3.UP, yaw)
	var h := size * 0.5
	var c: Array[Vector3] = []
	for i: int in 8:
		var p := Vector3(h.x if i & 1 else -h.x, h.y if i & 2 else -h.y, h.z if i & 4 else -h.z)
		c.append(centre + b * p)
	var faces := [[0, 1, 3, 2], [4, 6, 7, 5], [0, 4, 5, 1], [2, 3, 7, 6], [0, 2, 6, 4], [1, 5, 7, 3]]
	for f: Array in faces:
		_quad(st, c[f[0]], c[f[1]], c[f[2]], c[f[3]], colour)


static func _cylinder(st: SurfaceTool, base: Vector3, radius: float, height: float, colour: Color) -> void:
	var seg := 8
	for i: int in seg:
		var a0 := TAU * float(i) / float(seg)
		var a1 := TAU * float(i + 1) / float(seg)
		var p0 := base + Vector3(cos(a0) * radius, 0.0, sin(a0) * radius)
		var p1 := base + Vector3(cos(a1) * radius, 0.0, sin(a1) * radius)
		var top := Vector3(0.0, height, 0.0)
		_quad(st, p0, p1, p1 + top, p0 + top, colour)
		_tri(st, base + top, p1 + top, p0 + top, colour.lightened(0.08))


static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, colour: Color) -> void:
	_tri(st, a, b, c, colour)
	_tri(st, a, c, d, colour)


static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, colour: Color) -> void:
	st.set_color(colour)
	st.add_vertex(a)
	st.add_vertex(b)
	st.add_vertex(c)
