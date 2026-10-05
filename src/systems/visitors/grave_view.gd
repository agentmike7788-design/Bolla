class_name GraveView
extends RefCounted
## STUB (P2) – how a visitor sees the grave (docs/PHASE8_DESIGN.md §2.2.4, §3.4): disturbed > neglected
## > bare > kept, + bonus (fresh flowers, a candle last night, a vase), + specimen_rumor (a specimen of
## this dead sold, once per dead; returned ones do not count).
## W1 (P2) fills the bodies; the signatures are the contract.

const VIEWS: Array[StringName] = [&"disturbed", &"neglected", &"bare", &"kept"]


## {view, bonus, specimen_rumor}.
static func view(_grave_id: String, _tree: SceneTree, _cfg: VisitorConfig) -> Dictionary:
	return {}
