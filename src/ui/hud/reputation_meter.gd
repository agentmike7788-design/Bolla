class_name ReputationMeter
extends Control
## Slim reputation bar 0…100 with a tick at every tier threshold (docs/PHASE3_DESIGN.md §7).
## Colours from the theme type "ReputationMeter" (track, fill, tick, frame).

const THEME_TYPE := &"ReputationMeter"

var value: int = 0:
	set(v):
		value = clampi(v, 0, 100)
		queue_redraw()
var thresholds: PackedInt32Array = PackedInt32Array():
	set(v):
		thresholds = v
		queue_redraw()


func _init() -> void:
	custom_minimum_size = Vector2(220.0, 10.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	draw_rect(r, _color(&"track", Color(0.063, 0.086, 0.122, 0.9)))
	var fill := r
	fill.size.x = r.size.x * float(value) / 100.0
	draw_rect(fill, _color(&"fill", Color(0.949, 0.663, 0.231)))
	var tick := _color(&"tick", Color(0.93, 0.88, 0.77, 0.7))
	for t: int in thresholds:
		var x := roundf(r.size.x * float(t) / 100.0)
		draw_line(Vector2(x, -2.0), Vector2(x, r.size.y + 2.0), tick, 2.0)
	draw_rect(r, _color(&"frame", Color(0.29, 0.22, 0.165)), false, 1.0)


func _color(name: StringName, fallback: Color) -> Color:
	return get_theme_color(name, THEME_TYPE) if has_theme_color(name, THEME_TYPE) else fallback
