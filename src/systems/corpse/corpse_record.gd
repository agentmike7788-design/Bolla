class_name CorpseRecord
extends RefCounted
## State of one corpse (pure data + helpers).

# STUB – contract from docs/VERTICAL_SLICE_DESIGN.md. Owner replaces bodies, never signatures.

var id: String = ""
var seed: int = 0
var display_name: String = ""
var age: int = 0
var cause_id: StringName = &""
var traits: Array[StringName] = []
var examined: bool = false
var shrouded: bool = false
var valuables_coins: int = 0
var valuables_decision: StringName = &""
var freshness: float = 1.0
var freshness_at_burial: float = -1.0
var last_decay_total: int = 0
var location: StringName = &"dropoff"
var position: Vector3 = Vector3.ZERO
var rot_y: float = 0.0
var grave_id: String = ""
var arrival_total_minutes: int = 0

func has_trait(t: StringName) -> bool:
	push_warning("STUB CorpseRecord.has_trait")
	return false


func revealed_traits() -> Array[StringName]:
	push_warning("STUB CorpseRecord.revealed_traits")
	return []


func freshness_stage() -> StringName:
	push_warning("STUB CorpseRecord.freshness_stage")
	return &""


func needs_valuables_decision() -> bool:
	push_warning("STUB CorpseRecord.needs_valuables_decision")
	return false


func to_dict() -> Dictionary:
	push_warning("STUB CorpseRecord.to_dict")
	return {}


static func from_dict(d: Dictionary) -> CorpseRecord:
	push_warning("STUB CorpseRecord.from_dict")
	return null
