class_name GraveQuality
extends RefCounted
## Grave quality and payment rules (docs §2.4).

# STUB – contract from docs/VERTICAL_SLICE_DESIGN.md. Owner replaces bodies, never signatures.

static func breakdown(corpse: CorpseRecord, marker_id: StringName, config: EconomyConfig) -> Array[Dictionary]:
	push_warning("STUB GraveQuality.breakdown")
	return []


static func compute(corpse: CorpseRecord, marker_id: StringName, config: EconomyConfig) -> int:
	push_warning("STUB GraveQuality.compute")
	return 0


static func payment(corpse: CorpseRecord, quality: int, tables: CorpseTables, config: EconomyConfig) -> int:
	push_warning("STUB GraveQuality.payment")
	return 0
