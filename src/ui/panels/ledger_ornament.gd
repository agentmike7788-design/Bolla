class_name LedgerOrnament
extends Control
## Small ink ornament of the grave register page: a thin double rule with a diamond and
## two dots in the middle. Colours from the theme type "LedgerOrnament" (ink, rule).

const THEME_TYPE := &"LedgerOrnament"

@export var diamond_radius: float = 7.0
## Half width of the gap around the centre motif.
@export var gap: float = 34.0


func _init() -> void:
	custom_minimum_size = Vector2(0.0, 22.0)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var ink := get_theme_color(&"ink", THEME_TYPE)
	var rule := get_theme_color(&"rule", THEME_TYPE)
	var mid := size * 0.5
	var r := diamond_radius
	for side: float in [-1.0, 1.0]:
		var inner := mid.x + side * gap
		var outer := mid.x + side * (mid.x - 4.0)
		draw_line(Vector2(inner, mid.y - 2.0), Vector2(outer, mid.y - 2.0), rule, 1.5, true)
		draw_line(Vector2(inner, mid.y + 2.0), Vector2(outer, mid.y + 2.0), rule, 1.0, true)
		draw_circle(mid + Vector2(side * (r + 10.0), 0.0), 2.5, ink, true, -1.0, true)
	var diamond := PackedVector2Array([
		mid + Vector2(0.0, -r), mid + Vector2(r, 0.0), mid + Vector2(0.0, r), mid + Vector2(-r, 0.0)])
	draw_colored_polygon(diamond, ink)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED or what == NOTIFICATION_THEME_CHANGED:
		queue_redraw()
