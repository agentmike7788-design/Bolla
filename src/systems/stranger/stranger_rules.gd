class_name StrangerRules
extends RefCounted
## STUB (P5) – pure rules of Brenneisen (docs/PHASE9_DESIGN.md §2.5, §3.4): the visit days relative to p9_open_day
## (arrive_offset 2, every 5 days, 3 days), present in a region at a minute (gate / Holderkrug windows; never inside
## the cemetery), why an offer cannot be sold (fresh grave ≤ 5 days, register extract, specimens × 1.5).
## W1 (P5) fills the bodies; the signatures are the contract.


static func visit_days(_open_day: int, _cfg: StrangerConfig) -> PackedInt32Array:
	return PackedInt32Array()


static func present(_day: int, _minute: int, _region: StringName, _state: Dictionary, _cfg: StrangerConfig) -> bool:
	return false


static func offer_block_reason(_offer: StrangerOfferData, _inv: Inventory, _context: Dictionary) -> String:
	return ""
