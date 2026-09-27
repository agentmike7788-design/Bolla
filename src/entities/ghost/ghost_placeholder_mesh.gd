class_name GhostPlaceholderMesh
extends RefCounted
## ph_ghost_placeholder: stand-in for P5's ph_chr_ghost until the asset exists (docs §8).
## A lathed shroud with hood – pivot at the hem centre (y 0), faces +Z, ~1.65 m high, open
## ragged hem, a forward bulge at chest height where the hands hold the soul light.
## Built in code so tests never depend on the asset.

const SEGMENTS := 28
## (height, radius) from the hem up to the hood tip.
const PROFILE: Array[Vector2] = [
	Vector2(0.0, 0.44), Vector2(0.12, 0.40), Vector2(0.32, 0.33), Vector2(0.55, 0.27),
	Vector2(0.78, 0.25), Vector2(0.98, 0.27), Vector2(1.12, 0.26), Vector2(1.22, 0.22),
	Vector2(1.30, 0.205), Vector2(1.42, 0.21), Vector2(1.52, 0.185), Vector2(1.61, 0.12),
	Vector2(1.67, 0.05), Vector2(1.70, 0.0),
]
## Chest bulge (hands + soul light) towards +Z.
const BULGE := 0.35
const BULGE_Y := 0.95
const BULGE_WIDTH := 0.16
## Ragged hem: radius and height jitter at the lowest ring.
const HEM_JITTER := 0.08
## The hood leans back slightly (−Z) above this height.
const HOOD_Y := 1.2
const HOOD_LEAN := -0.08

static var _cached: ArrayMesh


static func build() -> ArrayMesh:
	if _cached != null:
		return _cached
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings: Array[PackedVector3Array] = []
	for i: int in PROFILE.size():
		var ring := PackedVector3Array()
		var y := PROFILE[i].x
		for s: int in SEGMENTS + 1:
			var theta := TAU * float(s % SEGMENTS) / float(SEGMENTS)
			var front := maxf(0.0, cos(theta))
			var r := PROFILE[i].y * (1.0 + BULGE * front * front * exp(-pow((y - BULGE_Y) / BULGE_WIDTH, 2.0)))
			var yy := y
			if i == 0:
				var n := sin(theta * 5.0) * 0.6 + sin(theta * 9.0 + 1.3) * 0.4
				r *= 1.0 + n * HEM_JITTER
				yy += (n * 0.5 + 0.5) * HEM_JITTER
			var lean := HOOD_LEAN * clampf((y - HOOD_Y) / 0.4, 0.0, 1.0)
			ring.append(Vector3(sin(theta) * r, yy, cos(theta) * r + lean))
		rings.append(ring)
	for i: int in rings.size() - 1:
		for s: int in SEGMENTS:
			var a := rings[i][s]
			var b := rings[i][s + 1]
			var c := rings[i + 1][s]
			var d := rings[i + 1][s + 1]
			for v: Vector3 in [a, c, b, b, c, d]:
				st.set_uv(Vector2(float(s) / SEGMENTS, float(i) / (rings.size() - 1)))
				st.add_vertex(v)
	st.generate_normals()
	_cached = st.commit()
	_cached.resource_name = "ph_ghost_placeholder"
	return _cached
