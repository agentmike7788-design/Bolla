class_name MapCanvas
extends Control
## One sheet of the map (MapPanel): the region's MapLayout painted as an ink-and-wash estate map, the
## MapState context on top. show_region() computes everything that is not paint – the projection, the
## section states, the labels, the markers, the hover spots – so tests can read it without a renderer;
## _draw only paints it. Tooltips: _get_tooltip() over buildings (keeper, opening hours), people,
## orders, landmarks, sections and graves.

const TEXT_OPEN_NOW := "Jetzt geöffnet"
const TEXT_CLOSED_NOW := "Jetzt geschlossen"
const TEXT_SHOP_HOURS := "Laden: %s"
const TEXT_DOOR_HOURS := "Tür offen: %s"
const TEXT_SPAN := "%s–%s"
const TEXT_LOCKED := "%s (noch nicht freigelegt)"
const TEXT_UNKNOWN := "Unbekannt"
const TEXT_ORDER := "Auftrag: %s"
const TEXT_YOU := "Du"
const TEXT_YOU_IN := "Du bist hier: %s"
const TEXT_SITE := "%s (Bauplatz)"
const GRAVE_TEXTS: Dictionary[StringName, String] = {&"free": "Freie Grabstelle", &"taken": "Belegtes Grab",
		&"tended": "Gepflegtes Grab mit Grabzeichen"}
const LEGEND_TITLE := "Zeichenerklärung"
const LEGEND: Array[Array] = [
	[&"player", "Du (Blickrichtung)"], [&"carter", "Osric mit Karren"], [&"person", "Bekannte Leute"],
	[&"order", "Auftrag / Abgabeort"], [&"free", "Grabstelle frei"], [&"taken", "Grab belegt"],
	[&"tended", "Grab gepflegt"], [&"locked", "Noch gesperrt"], [&"road", "Weg"], [&"fence", "Zaun"],
	[&"water", "Wasser"], [&"tree", "Baum"],
]
const MARGIN := 34.0

var cfg: MapConfig
var layout: MapLayout
var ctx: Dictionary = {}
var region: StringName = &""
var legend_visible: bool = true:
	set(value):
		legend_visible = value
		queue_redraw()

## px per metre and the top-left of the view on the sheet.
var map_scale: float = 1.0
var map_offset: Vector2 = Vector2.ZERO
## Section id → &"open" | &"locked" | &"hidden".
var section_view: Dictionary[StringName, StringName] = {}
## Layout id → the text written on the sheet (buildings, landmarks, sections, area names).
var labels: Dictionary[String, String] = {}
## Buildings drawn (ids) – the graveyard's sites only from buildings_open.
var shown_buildings: PackedStringArray = []
## Graves drawn: id → free / taken / tended.
var shown_graves: Dictionary[String, StringName] = {}
## Player marker on the sheet (px) and heading (map direction; ZERO inside a room). INF = not here.
var player_point: Vector2 = Vector2.INF
var player_heading: Vector2 = Vector2.ZERO
## [{kind, point: Vector2, name, text}] – people and order seals.
var markers: Array[Dictionary] = []
## [{point: Vector2, radius: float, text: String}] for the tooltips (first hit wins).
var hotspots: Array[Dictionary] = []

var _font: Font


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true


## Shows `region_id` of `the_layout` with the live `context` (MapState.context).
func show_region(region_id: StringName, the_layout: MapLayout, context: Dictionary, config: MapConfig) -> void:
	region = region_id
	layout = the_layout
	ctx = context
	cfg = config
	_rebuild()
	queue_redraw()


## Sheet position (px) of a region-local position (m).
func world_to_map(local: Vector2) -> Vector2:
	if layout == null:
		return local
	return map_offset + (local - layout.view.position) * map_scale


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and layout != null:
		_rebuild()
		queue_redraw()


# --- model ----------------------------------------------------------------------------------

func _rebuild() -> void:
	section_view.clear()
	labels.clear()
	shown_buildings.clear()
	shown_graves.clear()
	markers.clear()
	hotspots.clear()
	player_point = Vector2.INF
	player_heading = Vector2.ZERO
	if layout == null or cfg == null:
		return
	var area := Rect2(Vector2(MARGIN, MARGIN), size - Vector2(MARGIN, MARGIN) * 2.0)
	if area.size.x <= 0.0 or area.size.y <= 0.0:
		area = Rect2(Vector2.ZERO, Vector2(1000.0, 700.0))
	map_scale = minf(area.size.x / layout.view.size.x, area.size.y / layout.view.size.y)
	map_offset = area.position + (area.size - layout.view.size * map_scale) * 0.5
	var flags: Dictionary = ctx.get("flags", {})
	var sections: Dictionary = ctx.get("sections", {})
	for s: Dictionary in layout.sections:
		var id: StringName = s.id
		var info: Dictionary = sections.get(id, {})
		var state := &"open" if bool(info.get("unlocked", id == &"yard")) else &"locked"
		var known := bool(info.get("known", true))
		if state == &"locked" and not known and String(id) in cfg.hidden_sections:
			state = &"hidden"
		section_view[id] = state
		if state == &"hidden":
			continue
		var name := str(info.get("name", String(id)))
		labels[String(id)] = name if state == &"open" or known else cfg.unknown_section_text
		var tip := name if state == &"open" else (TEXT_LOCKED % name if known else TEXT_UNKNOWN)
		_spot(world_to_map(s.rect.get_center()), minf(s.rect.size.x, s.rect.size.y) * map_scale * 0.35, tip)
	_rebuild_buildings(flags)
	for l: Dictionary in layout.landmarks:
		if l.id == "obs_c_gate" and not _section_shown(&"churchyard"):
			continue
		labels[l.id] = l.label
		if l.label != "":
			_spot(world_to_map(l.pos), cfg.hotspot_radius, l.label)
	for a: Dictionary in layout.area_labels:
		labels[a.key] = a.text
	var graves: Dictionary = ctx.get("graves", {})
	for g: Dictionary in layout.graves:
		if section_view.get(g.section, &"open") != &"open":
			continue
		var kind: StringName = graves.get(g.id, &"taken" if g.old else &"free")
		if kind == &"locked":
			continue
		shown_graves[g.id] = kind
		_spot(world_to_map(g.pos), cfg.grave_radius + 3.0, GRAVE_TEXTS.get(kind, ""))
	_rebuild_player()
	_rebuild_people()
	_rebuild_orders()


func _rebuild_buildings(flags: Dictionary) -> void:
	var sites_on := bool(flags.get(cfg.buildings_flag, false))
	var shops: Dictionary = ctx.get("shops", {})
	var levels: Dictionary = ctx.get("building_levels", {})
	for b: Dictionary in layout.buildings:
		if b.site and not sites_on:
			continue
		shown_buildings.append(b.id)
		labels[b.id] = b.label
		var lines := PackedStringArray([b.label])
		if b.site and int(levels.get(String(b.id).trim_prefix("site_"), 1)) <= 0:
			lines[0] = TEXT_SITE % b.label
		for shop_id: Variant in cfg.shop_places:
			if cfg.shop_places[shop_id] != b.id:
				continue
			lines.append_array(_shop_lines(shops.get(shop_id, {})))
		var windows: PackedInt32Array = layout.door_windows.get(b.id, PackedInt32Array())
		if not windows.is_empty():
			lines.append(TEXT_DOOR_HOURS % _spans(windows))
		_spot(world_to_map(b.center), maxf(b.size.x, b.size.y) * map_scale * 0.5, "\n".join(lines))
	for l: Dictionary in layout.landmarks:
		for shop_id: Variant in cfg.shop_places:
			if cfg.shop_places[shop_id] == l.id:
				var lines := PackedStringArray([l.label])
				lines.append_array(_shop_lines(shops.get(shop_id, {})))
				_spot(world_to_map(l.pos), cfg.hotspot_radius, "\n".join(lines))


func _shop_lines(shop: Dictionary) -> PackedStringArray:
	var out := PackedStringArray()
	if shop.is_empty():
		return out
	if str(shop.get("keeper", "")) != "":
		out.append(str(shop.keeper))
	var hours: Array = shop.get("hours", [])
	if not hours.is_empty():
		var spans := PackedStringArray()
		for h: Vector2i in hours:
			spans.append(TEXT_SPAN % [UIKit.clock(h.x), UIKit.clock(h.y)])
		out.append(TEXT_SHOP_HOURS % " · ".join(spans))
	out.append(TEXT_OPEN_NOW if bool(shop.get("open", false)) else TEXT_CLOSED_NOW)
	return out


static func _spans(windows: PackedInt32Array) -> String:
	var parts := PackedStringArray()
	for i: int in range(0, windows.size() - 1, 2):
		parts.append(TEXT_SPAN % [UIKit.clock(windows[i]), UIKit.clock(windows[i + 1])])
	return " · ".join(parts)


func _rebuild_player() -> void:
	var p: Dictionary = ctx.get("player", {})
	if p.is_empty() or ctx.get("region", &"graveyard") != region:
		return
	var room: StringName = ctx.get("room", &"")
	var local: Vector2
	if room != &"" and layout.places.has(cfg.room_places.get(room, "")):
		local = layout.places[cfg.room_places[room]]
		_spot(world_to_map(local), cfg.player_radius, TEXT_YOU_IN % labels.get(cfg.room_places[room], String(room)))
	else:
		local = layout.local_of(p.world, cfg)
		var h := float(p.get("heading", 0.0))
		player_heading = Vector2(sin(h), cos(h))
		_spot(world_to_map(local), cfg.player_radius, TEXT_YOU)
	player_point = world_to_map(local)


func _rebuild_people() -> void:
	var stacked: Dictionary[Vector2i, int] = {}
	for person: Dictionary in ctx.get("people", []):
		if StringName(str(person.get("region", "graveyard"))) != region:
			continue
		var local := layout.local_of(person.world, cfg)
		if not layout.view.grow(2.0).has_point(local):
			continue
		var point := world_to_map(local)
		var key := Vector2i(roundi(point.x / 12.0), roundi(point.y / 12.0))
		var n: int = stacked.get(key, 0)
		stacked[key] = n + 1
		point += Vector2(n * 14.0, -n * 4.0)
		var kind: StringName = person.kind
		var first := str(person.name).get_slice(" ", 0)
		markers.append({"kind": kind, "point": point, "name": first, "text": str(person.name), "id": person.id})
		_spot(point, cfg.person_radius + 6.0, str(person.name))


func _rebuild_orders() -> void:
	var stacked: Dictionary[String, int] = {}
	for o: Dictionary in ctx.get("orders", []):
		if StringName(str(o.get("region", ""))) != region:
			continue
		var place := str(o.get("place", ""))
		if not layout.places.has(place):
			place = str(o.get("fallback", ""))
		if not layout.places.has(place):
			continue
		var n: int = stacked.get(place, 0)
		stacked[place] = n + 1
		var point := world_to_map(layout.places[place]) + Vector2(10.0 + n * 13.0, -16.0)
		var text := TEXT_ORDER % str(o.get("title", ""))
		markers.append({"kind": &"order", "point": point, "name": "", "text": text, "id": o.get("id", &"")})
		_spot(point, 10.0, text)


func _section_shown(id: StringName) -> bool:
	return section_view.get(id, &"open") != &"hidden"


func _spot(point: Vector2, radius: float, text: String) -> void:
	if text != "":
		hotspots.push_front({"point": point, "radius": maxf(radius, 6.0), "text": text})


func _get_tooltip(at_position: Vector2) -> String:
	return tooltip_at(at_position)


## The text of the nearest hover spot under `at` ("" = none).
func tooltip_at(at: Vector2) -> String:
	var best := ""
	var best_d := INF
	for h: Dictionary in hotspots:
		var d := at.distance_to(h.point)
		if d <= h.radius and d / h.radius < best_d:
			best_d = d / h.radius
			best = h.text
	return best


func person_marker(id: StringName) -> Dictionary:
	for m: Dictionary in markers:
		if m.get("id") == id and m.kind != &"order":
			return m
	return {}


func order_markers() -> Array[Dictionary]:
	return markers.filter(func(m: Dictionary) -> bool: return m.kind == &"order")


# --- paint ----------------------------------------------------------------------------------

func _draw() -> void:
	if layout == null or cfg == null:
		return
	_font = get_theme_default_font()
	var sheet := Rect2(Vector2.ZERO, size)
	draw_texture_rect(MapPaint.paper_texture(cfg.paper, cfg.paper_dark), sheet, false)
	_draw_sections()
	_draw_waters()
	_draw_ways()
	_draw_fences()
	_draw_cliffs()
	_draw_trees()
	_draw_buildings()
	_draw_graves()
	_draw_landmarks()
	_draw_labels()
	_draw_markers()
	_draw_frame(sheet)
	if legend_visible:
		_draw_legend()


func _m(local: Vector2) -> Vector2:
	return world_to_map(local)


func _mp(pts: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p: Vector2 in pts:
		out.append(_m(p))
	return out


func _draw_sections() -> void:
	var i := 0
	for s: Dictionary in layout.sections:
		i += 1
		var state: StringName = section_view.get(s.id, &"open")
		if state == &"hidden":
			continue
		var r := Rect2(_m(s.rect.position), s.rect.size * map_scale)
		if state == &"open":
			draw_rect(r, cfg.meadow, true)
			draw_rect(r.grow(-3.0), Color(cfg.meadow, cfg.meadow.a * 0.6), true)
		else:
			draw_rect(r, cfg.locked_wash, true)
			MapPaint.hatch(self, r.grow(-2.0), Color(cfg.ink_faded, 0.28), 9.0)
	for p: Dictionary in layout.plazas:
		var c := _m(p.center)
		draw_circle(c, p.radius * map_scale, cfg.paving, true, -1.0, true)
		draw_arc(c, p.radius * map_scale, 0.0, TAU, 48, Color(cfg.ink, 0.55), 1.2, true)
	for r: Rect2 in layout.plaza_rects:
		draw_rect(Rect2(_m(r.position), r.size * map_scale), cfg.paving, true)


func _draw_waters() -> void:
	var i := 0
	for w: Dictionary in layout.waters:
		var pts := _mp(w.points)
		var width := float(w.half_width) * 2.0 * map_scale
		for k: int in 3:
			var c := cfg.water
			c.a *= 0.55 + k * 0.2
			draw_polyline(MapPaint.wobble(pts, 2.0 + k, 11 + k + i), c, width * (1.15 - k * 0.22), true)
		for side: float in [-0.5, 0.5]:
			MapPaint.ink_line(self, MapPaint.offset_line(pts, side * width), Color(cfg.ink, 0.6), 1.2, 3 + i, 1.2)
		for k: int in range(2, pts.size() - 2, 3):
			var a := pts[k]
			draw_line(a + Vector2(-width * 0.18, 0.0), a + Vector2(width * 0.12, 3.0), Color(cfg.water.darkened(0.35), 0.6), 1.0, true)
		i += 1


func _draw_ways() -> void:
	var i := 0
	for w: Dictionary in layout.ways:
		i += 1
		var pts := _mp(w.points)
		var width := maxf(float(w.width) * map_scale, 3.0)
		match w.kind:
			&"road", &"lane":
				draw_polyline(MapPaint.wobble(pts, 0.8, i), cfg.road, width, true)
				for side: float in [-0.5, 0.5]:
					MapPaint.ink_line(self, MapPaint.offset_line(pts, side * width), Color(cfg.ink, 0.75), 1.2, i * 7 + int(side * 4.0), 0.7)
			_:
				draw_polyline(MapPaint.wobble(pts, 0.8, i), Color(cfg.road, cfg.road.a * 0.8), width * 0.8, true)
				var dotted := MapPaint.wobble(pts, 0.6, i + 40)
				for k: int in range(0, dotted.size() - 1, 2):
					draw_line(dotted[k], dotted[k + 1], Color(cfg.ink, 0.6), 1.1, true)


func _draw_fences() -> void:
	for f: PackedVector2Array in layout.fences:
		MapPaint.dashed(self, _m(f[0]), _m(f[1]), Color(cfg.ink, 0.85), 1.4, 7.0, 3.0, true)


func _draw_cliffs() -> void:
	var i := 0
	for c: Dictionary in layout.cliffs:
		i += 1
		MapPaint.cliff(self, _m(c.pos), c.rot, float(c.len) * map_scale, Color(cfg.sepia, 0.85), i)


func _draw_trees() -> void:
	var i := 0
	for t: Dictionary in layout.trees:
		i += 1
		var p := _m(t.pos)
		if not Rect2(Vector2.ZERO, size).grow(30.0).has_point(p):
			continue
		var r := maxf(float(t.size) * map_scale * 0.5, 4.0)
		MapPaint.tree(self, p, r, cfg.tree, cfg.tree_dark, t.kind, i)


func _draw_buildings() -> void:
	var i := 0
	var levels: Dictionary = ctx.get("building_levels", {})
	for b: Dictionary in layout.buildings:
		i += 1
		if not b.id in shown_buildings:
			continue
		var poly := _mp(b.poly)
		var planned: bool = b.site and int(levels.get(String(b.id).trim_prefix("site_"), 1)) <= 0
		if planned:
			for k: int in 4:
				MapPaint.dashed(self, poly[k], poly[(k + 1) % 4], cfg.sepia, 1.4, 5.0, 4.0, false)
			draw_colored_polygon(poly, cfg.roof_site)
			continue
		var shadow := PackedVector2Array()
		for p: Vector2 in poly:
			shadow.append(p + Vector2(3.0, 3.5))
		draw_colored_polygon(shadow, Color(0.15, 0.09, 0.05, 0.28))
		draw_colored_polygon(poly, cfg.roof)
		# Ridge along the long side, the shaded half of the roof.
		var long_x: bool = b.size.x >= b.size.y
		var a := (poly[0] + poly[3]) * 0.5 if long_x else (poly[0] + poly[1]) * 0.5
		var e := (poly[1] + poly[2]) * 0.5 if long_x else (poly[3] + poly[2]) * 0.5
		var half := PackedVector2Array([a, e, poly[2], poly[3]]) if long_x else PackedVector2Array([a, e, poly[2], poly[1]])
		draw_colored_polygon(half, Color(0.2, 0.08, 0.05, 0.18))
		draw_line(a, e, Color(cfg.ink, 0.8), 1.2, true)
		MapPaint.ink_line(self, poly, cfg.ink, 1.6, i, 0.5, true)
		if b.glyph != &"":
			MapPaint.roof_glyph(self, b.glyph, _m(b.center), clampf(map_scale / 12.0, 0.8, 1.4), Color(cfg.paper, 0.92))


func _draw_graves() -> void:
	for g: Dictionary in layout.graves:
		if not shown_graves.has(g.id):
			continue
		var p := _m(g.pos)
		var r := cfg.grave_radius
		match shown_graves[g.id]:
			&"free":
				draw_arc(p, r, 0.0, TAU, 14, Color(cfg.ink, 0.8), 1.2, true)
			&"taken":
				draw_circle(p, r, cfg.sepia, true, -1.0, true)
				draw_arc(p, r, 0.0, TAU, 14, cfg.ink, 1.0, true)
			&"tended":
				draw_circle(p, r + 2.0, Color(cfg.grave_tended, 0.55), true, -1.0, true)
				draw_circle(p, r - 0.5, cfg.ink, true, -1.0, true)
				draw_line(p + Vector2(0.0, -r - 3.0), p + Vector2(0.0, -r + 1.0), cfg.ink, 1.2, true)


func _draw_landmarks() -> void:
	var s := clampf(map_scale / 12.0, 0.9, 1.5)
	for l: Dictionary in layout.landmarks:
		if not labels.has(l.id):
			continue
		MapPaint.glyph(self, l.glyph, _m(l.pos), s, cfg.ink, cfg.paper.darkened(0.08), cfg.water)


func _draw_labels() -> void:
	var halo := Color(cfg.paper, 0.85)
	for s: Dictionary in layout.sections:
		var text: String = labels.get(String(s.id), "")
		if text == "":
			continue
		var open: bool = section_view.get(s.id) == &"open"
		var color := Color(cfg.sepia, 0.9) if open else cfg.ink_faded
		var at := _m(s.rect.get_center())
		var size_px := cfg.font_area if text != cfg.unknown_section_text else cfg.font_area + 10
		MapPaint.label(self, _font, at, text.to_upper() if text != cfg.unknown_section_text else text, size_px, color, halo, true, 3.0)
	for a: Dictionary in layout.area_labels:
		var at := _m(a.pos)
		var ang: float = a.angle
		if ang > PI * 0.5:
			ang -= PI
		elif ang < -PI * 0.5:
			ang += PI
		draw_set_transform(at, ang)
		MapPaint.label(self, _font, Vector2.ZERO, str(a.text), cfg.font_building + 2, Color(cfg.sepia, 0.85), halo, true, 2.0)
		draw_set_transform(Vector2.ZERO)
	for b: Dictionary in layout.buildings:
		if not b.id in shown_buildings:
			continue
		var bottom := 0.0
		for p: Vector2 in b.poly:
			bottom = maxf(bottom, _m(p).y)
		MapPaint.label(self, _font, Vector2(_m(b.center).x, bottom + cfg.font_building * 0.8), b.label, cfg.font_building, cfg.ink, halo)
	for l: Dictionary in layout.landmarks:
		if not labels.has(l.id) or l.label == "":
			continue
		MapPaint.label(self, _font, _m(l.pos) + Vector2(0.0, 18.0), l.label, cfg.font_small, cfg.ink, halo)


func _draw_markers() -> void:
	var halo := Color(cfg.paper, 0.9)
	for m: Dictionary in markers:
		var p: Vector2 = m.point
		match m.kind:
			&"order":
				MapPaint.seal(self, p, 7.0, cfg.objective, cfg.ink)
			&"carter":
				MapPaint.cart(self, p, 1.0, cfg.ink, cfg.carter.lightened(0.35))
				MapPaint.label(self, _font, p + Vector2(0.0, -16.0), str(m.name), cfg.font_small, cfg.carter.darkened(0.3), halo)
			_:
				MapPaint.figure(self, p, cfg.person_radius, cfg.person.lightened(0.35), cfg.ink)
				MapPaint.label(self, _font, p + Vector2(0.0, -cfg.person_radius - 10.0), str(m.name), cfg.font_small, cfg.person.darkened(0.3), halo)
	if player_point != Vector2.INF:
		MapPaint.hat_marker(self, player_point, cfg.player_radius, player_heading, cfg.player_mark, cfg.player_ring, cfg.paper)


func _draw_frame(sheet: Rect2) -> void:
	var outer := sheet.grow(-10.0)
	var inner := sheet.grow(-16.0)
	draw_rect(outer, cfg.ink, false, 2.4)
	draw_rect(inner, Color(cfg.ink, 0.7), false, 1.0)
	for c: Vector2 in [outer.position, Vector2(outer.end.x, outer.position.y), outer.end, Vector2(outer.position.x, outer.end.y)]:
		var d := PackedVector2Array([c + Vector2(0.0, -6.0), c + Vector2(6.0, 0.0), c + Vector2(0.0, 6.0), c + Vector2(-6.0, 0.0)])
		draw_colored_polygon(d, cfg.ink)
	# Compass rose (top right) and scale (bottom left).
	MapPaint.compass(self, Vector2(sheet.end.x - 82.0, 96.0), 48.0, cfg.ink, cfg.paper, _font, cfg.font_building)
	var steps := cfg.scale_steps
	var length := steps * cfg.step_metres * map_scale
	MapPaint.scale_bar(self, Vector2(48.0, sheet.end.y - 70.0), length, 5, cfg.ink, cfg.paper, cfg.scale_text % steps, _font, cfg.font_small)
	# Title cartouche (top left).
	var title: String = cfg.map_titles.get(region, "")
	if title != "":
		var w := _font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, cfg.font_title).x
		var box := Rect2(Vector2(36.0, 32.0), Vector2(w + 48.0, cfg.font_title + 26.0))
		draw_rect(box, Color(cfg.paper, 0.92), true)
		draw_rect(box, cfg.ink, false, 1.6)
		draw_rect(box.grow(-4.0), Color(cfg.ink, 0.6), false, 0.8)
		draw_string(_font, box.position + Vector2(24.0, cfg.font_title + 8.0), title, HORIZONTAL_ALIGNMENT_LEFT, -1, cfg.font_title, cfg.sepia.darkened(0.2))


func _draw_legend() -> void:
	var row := 26.0
	var w := 250.0
	var h := 44.0 + LEGEND.size() * row
	var box := Rect2(Vector2(size.x - w - 34.0, size.y - h - 34.0), Vector2(w, h))
	draw_rect(box.grow(2.0), Color(0.15, 0.09, 0.05, 0.2), true)
	draw_rect(box, Color(cfg.paper.lightened(0.04), 0.96), true)
	draw_rect(box, cfg.ink, false, 1.4)
	draw_rect(box.grow(-4.0), Color(cfg.ink, 0.5), false, 0.8)
	draw_string(_font, box.position + Vector2(16.0, 28.0), LEGEND_TITLE, HORIZONTAL_ALIGNMENT_LEFT, -1, cfg.font_building, cfg.sepia.darkened(0.2))
	for i: int in LEGEND.size():
		var key: StringName = LEGEND[i][0]
		var c := box.position + Vector2(30.0, 48.0 + i * row)
		_legend_glyph(key, c)
		draw_string(_font, c + Vector2(26.0, 6.0), str(LEGEND[i][1]), HORIZONTAL_ALIGNMENT_LEFT, -1, cfg.font_small + 1, cfg.ink)


func _legend_glyph(key: StringName, c: Vector2) -> void:
	var r := cfg.grave_radius
	match key:
		&"player":
			MapPaint.hat_marker(self, c, 9.0, Vector2.ZERO, cfg.player_mark, cfg.player_ring, cfg.paper)
		&"carter":
			MapPaint.cart(self, c, 0.8, cfg.ink, cfg.carter.lightened(0.35))
		&"person":
			MapPaint.figure(self, c, cfg.person_radius, cfg.person.lightened(0.35), cfg.ink)
		&"order":
			MapPaint.seal(self, c + Vector2(0.0, -3.0), 6.0, cfg.objective, cfg.ink)
		&"free":
			draw_arc(c, r, 0.0, TAU, 14, Color(cfg.ink, 0.8), 1.2, true)
		&"taken":
			draw_circle(c, r, cfg.sepia, true, -1.0, true)
			draw_arc(c, r, 0.0, TAU, 14, cfg.ink, 1.0, true)
		&"tended":
			draw_circle(c, r + 2.0, Color(cfg.grave_tended, 0.55), true, -1.0, true)
			draw_circle(c, r - 0.5, cfg.ink, true, -1.0, true)
		&"locked":
			var rr := Rect2(c - Vector2(10.0, 7.0), Vector2(20.0, 14.0))
			draw_rect(rr, cfg.locked_wash, true)
			MapPaint.hatch(self, rr, Color(cfg.ink_faded, 0.5), 5.0)
		&"road":
			draw_line(c - Vector2(11.0, 0.0), c + Vector2(11.0, 0.0), cfg.road, 7.0, true)
			draw_line(c + Vector2(-11.0, -3.5), c + Vector2(11.0, -3.5), cfg.ink, 1.0, true)
			draw_line(c + Vector2(-11.0, 3.5), c + Vector2(11.0, 3.5), cfg.ink, 1.0, true)
		&"fence":
			MapPaint.dashed(self, c - Vector2(11.0, 0.0), c + Vector2(11.0, 0.0), cfg.ink, 1.4, 6.0, 3.0, true)
		&"water":
			draw_line(c - Vector2(11.0, 0.0), c + Vector2(11.0, 0.0), cfg.water, 8.0, true)
		&"tree":
			MapPaint.tree(self, c, 8.0, cfg.tree, cfg.tree_dark, &"tree", 3)
