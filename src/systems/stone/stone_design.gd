class_name StoneDesign
extends RefCounted
## Value object of one designed gravestone (docs/PHASE5_DESIGN.md §2.5, §3.4, §5.1): shape ×
## inscription × ornament × gilding and the text fixed when it was carved. Stored as
## GraveRecord.design / Stonemasonry ready orders via to_dict (JSON-safe: Strings, bool, Array).

var shape: StringName = &""
var inscription: StringName = &""
var ornament: StringName = &""
var gilded: bool = false
## Fixed when carved (name / dates never change afterwards).
var text: PackedStringArray = []


## {} for an empty design, else {"shape", "inscription", "ornament", "gilded", "text"}.
func to_dict() -> Dictionary:
	if is_empty():
		return {}
	return {"shape": String(shape), "inscription": String(inscription), "ornament": String(ornament),
			"gilded": gilded, "text": Array(text)}


## Tolerant: missing / wrong-typed keys fall back to the defaults ({} → an empty design).
static func from_dict(d: Dictionary) -> StoneDesign:
	var out := StoneDesign.new()
	if d == null:
		return out
	out.shape = _name(d.get("shape"))
	out.inscription = _name(d.get("inscription"))
	out.ornament = _name(d.get("ornament"))
	var g: Variant = d.get("gilded", false)
	out.gilded = g is bool and g
	var t: Variant = d.get("text", [])
	if t is Array or t is PackedStringArray:
		for line: Variant in t:
			if line is String or line is StringName:
				out.text.append(str(line))
	return out


## No shape = no designed stone.
func is_empty() -> bool:
	return shape == &""


static func _name(v: Variant) -> StringName:
	return StringName(str(v)) if v is String or v is StringName else &""
