extends OmniLight3D
## Subtle candle/lantern flicker. Scales the energy set by AtmosphereController.
## Optional meta "min_scale": the light never drops below that share of its base energy –
## the hut stove keeps burning by day (docs §11, its own day factor).

@export var amount: float = 0.12
@export var speed: float = 7.0

var _t: float = randf() * 100.0
var _noise := FastNoiseLite.new()


func _process(delta: float) -> void:
	_t += delta * speed
	var scale := maxf(float(get_meta("scale", 1.0)), float(get_meta("min_scale", 0.0)))
	var base := float(get_meta("base_energy", 1.0)) * scale
	light_energy = base * (1.0 + _noise.get_noise_1d(_t * 10.0) * amount)
