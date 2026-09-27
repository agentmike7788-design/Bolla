class_name TitleBackdrop
extends Control
## Drawn title backdrop in the approved palette: ink-blue night sky, pale moon, drifting
## fog, a hill of gravestone silhouettes and the gravekeeper's hut with a candle-amber
## window. Pure 2D (no 3D view); layout is relative to the control size. Glows, fog and
## vignette are soft gradient textures (no banding).

const SKY_TOP := Color(0.043, 0.063, 0.094)
const SKY_HORIZON := Color(0.137, 0.184, 0.251)
const MOON := Color(0.87, 0.87, 0.8)
const MOON_GLOW := Color(0.72, 0.8, 0.85, 0.3)
const STAR := Color(0.85, 0.87, 0.82, 0.55)
const HILL_FAR := Color(0.086, 0.114, 0.157)
const HILL_NEAR := Color(0.039, 0.055, 0.078)
const FOG := Color(0.718, 0.761, 0.69, 0.13)
const AMBER := Color(0.949, 0.663, 0.231)
const AMBER_GLOW := Color(0.949, 0.663, 0.231, 0.4)
const VIGNETTE := Color(0.0, 0.0, 0.0, 0.55)
const STAR_COUNT := 70
const STAR_SEED := 1797
const HILL_STEPS := 48
const TEXTURE_SIZE := 256
## [x (relative), height (relative), kind: 0 round stone, 1 cross, 2 leaning slab]
const GRAVES: Array[Vector3] = [
	Vector3(0.08, 0.075, 0), Vector3(0.15, 0.1, 1), Vector3(0.22, 0.06, 2), Vector3(0.3, 0.085, 0),
	Vector3(0.37, 0.12, 1), Vector3(0.45, 0.07, 0), Vector3(0.53, 0.09, 2), Vector3(0.6, 0.105, 1),
	Vector3(0.67, 0.065, 0),
]

## Seconds for one fog drift cycle.
@export var fog_period: float = 40.0

var _time: float = 0.0
var _stars: PackedVector3Array = []
var _moon_glow: GradientTexture2D
var _window_glow: GradientTexture2D
var _fog: GradientTexture2D
var _vignette: GradientTexture2D


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rng := RandomNumberGenerator.new()
	rng.seed = STAR_SEED
	for i: int in STAR_COUNT:
		_stars.append(Vector3(rng.randf(), rng.randf_range(0.0, 0.55), rng.randf_range(0.8, 2.2)))
	_moon_glow = _radial([0.0, 1.0], [MOON_GLOW, Color(MOON_GLOW, 0.0)])
	_window_glow = _radial([0.0, 1.0], [AMBER_GLOW, Color(AMBER_GLOW, 0.0)])
	_vignette = _radial([0.0, 0.62, 1.0], [Color(VIGNETTE, 0.0), Color(VIGNETTE, 0.0), VIGNETTE])
	_fog = _linear_band(FOG)


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, h), Vector2(0, h)]),
			PackedColorArray([SKY_TOP, SKY_TOP, SKY_HORIZON, SKY_HORIZON]))
	for s: Vector3 in _stars:
		draw_circle(Vector2(s.x * w, s.y * h), s.z, STAR)
	var moon := Vector2(w * 0.8, h * 0.2)
	var moon_r := h * 0.055
	_draw_centered(_moon_glow, moon, moon_r * 5.0)
	draw_circle(moon, moon_r, MOON)
	_draw_hill(HILL_FAR, h * 0.66, h * 0.05, 1.3, 0.0)
	_draw_fog(h * 0.62, h * 0.09, 0.0)
	_draw_hill(HILL_NEAR, h * 0.8, h * 0.035, 2.1, 1.7)
	_draw_hut(Vector2(w * 0.78, h * 0.79), h * 0.16)
	_draw_graves(h * 0.8)
	_draw_fog(h * 0.85, h * 0.12, PI)
	draw_texture_rect(_vignette, Rect2(Vector2.ZERO, size), false)


func _draw_hill(color: Color, base_y: float, amplitude: float, waves: float, phase: float) -> void:
	var points := PackedVector2Array()
	for i: int in HILL_STEPS + 1:
		var t := float(i) / HILL_STEPS
		points.append(Vector2(size.x * t, base_y - sin(t * PI * waves + phase) * amplitude))
	points.append(Vector2(size.x, size.y))
	points.append(Vector2(0, size.y))
	draw_colored_polygon(points, color)


## Two soft, slowly drifting fog bands around center_y.
func _draw_fog(center_y: float, thickness: float, phase: float) -> void:
	var w := size.x
	var drift := sin(_time * TAU / fog_period + phase) * w * 0.04
	for i: int in 2:
		var y := center_y - thickness * 0.5 + (i - 0.5) * thickness * 0.4
		draw_texture_rect(_fog, Rect2(Vector2(-w * 0.1 + drift * (1.0 + i), y), Vector2(w * 1.2, thickness)), false)


func _draw_graves(ground_y: float) -> void:
	var h := size.y
	for g: Vector3 in GRAVES:
		var base := Vector2(g.x * size.x, ground_y - sin(g.x * PI * 2.1 + 1.7) * h * 0.035 + h * 0.012)
		var gh := g.y * h
		var gw := gh * 0.5
		match int(g.z):
			0:
				draw_rect(Rect2(base + Vector2(-gw * 0.5, -gh + gw * 0.5), Vector2(gw, gh - gw * 0.5)), HILL_NEAR)
				draw_circle(base + Vector2(0, -gh + gw * 0.5), gw * 0.5, HILL_NEAR)
			1:
				draw_rect(Rect2(base + Vector2(-gw * 0.12, -gh), Vector2(gw * 0.24, gh)), HILL_NEAR)
				draw_rect(Rect2(base + Vector2(-gw * 0.45, -gh * 0.78), Vector2(gw * 0.9, gw * 0.22)), HILL_NEAR)
			_:
				draw_colored_polygon(PackedVector2Array([base + Vector2(-gw * 0.45, 0), base + Vector2(gw * 0.45, 0),
						base + Vector2(gw * 0.7, -gh), base + Vector2(-gw * 0.15, -gh * 1.05)]), HILL_NEAR)


func _draw_hut(base: Vector2, height: float) -> void:
	var body := Vector2(height * 1.1, height * 0.62)
	var body_pos := base + Vector2(-body.x * 0.5, -body.y)
	var window := Rect2(base + Vector2(body.x * 0.1, -body.y * 0.66), Vector2(height * 0.16, height * 0.15))
	_draw_centered(_window_glow, window.get_center(), height * 0.75)
	draw_rect(Rect2(body_pos, body), HILL_NEAR)
	draw_colored_polygon(PackedVector2Array([body_pos + Vector2(-height * 0.12, 0),
			body_pos + Vector2(body.x * 0.45, -height * 0.5), body_pos + Vector2(body.x + height * 0.12, 0)]), HILL_NEAR)
	draw_rect(Rect2(body_pos + Vector2(body.x * 0.7, -height * 0.42), Vector2(height * 0.1, height * 0.3)), HILL_NEAR)
	draw_rect(window, AMBER)
	draw_rect(Rect2(window.position + Vector2(window.size.x * 0.46, 0), Vector2(window.size.x * 0.08, window.size.y)), HILL_NEAR)
	draw_rect(Rect2(window.position + Vector2(0, window.size.y * 0.46), Vector2(window.size.x, window.size.y * 0.08)), HILL_NEAR)


func _draw_centered(texture: Texture2D, center: Vector2, radius: float) -> void:
	draw_texture_rect(texture, Rect2(center - Vector2(radius, radius), Vector2(radius, radius) * 2.0), false)


static func _radial(offsets: Array[float], colors: Array[Color]) -> GradientTexture2D:
	var tex := GradientTexture2D.new()
	tex.gradient = _gradient(offsets, colors)
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = TEXTURE_SIZE
	tex.height = TEXTURE_SIZE
	return tex


## Vertical band: transparent → color → transparent.
static func _linear_band(color: Color) -> GradientTexture2D:
	var tex := GradientTexture2D.new()
	tex.gradient = _gradient([0.0, 0.5, 1.0], [Color(color, 0.0), color, Color(color, 0.0)])
	tex.fill_from = Vector2(0.5, 0.0)
	tex.fill_to = Vector2(0.5, 1.0)
	tex.width = 4
	tex.height = TEXTURE_SIZE
	return tex


static func _gradient(offsets: Array[float], colors: Array[Color]) -> Gradient:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array(offsets)
	g.colors = PackedColorArray(colors)
	return g
