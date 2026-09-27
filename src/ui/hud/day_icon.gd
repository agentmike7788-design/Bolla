class_name DayIcon
extends Control
## Drawn sun (day) or crescent moon (night) next to the HUD clock.
## Colours come from the theme type "DayIcon" (sun, sun_glow, moon, moon_glow).

const THEME_TYPE := &"DayIcon"
const RAY_COUNT := 8
## Radii relative to half the control edge.
const SUN_RADIUS := 0.46
const RAY_INNER := 0.62
const RAY_OUTER := 0.9
const RAY_WIDTH := 0.1
const GLOW_RADIUS := 1.0
const MOON_RADIUS := 0.6
## Offset of the shadow disc that cuts the crescent (relative to the moon radius).
const MOON_CUT := Vector2(0.45, -0.3)
const MOON_CUT_RADIUS := 0.86
const DISC_SEGMENTS := 40

## true = moon.
var night: bool = false:
	set(value):
		if night != value:
			night = value
			queue_redraw()


func _init() -> void:
	custom_minimum_size = Vector2(44, 44)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var half := minf(size.x, size.y) * 0.5
	var c := size * 0.5
	if night:
		_draw_moon(c, half)
	else:
		_draw_sun(c, half)


func _draw_sun(c: Vector2, half: float) -> void:
	var sun := get_theme_color(&"sun", THEME_TYPE)
	draw_circle(c, half * GLOW_RADIUS, get_theme_color(&"sun_glow", THEME_TYPE))
	for i: int in RAY_COUNT:
		var dir := Vector2.RIGHT.rotated(TAU * i / RAY_COUNT)
		draw_line(c + dir * half * RAY_INNER, c + dir * half * RAY_OUTER, sun, half * RAY_WIDTH, true)
	draw_circle(c, half * SUN_RADIUS, sun)


## Crescent = moon disc minus an offset disc (polygon clip, so the glow stays visible).
func _draw_moon(c: Vector2, half: float) -> void:
	var r := half * MOON_RADIUS
	draw_circle(c, half * GLOW_RADIUS, get_theme_color(&"moon_glow", THEME_TYPE))
	var moon := _disc(c, r)
	var cut := _disc(c + MOON_CUT * r, r * MOON_CUT_RADIUS)
	# The cut disc pokes out of the moon on one side only, so the result has no holes.
	for part: PackedVector2Array in Geometry2D.clip_polygons(moon, cut):
		draw_colored_polygon(part, get_theme_color(&"moon", THEME_TYPE))


func _disc(center: Vector2, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i: int in DISC_SEGMENTS:
		points.append(center + Vector2.RIGHT.rotated(TAU * i / DISC_SEGMENTS) * radius)
	return points
