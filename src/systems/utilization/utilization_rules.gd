class_name UtilizationRules
extends RefCounted
## STUB (P3) – docs/PHASE4_DESIGN.md §2.6, §3.4. Pure harvesting / selling rules.

## block_reason: button invisible (trader not known yet).
const HIDDEN := "-"


## "" = possible; HIDDEN = no button (trader not known); otherwise the dimmed reason
## ("Werkzeug fehlt – Ilse Kranich hat es.", "Das Haar ist zu brüchig.", …).
static func block_reason(_record: CorpseRecord, _kind: StringName, _inv: Inventory, _cfg: UtilizationConfig, _known: bool) -> String:
	return HIDDEN


## Σ amount × (sell_prices[item] + bonus_per_item) over `items` {item_id: amount}.
static func sale_value(_items: Dictionary, _bonus_per_item: int, _cfg: UtilizationConfig) -> int:
	return 0
