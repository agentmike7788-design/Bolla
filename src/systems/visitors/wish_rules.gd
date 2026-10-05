class_name WishRules
extends RefCounted
## STUB (P2) – pure wish rules (docs/PHASE8_DESIGN.md §2.2.5, §3.4): the choice (order tend [only when
## neglected], flowers, candle, line, vase – turned by the grave seed), fulfilment by kind, the tip.
## W1 (P2) fills the bodies; the signatures are the contract.


## Wish id or &"".
static func choose(_grave_id: String, _kin_id: StringName, _day: int, _tree: SceneTree) -> StringName:
	return &""


static func fulfilled(_wish: Dictionary, _tree: SceneTree) -> bool:
	return false


## tip_base (+1 goodwill ≥ 6, +1 quality ≥ 15), capped by tip_cap_day − paid_today.
static func tip(_goodwill: int, _quality: int, _paid_today: int, _cfg: VisitorConfig) -> int:
	return 0
