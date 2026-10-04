class_name FlickerProfile
extends Resource
## How a fire light flickers (G7 round 1: data/config/fx/<id>.tres – candle, lantern, stove, forge,
## window). FlickerLight scales the light's base energy by factor(seed, t), which always stays in
## [1 − amplitude − gust_depth, 1 + amplitude] (the minimum-brightness band the tests check), and
## warms / cools the colour a little with the same noise.

## Share of the base energy the light swings around it (0.1 = ±10 %).
@export_range(0.0, 0.5) var amplitude: float = 0.12
## Main flicker speed (noise cycles per second).
@export var frequency: float = 1.6
## 0 = a soft sine breathing, 1 = pure value noise (candles 0.8, windows 0.2).
@export_range(0.0, 1.0) var noise_mix: float = 0.8
## A second, faster noise layered on top (share of the amplitude).
@export_range(0.0, 1.0) var jitter: float = 0.35
@export var jitter_frequency: float = 7.0
## Occasional short dips (a draught): extra depth below 1 − amplitude, and how often (per second).
@export_range(0.0, 0.3) var gust_depth: float = 0.0
@export var gust_rate: float = 0.15
## Colour wobble: at full noise the colour shifts this far towards `warm_shift` (0 = colour untouched).
@export_range(0.0, 0.3) var color_wobble: float = 0.0
@export var warm_shift: Color = Color(1.0, 0.55, 0.25)
## Sparks / glow motes rising from the fire (stove, forge): count (0 = none), emission box, colour.
@export var embers: int = 0
@export var ember_box: Vector3 = Vector3(0.3, 0.1, 0.15)
@export var ember_rise: float = 0.5
@export var ember_color: Color = Color(1.0, 0.62, 0.25)
## Beyond this distance to the active camera the light holds its base energy (no per-frame work).
@export var lod_distance: float = 28.0


## The energy factor of a light with `seed` at time `t` (seconds) – deterministic and pure.
func factor(seed: int, t: float) -> float:
	var n := signal_at(seed, t)
	var f := 1.0 + n * amplitude
	if gust_depth > 0.0:
		f -= gust_depth * gust_at(seed, t)
	return f


## The flicker signal −1..1 (sine / noise mix plus jitter) at `t`.
func signal_at(seed: int, t: float) -> float:
	var phase := float(posmod(seed, 9973)) * 0.6180339
	var s := sin((t * frequency + phase) * TAU)
	var v := value_noise(seed, t * frequency)
	var main := lerpf(s, v, noise_mix)
	var j := value_noise(seed + 7919, t * jitter_frequency)
	return clampf(lerpf(main, j, jitter * 0.5), -1.0, 1.0)


## 0..1: a dip that comes now and then (smooth bump on a slow noise above its threshold).
func gust_at(seed: int, t: float) -> float:
	var g := value_noise(seed + 104729, t * gust_rate * 4.0)
	return smoothstep(0.55, 0.95, g)


## Lowest and highest factor this profile can give (the tests' brightness band).
func band() -> Vector2:
	return Vector2(1.0 - amplitude - gust_depth, 1.0 + amplitude)


## Smooth 1D value noise −1..1 (hash of the lattice points, cosine-free smoothstep).
static func value_noise(seed: int, x: float) -> float:
	var i := floori(x)
	var f := x - float(i)
	var a := _hash(seed, i)
	var b := _hash(seed, i + 1)
	var u := f * f * (3.0 - 2.0 * f)
	return lerpf(a, b, u)


static func _hash(seed: int, i: int) -> float:
	var h := (i * 374761393 + seed * 668265263) & 0x7fffffff
	h = ((h ^ (h >> 13)) * 1274126177) & 0x7fffffff
	h = h ^ (h >> 16)
	return float(h & 0xffff) / 32767.5 - 1.0
