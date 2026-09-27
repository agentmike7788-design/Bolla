class_name DecorPlacement
extends RefCounted
## One placed decor piece (docs/PHASE3_DESIGN.md §3.4), saved in DecorationManager.save_state
## as {"uid", "decor_id", "cell", "rot"} (native types: StringName, Vector2i, int).

var uid: String = ""
var decor_id: StringName = &""
## Anchor cell = bottom-left cell of the footprint (min x, min z).
var cell: Vector2i = Vector2i.ZERO
## 0..3 (× 90°).
var rot: int = 0


func to_dict() -> Dictionary:
	return {"uid": uid, "decor_id": decor_id, "cell": cell, "rot": rot}


## Accepts native values and plain JSON values (Strings, floats, [x, y] / {x, y} for the cell).
static func from_dict(d: Dictionary) -> DecorPlacement:
	var p := DecorPlacement.new()
	p.uid = str(d.get("uid", ""))
	p.decor_id = StringName(str(d.get("decor_id", "")))
	p.cell = _to_cell(d.get("cell"))
	var r: Variant = d.get("rot", 0)
	p.rot = posmod(int(r), 4) if (r is int or r is float) else 0
	return p


static func _to_cell(v: Variant) -> Vector2i:
	if v is Vector2i:
		return v
	if v is Vector2:
		return Vector2i(roundi((v as Vector2).x), roundi((v as Vector2).y))
	if v is Array and (v as Array).size() >= 2:
		return Vector2i(roundi(float((v as Array)[0])), roundi(float((v as Array)[1])))
	if v is Dictionary:
		var dict := v as Dictionary
		return Vector2i(roundi(float(dict.get("x", 0))), roundi(float(dict.get("y", 0))))
	return Vector2i.ZERO
