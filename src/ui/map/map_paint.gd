class_name MapPaint
extends RefCounted
## Drawing helpers of the map in the style of an old ink-and-wash estate map: the parchment sheet
## (baked once from noise), wobbly ink lines, washes, tree dabs, hachures, the compass rose, the scale
## bar and the small pictograms (hat, cart, figure, seal, gate, well …). Static, deterministic (the same
## map looks the same every time it opens).

const PAPER_SIZE := Vector2i(420, 300)
## Pixels between two wobble samples of an ink line.
const WOBBLE_STEP := 7.0

static var _paper: Texture2D
static var _paper_key: String = ""


## The parchment: paper colour mottled by two noises, darker towards the edges, a few stains.
static func paper_texture(paper: Color, dark: Color) -> Texture2D:
	var key := "%s|%s" % [paper.to_html(), dark.to_html()]
	if _paper != null and _paper_key == key:
		return _paper
	var noise := FastNoiseLite.new()
	noise.seed = 1701
	noise.frequency = 0.012
	noise.fractal_octaves = 4
	var fine := FastNoiseLite.new()
	fine.seed = 77
	fine.frequency = 0.09
	var img := Image.create(PAPER_SIZE.x, PAPER_SIZE.y, false, Image.FORMAT_RGB8)
	var w := float(PAPER_SIZE.x)
	var h := float(PAPER_SIZE.y)
	for y: int in PAPER_SIZE.y:
		for x: int in PAPER_SIZE.x:
			var n := noise.get_noise_2d(x, y) * 0.5 + 0.5
			var f := fine.get_noise_2d(x, y * 0.35) * 0.5 + 0.5
			var ex := minf(float(x), w - 1.0 - x) / w
			var ey := minf(float(y), h - 1.0 - y) / h
			var edge := clampf(1.0 - minf(ex, ey) * 9.0, 0.0, 1.0)
			var t := clampf(0.1 + n * 0.32 + f * 0.08 + edge * edge * 0.55, 0.0, 1.0)
			img.set_pixel(x, y, paper.lerp(dark, t * 0.62))
	_paper = ImageTexture.create_from_image(img)
	_paper_key = key
	return _paper


## `pts` subdivided and nudged sideways by a smooth, seeded noise – a pen line, not a vector line.
static func wobble(pts: PackedVector2Array, amp: float, seed: int, closed: bool = false) -> PackedVector2Array:
	var src := pts.duplicate()
	if closed and src.size() > 1:
		src.append(src[0])
	var out := PackedVector2Array()
	var dist := 0.0
	for i: int in src.size() - 1:
		var a := src[i]
		var b := src[i + 1]
		var seg := b - a
		var len := seg.length()
		if len < 0.001:
			continue
		var n := Vector2(-seg.y, seg.x) / len
		var steps := maxi(1, ceili(len / WOBBLE_STEP))
		for s: int in steps:
			var t := float(s) / steps
			var d := dist + len * t
			var off := sin(d * 0.21 + seed * 1.7) * 0.6 + sin(d * 0.057 + seed * 0.3) * 0.4
			out.append(a + seg * t + n * off * amp)
		dist += len
	if not src.is_empty():
		out.append(src[src.size() - 1])
	return out


static func ink_line(ci: CanvasItem, pts: PackedVector2Array, color: Color, width: float, seed: int, amp: float = 0.8, closed: bool = false) -> void:
	if pts.size() < 2:
		return
	ci.draw_polyline(wobble(pts, amp, seed, closed), color, width, true)


## Dashed ink line (fences: short strokes with a small picket tick).
static func dashed(ci: CanvasItem, a: Vector2, b: Vector2, color: Color, width: float, dash: float, gap: float, ticks: bool) -> void:
	var seg := b - a
	var len := seg.length()
	if len < 0.5:
		return
	var dir := seg / len
	var n := Vector2(-dir.y, dir.x)
	var d := 0.0
	while d < len:
		var e := minf(d + dash, len)
		ci.draw_line(a + dir * d, a + dir * e, color, width, true)
		if ticks:
			var m := a + dir * (d + (e - d) * 0.5)
			ci.draw_line(m - n * 2.2, m + n * 2.2, color, maxf(width - 0.4, 1.0), true)
		d = e + gap


## A polyline offset sideways by `off` (road edges).
static func offset_line(pts: PackedVector2Array, off: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i: int in pts.size():
		var prev := pts[maxi(i - 1, 0)]
		var next := pts[mini(i + 1, pts.size() - 1)]
		var dir := (next - prev).normalized()
		out.append(pts[i] + Vector2(-dir.y, dir.x) * off)
	return out


## A watercolour blob: three soft, slightly shifted discs.
static func dab(ci: CanvasItem, at: Vector2, r: float, color: Color, seed: int) -> void:
	for i: int in 3:
		var a := seed * 2.39 + i * 2.1
		var c := color
		c.a *= 0.55 if i > 0 else 0.8
		ci.draw_circle(at + Vector2(cos(a), sin(a)) * r * 0.22, r * (1.0 - i * 0.12), c, true, -1.0, true)


## A tree seen from above: a crown of dabs with a scalloped ink rim and a shadow to the south-east.
static func tree(ci: CanvasItem, at: Vector2, r: float, fill: Color, rim: Color, kind: StringName, seed: int) -> void:
	var shadow := Color(0.2, 0.15, 0.1, 0.14)
	ci.draw_circle(at + Vector2(r * 0.28, r * 0.32), r * 0.95, shadow, true, -1.0, true)
	var lobes := 7 if kind != &"bush" else 5
	if kind == &"birch":
		fill = fill.lightened(0.25)
	for i: int in lobes:
		var a := TAU * i / lobes + seed * 0.7
		dab(ci, at + Vector2(cos(a), sin(a)) * r * 0.42, r * 0.58, fill, seed + i)
	dab(ci, at, r * 0.6, fill.darkened(0.12), seed)
	for i: int in lobes:
		var a := TAU * i / lobes + seed * 0.7
		var c := at + Vector2(cos(a), sin(a)) * r * 0.55
		ci.draw_arc(c, r * 0.45, a - 1.1, a + 1.1, 7, rim, 1.1, true)
	if kind == &"elder":
		for i: int in 5:
			var a := seed * 1.3 + i * 1.9
			ci.draw_circle(at + Vector2(cos(a), sin(a)) * r * 0.45, maxf(r * 0.08, 1.2), Color(0.25, 0.12, 0.2, 0.85), true, -1.0, true)
	elif kind == &"birch":
		ci.draw_line(at + Vector2(0.0, -r * 0.2), at + Vector2(0.0, r * 0.25), Color(0.95, 0.93, 0.86, 0.9), 1.6, true)
	elif kind == &"linden":
		ci.draw_circle(at, r * 0.12, rim, true, -1.0, true)


## Hachures along a rock edge (ticks on the low side).
static func cliff(ci: CanvasItem, at: Vector2, rot: float, len: float, color: Color, seed: int) -> void:
	var dir := Vector2(cos(rot), -sin(rot))
	var n := Vector2(-dir.y, dir.x)
	var a := at - dir * len * 0.5
	var b := at + dir * len * 0.5
	ink_line(ci, PackedVector2Array([a, b]), color, 1.6, seed, 1.0)
	var count := maxi(3, int(len / 4.0))
	for i: int in count + 1:
		var p := a.lerp(b, float(i) / count)
		var l := 4.0 + 3.0 * absf(sin(i * 1.7 + seed))
		ci.draw_line(p, p + n * l, color, 1.0, true)


## Diagonal hatching inside a rect (locked areas).
static func hatch(ci: CanvasItem, r: Rect2, color: Color, spacing: float) -> void:
	var start := -r.size.y
	var x := start
	while x < r.size.x:
		var p0 := Vector2(x, 0.0)
		var p1 := Vector2(x + r.size.y, r.size.y)
		# Clip the 45° segment to the rect.
		if p0.x < 0.0:
			p0 = Vector2(0.0, -x)
		if p1.x > r.size.x:
			p1 = Vector2(r.size.x, r.size.x - x)
		if p1.y > p0.y:
			ci.draw_line(r.position + p0, r.position + p1, color, 1.0, true)
		x += spacing


## Eight-point compass rose with N.
static func compass(ci: CanvasItem, c: Vector2, r: float, ink: Color, paper: Color, font: Font, font_size: int) -> void:
	ci.draw_circle(c, r * 0.72, Color(paper, 0.6), true, -1.0, true)
	ci.draw_arc(c, r * 0.72, 0.0, TAU, 48, ink, 1.2, true)
	ci.draw_arc(c, r * 0.64, 0.0, TAU, 48, Color(ink, 0.5), 0.8, true)
	for i: int in 8:
		var a := -PI * 0.5 + i * PI * 0.25
		var long := i % 2 == 0
		var tip := c + Vector2(cos(a), sin(a)) * (r if long else r * 0.55)
		var side := r * (0.13 if long else 0.09)
		var left := c + Vector2(cos(a - PI * 0.5), sin(a - PI * 0.5)) * side
		var right := c + Vector2(cos(a + PI * 0.5), sin(a + PI * 0.5)) * side
		ci.draw_colored_polygon(PackedVector2Array([c, left, tip]), ink if long else Color(ink, 0.75))
		ci.draw_colored_polygon(PackedVector2Array([c, tip, right]), paper.darkened(0.08))
		ci.draw_polyline(PackedVector2Array([left, tip, right]), ink, 1.0, true)
	ci.draw_circle(c, r * 0.07, ink, true, -1.0, true)
	var text := "N"
	var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	ci.draw_string(font, c + Vector2(-tw * 0.5, -r - 6.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, ink)


## Scale bar: alternating ink and paper blocks, `steps` Schritt long, with its caption.
static func scale_bar(ci: CanvasItem, at: Vector2, length: float, segments: int, ink: Color, paper: Color, text: String, font: Font, font_size: int) -> void:
	var h := 7.0
	var seg := length / segments
	for i: int in segments:
		var r := Rect2(at + Vector2(seg * i, 0.0), Vector2(seg, h))
		ci.draw_rect(r, ink if i % 2 == 0 else paper, true)
	ci.draw_rect(Rect2(at, Vector2(length, h)), ink, false, 1.2)
	for i: int in segments + 1:
		ci.draw_line(at + Vector2(seg * i, h), at + Vector2(seg * i, h + 4.0), ink, 1.0, true)
	var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	ci.draw_string(font, at + Vector2(length * 0.5 - tw * 0.5, h + 6.0 + font_size), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, ink)


## The gravekeeper: a broad-brimmed hat on a candle-amber disc, a pointer in the walking direction.
static func hat_marker(ci: CanvasItem, c: Vector2, r: float, heading: Vector2, ink: Color, ring: Color, paper: Color) -> void:
	if heading != Vector2.ZERO:
		var d := heading.normalized()
		var n := Vector2(-d.y, d.x)
		var tip := c + d * r * 1.75
		ci.draw_colored_polygon(PackedVector2Array([c + n * r * 0.62, tip, c - n * r * 0.62]), ink)
		ci.draw_colored_polygon(PackedVector2Array([c + n * r * 0.42, c + d * r * 1.5, c - n * r * 0.42]), ring)
	ci.draw_circle(c + Vector2(1.5, 2.0), r, Color(0.1, 0.06, 0.03, 0.35), true, -1.0, true)
	ci.draw_circle(c, r, ring, true, -1.0, true)
	ci.draw_arc(c, r, 0.0, TAU, 32, ink, 1.8, true)
	ci.draw_arc(c, r - 3.0, 0.0, TAU, 32, Color(paper, 0.7), 1.0, true)
	# Hat: brim, crown, band.
	var s := r / 15.0
	var brim := PackedVector2Array()
	for i: int in 17:
		var a := PI * i / 16.0
		brim.append(c + Vector2(cos(a) * 11.0 * s, 2.6 * s + sin(a) * 2.4 * s))
	for i: int in 17:
		var a := PI + PI * i / 16.0
		brim.append(c + Vector2(cos(a) * 11.0 * s, 2.6 * s + sin(a) * 1.2 * s))
	ci.draw_colored_polygon(brim, ink)
	var crown := PackedVector2Array([c + Vector2(-6.0, 2.2) * s, c + Vector2(-5.0, -7.5) * s, c + Vector2(-2.0, -9.0) * s,
			c + Vector2(2.0, -9.0) * s, c + Vector2(5.0, -7.5) * s, c + Vector2(6.0, 2.2) * s])
	ci.draw_colored_polygon(crown, ink)
	ci.draw_line(c + Vector2(-5.8, -0.6) * s, c + Vector2(5.8, -0.6) * s, ring.darkened(0.25), 2.2 * s, true)


## Osric's handcart: a box on two wheels with the shafts.
static func cart(ci: CanvasItem, c: Vector2, s: float, ink: Color, fill: Color) -> void:
	var box := Rect2(c + Vector2(-7.0, -5.0) * s, Vector2(14.0, 7.0) * s)
	ci.draw_rect(box, fill, true)
	ci.draw_rect(box, ink, false, 1.4)
	ci.draw_line(c + Vector2(7.0, -3.0) * s, c + Vector2(13.0, -6.0) * s, ink, 1.4, true)
	ci.draw_line(c + Vector2(7.0, 0.0) * s, c + Vector2(13.0, -3.0) * s, ink, 1.4, true)
	for x: float in [-4.0, 4.0]:
		ci.draw_circle(c + Vector2(x, 3.5) * s, 3.0 * s, Color(fill, 0.0), false, 1.3, true)
		ci.draw_arc(c + Vector2(x, 3.5) * s, 3.0 * s, 0.0, TAU, 14, ink, 1.4, true)


## A villager: head and cloak.
static func figure(ci: CanvasItem, c: Vector2, r: float, fill: Color, ink: Color) -> void:
	var cloak := PackedVector2Array([c + Vector2(0.0, -r * 0.3), c + Vector2(r * 0.95, r * 1.25), c + Vector2(-r * 0.95, r * 1.25)])
	ci.draw_colored_polygon(cloak, fill)
	ci.draw_polyline(PackedVector2Array([cloak[0], cloak[1], cloak[2], cloak[0]]), ink, 1.1, true)
	ci.draw_circle(c + Vector2(0.0, -r * 0.55), r * 0.5, fill.lightened(0.15), true, -1.0, true)
	ci.draw_arc(c + Vector2(0.0, -r * 0.55), r * 0.5, 0.0, TAU, 14, ink, 1.1, true)


## An order: a red wax seal with a pin.
static func seal(ci: CanvasItem, c: Vector2, r: float, red: Color, ink: Color) -> void:
	ci.draw_line(c, c + Vector2(0.0, r * 2.2), ink, 1.6, true)
	var pts := PackedVector2Array()
	for i: int in 14:
		var a := TAU * i / 14.0
		var rr := r * (1.0 if i % 2 == 0 else 0.84)
		pts.append(c + Vector2(cos(a), sin(a)) * rr)
	ci.draw_colored_polygon(pts, red)
	ci.draw_circle(c, r * 0.55, red.darkened(0.25), false, 1.2, true)
	ci.draw_circle(c, r * 0.18, red.lightened(0.3), true, -1.0, true)


## The small landmark pictograms.
static func glyph(ci: CanvasItem, kind: StringName, c: Vector2, s: float, ink: Color, fill: Color, water: Color) -> void:
	match kind:
		&"gate":
			ci.draw_rect(Rect2(c + Vector2(-7.0, -3.0) * s, Vector2(2.5, 6.0) * s), ink)
			ci.draw_rect(Rect2(c + Vector2(4.5, -3.0) * s, Vector2(2.5, 6.0) * s), ink)
			ci.draw_line(c + Vector2(-4.5, -1.0) * s, c + Vector2(4.5, -1.0) * s, ink, 1.2, true)
			ci.draw_line(c + Vector2(-4.5, 1.5) * s, c + Vector2(4.5, 1.5) * s, ink, 1.2, true)
		&"milestone":
			var pts := PackedVector2Array([c + Vector2(-3.5, 5.0) * s, c + Vector2(-3.5, -2.0) * s])
			for i: int in 9:
				var a := PI + PI * i / 8.0
				pts.append(c + Vector2(cos(a) * 3.5, -2.0 + sin(a) * 3.5) * s)
			pts.append(c + Vector2(3.5, 5.0) * s)
			ci.draw_colored_polygon(pts, fill)
			ci.draw_polyline(pts + PackedVector2Array([pts[0]]), ink, 1.3, true)
			ci.draw_line(c + Vector2(-1.8, 0.0) * s, c + Vector2(1.8, 0.0) * s, ink, 1.0, true)
		&"board":
			ci.draw_line(c + Vector2(-4.0, 0.0) * s, c + Vector2(-4.0, 6.0) * s, ink, 1.4, true)
			ci.draw_line(c + Vector2(4.0, 0.0) * s, c + Vector2(4.0, 6.0) * s, ink, 1.4, true)
			ci.draw_rect(Rect2(c + Vector2(-6.0, -5.0) * s, Vector2(12.0, 6.5) * s), fill)
			ci.draw_rect(Rect2(c + Vector2(-6.0, -5.0) * s, Vector2(12.0, 6.5) * s), ink, false, 1.3)
			ci.draw_line(c + Vector2(-3.5, -3.0) * s, c + Vector2(3.0, -3.0) * s, Color(ink, 0.6), 1.0)
			ci.draw_line(c + Vector2(-3.5, -1.0) * s, c + Vector2(2.0, -1.0) * s, Color(ink, 0.6), 1.0)
		&"well":
			ci.draw_circle(c, 5.5 * s, fill, true, -1.0, true)
			ci.draw_circle(c, 3.0 * s, water.darkened(0.1), true, -1.0, true)
			ci.draw_arc(c, 5.5 * s, 0.0, TAU, 20, ink, 1.5, true)
			ci.draw_arc(c, 3.0 * s, 0.0, TAU, 16, ink, 1.0, true)
		&"bridge":
			for side: float in [-1.0, 1.0]:
				ci.draw_arc(c + Vector2(0.0, side * 9.0 * s), 9.0 * s, PI * (0.5 - 0.5 * side) + 0.5, PI * (0.5 - 0.5 * side) + PI - 0.5, 10, ink, 1.8, true)
			for i: int in 5:
				var x := lerpf(-6.0, 6.0, i / 4.0) * s
				ci.draw_line(c + Vector2(x, -3.0 * s), c + Vector2(x, 3.0 * s), Color(ink, 0.55), 1.0, true)
		&"wash":
			for p: Vector2 in [Vector2(-3.5, 0.0), Vector2(1.5, -2.5), Vector2(3.0, 2.5)]:
				ci.draw_circle(c + p * s, 2.4 * s, fill, true, -1.0, true)
				ci.draw_arc(c + p * s, 2.4 * s, 0.0, TAU, 10, ink, 1.0, true)
		&"shrine":
			ci.draw_line(c + Vector2(0.0, 6.0) * s, c + Vector2(0.0, -6.0) * s, ink, 1.6, true)
			ci.draw_line(c + Vector2(-3.5, -3.0) * s, c + Vector2(3.5, -3.0) * s, ink, 1.6, true)
		&"linden":
			pass


## Roof glyphs of the buildings.
static func roof_glyph(ci: CanvasItem, kind: StringName, c: Vector2, s: float, ink: Color) -> void:
	match kind:
		&"cross":
			ci.draw_line(c + Vector2(0.0, -6.0) * s, c + Vector2(0.0, 6.0) * s, ink, 2.0, true)
			ci.draw_line(c + Vector2(-4.0, -2.5) * s, c + Vector2(4.0, -2.5) * s, ink, 2.0, true)
		&"crypt":
			ci.draw_arc(c + Vector2(0.0, 1.0) * s, 4.0 * s, PI, TAU, 10, ink, 1.6, true)
			ci.draw_line(c + Vector2(-4.0, 1.0) * s, c + Vector2(-4.0, 5.0) * s, ink, 1.6, true)
			ci.draw_line(c + Vector2(4.0, 1.0) * s, c + Vector2(4.0, 5.0) * s, ink, 1.6, true)
		&"anvil":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-6.0, -2.0) * s, c + Vector2(5.0, -2.0) * s,
					c + Vector2(2.0, 1.0) * s, c + Vector2(2.0, 3.0) * s, c + Vector2(-2.0, 3.0) * s, c + Vector2(-2.0, 1.0) * s]), ink)
		&"mug":
			ci.draw_rect(Rect2(c + Vector2(-3.5, -4.0) * s, Vector2(7.0, 8.0) * s), ink, false, 1.6)
			ci.draw_arc(c + Vector2(4.5, 0.0) * s, 2.2 * s, -PI * 0.5, PI * 0.5, 8, ink, 1.4, true)
		&"bowl":
			ci.draw_arc(c + Vector2(0.0, -1.0) * s, 5.0 * s, 0.0, PI, 10, ink, 1.8, true)
			ci.draw_line(c + Vector2(-5.0, -1.0) * s, c + Vector2(5.0, -1.0) * s, ink, 1.6, true)
		&"scales":
			ci.draw_line(c + Vector2(0.0, -5.0) * s, c + Vector2(0.0, 4.0) * s, ink, 1.4, true)
			ci.draw_line(c + Vector2(-5.0, -3.0) * s, c + Vector2(5.0, -3.0) * s, ink, 1.4, true)
			ci.draw_arc(c + Vector2(-5.0, 0.0) * s, 2.0 * s, 0.0, PI, 6, ink, 1.2, true)
			ci.draw_arc(c + Vector2(5.0, 0.0) * s, 2.0 * s, 0.0, PI, 6, ink, 1.2, true)
		&"seal":
			ci.draw_circle(c, 4.0 * s, Color(ink, 0.0), false, 1.4, true)
			ci.draw_arc(c, 4.0 * s, 0.0, TAU, 14, ink, 1.4, true)
			ci.draw_line(c + Vector2(-2.0, 0.0) * s, c + Vector2(2.0, 0.0) * s, ink, 1.2, true)


## Text with a soft paper halo (legible over ink and wash).
static func label(ci: CanvasItem, font: Font, at: Vector2, text: String, size: int, color: Color, halo: Color, centered: bool = true, spacing: float = 0.0) -> void:
	if text == "":
		return
	if spacing > 0.0:
		_spaced(ci, font, at, text, size, color, halo, spacing)
		return
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var p := at - Vector2(w * 0.5 if centered else 0.0, -size * 0.35)
	ci.draw_string_outline(font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 5, halo)
	ci.draw_string(font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


static func spaced_width(font: Font, text: String, size: int, spacing: float) -> float:
	var w := 0.0
	for ch: String in text:
		w += font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x + spacing
	return w - spacing


static func _spaced(ci: CanvasItem, font: Font, at: Vector2, text: String, size: int, color: Color, halo: Color, spacing: float) -> void:
	var w := spaced_width(font, text, size, spacing)
	var x := at.x - w * 0.5
	var y := at.y + size * 0.35
	for ch: String in text:
		ci.draw_string_outline(font, Vector2(x, y), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 4, halo)
		ci.draw_string(font, Vector2(x, y), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
		x += font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x + spacing
