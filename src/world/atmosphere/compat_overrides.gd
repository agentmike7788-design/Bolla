class_name CompatOverrides
extends Resource
## G8 Runde 2 (Licht, „im Browser wirkt der Lichtgang heller"): the browser renderer's own values for the approved
## atmosphere presets (data/atmosphere/compat_overrides.tres). The preset files stay byte-identical (ART STYLE LOCK,
## test_atmosphere); only in the Compatibility renderer AtmosphereController works on copies of the presets with
## these AtmospherePreset.compat_* fields set, and blends them like every other field.
## presets: preset id (file name without .tres) → {field name: value}.

@export var presets: Dictionary = {}


## A copy of `preset` with the overrides of `id` (the preset itself if there are none).
func apply_to(preset: AtmospherePreset, id: String) -> AtmospherePreset:
	if preset == null or not presets.has(id):
		return preset
	var copy := preset.duplicate() as AtmospherePreset
	var values: Dictionary = presets[id]
	for key: Variant in values:
		var field := StringName(str(key))
		if not String(field).begins_with("compat_"):
			push_warning("[CompatOverrides] %s: only compat_* fields may be overridden (%s)" % [id, field])
			continue
		copy.set(field, values[key])
	copy.set_meta(&"preset_id", id)
	return copy
