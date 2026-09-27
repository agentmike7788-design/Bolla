class_name DecorPlacement
extends RefCounted
## STUB (P2) – docs/PHASE3_DESIGN.md §3.4. One placed decor piece (saved in
## DecorationManager.save_state as {"uid", "decor_id", "cell", "rot"}).

var uid: String = ""
var decor_id: StringName = &""
## Anchor cell = bottom-left cell of the footprint.
var cell: Vector2i = Vector2i.ZERO
## 0..3 (× 90°).
var rot: int = 0


func to_dict() -> Dictionary:
	return {}


static func from_dict(_d: Dictionary) -> DecorPlacement:
	return DecorPlacement.new()
