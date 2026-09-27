class_name GraveRecord
extends RefCounted
## State of one grave.

# STUB – contract from docs/VERTICAL_SLICE_DESIGN.md. Owner replaces bodies, never signatures.

enum State { EMPTY, DUG, FILLED, MARKED, OLD }

var id: String = ""
var state: State = State.EMPTY
var corpse_id: String = ""
var marker_id: StringName = &""
var quality: int = 0
var breakdown: Array = []

func to_dict() -> Dictionary:
	push_warning("STUB GraveRecord.to_dict")
	return {}


static func from_dict(d: Dictionary) -> GraveRecord:
	push_warning("STUB GraveRecord.from_dict")
	return null
