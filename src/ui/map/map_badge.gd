class_name MapBadge
extends Button
## The map button of the HUD (clock panel, beside the Merkbuch): a small inked compass rose and
## „[M] Karte" like the Merkbuch's „[J] Merkbuch". UIRoot connects `pressed` to toggle_map. No minimap –
## the top-right corner already carries the resources, the quality and the reputation (G7 Änderungsrunde 1).

const TEXT := "[M] Karte"
const TEXT_TOOLTIP := "Karte öffnen [M]"

var label: Label


func _init() -> void:
	name = "MapBadge"
	flat = true
	focus_mode = Control.FOCUS_NONE
	tooltip_text = TEXT_TOOLTIP
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var row := UIKit.hbox(8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(CompassIcon.new())
	label = UIKit.label(TEXT, &"HudDimLabel")
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(label)
	add_child(row)
	custom_minimum_size = Vector2(150.0, 38.0)


func _ready() -> void:
	var row := get_child(0) as Control
	custom_minimum_size.x = maxf(custom_minimum_size.x, row.get_combined_minimum_size().x + 8.0)


## The rose of the badge, in the HUD's parchment ink.
class CompassIcon extends Control:
	const INK := Color(0.91, 0.863, 0.753, 0.9)
	const BACK := Color(0.113, 0.153, 0.212, 1.0)

	func _init() -> void:
		custom_minimum_size = Vector2(30.0, 30.0)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size_flags_vertical = Control.SIZE_SHRINK_CENTER

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.5 - 1.0
		draw_arc(c, r * 0.72, 0.0, TAU, 24, Color(INK, 0.7), 1.0, true)
		for i: int in 8:
			var a := -PI * 0.5 + i * PI * 0.25
			var long := i % 2 == 0
			var tip := c + Vector2(cos(a), sin(a)) * (r if long else r * 0.55)
			var side := r * (0.16 if long else 0.1)
			var left := c + Vector2(cos(a - PI * 0.5), sin(a - PI * 0.5)) * side
			var right := c + Vector2(cos(a + PI * 0.5), sin(a + PI * 0.5)) * side
			draw_colored_polygon(PackedVector2Array([c, left, tip]), INK if long else Color(INK, 0.7))
			draw_colored_polygon(PackedVector2Array([c, tip, right]), BACK.lightened(0.15))
		# North in candle amber.
		var n := c + Vector2(0.0, -r)
		draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.16, 0.0), n, c + Vector2(r * 0.16, 0.0)]), Color(0.949, 0.663, 0.231, 1.0))
