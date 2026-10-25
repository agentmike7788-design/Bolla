class_name MarketStall
extends StaticBody3D
## STUB (P4) – a market stand on the Anger (docs/PHASE10_DESIGN.md §2.7.4, §2.7.5, §3.1, §4.2, §7.3–§7.5; model
## ph_prop_market_stall, child meshes only on market days 06:30–13:30, places goods_1…6). The own stand
## (stall_id market_stall_own) offers a short choice (&"action_choice", Lehren aus G9): „Am Stand: aufbauen" (10 Min,
## panel &"market_stall") · „Am Stand verkaufen (30 Min)" (ticks until 12:30) · „Stand abbauen" (5 Min); the main action
## has the focus. A foreign stand: „[E] Am Stand von … kaufen" → the shop panel &"shop" with the market head
## (Market.stall_offers / Market.buy).
## W1 (P4) fills the bodies; the signatures are the contract. W-Welt places the four stands (W2).

const PROMPT_SET_UP := "[E] Am Stand: aufbauen"
const PROMPT_SELL := "[E] Am Stand verkaufen (30 Min)"
const PROMPT_TAKE_DOWN := "[E] Stand abbauen"
const PROMPT_BUY := "[E] Am Stand von %s kaufen"
const OPTION_SET_UP := &"set_up"
const OPTION_SELL := &"sell"
const OPTION_TAKE_DOWN := &"take_down"

## ms_agathe | ms_kehr | ms_brandt | market_stall_own
@export var stall_id: StringName = &""

@onready var interactable: Interactable = get_node_or_null(^"Interactable") as Interactable


func can_interact(_player: Player) -> bool:
	return false


func get_interaction_prompt(_player: Player) -> String:
	return ""


func interact(_player: Player) -> void:
	pass


## The choice's answer at the own stand: &"set_up" | &"sell" | &"take_down".
func request_action(_id: StringName) -> void:
	pass


func is_own() -> bool:
	return stall_id == Market.OWN_STALL
