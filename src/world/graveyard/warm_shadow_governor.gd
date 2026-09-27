extends Node
## Render budget: the warm lights (group warm_lights) cast their shadows only while the
## time-driven atmosphere makes them matter – the light's "scale" meta (set by
## AtmosphereController from warm_light_scale) must reach min_scale. By day (scale 0.25) a
## lantern shadow is invisible but its cube shadow map would redraw every mesh in range six
## times. The shadow flag authored on the light is remembered in the meta "casts_shadow".

const GROUP := &"warm_lights"
const META_AUTHORED := &"casts_shadow"
const META_SCALE := &"scale"
## A light that never dims below this share (flicker_light.gd, the hut stove) counts with it.
const META_MIN_SCALE := &"min_scale"

@export var min_scale: float = 0.4


func _process(_delta: float) -> void:
	apply()


func apply() -> void:
	for node: Node in get_tree().get_nodes_in_group(GROUP):
		var light := node as Light3D
		if light == null:
			continue
		if not light.has_meta(META_AUTHORED):
			light.set_meta(META_AUTHORED, light.shadow_enabled)
		var scale := maxf(float(light.get_meta(META_SCALE, 1.0)), float(light.get_meta(META_MIN_SCALE, 0.0)))
		var wanted := bool(light.get_meta(META_AUTHORED)) and scale >= min_scale
		if light.shadow_enabled != wanted:
			light.shadow_enabled = wanted
