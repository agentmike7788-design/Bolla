extends OmniLight3D
## Subtle candle/lantern flicker. Scales the energy set by AtmosphereController.

@export var amount: float = 0.12
@export var speed: float = 7.0

var _t: float = randf() * 100.0
var _noise := FastNoiseLite.new()


func _process(delta: float) -> void:
	_t += delta * speed
	var base := float(get_meta("base_energy", 1.0)) * float(get_meta("scale", 1.0))
	light_energy = base * (1.0 + _noise.get_noise_1d(_t * 10.0) * amount)
