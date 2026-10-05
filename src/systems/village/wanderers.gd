class_name Wanderers
extends Node
## STUB (P7) – Systems/Wanderers (docs/PHASE8_DESIGN.md §2.6.1, §2.6.2, §3.1, §3.4, §5.1), groups
## &"wanderers", &"saveable": Veit Ammer (alms once a day → piety, the counter, c_n_veit after 3 alms on
## different days or listening + 2) and Hanne Vogelsang (every 6th day, day % 6 == 1; her stock for the
## whole day over both stands).
## W0: alms_count answers from load_state (§5.1 {"alms"}); everything else is inert.
## W1 (P7) fills the bodies; the signatures are the contract.

const GROUP := &"wanderers"
const BEGGAR := &"beggar"
const PEDDLER := &"peddler"
const PAYMENT_REASON := "Verkauf an Hanne"

@export var save_id: String = "wanderers"
@export var save_order: int = 76

## W0 stub store (P7 may rename it – the fixtures use load_state only).
var _alms: int = 0


func _init() -> void:
	add_to_group(GROUP, true)
	add_to_group(&"saveable", true)


## The wanderer is in the world now (by his / her schedule and day).
func present(_id: StringName) -> bool:
	return false


## Hanne's day (WandererData every_days / day_rest).
func peddler_day(_day: int) -> bool:
	return false


func alms_block_reason(_inv: Inventory) -> String:
	return "-"


## coins_spent(1, &"alms"), piety alms, stats.alms_given, maybe c_n_veit.
func give_alms(_inv: Inventory) -> bool:
	return false


func alms_count() -> int:
	return _alms


## {alms, alms_day, talks, peddler_stock} (§5.1).
func save_state() -> Dictionary:
	return {}


func load_state(data: Dictionary) -> void:
	var a: Variant = data.get("alms", 0)
	_alms = maxi(0, int(a)) if a is int or a is float else 0
