class_name Orders
extends Node
## STUB (P3) – Systems/Orders (docs/PHASE7_DESIGN.md §2.5, §3.1, §3.3, §3.4, §5.1), groups &"orders",
## &"saveable": offered → accepted → completed / failed; at most OrdersConfig.max_active accepted;
## deadlines at 06:00; the parish board offers each morning. complete pays (payment_received),
## changes relationships (Relationships.add) and reputation (Reputation.event) and calls
## Village.check_goal. Graveyard / Stonemasonry / ExpansionManager / CorpseCare report directly.
## W0: state() answers from load_state({"states": {…}}) so W1 tests can set order states
## (Phase7Fixtures.order_in) before P3 is merged; everything else is inert.
## W1 (P3) fills the bodies; the signatures are the contract.

const GROUP := &"orders"
const STATE_OFFERED := &"offered"
const STATE_ACCEPTED := &"accepted"
const STATE_COMPLETED := &"completed"
const STATE_FAILED := &"failed"
const STATES: Array[StringName] = [STATE_OFFERED, STATE_ACCEPTED, STATE_COMPLETED, STATE_FAILED]

@export var save_id: String = "orders"
@export var save_order: int = 53

## Rules; null = data/config/orders_config.tres (resolved lazily).
var config: OrdersConfig

## W0 stub store (P3 may rename it – the fixtures use load_state only).
var _states: Dictionary[StringName, StringName] = {}


func _init() -> void:
	add_to_group(GROUP, true)
	add_to_group(&"saveable", true)


## Offered order ids (of `giver`; &"" = all).
func offers(_giver: StringName = &"") -> Array[StringName]:
	return []


func active() -> Array[StringName]:
	return []


## &"" | offered | accepted | completed | failed.
func state(order_id: StringName) -> StringName:
	return _states.get(order_id, &"")


## max_active; accept_flag; order_changed.
func accept(_order_id: StringName) -> bool:
	return false


## deliver / donate atomic → complete.
func turn_in(_order_id: StringName, _inv: Inventory) -> bool:
	return false


## Reward: payment_received, Relationships.add, Reputation.event; stats.orders_done; Village.check_goal.
func complete(_order_id: StringName) -> void:
	pass


func note_grave_completed(_grave_id: String, _corpse_id: String) -> void:
	pass


func note_stone_set(_grave_id: String) -> void:
	pass


func note_section_progress(_section_id: StringName, _done: int, _total: int) -> void:
	pass


## bury orders with unharvested → broken → fail.
func note_harvest(_corpse_id: String) -> void:
	pass


## Deadlines, the tend check, board offers (idempotent per day).
func apply_morning(_day: int) -> void:
	pass


func done_count() -> int:
	return 0


func done_givers() -> PackedStringArray:
	return PackedStringArray()


## {states, accepted_day, board_day, board, history, progress} (§5.1).
func save_state() -> Dictionary:
	return {}


func load_state(data: Dictionary) -> void:
	_states.clear()
	var saved: Variant = data.get("states")
	if saved is Dictionary:
		for key: Variant in saved:
			var s := StringName(str((saved as Dictionary)[key]))
			if s in STATES:
				_states[StringName(str(key))] = s
