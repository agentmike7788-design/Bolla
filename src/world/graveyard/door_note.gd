extends Node3D
## Ilse Kranich's note at the hut door (docs/PHASE4_DESIGN.md §2.11 (5), §4.2 – built by
## graveyard_build_phase4.gd as Decor/DoorNote). Pure presentation: visible while the door note
## has been found (flag trader_known) and Ilse has not been met yet (NightTrade.tools_given()).
## Re-evaluated on every game minute, after a load and on each trade (no state, not saved).

const FLAG_KNOWN := &"trader_known"
const NIGHT_TRADE_GROUP := &"night_trade"


func _ready() -> void:
	EventBus.time_tick.connect(_on_time_tick)
	EventBus.game_loaded.connect(_on_game_loaded)
	EventBus.trader_trade.connect(_on_trader_trade)
	refresh.call_deferred()


func refresh() -> void:
	if not is_inside_tree():
		return
	visible = should_show()


func should_show() -> bool:
	if not GameState.flag_on(FLAG_KNOWN):
		return false
	var trade := get_tree().get_first_node_in_group(NIGHT_TRADE_GROUP)
	return trade == null or not trade.has_method(&"tools_given") or not bool(trade.call(&"tools_given"))


func _on_time_tick(_day: int, _minute: int) -> void:
	refresh()


func _on_game_loaded(_slot: int) -> void:
	refresh()


func _on_trader_trade(_coins: int, _sold: Dictionary, _bought: Dictionary) -> void:
	refresh()
