class_name ChapelRules
extends RefCounted
## STUB (P4) – pure rules of the funeral service and the devotion (docs/PHASE6_DESIGN.md §2.4,
## §3.4). W1 (P4) fills the bodies; the signatures are the contract.

const TEXT_DAYTIME := "Die Trauergäste kommen nur bei Tag."
const TEXT_DRESS := "Erst einkleiden – so legt man niemanden vor den Altar."
const TEXT_LATE := "Zu spät für eine offene Aussegnung."
const TEXT_NO_CANDLE := "Keine Altarkerze – Osric hat welche."
const TEXT_LIT := "Für dieses Grab brennt schon ein Licht."


## "" or why the service cannot start (time window, dress, freshness, already held, candle, level).
static func service_block_reason(_record: CorpseRecord, _inv: Inventory, _minute: int, _level: int, _cfg: ChapelConfig) -> String:
	return ""


## "" or why no devotion for this grave (`current` = the level already held for it, 0 = none).
static func devotion_block_reason(_grave: GraveRecord, _current: int, _inv: Inventory, _level: int, _cfg: ChapelConfig) -> String:
	return ""


## devotion_mood_by_level[level_held], capped for robbed souls (base_score + bonus ≤ devotion_robbed_cap).
static func devotion_bonus(_level_held: int, _robbed: int, _base_score: int, _cfg: ChapelConfig) -> int:
	return 0
