class_name MapLegend
extends Control
## The key of the map (MapPanel, beside the sheet, on and off with its button): the same pictograms the
## sheet uses, on parchment, with a small note about the sheet that is shown.

const TITLE := "Zeichenerklärung"
const ENTRIES: Array[Array] = [
	[&"player", "Du (Blickrichtung)"], [&"carter", "Osric mit Karren"], [&"person", "Bekannte Leute"],
	[&"order", "Auftrag / Abgabeort"], [&"free", "Grabstelle frei"], [&"taken", "Grab belegt"],
	[&"tended", "Grab gepflegt"], [&"locked", "Noch gesperrt"], [&"house", "Haus"], [&"road", "Weg"],
	[&"fence", "Zaun"], [&"water", "Wasser"], [&"tree", "Baum"],
]
const NOTE := "Fahre mit der Maus über einen Ort: Wer dort wohnt, wann offen ist, was zu tun ist."
const ROW := 36.0

var cfg: MapConfig


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	if cfg == null:
		return
	var font := get_theme_default_font()
	var r := Rect2(Vector2.ZERO, size)
	draw_texture_rect(MapPaint.paper_texture(cfg.paper, cfg.paper_dark), r, false)
	draw_rect(r.grow(-10.0), cfg.ink, false, 2.0)
	draw_rect(r.grow(-15.0), Color(cfg.ink, 0.6), false, 0.8)
	var title_w := font.get_string_size(TITLE, HORIZONTAL_ALIGNMENT_LEFT, -1, cfg.font_building + 5).x
	draw_string(font, Vector2((size.x - title_w) * 0.5, 58.0), TITLE, HORIZONTAL_ALIGNMENT_LEFT, -1, cfg.font_building + 5, cfg.sepia.darkened(0.25))
	MapPaint.ornament(self, Vector2(size.x * 0.5, 76.0), size.x * 0.36, cfg.ink, cfg.sepia)
	for i: int in ENTRIES.size():
		var c := Vector2(52.0, 112.0 + i * ROW)
		glyph(self, cfg, ENTRIES[i][0], c)
		draw_string(font, c + Vector2(30.0, 7.0), str(ENTRIES[i][1]), HORIZONTAL_ALIGNMENT_LEFT, -1, cfg.font_building, cfg.ink)
	var y := 112.0 + ENTRIES.size() * ROW + 6.0
	MapPaint.ornament(self, Vector2(size.x * 0.5, y), size.x * 0.36, cfg.ink, cfg.sepia)
	draw_multiline_string(font, Vector2(30.0, y + 34.0), NOTE, HORIZONTAL_ALIGNMENT_LEFT, size.x - 60.0, cfg.font_small + 1, -1, Color(cfg.ink, 0.8))


static func glyph(ci: CanvasItem, cfg: MapConfig, key: StringName, c: Vector2) -> void:
	var r := cfg.grave_radius + 1.0
	match key:
		&"player":
			MapPaint.hat_marker(ci, c, 11.0, Vector2(1.0, -0.6), cfg.player_mark, cfg.player_ring, cfg.paper)
		&"carter":
			MapPaint.cart(ci, c, 1.0, cfg.ink, cfg.carter.lightened(0.35))
		&"person":
			MapPaint.figure(ci, c, cfg.person_radius, cfg.person.lightened(0.35), cfg.ink)
		&"order":
			MapPaint.seal(ci, c + Vector2(0.0, -4.0), 7.0, cfg.objective, cfg.ink)
		&"free":
			ci.draw_arc(c, r, 0.0, TAU, 14, Color(cfg.ink, 0.8), 1.3, true)
		&"taken":
			ci.draw_circle(c, r, cfg.sepia, true, -1.0, true)
			ci.draw_arc(c, r, 0.0, TAU, 14, cfg.ink, 1.0, true)
		&"tended":
			MapPaint.tended_grave(ci, c, r, cfg.ink, cfg.grave_tended)
		&"locked":
			var rr := Rect2(c - Vector2(13.0, 9.0), Vector2(26.0, 18.0))
			ci.draw_rect(rr, cfg.locked_wash, true)
			MapPaint.hatch(ci, rr, Color(cfg.ink_faded, 0.55), 5.0)
			ci.draw_rect(rr, Color(cfg.ink_faded, 0.7), false, 1.0)
		&"house":
			var poly := PackedVector2Array([c + Vector2(-13.0, -8.0), c + Vector2(13.0, -8.0), c + Vector2(13.0, 8.0), c + Vector2(-13.0, 8.0)])
			MapPaint.house(ci, poly, true, cfg.roof, cfg.ink, 3)
		&"road":
			ci.draw_line(c - Vector2(14.0, 0.0), c + Vector2(14.0, 0.0), cfg.road, 9.0, true)
			ci.draw_line(c + Vector2(-14.0, -4.5), c + Vector2(14.0, -4.5), cfg.ink, 1.0, true)
			ci.draw_line(c + Vector2(-14.0, 4.5), c + Vector2(14.0, 4.5), cfg.ink, 1.0, true)
		&"fence":
			MapPaint.dashed(ci, c - Vector2(14.0, 0.0), c + Vector2(14.0, 0.0), cfg.ink, 1.4, 6.0, 3.0, true)
		&"water":
			ci.draw_line(c - Vector2(14.0, 0.0), c + Vector2(14.0, 0.0), cfg.water, 10.0, true)
			ci.draw_line(c + Vector2(-14.0, -5.0), c + Vector2(14.0, -5.0), Color(cfg.ink, 0.6), 1.0, true)
			ci.draw_line(c + Vector2(-14.0, 5.0), c + Vector2(14.0, 5.0), Color(cfg.ink, 0.6), 1.0, true)
		&"tree":
			MapPaint.tree(ci, c, 11.0, cfg.tree, cfg.tree_dark, &"tree", 3)
